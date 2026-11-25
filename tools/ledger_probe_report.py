#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""ledger_probe_report.py — анализатор замера не-гейтовых лимитеров LH (ledger/noFlag).

Инструмент для плана docs/LEDGER_LIMITER_PLAN_2026-11-24.md:
  * парсит НОВЫЙ read-only зонд ``[ledg2]`` (агрегирующие строки + sample rows);
  * режет сессии по откату match-clock > 30 c, агрегирует окна (по умолчанию
    0-300 / 300-600 / 0-600), считает метрики и инварианты;
  * применяет ПРЕДРЕГИСТРИРОВАННОЕ правило решения v1 (константы в коде);
  * опционально обогащает отчёт self_play-прокси ([SelfPlay prediction] /
    [SelfPlay last hit] / [SelfPlay last hit stats] / [SelfPlay score]);
  * опционально читает JSON ``tools/comp_filter.py --json`` для проверки состава;
  * ``--retro`` — анализ только self_play-лога (ретро-прокси вместо зонда);
  * ``--selftest`` — синтетические логи, все ветки вердикта, e2e-прогон, exit 0.

Только stdlib, Python 3.11. Ничего не запускает, живые скрипты/логи не меняет.

================================================================================
ФОРМАТ [ledg2] (контракт probe-билда, см. tools/make_ledger_probe.py)
================================================================================
Агрегирующая строка (одна не чаще 1/с match-clock), ключи регистрозависимы::

    HH:MM:SS [ledg2] clock=<float> role=<int> calls=<int> seenE=<int> ... hurtACyc=<int>

Sample-строки (до 3 на окно) — НЕ агрегируются, только считаются::

    HH:MM:SS [ledg2 row]  ...
    HH:MM:SS [ledg2 hurt] ...
    HH:MM:SS [ledg2] begin role=<int>        (маркер старта зонда)
    HH:MM:SS [ledg2] row  ...                 (тоже допустимая форма)

Обязательный набор ключей агрегирующей строки — ``clock``, ``role`` и все
54 счётчика PROBE_FIELDS. Отсутствие обязательного ключа в не-хвостовой
строке — ошибка парсинга с номером строки (формат разошёлся с контрактом).
Строка, не разобранная как агрегат (обрезана / нет numeric clock / нет
wall-префикса), пропускается и считается; если она последняя в файле,
она считается ``truncated`` (частичная запись в хвосте), а не malformed.

Сессии: split при уменьшении clock более чем на 30 c, а также по маркеру
``[ledg2] begin`` (новый begin закрывает предыдущую непустую сессию).
``--session last`` — последняя сессия; ``auto`` — сессия с максимальным clock;
``N`` — 0-based индекс.

Окна: строка включается в окно при ``lo <= clock <= hi`` (правая граница
включительно — конвенция зачётного ретро-контроля fsl3: prediction lines
0-300 = 127 требует включить строку clock=300).

================================================================================
ПРЕДРЕГИСТРИРОВАННОЕ ПРАВИЛО РЕШЕНИЯ v1 (порядок важен, константы ниже)
================================================================================
1. composition: нет --comp-json -> warning UNVERIFIED-COMPOSITION (анализ идёт);
   verdict comp_filter не в {MATCHED, MATCHED_SOLO} -> INVALID-COMPOSITION.
2. gate control (0-600): gateE/seenE > 0.15 -> INVALID-NON-GATE;
   0.05 < gate_share <= 0.15 -> флаг GATE-ACTIVE-CAUTION (вердикт не отменяет).
3. sufficiency: chkE(0-600) < 100 или tickChkE(0-600) < 30 -> INSUFFICIENT.
4. H1 ledger: noFlag_share >= 0.50 или coverage_creep < 0.60 -> LEDGER-DOMINANT
   (Stage 2b, LAYER2 §6.3).
5. H2 positioning: noFlag_share < 0.35 и coverage_creep >= 0.75 и
   coverage_tick >= 0.85 и near_share < 0.50 -> POSITIONING-DOMINANT
   (Stage 2c, LAYER2 §6.4).
6. иначе -> MIXED.
7. window stability: категория на 0-300 vs 0-600; если различаются -> флаг
   "UNSTABLE (2nd run needed)" (вердикт по 0-600 не меняется).

================================================================================
CLI
================================================================================
    python tools/ledger_probe_report.py --probe probe_ledger.log \
        [--self-play self_play.log] [--comp-json comp_filter.json] \
        [--session last|N|auto] [--windows "0-300,300-600,0-600"] \
        [--out-txt ledger_report.txt] [--out-json ledger_report.json]

    python tools/ledger_probe_report.py --retro --self-play self_play.log.fsl3 \
        --session last --out-txt retro_fsl3_ledger_proxies.txt

    python tools/ledger_probe_report.py --selftest

Exit codes: 0 — анализ выполнен (вердикт, в т.ч. INVALID-*/INSUFFICIENT, в отчёте);
1 — ошибка инструмента/парсинга (нет файла, битый формат, неверные аргументы).
Отчёты детерминированы (без timestamp), файлы пишутся в UTF-8.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys

# ==============================================================================
# Константы инструмента
# ==============================================================================

TOOL_NAME = "ledger_probe_report"
TOOL_VERSION = "1.0.0"
TOOL_DATE = "2026-11-24"

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ANALYSIS_DIR = os.path.join(ROOT, "archive", "20261124_ledger", "analysis")

DEF_WINDOWS = "0-300,300-600,0-600"
PRIMARY_WINDOW = "0-600"
SECONDARY_WINDOW = "0-300"
SESSION_CLOCK_RESET = 30.0

# --- контракт полей [ledg2]: агрегируемые суммы (точные имена) ----------------
PROBE_FIELDS = [
    "calls",
    "seenE", "seenA",
    "gateE", "denyNo",
    "stateE", "stateA",
    "farE", "farA",
    "chkE", "chkA",
    "passE", "passA",
    "noFlagE", "noFlagA",
    "noDelayE", "min0E",
    "evPosE", "evPosA",
    "ev0E", "evN1E", "evN2E", "evN4pE",
    "srcAnimE", "srcCycE", "srcPredE",
    "d350E", "d600E", "d900E", "d1300E",
    "noFlagCloseE", "passCloseE", "noFlagKillE",
    "candsE", "candsA", "chosenE", "chosenA",
    "nowinE", "unsafeE", "norouteE",
    "tickCall", "tickChkE", "tickEvE", "tickPassE", "tickCandsE", "tickChosenE",
    "hurtE", "hurtEHero", "hurtEMatch", "hurtENo", "hurtENodetect",
    "hurtEMisattr", "hurtAMatch", "hurtACyc",
]
REQUIRED_PROBE_KEYS = frozenset(["clock", "role"] + PROBE_FIELDS)

# --- предрегистрированные пороги правила v1 ----------------------------------
THRESHOLDS = {
    "gate_invalid_gt": 0.15,
    "gate_caution_gt": 0.05,
    "sufficient_chk_min": 100,
    "sufficient_tickchk_min": 30,
    "h1_noflag_min": 0.50,
    "h1_coverage_max": 0.60,
    "h2_noflag_max": 0.35,
    "h2_coverage_min": 0.75,
    "h2_tickcoverage_min": 0.85,
    "h2_near_max": 0.50,
    "hurt_recall_min_denominator": 20,
    "session_clock_reset": SESSION_CLOCK_RESET,
}
COMP_OK = ("MATCHED", "MATCHED_SOLO")

VERDICT_INVALID_COMPOSITION = "INVALID-COMPOSITION"
VERDICT_INVALID_NON_GATE = "INVALID-NON-GATE"
VERDICT_INSUFFICIENT = "INSUFFICIENT"
VERDICT_LEDGER = "LEDGER-DOMINANT"
VERDICT_POSITIONING = "POSITIONING-DOMINANT"
VERDICT_MIXED = "MIXED"
ALL_VERDICTS = [
    VERDICT_INVALID_COMPOSITION,
    VERDICT_INVALID_NON_GATE,
    VERDICT_INSUFFICIENT,
    VERDICT_LEDGER,
    VERDICT_POSITIONING,
    VERDICT_MIXED,
]

FLAG_UNVERIFIED_COMP = "UNVERIFIED-COMPOSITION"
FLAG_GATE_CAUTION = "GATE-ACTIVE-CAUTION"
FLAG_UNSTABLE = "UNSTABLE (2nd run needed)"
FLAG_INVARIANT = "INVARIANT-WARN"
FLAG_COMP_DISAGREE = "COMP-WINDOW-DISAGREE"

NEXT_STEPS = {
    VERDICT_LEDGER: (
        "Stage 2b — ledger coverage (LAYER2 §6.3): расширить источники событий входящих "
        "ударов (атаки союзных крипов/башни через LaneGroupsManager / поллинг "
        "NPC.IsAttacking) либо смягчить порог зрелости для role>3 в лейне "
        "(health < minimum*3 при creepPressure > 0). Предрегистрация + A/B."
    ),
    VERDICT_POSITIONING: (
        "Stage 2c — positioning (LAYER2 §6.4): positioning.holdSpot / helpers.laneAnchor "
        "(Self Play.lua:922-967); менять после замера myD/near_share, не «по ощущению»."
    ),
    VERDICT_MIXED: (
        "Второй matched-прогон; при подтверждении — разделять слои "
        "(ledger первым, т.к. он «ворота кандидатов», затем позиционирование)."
    ),
    VERDICT_INVALID_COMPOSITION: (
        "Повторить замер на другом matched-матче (лотерея); ничего не чинить."
    ),
    VERDICT_INVALID_NON_GATE: (
        "Повторить замер на другом matched-матче (лотерея); гейт активен — "
        "не-гейтовая интерпретация невалидна, ничего не чинить."
    ),
    VERDICT_INSUFFICIENT: (
        "Удлинить прогон (clock >= 800) или второй matched-матч: выборки "
        "недостаточно для вердикта."
    ),
}

# --- исторический baseline (только контекст, НЕ критерий) ---------------------
# Проверено по archive/20261122_layer2_ledger/probe.log: сессия, стартующая
# 23:02:25 (после отката clock), gate=0; суммs за 0-600 совпадают с планом §7.2.
# ВНИМАНИЕ: старый [ledger]-зонд probe2 смешивал allied+enemy счётчики,
# другой билд/база; enemy-only разбивки нет. Только порядок величин.
HISTORICAL_BASELINE = {
    "label": "old [ledger] probe2, gate-free session (mixed allied+enemy creeps)",
    "source": "archive/20261122_layer2_ledger/probe.log",
    "session_note": "сессия стартует wall 23:02:25 (split по clock reset), gate=0",
    "window": "0-600",
    "raw": {
        "seen": 9238,
        "chk": 3749,
        "gate": 0,
        "denyNo": 5243,
        "pass_flag": 2258,
        "noFlag_hpHiEv0": 1491,
        "evPos": 2005,
        "ev0": 1744,
        "cands": 274,
        "chosen": 234,
        "nowin": 1979,
        "noroute": 90,
    },
    "caveats": [
        "смешанные allied+enemy счётчики (enemy-only разбивки нет)",
        "старый probe2 другой базы/билда (064A9938 на F52C), без tick-уровня",
        "используется только как порядок величин, не как критерий",
    ],
}

# --- контрольные числа lead'а для зачётного ретро-прогона fsl3 ----------------
RETRO_CONTROL_FSL3 = {
    "self_play_md5": "C3199A8F076E056058D2FAFC76432F4B",
    "session_marker": "2026-11-23 23:50:13",
    "windows": {
        "0-300": {
            "prediction_lines": 127,
            "prediction_added_gt0": 68,
            "prediction_added_gt0_pct": 54,
            "last_hit_lines": 19,
            "last_hit_allied": 7,
            "last_hit_enemy": 12,
            "last_hit_events0": 3,
            "stats_died": 30,
            "stats_in_reach": 17,
            "stats_ours": 4,
            "stats_attempts": 17,
        },
        "0-600": {
            "prediction_lines": 224,
            "prediction_added_gt0": 100,
            "prediction_added_gt0_pct": 45,
            "last_hit_lines": 22,
            "last_hit_allied": 8,
            "last_hit_enemy": 14,
            "last_hit_events0": 5,
            "stats_died": 46,
            "stats_in_reach": 24,
            "stats_ours": 4,
            "stats_attempts": 22,
        },
    },
    "lh5": 5,
    "lh10": 7,
}

CAVEATS_PROBE = [
    "счётчики [ledg2] — суммы по интервалам; окна считаются по match-clock из агрегатной строки",
    "строка с clock == правой границе окна включается в окно (конвенция ретро-контроля fsl3)",
    "строки с clock < 0 (если зонд успел записать до horn) не входят в окна 0-N, "
    "но входят в session_total; на метрики не влияют, если счётчики нулевые",
    "sample-строки [ledg2 row]/[ledg2 hurt] не агрегируются, только считаются",
    "noFlag_share — прокси фильтра зрелости: не различает noFlag и позиционные/тайминговые причины",
    "hurt_recall консервативен: знаменатель hurtE-hurtEHero, необходим >= 20; только ближние lane-удары",
    "вердикт диагностический и не запускает правку кода (Stage 2b/2c — отдельная предрегистрация)",
    "composition берётся из comp_filter JSON; при отсутствии --comp-json состав UNVERIFIED",
    "исторический baseline — смешанные allied+enemy счётчики старого probe2, только контекст",
]
CAVEATS_RETRO = [
    "ретро-прокси не заменяют [ledg2]: events==0 не различает noFlag/noDelay/min0",
    "in reach/ours — из агрегатов [SelfPlay last hit stats] (60-с окна), не точное условие lastHit.plan",
    "окна по line-префиксу [m:ss]; строка с clock == правой границе окна включается в окно",
    "префикс [-0:01] трактуется как +1 c (конвенция tools/analyze_selfplay_log.py): "
    "pre-horn строки входят в окна 0-300/0-600 — так воспроизводятся контрольные числа fsl3",
    "LH@5/LH@10 — первый [SelfPlay score] с clock >= 300/>= 600 (конвенция ACCEPTANCE/comp_filter)",
    "LH и XP сравниваются с эталоном только на MATCHED/MATCHED_SOLO (ACCEPTANCE §10.2)",
    "исторический baseline — смешанные allied+enemy счётчики старого probe2, только контекст",
]

# ==============================================================================
# Регулярные выражения
# ==============================================================================

RE_PROBE_WALL_LINE = re.compile(r"^(\d\d:\d\d:\d\d)\s+(.*)$")
RE_PROBE_TAG = re.compile(r"^\[ledg2(?: (row|hurt|begin))?\]\s*(.*)$")
RE_PROBE_VERB_BODY = re.compile(r"^(begin|row|hurt)\b(.*)$")
RE_PROBE_KV = re.compile(r"([A-Za-z_][A-Za-z0-9_]*)=(-?\d+(?:\.\d+)?)")
RE_INT = re.compile(r"^-?\d+$")
RE_WINDOW = re.compile(r"^\s*(-?\d+(?:\.\d+)?)\s*-\s*(-?\d+(?:\.\d+)?)\s*$")
RE_SESSION_SELECTOR = re.compile(r"^(last|auto|\d+)$")

RE_SP_MARKER = re.compile(r"^===== Self Play session (.*?) =====\s*$")
RE_SP_PREFIX = re.compile(r"^\[(-?\d+):(\d\d)\]")
RE_SP_KV = re.compile(r"([A-Za-z][A-Za-z0-9_]*)=(-?[\d.]+)")
RE_SP_HERO = re.compile(r"hero=(\S+)")
RE_SP_PRED_ADDED = re.compile(r"addedHits=(-?\d+)")
RE_SP_PRED_HERO_INC = re.compile(r"heroIncoming=(-?\d+)")
RE_SP_LH_TARGET = re.compile(r"target=(\S+)")
RE_SP_LH_EVENTS = re.compile(r"events=(-?\d+)")
RE_SP_LH_HP = re.compile(r"\bhp=(-?\d+)")
RE_SP_LH_DAMAGE = re.compile(r"damage=(-?\d+)")
RE_SP_LH_INRANGE = re.compile(r"inRange=(true|false)")
RE_SP_STATS = re.compile(
    r"\[SelfPlay last hit stats\] \d+s: (\d+) enemy creeps died near us "
    r"\((\d+) in reach\) -> ours (\d+), our creeps/tower (\d+), ally heroes (\d+), "
    r"enemy heroes (\d+); denies (\d+), enemy denies (\d+); attempts (\d+)"
)

# ==============================================================================
# Ошибки
# ==============================================================================


class ToolError(Exception):
    """Ошибка инструмента/аргументов/ввода (exit code 1)."""


class ProbeParseError(ToolError):
    """Нарушение контракта [ledg2] с номером строки."""

    def __init__(self, line_no: int, message: str):
        self.line_no = line_no
        self.message = message
        super().__init__(f"строка {line_no}: {message}")


# ==============================================================================
# Утилиты
# ==============================================================================


def _configure_streams() -> None:
    """UTF-8 stdout/stderr, чтобы русский текст отчёта не зависел от локали."""
    for name in ("stdout", "stderr"):
        stream = getattr(sys, name, None)
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, ValueError, OSError):
            pass


def md5_file(path: str) -> str:
    h = hashlib.md5()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest().upper()


def file_info(path: str) -> dict:
    if not os.path.exists(path):
        raise ToolError(f"файл не найден: {path}")
    if not os.path.isfile(path):
        raise ToolError(f"не файл: {path}")
    st = os.stat(path)
    return {
        "path": os.path.abspath(path),
        "size": int(st.st_size),
        "md5": md5_file(path),
    }


def read_lines(path: str) -> list:
    if not os.path.exists(path):
        raise ToolError(f"файл не найден: {path}")
    if not os.path.isfile(path):
        raise ToolError(f"не файл: {path}")
    with open(path, encoding="utf-8", errors="replace") as f:
        return f.read().splitlines()


def write_text_file(path: str, text: str) -> None:
    directory = os.path.dirname(os.path.abspath(path))
    if directory:
        os.makedirs(directory, exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)


def write_json_file(path: str, obj) -> None:
    text = json.dumps(obj, ensure_ascii=False, indent=1) + "\n"
    write_text_file(path, text)


def _num(x: float) -> str:
    return str(int(x)) if float(x).is_integer() else f"{x:g}"


def _f3(x):
    return "n/a" if x is None else f"{x:.3f}"


def _pct1(x):
    return "n/a" if x is None else f"{100.0 * x:.1f}%"


def _ratio(a, b):
    return (float(a) / float(b)) if b else None


def _as_num(s: str):
    try:
        return float(s)
    except (TypeError, ValueError):
        return None


def _as_int(s: str):
    if s is None:
        return None
    if RE_INT.match(s):
        return int(s)
    f = _as_num(s)
    if f is not None and float(f).is_integer():
        return int(f)
    return None


def format_table(headers, rows, aligns=None) -> str:
    """Простая выровненная таблица (строки — списки str)."""
    headers = [str(h) for h in headers]
    if aligns is None:
        aligns = ["l"] * len(headers)
    widths = []
    for i, h in enumerate(headers):
        w = len(h)
        for row in rows:
            if i < len(row):
                w = max(w, len(str(row[i])))
        widths.append(w)
    out = []
    out.append("  ".join(h.ljust(widths[i]) if aligns[i] == "l" else h.rjust(widths[i])
                         for i, h in enumerate(headers)))
    out.append("  ".join("-" * widths[i] for i in range(len(headers))))
    for row in rows:
        cells = []
        for i in range(len(headers)):
            cell = str(row[i]) if i < len(row) else ""
            cells.append(cell.ljust(widths[i]) if aligns[i] == "l" else cell.rjust(widths[i]))
        out.append("  ".join(cells))
    return "\n".join(out)


def section(title: str) -> str:
    bar = "=" * 88
    return f"\n{bar}\n{title}\n{bar}"


# ==============================================================================
# Разбор --windows
# ==============================================================================


def parse_windows(spec: str) -> list:
    windows = []
    names = set()
    if not spec or not spec.strip():
        raise ToolError("--windows пуст")
    for token in spec.split(","):
        token = token.strip()
        if not token:
            raise ToolError(f"--windows: пустой элемент в {spec!r}")
        m = RE_WINDOW.match(token)
        if not m:
            raise ToolError(f"--windows: не разобрать {token!r} (ожидается LO-HI)")
        lo, hi = float(m.group(1)), float(m.group(2))
        if not hi > lo:
            raise ToolError(f"--windows: HI <= LO в {token!r}")
        name = f"{_num(lo)}-{_num(hi)}"
        if name in names:
            raise ToolError(f"--windows: дубликат окна {name}")
        names.add(name)
        windows.append({"name": name, "lo": lo, "hi": hi})
    return windows


def window_names(windows: list) -> list:
    return [w["name"] for w in windows]


def _in_window(clock, window: dict) -> bool:
    """lo <= clock <= hi (правая граница включительно)."""
    return window["lo"] <= clock <= window["hi"]


# ==============================================================================
# Парсинг [ledg2]
# ==============================================================================


def _note_skip(result: dict, kind: str, line_no: int, line: str, detail: str = "") -> None:
    result[kind + "_lines"] += 1
    samples = result[kind + "_samples"]
    if len(samples) < 8:
        text = line.strip()
        if len(text) > 120:
            text = text[:117] + "..."
        samples.append(f"line {line_no}: {text}" + (f" [{detail}]" if detail else ""))


def parse_probe_lines(lines: list) -> dict:
    """Разобрать строки лога [ledg2] (без файлового I/O — для selftest)."""
    result = {
        "lines_total": len(lines),
        "ledg2_lines": 0,
        "aggregate_lines": 0,
        "malformed_lines": 0,
        "truncated_lines": 0,
        "row_samples": 0,
        "hurt_samples": 0,
        "begin_markers": 0,
        "malformed_samples": [],
        "truncated_samples": [],
        "unknown_keys": [],
        "no_wall_lines": 0,
        "aggregates": [],
        "sessions": [],
    }
    last_content = -1
    for i, line in enumerate(lines):
        if line.strip():
            last_content = i

    events = []
    unknown = set()
    aggregate_events = []

    for i, line in enumerate(lines):
        if "[ledg2" not in line:
            continue
        result["ledg2_lines"] += 1
        lineno = i + 1
        at_eof = i == last_content

        m_wall = RE_PROBE_WALL_LINE.match(line)
        if m_wall:
            wall = m_wall.group(1)
            rest = m_wall.group(2)
        else:
            wall = ""
            rest = line
        m_tag = RE_PROBE_TAG.match(rest)
        if not m_tag:
            _note_skip(result, "malformed", lineno, line, "нет тега [ledg2]")
            continue
        kind = m_tag.group(1)
        body = m_tag.group(2) or ""
        if kind is None:
            m_verb = RE_PROBE_VERB_BODY.match(body)
            if m_verb:
                kind = m_verb.group(1)
                body = m_verb.group(2) or ""
            else:
                kind = "aggregate"

        if kind in ("row", "hurt"):
            events.append({"kind": kind, "line_no": lineno, "wall": wall})
            if kind == "row":
                result["row_samples"] += 1
            else:
                result["hurt_samples"] += 1
            continue

        if kind == "begin":
            bm_role = None
            rm = re.search(r"role=(-?\d+)", body)
            if rm:
                bm_role = int(rm.group(1))
            result["begin_markers"] += 1
            events.append({"kind": "begin", "line_no": lineno, "wall": wall,
                           "role": bm_role})
            continue

        # --- агрегирующая строка --------------------------------------------
        if not wall:
            result["no_wall_lines"] += 1
        kv = {}
        for km in RE_PROBE_KV.finditer(body):
            kv[km.group(1)] = km.group(2)

        if "clock" not in kv:
            if at_eof:
                _note_skip(result, "truncated", lineno, line, "нет numeric clock (хвост)")
            else:
                _note_skip(result, "malformed", lineno, line, "нет numeric clock")
            continue
        clock = _as_num(kv["clock"])
        if clock is None:
            if at_eof:
                _note_skip(result, "truncated", lineno, line, "clock не число (хвост)")
            else:
                _note_skip(result, "malformed", lineno, line, "clock не число")
            continue

        missing = [k for k in PROBE_FIELDS if k not in kv]
        if "role" not in kv:
            missing = ["role"] + missing
        if missing:
            short = ", ".join(missing[:8]) + ("..." if len(missing) > 8 else "")
            if at_eof:
                _note_skip(result, "truncated", lineno, line, "нет ключей: " + short)
                continue
            raise ProbeParseError(lineno, "missing required key(s): " + short)

        role = _as_int(kv["role"])
        if role is None:
            raise ProbeParseError(lineno, f"role не integer: {kv['role']!r}")

        ints = {}
        bad_fields = []
        for f in PROBE_FIELDS:
            v = _as_int(kv[f])
            if v is None:
                bad_fields.append(f)
            else:
                ints[f] = v
        if bad_fields:
            raise ProbeParseError(
                lineno, "non-integer field(s): " + ", ".join(bad_fields[:8])
            )

        unknown.update(k for k in kv if k not in REQUIRED_PROBE_KEYS)
        agg = {"kind": "aggregate", "line_no": lineno, "wall": wall, "clock": clock,
               "role": role, "kv": ints}
        events.append(agg)
        aggregate_events.append(agg)
        result["aggregate_lines"] += 1

    # --- сессии: split по откату clock > 30 и по маркеру [ledg2] begin ---------
    sessions = []
    cur = None

    def _new_session(wall, line_no):
        return {
            "aggregates": [],
            "begin_markers": [],
            "row_samples": 0,
            "hurt_samples": 0,
            "start_wall": wall,
            "start_line": line_no,
        }

    for ev in events:
        if ev["kind"] == "begin":
            if cur is not None and cur["aggregates"]:
                sessions.append(cur)
                cur = None
            if cur is None:
                cur = _new_session(ev["wall"], ev["line_no"])
            cur["begin_markers"].append({"line_no": ev["line_no"], "wall": ev["wall"],
                                         "role": ev.get("role")})
            continue
        if ev["kind"] in ("row", "hurt"):
            if cur is None:
                cur = _new_session(ev["wall"], ev["line_no"])
            if ev["kind"] == "row":
                cur["row_samples"] += 1
            else:
                cur["hurt_samples"] += 1
            continue
        # aggregate
        if cur is None:
            cur = _new_session(ev["wall"], ev["line_no"])
        elif cur["aggregates"] and ev["clock"] < cur["aggregates"][-1]["clock"] - SESSION_CLOCK_RESET:
            sessions.append(cur)
            cur = _new_session(ev["wall"], ev["line_no"])
        cur["aggregates"].append(ev)

    if cur is not None:
        sessions.append(cur)

    sessions = [s for s in sessions if s["aggregates"]]
    for idx, s in enumerate(sessions):
        s["index"] = idx
        s["info"] = _session_info(s)

    result["aggregates"] = aggregate_events
    result["sessions"] = sessions
    result["unknown_keys"] = sorted(unknown)
    if aggregate_events:
        roles = sorted({a["role"] for a in aggregate_events})
    else:
        roles = []
    result["roles"] = roles
    return result


def _session_info(session: dict) -> dict:
    aggs = session["aggregates"]
    clocks = [a["clock"] for a in aggs]
    walls = [a["wall"] or None for a in aggs]
    return {
        "index": session.get("index", -1),
        "n_aggregates": len(aggs),
        "first_wall": walls[0],
        "last_wall": walls[-1],
        "first_clock": clocks[0],
        "last_clock": clocks[-1],
        "clock_min": min(clocks),
        "clock_max": max(clocks),
        "roles": sorted({a["role"] for a in aggs}),
        "row_samples": session["row_samples"],
        "hurt_samples": session["hurt_samples"],
        "begin_markers": len(session["begin_markers"]),
    }


def parse_probe(path: str) -> dict:
    lines = read_lines(path)
    info = file_info(path)
    result = parse_probe_lines(lines)
    result.update(info)
    return result


def select_probe_session(sessions: list, selector: str):
    if not sessions:
        raise ToolError("в probe-логе нет ни одной сессии с агрегатными строками [ledg2]")
    n = len(sessions)
    if selector == "last":
        return sessions[-1], "last"
    if selector == "auto":
        best = max(sessions, key=lambda s: (s["info"]["clock_max"], s["info"]["index"]))
        return best, "auto (max clock)"
    if RE_INT.match(selector):
        idx = int(selector)
        if idx < 0 or idx >= n:
            raise ToolError(f"--session {idx}: доступно сессий {n} (0..{n - 1})")
        return sessions[idx], f"N={idx}"
    raise ToolError(f"--session {selector!r}: ожидается last|auto|N")


# ==============================================================================
# Агрегация и метрики [ledg2]
# ==============================================================================


def aggregate_probe_window(session: dict, window: dict) -> dict:
    sums = {f: 0 for f in PROBE_FIELDS}
    n_lines = 0
    clocks = []
    for agg in session["aggregates"]:
        if _in_window(agg["clock"], window):
            n_lines += 1
            clocks.append(agg["clock"])
            for f in PROBE_FIELDS:
                sums[f] += agg["kv"][f]
    return {
        "name": window["name"],
        "lo": window["lo"],
        "hi": window["hi"],
        "n_lines": n_lines,
        "clock_min": min(clocks) if clocks else None,
        "clock_max": max(clocks) if clocks else None,
        "sums": sums,
    }


def compute_metrics(sums: dict) -> dict:
    src_total = sums["srcAnimE"] + sums["srcCycE"] + sums["srcPredE"]
    hurt_den = sums["hurtE"] - sums["hurtEHero"]
    metrics = {
        "gate_share": _ratio(sums["gateE"], sums["seenE"]),
        "noFlag_share": _ratio(sums["noFlagE"], sums["passE"] + sums["noFlagE"]),
        "noFlag_share_chk": _ratio(sums["noFlagE"], sums["chkE"]),
        "coverage_creep": _ratio(sums["evPosE"], sums["chkE"]),
        "coverage_tick": _ratio(sums["tickEvE"], sums["tickChkE"]),
        "hurt_recall": _ratio(sums["hurtEMatch"], hurt_den)
        if hurt_den >= THRESHOLDS["hurt_recall_min_denominator"] else None,
        "near_share": _ratio(sums["d350E"], sums["chkE"]),
        "pass_close_share": _ratio(sums["passCloseE"], sums["chkE"]),
        "cand_rate": _ratio(sums["candsE"], sums["passE"]),
        "conversion": _ratio(sums["chosenE"], sums["candsE"]),
        "nowin_share": _ratio(sums["nowinE"], sums["candsE"]),
        "unsafe_share": _ratio(sums["unsafeE"], sums["candsE"]),
        "noflag_close_share": _ratio(sums["noFlagCloseE"], sums["noFlagE"]),
        "noflag_kill_share": _ratio(sums["noFlagKillE"], sums["noFlagE"]),
        "pass_share": _ratio(sums["passE"], sums["chkE"]),
        "nodelay_share": _ratio(sums["noDelayE"], sums["chkE"]),
        "min0_share": _ratio(sums["min0E"], sums["chkE"]),
        "source_mix": {
            "srcAnim": _ratio(sums["srcAnimE"], src_total),
            "srcCyc": _ratio(sums["srcCycE"], src_total),
            "srcPred": _ratio(sums["srcPredE"], src_total),
        },
        "source_rate": {
            "srcAnim": _ratio(sums["srcAnimE"], sums["chkE"]),
            "srcCyc": _ratio(sums["srcCycE"], sums["chkE"]),
            "srcPred": _ratio(sums["srcPredE"], sums["chkE"]),
        },
        "hurt_recall_denominator": hurt_den,
        "hurt_recall_applicable": hurt_den >= THRESHOLDS["hurt_recall_min_denominator"],
    }
    return metrics


def check_invariants(sums: dict) -> list:
    """Инварианты probe-контракта: предупреждаем, НЕ падаем."""
    checks = []

    rhs = sums["passE"] + sums["noFlagE"] + sums["noDelayE"] + sums["min0E"]
    checks.append({
        "name": "chkE == passE+noFlagE+noDelayE+min0E",
        "ok": sums["chkE"] == rhs,
        "lhs": sums["chkE"],
        "rhs": rhs,
        "delta": sums["chkE"] - rhs,
    })

    dsum = sums["d350E"] + sums["d600E"] + sums["d900E"] + sums["d1300E"]
    checks.append({
        "name": "d350E+d600E+d900E+d1300E <= chkE",
        "ok": dsum <= sums["chkE"],
        "lhs": dsum,
        "rhs": sums["chkE"],
        "delta": dsum - sums["chkE"],
    })

    esum = sums["evPosE"] + sums["ev0E"]
    checks.append({
        "name": "evPosE+ev0E == chkE",
        "ok": esum == sums["chkE"],
        "lhs": esum,
        "rhs": sums["chkE"],
        "delta": esum - sums["chkE"],
    })

    checks.append({
        "name": "chosenE <= candsE <= passE",
        "ok": sums["chosenE"] <= sums["candsE"] <= sums["passE"],
        "lhs": f"{sums['chosenE']}/{sums['candsE']}/{sums['passE']}",
        "rhs": "",
        "delta": "",
    })
    return checks


def invariants_ok(checks: list) -> bool:
    return all(c["ok"] for c in checks)


# ==============================================================================
# Вердикт v1
# ==============================================================================


def dominant_category(metrics: dict) -> str:
    """H1 -> H2 -> MIXED (пороги предрегистрации)."""
    noflag = metrics.get("noFlag_share")
    cov = metrics.get("coverage_creep")
    tickcov = metrics.get("coverage_tick")
    near = metrics.get("near_share")

    if (noflag is not None and noflag >= THRESHOLDS["h1_noflag_min"]) or (
        cov is not None and cov < THRESHOLDS["h1_coverage_max"]
    ):
        return VERDICT_LEDGER
    if (
        noflag is not None and noflag < THRESHOLDS["h2_noflag_max"]
        and cov is not None and cov >= THRESHOLDS["h2_coverage_min"]
        and tickcov is not None and tickcov >= THRESHOLDS["h2_tickcoverage_min"]
        and near is not None and near < THRESHOLDS["h2_near_max"]
    ):
        return VERDICT_POSITIONING
    return VERDICT_MIXED


def _norm_verdict(v):
    if not isinstance(v, str):
        return None
    return v.strip().upper().replace(" ", "")


def _session_marker_mismatch(comp, marker) -> bool:
    """comp_filter JSON относится к другой self-play сессии, чем анализируемая."""
    if not comp or not marker:
        return False
    comp_session = comp.get("session")
    if not comp_session:
        return False
    return str(comp_session).strip() != str(marker).strip()


def evaluate_verdict(window_results: list, comp: dict) -> dict:
    """Предрегистрированное правило v1; primary window = 0-600."""
    by_name = {w["name"]: w for w in window_results}
    primary = by_name.get(PRIMARY_WINDOW)
    if primary is None:
        raise ToolError(
            f"для вердикта v1 нужно окно {PRIMARY_WINDOW} в --windows "
            f"(получено: {', '.join(by_name)})"
        )
    flags = []
    pm = primary["metrics"]
    ps = primary["sums"]

    # --- 1. composition ------------------------------------------------------
    comp_check = {
        "provided": comp is not None,
        "verdict": None,
        "source": None,
        "ok": None,
        "reason": None,
    }
    if comp is None:
        flags.append(FLAG_UNVERIFIED_COMP)
        comp_check["reason"] = "нет --comp-json"
    else:
        comp_check["verdict"] = comp.get("verdict")
        comp_check["source"] = comp.get("chosen_key")
        if _norm_verdict(comp.get("verdict")) in {_norm_verdict(x) for x in COMP_OK}:
            comp_check["ok"] = True
        else:
            comp_check["ok"] = False
            comp_check["reason"] = (
                f"verdict {comp.get('verdict')!r} не в {{MATCHED, MATCHED_SOLO}}"
            )
        distinct = {_norm_verdict(v) for v in comp.get("verdicts", {}).values()}
        if len(distinct) > 1:
            flags.append(FLAG_COMP_DISAGREE)

    # --- 2. gate control -----------------------------------------------------
    gate_share = pm.get("gate_share")
    gate_check = {
        "gate_share": gate_share,
        "gateE": ps["gateE"],
        "seenE": ps["seenE"],
        "status": "UNKNOWN",
        "invalid": False,
        "caution": False,
    }
    if gate_share is None:
        gate_check["status"] = "UNKNOWN (seenE=0)"
    elif gate_share > THRESHOLDS["gate_invalid_gt"]:
        gate_check["status"] = "INVALID-NON-GATE"
        gate_check["invalid"] = True
    elif gate_share > THRESHOLDS["gate_caution_gt"]:
        gate_check["status"] = "CAUTION"
        gate_check["caution"] = True
        flags.append(FLAG_GATE_CAUTION)
    else:
        gate_check["status"] = "OK"

    # --- 3. sufficiency ------------------------------------------------------
    suff_check = {
        "chkE": ps["chkE"],
        "tickChkE": ps["tickChkE"],
        "chk_min": THRESHOLDS["sufficient_chk_min"],
        "tickchk_min": THRESHOLDS["sufficient_tickchk_min"],
        "ok": (ps["chkE"] >= THRESHOLDS["sufficient_chk_min"]
               and ps["tickChkE"] >= THRESHOLDS["sufficient_tickchk_min"]),
    }

    # --- 4/5. H1 / H2 (primary window) --------------------------------------
    cat_primary = dominant_category(pm)
    h1 = {
        "noFlag_share": pm.get("noFlag_share"),
        "coverage_creep": pm.get("coverage_creep"),
        "noflag_condition": (pm.get("noFlag_share") is not None
                             and pm["noFlag_share"] >= THRESHOLDS["h1_noflag_min"]),
        "coverage_condition": (pm.get("coverage_creep") is not None
                               and pm["coverage_creep"] < THRESHOLDS["h1_coverage_max"]),
        "confirmed": cat_primary == VERDICT_LEDGER,
    }
    h2 = {
        "noFlag_share": pm.get("noFlag_share"),
        "coverage_creep": pm.get("coverage_creep"),
        "coverage_tick": pm.get("coverage_tick"),
        "near_share": pm.get("near_share"),
        "confirmed": cat_primary == VERDICT_POSITIONING,
    }

    # --- 6. окна: категории и stability -------------------------------------
    categories = {w["name"]: dominant_category(w["metrics"]) for w in window_results}
    stability = {
        "available": (SECONDARY_WINDOW in categories and PRIMARY_WINDOW in categories),
        f"category_{SECONDARY_WINDOW}": categories.get(SECONDARY_WINDOW),
        f"category_{PRIMARY_WINDOW}": categories.get(PRIMARY_WINDOW),
        "stable": None,
    }
    if stability["available"]:
        stability["stable"] = (
            categories[SECONDARY_WINDOW] == categories[PRIMARY_WINDOW]
        )
        if not stability["stable"]:
            flags.append(FLAG_UNSTABLE)
    else:
        flags.append("WINDOW-STABILITY-NA")

    # --- 7. итоговая категория ----------------------------------------------
    if comp_check["ok"] is False:
        category = VERDICT_INVALID_COMPOSITION
    elif gate_check["invalid"]:
        category = VERDICT_INVALID_NON_GATE
    elif not suff_check["ok"]:
        category = VERDICT_INSUFFICIENT
    else:
        category = cat_primary

    if not invariants_ok(primary["invariants"]):
        flags.append(FLAG_INVARIANT)

    next_step = NEXT_STEPS[category]
    if FLAG_UNSTABLE in flags:
        next_step += (
            " Плюс: окна расходятся (UNSTABLE) — решение о правке отложить "
            "до второго прогона."
        )

    return {
        "category": category,
        "primary_window": PRIMARY_WINDOW,
        "flags": flags,
        "checks": {
            "composition": comp_check,
            "gate_control": gate_check,
            "sufficiency": suff_check,
            "h1_ledger": h1,
            "h2_positioning": h2,
            "window_stability": stability,
        },
        "categories_by_window": categories,
        "next_step": next_step,
        "next_steps_all": NEXT_STEPS,
    }


# ==============================================================================
# comp_filter JSON
# ==============================================================================


def load_comp_json(path: str) -> dict:
    info = file_info(path)
    with open(path, encoding="utf-8", errors="replace") as f:
        try:
            data = json.load(f)
        except json.JSONDecodeError as e:
            raise ToolError(f"comp-json {path}: битый JSON: {e}")
    if not isinstance(data, dict):
        raise ToolError(f"comp-json {path}: ожидался объект JSON")

    windows = data.get("windows")
    verdicts = {}
    if isinstance(windows, dict):
        for key, value in windows.items():
            if isinstance(value, dict) and isinstance(value.get("verdict"), str):
                verdicts[str(key)] = value["verdict"]
    if not verdicts:
        for key, value in data.items():
            if isinstance(value, dict) and isinstance(value.get("verdict"), str):
                verdicts[str(key)] = value["verdict"]
    top = data.get("verdict") if isinstance(data.get("verdict"), str) else None

    chosen_key = None
    chosen_verdict = None
    for key in ("lh10", "lh5", "early"):
        if key in verdicts:
            chosen_key, chosen_verdict = key, verdicts[key]
            break
    if chosen_verdict is None and verdicts:
        chosen_key = sorted(verdicts)[0]
        chosen_verdict = verdicts[chosen_key]
    if chosen_verdict is None and top:
        chosen_key, chosen_verdict = "top-level", top

    return {
        "path": info["path"],
        "size": info["size"],
        "md5": info["md5"],
        "session": data.get("session"),
        "our": data.get("our") if isinstance(data.get("our"), dict) else None,
        "primary": data.get("primary"),
        "verdicts": verdicts,
        "top_level_verdict": top,
        "chosen_key": chosen_key,
        "verdict": chosen_verdict,
    }


# ==============================================================================
# Self-play: парсинг и прокси-метрики
# ==============================================================================


def sp_prefix_clock(line: str):
    """[m:ss] -> секунды; конвенция tools/analyze_selfplay_log.py: int(mm)*60+ss.

    ВАЖНО: префикс ``[-0:01]`` (pre-horn строки) по этой конвенции даёт +1 c,
    а не -1: именно так считает существующий хелпер (``int("-0")*60 + 1``), и
    именно эта конвенция воспроизводит контрольные числа lead'а для fsl3
    (29 pre-horn [SelfPlay prediction] строк входят в окна 0-300 / 0-600:
    98+29 = 127 prediction-строк за 0-300). Других отрицательных префиксов
    в архивах не встречается (проверено: только ``[-0:01]``).
    """
    m = RE_SP_PREFIX.match(line)
    if not m:
        return None
    return int(m.group(1)) * 60 + int(m.group(2))


def _parse_score_line(line: str) -> dict:
    kv = dict(RE_SP_KV.findall(line))
    clock = _as_num(kv.get("clock"))
    hero_m = RE_SP_HERO.search(line)
    return {
        "kind": "score",
        "prefix_clock": sp_prefix_clock(line),
        "clock": clock,
        "hero": hero_m.group(1) if hero_m else None,
        "role": _as_int(kv.get("role")),
        "lane": _as_int(kv.get("lane")),
        "lastHits": _as_int(kv.get("lastHits")),
        "denies": _as_int(kv.get("denies")),
        "xp": _as_int(kv.get("xp")),
        "networth": _as_int(kv.get("networth")),
    }


def _parse_record(line: str):
    if "[SelfPlay score]" in line:
        return _parse_score_line(line)
    if "[SelfPlay prediction]" in line:
        m = RE_SP_PRED_ADDED.search(line)
        mh = RE_SP_PRED_HERO_INC.search(line)
        return {
            "kind": "prediction",
            "prefix_clock": sp_prefix_clock(line),
            "addedHits": int(m.group(1)) if m else None,
            "heroIncoming": int(mh.group(1)) if mh else None,
        }
    if "[SelfPlay last hit]" in line:
        mt = RE_SP_LH_TARGET.search(line)
        me = RE_SP_LH_EVENTS.search(line)
        mi = RE_SP_LH_INRANGE.search(line)
        mh = RE_SP_LH_HP.search(line)
        md = RE_SP_LH_DAMAGE.search(line)
        target = mt.group(1) if mt else ""
        return {
            "kind": "last_hit",
            "prefix_clock": sp_prefix_clock(line),
            "target": target,
            "allied": "goodguys" in target,
            "enemy": "badguys" in target,
            "events": int(me.group(1)) if me else None,
            "hp": int(mh.group(1)) if mh else None,
            "damage": int(md.group(1)) if md else None,
            "inRange": (mi.group(1) == "true") if mi else None,
        }
    if "last hit stats" in line:
        m = RE_SP_STATS.search(line)
        if not m:
            return None
        return {
            "kind": "stats",
            "prefix_clock": sp_prefix_clock(line),
            "died": int(m.group(1)),
            "in_reach": int(m.group(2)),
            "ours": int(m.group(3)),
            "our_creeps": int(m.group(4)),
            "ally_heroes": int(m.group(5)),
            "enemy_heroes": int(m.group(6)),
            "denies": int(m.group(7)),
            "enemy_denies": int(m.group(8)),
            "attempts": int(m.group(9)),
        }
    return None


def parse_self_play_lines(lines: list) -> dict:
    """Разбить self_play-лог по маркерам сессий и разобрать записи."""
    sessions = []
    cur = None
    markers_count = 0
    has_marker = any(RE_SP_MARKER.match(l) for l in lines)

    if has_marker:
        for i, line in enumerate(lines):
            m = RE_SP_MARKER.match(line)
            if m:
                markers_count += 1
                cur = {"marker": m.group(1).strip(), "line_no": i + 1, "lines": []}
                sessions.append(cur)
                continue
            if cur is not None:
                cur["lines"].append(line)
    else:
        cur = {"marker": None, "line_no": 1, "lines": []}
        sessions.append(cur)
        prev = None
        for i, line in enumerate(lines):
            c = sp_prefix_clock(line)
            if c is not None and prev is not None and c < prev - SESSION_CLOCK_RESET:
                cur = {"marker": None, "line_no": i + 1, "lines": []}
                sessions.append(cur)
            cur["lines"].append(line)
            if c is not None:
                prev = c

    for idx, sess in enumerate(sessions):
        sess["index"] = idx
        recs = []
        for line in sess["lines"]:
            rec = _parse_record(line)
            if rec is not None:
                recs.append(rec)
        sess["records"] = recs
        clocks = []
        for rec in recs:
            if rec.get("prefix_clock") is not None:
                clocks.append(rec["prefix_clock"])
            elif rec.get("clock") is not None:
                clocks.append(rec["clock"])
        sess["info"] = {
            "index": idx,
            "marker": sess["marker"],
            "line_no": sess["line_no"],
            "n_lines": len(sess["lines"]),
            "n_records": len(recs),
            "n_scores": sum(1 for r in recs if r["kind"] == "score"),
            "clock_min": min(clocks) if clocks else None,
            "clock_max": max(clocks) if clocks else None,
        }
    return {
        "sessions": sessions,
        "markers_count": markers_count,
        "has_markers": has_marker,
    }


def parse_self_play(path: str) -> dict:
    lines = read_lines(path)
    info = file_info(path)
    result = parse_self_play_lines(lines)
    result.update(info)
    result["lines_total"] = len(lines)
    return result


def select_self_play_session(sessions: list, selector: str):
    candidates = [s for s in sessions if s["lines"]]
    if not candidates:
        raise ToolError("в self_play-логе нет сессий с содержимым")
    n = len(candidates)
    if selector == "last":
        return candidates[-1], "last"
    if selector == "auto":
        with_clock = [s for s in candidates
                      if s["info"]["clock_max"] is not None]
        if not with_clock:
            return candidates[-1], "auto (no clock; last)"
        best = max(with_clock, key=lambda s: (s["info"]["clock_max"], s["info"]["index"]))
        return best, "auto (max clock)"
    if RE_INT.match(selector):
        idx = int(selector)
        if idx < 0 or idx >= n:
            raise ToolError(f"--session {idx}: доступно сессий {n} (0..{n - 1})")
        return candidates[idx], f"N={idx}"
    raise ToolError(f"--session {selector!r}: ожидается last|auto|N")


def sp_window_metrics(session: dict, window: dict) -> dict:
    pred_lines = pred_pos = pred_sum = pred_hero_inc = 0
    lh_lines = lh_allied = lh_enemy = lh_other = lh_ev0 = lh_ev_sum = 0
    lh_inrange = 0
    stats_lines = 0
    stats = {
        "died": 0, "in_reach": 0, "ours": 0, "our_creeps": 0,
        "ally_heroes": 0, "enemy_heroes": 0, "denies": 0,
        "enemy_denies": 0, "attempts": 0,
    }
    for rec in session["records"]:
        clock = rec.get("prefix_clock")
        if clock is None or not _in_window(clock, window):
            continue
        kind = rec["kind"]
        if kind == "prediction":
            if rec.get("addedHits") is None:
                continue
            pred_lines += 1
            pred_sum += rec["addedHits"]
            if rec["addedHits"] > 0:
                pred_pos += 1
            if rec.get("heroIncoming"):
                pred_hero_inc += rec["heroIncoming"]
        elif kind == "last_hit":
            lh_lines += 1
            if rec.get("allied"):
                lh_allied += 1
            elif rec.get("enemy"):
                lh_enemy += 1
            else:
                lh_other += 1
            if rec.get("events") is not None:
                lh_ev_sum += rec["events"]
                if rec["events"] == 0:
                    lh_ev0 += 1
            if rec.get("inRange"):
                lh_inrange += 1
        elif kind == "stats":
            stats_lines += 1
            for key in stats:
                stats[key] += rec.get(key, 0)

    def _safe_share(a, b):
        return _ratio(a, b)

    return {
        "name": window["name"],
        "lo": window["lo"],
        "hi": window["hi"],
        "prediction_lines": pred_lines,
        "prediction_added_gt0": pred_pos,
        "prediction_added_gt0_share": _safe_share(pred_pos, pred_lines),
        "prediction_added_gt0_pct": (int(round(100.0 * pred_pos / pred_lines))
                                     if pred_lines else None),
        "prediction_added_sum": pred_sum,
        "prediction_hero_incoming_sum": pred_hero_inc,
        "last_hit_lines": lh_lines,
        "last_hit_allied": lh_allied,
        "last_hit_enemy": lh_enemy,
        "last_hit_other": lh_other,
        "last_hit_events0": lh_ev0,
        "last_hit_events0_share": _safe_share(lh_ev0, lh_lines),
        "last_hit_mean_events": (float(lh_ev_sum) / lh_lines if lh_lines else None),
        "last_hit_inrange": lh_inrange,
        "stats_lines": stats_lines,
        "stats": stats,
        "ours_per_in_reach": _safe_share(stats["ours"], stats["in_reach"]),
        "attempts_per_in_reach": _safe_share(stats["attempts"], stats["in_reach"]),
    }


def sp_score_metrics(session: dict) -> dict:
    scores = [r for r in session["records"]
              if r["kind"] == "score" and r.get("clock") is not None]

    def first_ge(threshold):
        for rec in scores:
            if rec["clock"] >= threshold:
                return rec
        return None

    def pack(rec):
        if rec is None:
            return None
        return {
            "lh": rec.get("lastHits"),
            "denies": rec.get("denies"),
            "xp": rec.get("xp"),
            "networth": rec.get("networth"),
            "clock": rec.get("clock"),
            "hero": rec.get("hero"),
            "role": rec.get("role"),
            "lane": rec.get("lane"),
        }

    return {
        "n_scores": len(scores),
        "lh5": pack(first_ge(300)),
        "lh10": pack(first_ge(600)),
        "final": pack(scores[-1] if scores else None),
        "source": "score",
        "anchor": "first score with clock >= N",
    }


# ==============================================================================
# Ретро-контроль lead'а
# ==============================================================================


def check_retro_controls(sp_info: dict, session: dict, window_metrics: list,
                         score_metrics: dict) -> dict:
    control = {"applicable": False, "reason": "", "items": [],
               "passed": 0, "total": 0}
    if sp_info["md5"].upper() != RETRO_CONTROL_FSL3["self_play_md5"]:
        control["reason"] = (
            "md5 не совпадает с архивным self_play.log.fsl3 "
            f"({RETRO_CONTROL_FSL3['self_play_md5']})"
        )
        return control
    marker = session.get("marker")
    if marker != RETRO_CONTROL_FSL3["session_marker"]:
        control["reason"] = (
            f"выбранная сессия {marker!r} != зачётная "
            f"{RETRO_CONTROL_FSL3['session_marker']!r}"
        )
        return control

    control["applicable"] = True
    by_name = {w["name"]: w for w in window_metrics}
    for wname, expected_map in RETRO_CONTROL_FSL3["windows"].items():
        wm = by_name.get(wname)
        for key, expected in expected_map.items():
            actual = None
            if wm is not None:
                if key in ("prediction_lines", "prediction_added_gt0",
                           "prediction_added_gt0_pct", "last_hit_lines",
                           "last_hit_allied", "last_hit_enemy", "last_hit_events0"):
                    actual = wm.get(key)
                elif key == "stats_died":
                    actual = wm["stats"]["died"]
                elif key == "stats_in_reach":
                    actual = wm["stats"]["in_reach"]
                elif key == "stats_ours":
                    actual = wm["stats"]["ours"]
                elif key == "stats_attempts":
                    actual = wm["stats"]["attempts"]
            control["items"].append({
                "window": wname, "item": key, "expected": expected,
                "actual": actual, "ok": actual == expected,
            })

    for key, expected in (("lh5", RETRO_CONTROL_FSL3["lh5"]),
                          ("lh10", RETRO_CONTROL_FSL3["lh10"])):
        packed = score_metrics.get(key) or {}
        actual = packed.get("lh")
        control["items"].append({
            "window": "session", "item": key, "expected": expected,
            "actual": actual, "ok": actual == expected,
        })

    control["total"] = len(control["items"])
    control["passed"] = sum(1 for it in control["items"] if it["ok"])
    return control


# ==============================================================================
# Сборка отчёта: probe analysis
# ==============================================================================


def _fmt_clock_range(info: dict) -> str:
    lo = info.get("clock_min")
    hi = info.get("clock_max")
    if lo is None or hi is None:
        return "n/a"
    return f"{_num(float(lo))}..{_num(float(hi))}"


def _fmt_wall_range(info: dict) -> str:
    first = info.get("first_wall") or "n/a"
    last = info.get("last_wall") or "n/a"
    return f"{first}..{last}"


def analyze_probe(probe_path, self_play_path=None, comp_json_path=None,
                  selector="last", windows_spec=DEF_WINDOWS,
                  out_txt=None, out_json=None, console=True, synthetic=False):
    windows = parse_windows(windows_spec)
    names = window_names(windows)
    if PRIMARY_WINDOW not in names:
        raise ToolError(
            f"для вердикта v1 в --windows должно быть окно {PRIMARY_WINDOW} "
            f"(получено: {', '.join(names)})"
        )

    probe = parse_probe(probe_path)
    if not probe["aggregates"]:
        raise ToolError(
            f"в {probe_path} нет агрегатных строк [ledg2] "
            f"(ledg2_lines={probe['ledg2_lines']}, malformed={probe['malformed_lines']})"
        )
    session, reason = select_probe_session(probe["sessions"], selector)
    session_info = dict(session["info"])
    session_info["reason"] = reason

    window_results = []
    for window in windows:
        agg = aggregate_probe_window(session, window)
        agg["metrics"] = compute_metrics(agg["sums"])
        agg["invariants"] = check_invariants(agg["sums"])
        window_results.append(agg)

    session_sums = {f: 0 for f in PROBE_FIELDS}
    for agg in session["aggregates"]:
        for f in PROBE_FIELDS:
            session_sums[f] += agg["kv"][f]
    session_total = {
        "n_aggregates": len(session["aggregates"]),
        "sums": session_sums,
        "metrics": compute_metrics(session_sums),
        "invariants": check_invariants(session_sums),
    }

    comp = load_comp_json(comp_json_path) if comp_json_path else None
    verdict = evaluate_verdict(window_results, comp)

    self_play = None
    if self_play_path:
        sp = parse_self_play(self_play_path)
        sp_session, sp_reason = select_self_play_session(sp["sessions"], selector)
        sp_windows = [sp_window_metrics(sp_session, w) for w in windows]
        sp_scores = sp_score_metrics(sp_session)
        self_play = {
            "path": sp["path"],
            "size": sp["size"],
            "md5": sp["md5"],
            "lines_total": sp["lines_total"],
            "markers_count": sp["markers_count"],
            "sessions_total": len(sp["sessions"]),
            "selected_session": {
                **sp_session["info"],
                "reason": sp_reason,
            },
            "windows": sp_windows,
            "scores": sp_scores,
        }

    honesty_flags = []
    if synthetic:
        honesty_flags.append("SYNTHETIC-FIXTURE")
    if comp is None:
        honesty_flags.append(FLAG_UNVERIFIED_COMP)
    if probe["malformed_lines"]:
        honesty_flags.append("MALFORMED-LINES-SKIPPED")
    if probe["truncated_lines"]:
        honesty_flags.append("TRUNCATED-TAIL-SKIPPED")
    if probe["row_samples"] or probe["hurt_samples"]:
        honesty_flags.append("SAMPLE-ROWS-NOT-AGGREGATED")
    if probe["no_wall_lines"]:
        honesty_flags.append("NO-WALL-PREFIX")
    if probe["unknown_keys"]:
        honesty_flags.append("UNKNOWN-PROBE-KEYS")
    if len(session_info["roles"]) > 1:
        honesty_flags.append("PROBE-MULTI-ROLE")
    if session_info["roles"] and max(session_info["roles"]) < 4:
        honesty_flags.append("PROBE-ROLE-LT4")
    if self_play is None:
        honesty_flags.append("SELF-PLAY-NOT-PROVIDED")
    elif comp is not None and _session_marker_mismatch(
            comp, self_play["selected_session"].get("marker")):
        honesty_flags.append("COMP-SESSION-MISMATCH")
    honesty_flags.extend(verdict["flags"])
    honesty_flags = list(dict.fromkeys(honesty_flags))  # порядок без дубликатов

    report = {
        "kind": "ledger_probe_report",
        "mode": "selftest-e2e" if synthetic else "probe",
        "synthetic": bool(synthetic),
        "tool": {"name": TOOL_NAME, "version": TOOL_VERSION, "date": TOOL_DATE},
        "inputs": {
            "probe": {
                "path": probe["path"],
                "size": probe["size"],
                "md5": probe["md5"],
            },
            "self_play": ({"path": self_play["path"], "size": self_play["size"],
                           "md5": self_play["md5"]} if self_play else None),
            "comp_json": ({"path": comp["path"], "size": comp["size"],
                           "md5": comp["md5"]} if comp else None),
        },
        "windows_spec": [{"name": w["name"], "lo": w["lo"], "hi": w["hi"]}
                         for w in windows],
        "probe_parse": {
            "lines_total": probe["lines_total"],
            "ledg2_lines": probe["ledg2_lines"],
            "aggregate_lines": probe["aggregate_lines"],
            "malformed_lines": probe["malformed_lines"],
            "truncated_lines": probe["truncated_lines"],
            "malformed_samples": probe["malformed_samples"],
            "truncated_samples": probe["truncated_samples"],
            "row_samples": probe["row_samples"],
            "hurt_samples": probe["hurt_samples"],
            "begin_markers": probe["begin_markers"],
            "no_wall_lines": probe["no_wall_lines"],
            "unknown_keys": probe["unknown_keys"],
            "roles": probe["roles"],
            "sessions_total": len(probe["sessions"]),
            "sessions": [dict(s["info"]) for s in probe["sessions"]],
            "selected_session": session_info,
            "selected_reason": reason,
        },
        "comp": comp,
        "windows": window_results,
        "session_total": session_total,
        "verdict": verdict,
        "self_play": self_play,
        "historical_baseline": HISTORICAL_BASELINE,
        "thresholds": dict(THRESHOLDS),
        "caveats": CAVEATS_PROBE,
        "honesty_flags": honesty_flags,
    }

    text = build_probe_report_text(report)

    if out_txt:
        write_text_file(out_txt, text)
    if out_json:
        write_json_file(out_json, report)

    if console:
        print(build_probe_console_summary(report, out_txt, out_json))
        if not out_txt:
            print(text)
    return 0, report, text


def build_probe_console_summary(report: dict, out_txt, out_json) -> str:
    inputs = report["inputs"]
    parse_info = report["probe_parse"]
    selected = parse_info["selected_session"]
    lines = [f"{TOOL_NAME} v{TOOL_VERSION} | probe analysis ([ledg2])"]
    lines.append(f"probe    : {inputs['probe']['path']} "
                 f"(size={inputs['probe']['size']}, md5={inputs['probe']['md5']})")
    if inputs.get("self_play"):
        sp = inputs["self_play"]
        lines.append(f"self-play: {sp['path']} (size={sp['size']}, md5={sp['md5']})")
    if inputs.get("comp_json"):
        cj = inputs["comp_json"]
        lines.append(f"comp-json: {cj['path']} (size={cj['size']}, md5={cj['md5']})")
    lines.append(
        f"session  : #{selected['index']} ({selected['reason']}) "
        f"wall {_fmt_wall_range(selected)} "
        f"clock {_fmt_clock_range(selected)} "
        f"aggregates={selected['n_aggregates']} roles={selected['roles']}"
    )
    lines.append("windows  : " + ", ".join(w["name"] for w in report["windows"]))
    primary = next((w for w in report["windows"] if w["name"] == PRIMARY_WINDOW), None)
    if primary:
        m = primary["metrics"]
        lines.append(
            f"0-600    : gate_share={_f3(m['gate_share'])} "
            f"noFlag_share={_f3(m['noFlag_share'])} "
            f"coverage_creep={_f3(m['coverage_creep'])} "
            f"coverage_tick={_f3(m['coverage_tick'])} "
            f"near_share={_f3(m['near_share'])}"
        )
    verdict = report["verdict"]
    lines.append(f"VERDICT  : {verdict['category']}")
    lines.append("FLAGS    : " + (", ".join(verdict["flags"]) if verdict["flags"] else "(none)"))
    lines.append(f"next step: {verdict['next_step']}")
    if out_txt:
        lines.append(f"TXT      : {os.path.abspath(out_txt)}")
    if out_json:
        lines.append(f"JSON     : {os.path.abspath(out_json)}")
    if not out_txt:
        lines.append("(полный отчёт напечатан ниже; --out-txt сохранит его в файл)")
    return "\n".join(lines)


# ==============================================================================
# Текст отчёта: probe analysis
# ==============================================================================

METRIC_ROWS = [
    ("gate_share", "gate_share"),
    ("noFlag_share (primary)", "noFlag_share"),
    ("noFlag_share_chk", "noFlag_share_chk"),
    ("coverage_creep", "coverage_creep"),
    ("coverage_tick", "coverage_tick"),
    ("hurt_recall", "hurt_recall"),
    ("near_share", "near_share"),
    ("pass_close_share", "pass_close_share"),
    ("cand_rate", "cand_rate"),
    ("conversion", "conversion"),
    ("nowin_share", "nowin_share"),
    ("unsafe_share", "unsafe_share"),
    ("noflag_close_share", "noflag_close_share"),
    ("noflag_kill_share", "noflag_kill_share"),
    ("pass_share", "pass_share"),
    ("noDelay_share", "nodelay_share"),
    ("min0_share", "min0_share"),
    ("source_anim_mix", ("source_mix", "srcAnim")),
    ("source_cyc_mix", ("source_mix", "srcCyc")),
    ("source_pred_mix", ("source_mix", "srcPred")),
]


def _metric_value(metrics: dict, key):
    if isinstance(key, tuple):
        value = metrics
        for part in key:
            if not isinstance(value, dict):
                return None
            value = value.get(part)
        return value
    return metrics.get(key)


def _metrics_table(window_results: list) -> str:
    headers = ["metric"] + [w["name"] for w in window_results]
    rows = []
    for label, key in METRIC_ROWS:
        row = [label]
        for w in window_results:
            row.append(_f3(_metric_value(w["metrics"], key)))
        rows.append(row)
    return format_table(headers, rows, aligns=["l"] + ["r"] * len(window_results))


def _counts_table(window_results: list) -> str:
    headers = ["count"] + [w["name"] for w in window_results]
    rows = []
    for field in PROBE_FIELDS:
        row = [field]
        for w in window_results:
            row.append(str(w["sums"][field]))
        rows.append(row)
    return format_table(headers, rows, aligns=["l"] + ["r"] * len(window_results))


def _invariants_block(title: str, checks: list) -> list:
    out = [f"{title}:"]
    for check in checks:
        status = "OK  " if check["ok"] else "WARN"
        detail = ""
        if check["name"].startswith("chosenE"):
            detail = f" (chosen/cands/pass = {check['lhs']})"
        else:
            detail = (f" (lhs={check['lhs']}, rhs={check['rhs']}, "
                      f"delta={check['delta']})")
        out.append(f"  [{status}] {check['name']}{detail}")
    return out


def _sp_table(window_metrics: list) -> str:
    headers = ["metric"] + [w["name"] for w in window_metrics]
    rows = [
        ("prediction lines", lambda w: str(w["prediction_lines"])),
        ("prediction addedHits>0", lambda w: str(w["prediction_added_gt0"])),
        ("prediction addedHits>0 share",
         lambda w: _pct1(w["prediction_added_gt0_share"])),
        ("prediction addedHits sum", lambda w: str(w["prediction_added_sum"])),
        ("last-hit lines", lambda w: str(w["last_hit_lines"])),
        ("  allied (goodguys)", lambda w: str(w["last_hit_allied"])),
        ("  enemy (badguys)", lambda w: str(w["last_hit_enemy"])),
        ("  events==0", lambda w: str(w["last_hit_events0"])),
        ("  events==0 share", lambda w: _pct1(w["last_hit_events0_share"])),
        ("  mean events", lambda w: _f3(w["last_hit_mean_events"])),
        ("stats lines", lambda w: str(w["stats_lines"])),
        ("  died near us", lambda w: str(w["stats"]["died"])),
        ("  in reach", lambda w: str(w["stats"]["in_reach"])),
        ("  ours", lambda w: str(w["stats"]["ours"])),
        ("  attempts", lambda w: str(w["stats"]["attempts"])),
        ("  ours/in_reach", lambda w: _pct1(w["ours_per_in_reach"])),
    ]
    table_rows = []
    for label, fn in rows:
        table_rows.append([label] + [fn(w) for w in window_metrics])
    return format_table(headers, table_rows, aligns=["l"] + ["r"] * len(window_metrics))


def build_probe_report_text(report: dict) -> str:
    out = []
    out.append("=" * 88)
    out.append(
        f"LEDGER/NOFLAG [ledg2] — ОТЧЁТ АНАЛИЗАТОРА  "
        f"({report['tool']['name']} v{report['tool']['version']})"
    )
    out.append("=" * 88)
    out.append("Режим: probe analysis нового read-only зонда [ledg2]; Dota не запускается,")
    out.append("живые скрипты/логи не меняются. Окна: "
               + ", ".join(w["name"] for w in report["windows"])
               + " (правая граница включительно).")
    if report.get("synthetic"):
        out.append("ВНИМАНИЕ: SYNTHETIC FIXTURE — данные сгенерированы --selftest, "
                   "это НЕ замер и не прогон Dota.")

    # 1. provenance
    out.append(section("1. ВХОДЫ / PROVENANCE"))
    inputs = report["inputs"]
    out.append(f"probe     : {inputs['probe']['path']}")
    out.append(f"            size={inputs['probe']['size']} bytes  md5={inputs['probe']['md5']}")
    if inputs.get("self_play"):
        sp = inputs["self_play"]
        out.append(f"self-play : {sp['path']}")
        out.append(f"            size={sp['size']} bytes  md5={sp['md5']}")
    else:
        out.append("self-play : не передан (self-play enrichment отключён)")
    if inputs.get("comp_json"):
        cj = inputs["comp_json"]
        out.append(f"comp-json : {cj['path']}")
        out.append(f"            size={cj['size']} bytes  md5={cj['md5']}")
    else:
        out.append("comp-json : не передан (состав UNVERIFIED-COMPOSITION)")
    out.append(f"tool      : {TOOL_NAME} v{TOOL_VERSION} ({TOOL_DATE})")

    # 2. parse
    pp = report["probe_parse"]
    out.append(section("2. ПАРСИНГ [ledg2] И СЕССИИ"))
    out.append(f"lines_total={pp['lines_total']}  ledg2_lines={pp['ledg2_lines']}  "
               f"aggregate_lines={pp['aggregate_lines']}")
    out.append(f"malformed_skipped={pp['malformed_lines']}  "
               f"truncated_skipped={pp['truncated_lines']}  "
               f"row_samples={pp['row_samples']}  hurt_samples={pp['hurt_samples']}  "
               f"begin_markers={pp['begin_markers']}  "
               f"no_wall_prefix={pp['no_wall_lines']}")
    out.append(f"roles (весь лог): {pp['roles']}  unknown_keys: "
               + (", ".join(pp["unknown_keys"]) if pp["unknown_keys"] else "(none)"))
    if pp["malformed_samples"]:
        out.append("malformed (первые):")
        for sample in pp["malformed_samples"]:
            out.append("  " + sample)
    if pp["truncated_samples"]:
        out.append("truncated (первые):")
        for sample in pp["truncated_samples"]:
            out.append("  " + sample)
    out.append("")
    out.append(f"сессии (split по откату clock > {_num(SESSION_CLOCK_RESET)} c "
               f"и по маркеру [ledg2] begin), всего {pp['sessions_total']}:")
    session_rows = []
    for sess in pp["sessions"]:
        session_rows.append([
            str(sess["index"]),
            f"{_fmt_wall_range(sess)}",
            f"{_num(float(sess['clock_min']))}..{_num(float(sess['clock_max']))}",
            str(sess["n_aggregates"]),
            str(sess["row_samples"]),
            str(sess["hurt_samples"]),
            str(sess["begin_markers"]),
            str(sess["roles"]),
        ])
    out.append(format_table(
        ["#", "wall", "clock", "agg", "row", "hurt", "begin", "roles"],
        session_rows,
        aligns=["r", "l", "l", "r", "r", "r", "r", "l"],
    ))
    selected = pp["selected_session"]
    out.append("")
    out.append(f"ВЫБРАННАЯ СЕССИЯ: #{selected['index']} ({pp['selected_reason']})")
    out.append(f"  wall  {_fmt_wall_range(selected)}")
    out.append(f"  clock {_fmt_clock_range(selected)}  aggregates={selected['n_aggregates']}")
    out.append(f"  roles={selected['roles']}  row_samples={selected['row_samples']}  "
               f"hurt_samples={selected['hurt_samples']}")

    # 3. composition
    out.append(section("3. СОСТАВ (composition context)"))
    comp = report.get("comp")
    verdict = report["verdict"]
    comp_check = verdict["checks"]["composition"]
    if comp is None:
        out.append("comp_filter verdict: UNVERIFIED-COMPOSITION (--comp-json не передан)")
        out.append("  анализ продолжен; вердикт не может быть INVALID-COMPOSITION.")
    else:
        windows_txt = ", ".join(f"{k}={v}" for k, v in sorted(comp["verdicts"].items()))
        out.append(f"comp_filter verdict: {comp['verdict']!r} "
                   f"(источник: {comp['chosen_key']})")
        out.append(f"  session={comp.get('session')!r}  windows: {windows_txt or '(n/a)'}")
        if comp.get("top_level_verdict"):
            out.append(f"  top-level verdict={comp['top_level_verdict']!r}")
        if comp_check["ok"]:
            out.append("  -> OK: вердикт в {MATCHED, MATCHED_SOLO}")
        else:
            out.append(f"  -> INVALID-COMPOSITION ({comp_check['reason']})")
        sp_sel = (report.get("self_play") or {}).get("selected_session") or {}
        if _session_marker_mismatch(comp, sp_sel.get("marker")):
            out.append("  ВНИМАНИЕ: comp-json относится к другой self-play сессии "
                       "(COMP-SESSION-MISMATCH) — сверять с run-book вручную.")

    # 4. metrics
    out.append(section("4. МЕТРИКИ ПО ОКНАМ (доли 0..1; n/a = нет знаменателя)"))
    out.append(_metrics_table(report["windows"]))
    hurt_note = (f"hurt_recall: знаменатель hurtE-hurtEHero; N/A при значении "
                 f"< {THRESHOLDS['hurt_recall_min_denominator']}")
    out.append("")
    out.append(hurt_note + "; primary window = " + PRIMARY_WINDOW + ".")

    # 5. counts
    out.append(section("5. COUNTS / RAW SUMS ПО ОКНАМ"))
    out.append(_counts_table(report["windows"]))

    # 6. invariants
    out.append(section("6. ИНВАРИАНТЫ (предупреждение, не ошибка)"))
    for w in report["windows"]:
        out.extend(_invariants_block(f"окно {w['name']} (n_lines={w['n_lines']})",
                                     w["invariants"]))
        out.append("")
    out.extend(_invariants_block("сессия целиком", report["session_total"]["invariants"]))

    # 7. verdict
    out.append(section("7. ВЕРДИКТ (pre-registered v1)"))
    checks = verdict["checks"]
    gate = checks["gate_control"]
    suff = checks["sufficiency"]
    h1 = checks["h1_ledger"]
    h2 = checks["h2_positioning"]
    stab = checks["window_stability"]
    if comp_check["ok"] is True:
        out.append("composition  : OK (в {MATCHED, MATCHED_SOLO})")
    elif comp_check["ok"] is False:
        out.append(f"composition  : INVALID-COMPOSITION ({comp_check['reason']})")
    else:
        out.append("composition  : UNVERIFIED-COMPOSITION (warning; анализ продолжен)")
    out.append(f"gate control : gate_share({PRIMARY_WINDOW}) = "
               f"{_f3(gate['gate_share'])} "
               f"({gate['gateE']}/{gate['seenE']}) -> {gate['status']}")
    out.append(f"  пороги: >{THRESHOLDS['gate_invalid_gt']} = INVALID-NON-GATE; "
               f"{THRESHOLDS['gate_caution_gt']}..{THRESHOLDS['gate_invalid_gt']} = "
               f"GATE-ACTIVE-CAUTION")
    out.append(f"sufficiency  : chkE={suff['chkE']} (>= {suff['chk_min']}), "
               f"tickChkE={suff['tickChkE']} (>= {suff['tickchk_min']}) -> "
               + ("OK" if suff["ok"] else "INSUFFICIENT"))
    out.append(f"H1 ledger    : noFlag_share={_f3(h1['noFlag_share'])} "
               f"(>= {THRESHOLDS['h1_noflag_min']}? {h1['noflag_condition']}); "
               f"coverage_creep={_f3(h1['coverage_creep'])} "
               f"(< {THRESHOLDS['h1_coverage_max']}? {h1['coverage_condition']}) "
               f"-> {'CONFIRMED' if h1['confirmed'] else 'not confirmed'}")
    out.append(f"H2 positioning: noFlag_share={_f3(h2['noFlag_share'])} "
               f"(< {THRESHOLDS['h2_noflag_max']}), "
               f"coverage_creep={_f3(h2['coverage_creep'])} "
               f"(>= {THRESHOLDS['h2_coverage_min']}), "
               f"coverage_tick={_f3(h2['coverage_tick'])} "
               f"(>= {THRESHOLDS['h2_tickcoverage_min']}), "
               f"near_share={_f3(h2['near_share'])} "
               f"(< {THRESHOLDS['h2_near_max']}) "
               f"-> {'CONFIRMED' if h2['confirmed'] else 'not confirmed'}")
    if stab["available"]:
        out.append(f"window stability: {SECONDARY_WINDOW}={stab['category_' + SECONDARY_WINDOW]} "
                   f"vs {PRIMARY_WINDOW}={stab['category_' + PRIMARY_WINDOW]} -> "
                   + ("STABLE" if stab["stable"] else "UNSTABLE (2nd run needed)"))
    else:
        out.append("window stability: N/A (нужны окна "
                   f"{SECONDARY_WINDOW} и {PRIMARY_WINDOW})")
    out.append("")
    out.append(f"VERDICT: {verdict['category']}")
    out.append("FLAGS: " + (", ".join(verdict["flags"]) if verdict["flags"] else "(none)"))
    out.append(f"NEXT STEP: {verdict['next_step']}")
    out.append("")
    out.append("mapping (pre-registered):")
    for category in ALL_VERDICTS:
        marker = "  <-- ВЫБРАНО" if category == verdict["category"] else ""
        out.append(f"  {category:20s} -> {NEXT_STEPS[category]}{marker}")

    # 8. self-play
    self_play = report.get("self_play")
    out.append(section("8. SELF-PLAY ENRICHMENT (опционально)"))
    if self_play is None:
        out.append("не передан --self-play; секция пропущена.")
    else:
        sel = self_play["selected_session"]
        out.append(f"self_play: {self_play['path']}")
        out.append(f"  size={self_play['size']} bytes md5={self_play['md5']} "
                   f"lines={self_play['lines_total']} sessions={self_play['sessions_total']}")
        out.append(f"  сессия: {sel.get('marker')!r} (index={sel['index']}, "
                   f"{sel.get('reason')}), scores={sel['n_scores']}, "
                   f"clock {_fmt_clock_range(sel)}")
        out.append("")
        out.append(_sp_table(self_play["windows"]))
        scores = self_play["scores"]

        def _packed(packed):
            if not packed:
                return "n/a"
            return (f"LH={packed['lh']} denies={packed['denies']} xp={packed['xp']} "
                    f"@ clock {packed['clock']}")

        out.append("")
        out.append("LH-метрики ([SelfPlay score], first score clock >= N):")
        out.append(f"  LH@5  = {_packed(scores['lh5'])}")
        out.append(f"  LH@10 = {_packed(scores['lh10'])}")
        out.append(f"  final = {_packed(scores['final'])}")

    # 9. baseline
    out.append(section("9. ИСТОРИЧЕСКИЙ BASELINE (контекст, НЕ критерий)"))
    baseline = report["historical_baseline"]
    raw = baseline["raw"]
    out.append(f"{baseline['label']}")
    out.append(f"  source: {baseline['source']} ({baseline['session_note']}), "
               f"окно {baseline['window']}")
    out.append(f"  seen={raw['seen']} chk={raw['chk']} gate={raw['gate']} "
               f"denyNo={raw['denyNo']} pass(flag)={raw['pass_flag']} "
               f"noFlag(hpHiEv0)={raw['noFlag_hpHiEv0']}")
    out.append(f"  evPos={raw['evPos']} ev0={raw['ev0']} cands={raw['cands']} "
               f"chosen={raw['chosen']} nowin={raw['nowin']} noroute={raw['noroute']}")
    out.append(
        "  производные: noFlag_share = "
        f"{raw['noFlag_hpHiEv0']}/({raw['pass_flag']}+{raw['noFlag_hpHiEv0']}) = "
        f"{raw['noFlag_hpHiEv0']}/{raw['chk']} = "
        f"{raw['noFlag_hpHiEv0'] / raw['chk']:.3f} (~0.40); "
        f"evPos/chk = {raw['evPos'] / raw['chk']:.3f} (~0.53); "
        f"cands/chk = {raw['cands'] / raw['chk']:.3f} (~0.07); "
        f"chosen/cands = {raw['chosen'] / raw['cands']:.3f} (~0.85)"
    )
    out.append("  ОГОВОРКИ (baseline — только порядок величин):")
    for caveat in baseline["caveats"]:
        out.append("    - " + caveat)

    # 10. caveats + honesty
    out.append(section("10. ОГРАНИЧЕНИЯ / HONESTY"))
    for caveat in report["caveats"]:
        out.append("- " + caveat)
    out.append("")
    out.append("honesty_flags: "
               + (", ".join(report["honesty_flags"]) if report["honesty_flags"] else "(none)"))
    out.append("thresholds: " + json.dumps(report["thresholds"], ensure_ascii=False,
                                          sort_keys=True))
    out.append("")
    return "\n".join(out)


# ==============================================================================
# Ретро-режим
# ==============================================================================


def _sample_session_lines() -> list:
    """Синтетический self_play-лог для selftest (2 сессии с известными числами)."""
    return [
        "===== Self Play session 2026-11-23 21:00:00 =====",
        "[-0:01] [SelfPlay score] clock=-1.0 hero=npc_dota_hero_treant role=4 lane=1 "
        "lastHits=0 denies=0 networth=600 gold=0 xp=0",
        "[0:10] [SelfPlay prediction] addedHits=0 heroIncoming=0 error=nil",
        "[0:20] [SelfPlay prediction] addedHits=3 heroIncoming=0 error=nil",
        "[0:40] [SelfPlay last hit] target=npc_dota_creep_badguys_melee hp=54 damage=76 "
        "events=0 start=0.5 impact=1.2 approach=0.5 inRange=true",
        "[1:00] [SelfPlay last hit] target=npc_dota_creep_goodguys_melee hp=54 damage=76 "
        "events=7 start=0.5 impact=1.2 approach=0.5 inRange=true",
        "[1:30] [SelfPlay last hit stats] 60s: 8 enemy creeps died near us (3 in reach) -> "
        "ours 1, our creeps/tower 7, ally heroes 0, enemy heroes 0; denies 0, "
        "enemy denies 0; attempts 2",
        "[5:00] [SelfPlay prediction] addedHits=5 heroIncoming=0 error=nil",
        "[5:00] [SelfPlay score] clock=300.0 hero=npc_dota_hero_treant role=4 lane=1 "
        "lastHits=4 denies=1 networth=900 gold=0 xp=800",
        "[10:00] [SelfPlay score] clock=600.0 hero=npc_dota_hero_treant role=4 lane=1 "
        "lastHits=9 denies=2 networth=1500 gold=0 xp=1600",
        "===== Self Play session 2026-11-23 22:00:00 =====",
        "[-0:01] [SelfPlay score] clock=-1.0 hero=npc_dota_hero_treant role=4 lane=1 "
        "lastHits=0 denies=0 networth=600 gold=0 xp=0",
        "[0:10] [SelfPlay prediction] addedHits=1 heroIncoming=0 error=nil",
        "[0:20] [SelfPlay last hit] target=npc_dota_creep_badguys_melee hp=54 damage=76 "
        "events=4 start=0.5 impact=1.2 approach=0.5 inRange=true",
        "[1:00] [SelfPlay last hit stats] 60s: 4 enemy creeps died near us (2 in reach) -> "
        "ours 1, our creeps/tower 3, ally heroes 0, enemy heroes 0; denies 0, "
        "enemy denies 0; attempts 1",
        "[5:30] [SelfPlay score] clock=330.0 hero=npc_dota_hero_treant role=4 lane=1 "
        "lastHits=3 denies=0 networth=900 gold=0 xp=500",
    ]


def build_retro_report(sp_path, comp_json_path=None, selector="last",
                       windows_spec=DEF_WINDOWS, out_txt=None, out_json=None,
                       console=True, synthetic=False):
    windows = parse_windows(windows_spec)
    self_play = parse_self_play(sp_path)
    session, reason = select_self_play_session(self_play["sessions"], selector)
    session_info = dict(session["info"])
    session_info["reason"] = reason

    window_metrics = [sp_window_metrics(session, w) for w in windows]
    score_metrics = sp_score_metrics(session)
    comp = load_comp_json(comp_json_path) if comp_json_path else None
    controls = check_retro_controls(self_play, session, window_metrics, score_metrics)

    honesty_flags = ["SELF-PLAY-ONLY-PROXIES", "NO-LEDG2-PROBE"]
    if synthetic:
        honesty_flags.append("SYNTHETIC-FIXTURE")
    if comp is None:
        honesty_flags.append(FLAG_UNVERIFIED_COMP)
    elif _session_marker_mismatch(comp, session.get("marker")):
        honesty_flags.append("COMP-SESSION-MISMATCH")
    if not controls["applicable"]:
        honesty_flags.append("CONTROLS-NOT-APPLICABLE")
    honesty_flags = list(dict.fromkeys(honesty_flags))

    report = {
        "kind": "ledger_retro_report",
        "mode": "selftest-e2e-retro" if synthetic else "retro",
        "synthetic": bool(synthetic),
        "tool": {"name": TOOL_NAME, "version": TOOL_VERSION, "date": TOOL_DATE},
        "inputs": {
            "self_play": {
                "path": self_play["path"],
                "size": self_play["size"],
                "md5": self_play["md5"],
            },
            "comp_json": ({"path": comp["path"], "size": comp["size"],
                           "md5": comp["md5"]} if comp else None),
        },
        "windows_spec": [{"name": w["name"], "lo": w["lo"], "hi": w["hi"]}
                         for w in windows],
        "self_play_parse": {
            "lines_total": self_play["lines_total"],
            "markers_count": self_play["markers_count"],
            "has_markers": self_play["has_markers"],
            "sessions_total": len(self_play["sessions"]),
            "sessions": [dict(s["info"]) for s in self_play["sessions"]],
            "selected_session": session_info,
            "selected_reason": reason,
        },
        "windows": window_metrics,
        "scores": score_metrics,
        "controls": controls,
        "comp": comp,
        "historical_baseline": HISTORICAL_BASELINE,
        "thresholds": dict(THRESHOLDS),
        "caveats": CAVEATS_RETRO,
        "honesty_flags": honesty_flags,
    }

    text = build_retro_report_text(report)
    if out_txt:
        write_text_file(out_txt, text)
    if out_json:
        write_json_file(out_json, report)

    if console:
        print(build_retro_console_summary(report, out_txt, out_json))
        if not out_txt:
            print(text)
    return 0, report, text


def build_retro_console_summary(report: dict, out_txt, out_json) -> str:
    sp = report["inputs"]["self_play"]
    sel = report["self_play_parse"]["selected_session"]
    scores = report["scores"]
    lines = [f"{TOOL_NAME} v{TOOL_VERSION} | retro (self_play only)"]
    lines.append(f"self-play: {sp['path']} (size={sp['size']}, md5={sp['md5']})")
    lines.append(
        f"session  : {sel.get('marker')!r} ({sel.get('reason')}) scores={sel['n_scores']} "
        f"clock {_fmt_clock_range(sel)}"
    )
    lines.append("windows  : " + ", ".join(w["name"] for w in report["windows"]))

    def _brief(packed):
        if not packed:
            return "n/a"
        return f"lh={packed['lh']} @{packed['clock']}"

    lines.append(f"LH@5={_brief(scores['lh5'])} | LH@10={_brief(scores['lh10'])} | "
                 f"final={_brief(scores['final'])}")
    control = report["controls"]
    if control["applicable"]:
        lines.append(f"controls : {'PASS' if control['passed'] == control['total'] else 'FAIL'} "
                     f"{control['passed']}/{control['total']} (зачётный fsl3)")
    else:
        lines.append(f"controls : n/a ({control['reason']})")
    if out_txt:
        lines.append(f"TXT      : {os.path.abspath(out_txt)}")
    if out_json:
        lines.append(f"JSON     : {os.path.abspath(out_json)}")
    if not out_txt:
        lines.append("(полный отчёт напечатан ниже; --out-txt сохранит его в файл)")
    return "\n".join(lines)


def build_retro_report_text(report: dict) -> str:
    out = []
    out.append("=" * 88)
    out.append(
        f"RETRO PROXIES ledger/noFlag — ОТЧЁТ АНАЛИЗАТОРА  "
        f"({report['tool']['name']} v{report['tool']['version']})"
    )
    out.append("=" * 88)
    out.append("Режим: --retro (только self_play-лог; [ledg2]-зонда нет).")
    out.append("Прокси не заменяют зонд: различают not-выбор по кандидатам/таймингу только косвенно.")
    out.append("Окна: " + ", ".join(w["name"] for w in report["windows"])
               + " (по line-префиксу [m:ss], правая граница включительно).")
    if report.get("synthetic"):
        out.append("ВНИМАНИЕ: SYNTHETIC FIXTURE — данные сгенерированы --selftest, "
                   "это НЕ замер.")

    # 1. provenance
    sp = report["inputs"]["self_play"]
    parse_info = report["self_play_parse"]
    out.append(section("1. ВХОД / PROVENANCE"))
    out.append(f"self-play: {sp['path']}")
    out.append(f"           size={sp['size']} bytes  md5={sp['md5']}")
    out.append(f"tool     : {TOOL_NAME} v{TOOL_VERSION} ({TOOL_DATE})")
    out.append(f"lines_total={parse_info['lines_total']}  "
               f"markers={parse_info['markers_count']}  "
               f"sessions={parse_info['sessions_total']}  "
               f"has_markers={parse_info['has_markers']}")

    # 2. session + scores
    sel = parse_info["selected_session"]
    out.append(section("2. СЕССИЯ И LH-МЕТРИКИ ([SelfPlay score])"))
    out.append(f"ВЫБРАННАЯ СЕССИЯ: {sel.get('marker')!r} "
               f"(index={sel['index']}, {report['self_play_parse']['selected_reason']})")
    out.append(f"  n_lines={sel['n_lines']}  n_scores={sel['n_scores']}  "
               f"clock {_fmt_clock_range(sel)}")
    out.append("")
    scores = report["scores"]

    def _packed(packed):
        if not packed:
            return "n/a"
        return (f"LH={packed['lh']} denies={packed['denies']} xp={packed['xp']} "
                f"networth={packed['networth']} @ clock {packed['clock']}")

    out.append(f"LH@5  = {_packed(scores['lh5'])}   (first score clock >= 300)")
    out.append(f"LH@10 = {_packed(scores['lh10'])}   (first score clock >= 600)")
    out.append(f"final = {_packed(scores['final'])}   (последний score сессии)")

    # 3. proxies
    out.append(section("3. РЕТРО-ПРОКСИ [SelfPlay prediction] / last hit / stats"))
    wm = report["windows"]
    out.append("3.1. prediction (addedHits):")
    rows = []
    for w in wm:
        rows.append([
            w["name"],
            str(w["prediction_lines"]),
            str(w["prediction_added_gt0"]),
            _pct1(w["prediction_added_gt0_share"]),
            str(w["prediction_added_sum"]),
        ])
    out.append(format_table(
        ["window", "lines", "addedHits>0", "share", "addedHits sum"],
        rows, aligns=["l", "r", "r", "r", "r"]))
    out.append("")
    out.append("3.2. [SelfPlay last hit] (target goodguys=allied deny / badguys=enemy):")
    rows = []
    for w in wm:
        rows.append([
            w["name"],
            str(w["last_hit_lines"]),
            str(w["last_hit_allied"]),
            str(w["last_hit_enemy"]),
            str(w["last_hit_other"]),
            str(w["last_hit_events0"]),
            _pct1(w["last_hit_events0_share"]),
            _f3(w["last_hit_mean_events"]),
        ])
    out.append(format_table(
        ["window", "lines", "allied", "enemy", "other", "events==0", "ev0 share",
         "mean events"],
        rows, aligns=["l"] + ["r"] * 7))
    out.append("")
    out.append("3.3. [SelfPlay last hit stats] (60-с окна, суммы):")
    rows = []
    for w in wm:
        st = w["stats"]
        rows.append([
            w["name"],
            str(w["stats_lines"]),
            str(st["died"]),
            str(st["in_reach"]),
            str(st["ours"]),
            str(st["attempts"]),
            _pct1(w["ours_per_in_reach"]),
        ])
    out.append(format_table(
        ["window", "stats lines", "died", "in reach", "ours", "attempts",
         "ours/in_reach"],
        rows, aligns=["l"] + ["r"] * 6))

    # 4. controls
    out.append(section("4. КОНТРОЛЬНЫЕ ЧИСЛА lead'а (зачётный fsl3)"))
    control = report["controls"]
    if not control["applicable"]:
        out.append(f"не применимо: {control['reason']}")
    else:
        status = "PASS" if control["passed"] == control["total"] else "FAIL"
        out.append(f"{status} {control['passed']}/{control['total']}")
        rows = []
        for item in control["items"]:
            rows.append([
                item["window"],
                item["item"],
                str(item["expected"]),
                "n/a" if item["actual"] is None else str(item["actual"]),
                "PASS" if item["ok"] else "FAIL",
            ])
        out.append(format_table(
            ["window", "item", "expected", "actual", "status"],
            rows, aligns=["l", "l", "r", "r", "l"]))

    # 5. comp
    out.append(section("5. СОСТАВ (контекст)"))
    comp = report.get("comp")
    if comp is None:
        out.append("--comp-json не передан: composition UNVERIFIED-COMPOSITION")
        out.append("(для ретро-прокси не требуется; LH сравнивается только на MATCHED).")
    else:
        out.append(f"comp_filter verdict={comp['verdict']!r} (источник {comp['chosen_key']}), "
                   f"session={comp.get('session')!r}")
        out.append("windows: " + ", ".join(f"{k}={v}" for k, v in sorted(comp["verdicts"].items())))
        if _session_marker_mismatch(comp, sel.get("marker")):
            out.append("ВНИМАНИЕ: comp-json относится к другой сессии (COMP-SESSION-MISMATCH).")

    # 6. baseline
    out.append(section("6. ИСТОРИЧЕСКИЙ BASELINE (контекст, НЕ критерий)"))
    baseline = report["historical_baseline"]
    raw = baseline["raw"]
    out.append(f"{baseline['label']}; source: {baseline['source']}")
    out.append(f"  seen={raw['seen']} chk={raw['chk']} gate={raw['gate']} "
               f"pass(flag)={raw['pass_flag']} noFlag(hpHiEv0)={raw['noFlag_hpHiEv0']} "
               f"evPos={raw['evPos']} cands={raw['cands']} chosen={raw['chosen']}")
    out.append(
        f"  noFlag_share = {raw['noFlag_hpHiEv0']}/{raw['chk']} = "
        f"{raw['noFlag_hpHiEv0'] / raw['chk']:.3f} (~0.40); "
        f"evPos/chk = {raw['evPos'] / raw['chk']:.3f} (~0.53); "
        f"cands/chk = {raw['cands'] / raw['chk']:.3f} (~0.07); "
        f"chosen/cands = {raw['chosen'] / raw['cands']:.3f} (~0.85)"
    )
    out.append("  ОГОВОРКИ:")
    for caveat in baseline["caveats"]:
        out.append("    - " + caveat)

    # 7. caveats/honesty
    out.append(section("7. ОГРАНИЧЕНИЯ / HONESTY"))
    for caveat in report["caveats"]:
        out.append("- " + caveat)
    out.append("")
    out.append("honesty_flags: "
               + (", ".join(report["honesty_flags"]) if report["honesty_flags"] else "(none)"))
    out.append("")
    return "\n".join(out)


# ==============================================================================
# Selftest
# ==============================================================================


def _synthetic_agg_line(wall: str, clock: int, role: int, **fields) -> str:
    values = {f: 0 for f in PROBE_FIELDS}
    values.update(fields)
    parts = [f"clock={clock}", f"role={role}"]
    for field in PROBE_FIELDS:
        parts.append(f"{field}={values[field]}")
    prefix = f"{wall} " if wall else ""
    return prefix + "[ledg2] " + " ".join(parts)


def _selftest_probe_lines() -> list:
    """Синтетический probe-лог: 2 сессии, sample/begin/malformed/truncated."""
    a1 = dict(
        calls=2, seenE=4, chkE=6, passE=2, noFlagE=3, noDelayE=1,
        evPosE=3, ev0E=3, tickCall=2, tickChkE=2, tickEvE=1, tickPassE=2,
        tickCandsE=1, tickChosenE=1, candsE=1, chosenE=1,
        d350E=1, d600E=1, d900E=1, d1300E=1,
        hurtE=3, hurtEHero=0, hurtEMatch=2, srcAnimE=1, srcCycE=1, srcPredE=1,
    )
    b1 = dict(
        calls=10, seenE=20, seenA=5, chkE=50, passE=10, noFlagE=30,
        noDelayE=5, min0E=5, evPosE=20, ev0E=30, evN1E=5, evN2E=5, evN4pE=10,
        srcAnimE=5, srcCycE=10, srcPredE=5,
        tickCall=20, tickChkE=20, tickEvE=15, tickPassE=12, tickCandsE=8,
        tickChosenE=5, candsE=8, chosenE=5, nowinE=2, unsafeE=1, norouteE=1,
        d350E=5, d600E=10, d900E=5, d1300E=5,
        noFlagCloseE=10, passCloseE=5, noFlagKillE=5,
        hurtE=25, hurtEHero=2, hurtEMatch=15, hurtENo=8, hurtENodetect=5,
        hurtEMisattr=2, hurtAMatch=8, hurtACyc=3,
    )
    b3 = dict(
        calls=4, seenE=8, chkE=20, passE=5, noFlagE=12, noDelayE=2, min0E=1,
        evPosE=8, ev0E=12, evN1E=2, evN2E=2, evN4pE=4,
        srcAnimE=2, srcCycE=4, srcPredE=2,
        tickCall=8, tickChkE=8, tickEvE=6, tickPassE=6, tickCandsE=3,
        tickChosenE=2, candsE=3, chosenE=2, nowinE=1, unsafeE=1,
        d350E=30, d600E=30, d900E=30, d1300E=30,
        noFlagCloseE=4, passCloseE=1, noFlagKillE=2,
        hurtE=10, hurtEHero=1, hurtEMatch=6, hurtENo=3, hurtENodetect=2,
        hurtEMisattr=1, hurtAMatch=3, hurtACyc=1,
    )
    return [
        "21:30:00 [ledg2] begin role=4",
        _synthetic_agg_line("21:30:01", 4, 4, **a1),
        _synthetic_agg_line("21:30:02", 8, 4, **a1),
        _synthetic_agg_line("21:30:03", 350, 4, **a1),
        "21:31:00 [ledg2] clock=oops calls=1",
        "21:31:01 [ledg2] begin role=4",
        _synthetic_agg_line("21:31:02", 0, 4, **b1),
        "21:31:03 [ledg2 row] creep=npc_dota_creep_badguys_melee clock=5 d=100 ev=2",
        _synthetic_agg_line("21:31:04", 100, 4, **b1),
        "21:31:05 [ledg2 hurt] clock=105 total=1 match=1",
        _synthetic_agg_line("21:31:06", 400, 4, **b3),
        "not a probe line [ledg2] foo",
        "21:40:00 [ledg2] clock=500 calls=3 seenE=4",
    ]


def _sums(**overrides) -> dict:
    sums = {f: 0 for f in PROBE_FIELDS}
    sums.update(overrides)
    return sums


def _window_result(name: str, lo: float, hi: float, sums: dict) -> dict:
    window = {"name": name, "lo": lo, "hi": hi}
    result = {
        "name": name,
        "lo": lo,
        "hi": hi,
        "n_lines": 1,
        "clock_min": lo,
        "clock_max": lo,
        "sums": sums,
    }
    result["metrics"] = compute_metrics(sums)
    result["invariants"] = check_invariants(sums)
    return result


def run_selftest() -> int:
    _configure_streams()
    passed = 0
    failed = 0
    failures = []

    def check(name: str, condition: bool, detail: str = "") -> None:
        nonlocal passed, failed
        if condition:
            passed += 1
            print(f"PASS  {name}")
        else:
            failed += 1
            failures.append(name + (f"  [{detail}]" if detail else ""))
            print(f"FAIL  {name}" + (f"  [{detail}]" if detail else ""))

    print(f"{TOOL_NAME} v{TOOL_VERSION} — SELFTEST (только синтетические данные)")
    print(f"analysis dir: {ANALYSIS_DIR}")

    # --- 1. парсинг синтетического лога -------------------------------------
    lines = _selftest_probe_lines()
    parsed = parse_probe_lines(lines)
    check("parse: aggregate lines == 6", parsed["aggregate_lines"] == 6,
          f"got {parsed['aggregate_lines']}")
    check("parse: sessions == 2", len(parsed["sessions"]) == 2,
          f"got {len(parsed['sessions'])}")
    check("parse: malformed skipped == 2", parsed["malformed_lines"] == 2,
          f"got {parsed['malformed_lines']}")
    check("parse: truncated tail skipped == 1", parsed["truncated_lines"] == 1,
          f"got {parsed['truncated_lines']}")
    check("parse: begin markers == 2", parsed["begin_markers"] == 2,
          f"got {parsed['begin_markers']}")
    check("parse: sample rows (row/hurt) == (1,1)",
          (parsed["row_samples"], parsed["hurt_samples"]) == (1, 1),
          f"got {(parsed['row_samples'], parsed['hurt_samples'])}")
    check("parse: roles == [4]", parsed["roles"] == [4], f"got {parsed['roles']}")
    check("parse: session 0 aggregates == 3",
          parsed["sessions"][0]["info"]["n_aggregates"] == 3)
    check("parse: session 1 aggregates == 3",
          parsed["sessions"][1]["info"]["n_aggregates"] == 3)
    check("parse: session 1 clock max == 400",
          parsed["sessions"][1]["info"]["clock_max"] == 400)

    lenient = parse_probe_lines([
        _synthetic_agg_line("", 0, 4),
        "21:00:02 [ledg2 begin] role=4",
        "21:00:03 [ledg2] row creep=x",
    ])
    check("parse: агрегат без wall-префикса принят (no_wall_lines=1)",
          lenient["aggregate_lines"] == 1 and lenient["no_wall_lines"] == 1,
          f"agg={lenient['aggregate_lines']} nowall={lenient['no_wall_lines']}")
    check("parse: tag-форма [ledg2 begin]/[ledg2] row принята",
          lenient["begin_markers"] == 1 and lenient["row_samples"] == 1)

    # --- 2. агрегация окон ---------------------------------------------------
    session = parsed["sessions"][1]
    windows = parse_windows(DEF_WINDOWS)
    by_name = {}
    for window in windows:
        result = aggregate_probe_window(session, window)
        result["metrics"] = compute_metrics(result["sums"])
        result["invariants"] = check_invariants(result["sums"])
        by_name[window["name"]] = result
    w0300 = by_name["0-300"]
    w3060 = by_name["300-600"]
    w0600 = by_name["0-600"]
    check("window 0-300: n_lines == 2", w0300["n_lines"] == 2, f"got {w0300['n_lines']}")
    check("window 0-300: chkE == 100", w0300["sums"]["chkE"] == 100,
          f"got {w0300['sums']['chkE']}")
    check("window 0-300: noFlagE == 60", w0300["sums"]["noFlagE"] == 60)
    check("window 0-300: passE == 20", w0300["sums"]["passE"] == 20)
    check("window 0-300: evPosE == 40", w0300["sums"]["evPosE"] == 40)
    check("window 300-600: chkE == 20", w3060["sums"]["chkE"] == 20,
          f"got {w3060['sums']['chkE']}")
    check("window 0-600: chkE == 120", w0600["sums"]["chkE"] == 120,
          f"got {w0600['sums']['chkE']}")
    check("window 0-600: noFlagE == 72", w0600["sums"]["noFlagE"] == 72)
    check("window 0-600: seenE == 48", w0600["sums"]["seenE"] == 48)

    # --- 3. метрики ----------------------------------------------------------
    m0300 = compute_metrics(w0300["sums"])
    m0600 = compute_metrics(w0600["sums"])
    check("metrics 0-300: noFlag_share ~ 0.75",
          m0300["noFlag_share"] is not None and abs(m0300["noFlag_share"] - 0.75) < 1e-9,
          f"got {m0300['noFlag_share']}")
    check("metrics 0-300: coverage_creep ~ 0.40",
          abs(m0300["coverage_creep"] - 0.40) < 1e-9, f"got {m0300['coverage_creep']}")
    check("metrics 0-300: coverage_tick ~ 0.75",
          abs(m0300["coverage_tick"] - 0.75) < 1e-9, f"got {m0300['coverage_tick']}")
    check("metrics 0-300: hurt_recall ~ 0.652",
          abs(m0300["hurt_recall"] - (30.0 / 46.0)) < 1e-9,
          f"got {m0300['hurt_recall']}")
    check("metrics 0-300: near_share ~ 0.10",
          abs(m0300["near_share"] - 0.10) < 1e-9, f"got {m0300['near_share']}")
    check("metrics 0-600: noFlag_share ~ 72/97",
          abs(m0600["noFlag_share"] - (72.0 / 97.0)) < 1e-9,
          f"got {m0600['noFlag_share']}")
    check("metrics 0-600: cand_rate ~ 19/25",
          abs(m0600["cand_rate"] - (19.0 / 25.0)) < 1e-9)
    check("metrics: hurt_recall N/A при малом знаменателе",
          compute_metrics(_sums(hurtE=10, hurtEHero=2, hurtEMatch=5))["hurt_recall"] is None)
    check("metrics: gate_share N/A при seenE=0",
          compute_metrics(_sums())["gate_share"] is None)

    # --- 4. инварианты (warn, не fail) --------------------------------------
    check("invariants: чистая сессия 0-300 OK",
          invariants_ok(w0300["invariants"]), "expected all OK")
    check("invariants: d-bucket violation поймана (0-600)",
          any(not c["ok"] and c["name"].startswith("d350E") for c in w0600["invariants"]))
    bad = _window_result("0-600", 0, 600, _sums(chkE=10, passE=5, noFlagE=5, evPosE=9))
    check("invariants: evPos+ev0 != chk пойман",
          any(not c["ok"] and c["name"].startswith("evPosE") for c in bad["invariants"]))
    check("invariants: проверки не бросают исключение",
          isinstance(check_invariants(_sums(chkE=1)), list))

    # --- 5. ветки вердикта ---------------------------------------------------
    comp_matched = {"verdict": "MATCHED", "chosen_key": "lh10",
                    "verdicts": {"lh5": "MATCHED", "lh10": "MATCHED"}}
    comp_not_matched = {"verdict": "NOT-MATCHED", "chosen_key": "lh10",
                        "verdicts": {"lh5": "NOT-MATCHED", "lh10": "NOT-MATCHED"}}

    def make_windows(s0300: dict, s0600: dict):
        return [_window_result("0-300", 0, 300, s0300),
                _window_result("300-600", 300, 600, s0300),
                _window_result("0-600", 0, 600, s0600)]

    sufficient = _sums(
        gate_share=0, seenE=100, chkE=100, passE=20, noFlagE=60, noDelayE=10,
        min0E=10, evPosE=40, ev0E=60, tickCall=50, tickChkE=40, tickEvE=30,
        tickPassE=20, tickCandsE=10, tickChosenE=8, candsE=15, chosenE=10,
        d350E=10, d600E=20, d900E=10, d1300E=10,
        hurtE=30, hurtEHero=2, hurtEMatch=20, srcAnimE=10, srcCycE=20, srcPredE=10,
        nowinE=2, unsafeE=1, calls=20,
    )
    ledger_windows = make_windows(sufficient, sufficient)
    verdict = evaluate_verdict(ledger_windows, comp_matched)
    check("verdict: LEDGER-DOMINANT (noFlag_share>=0.50)",
          verdict["category"] == VERDICT_LEDGER, f"got {verdict['category']}")

    verdict = evaluate_verdict(ledger_windows, comp_not_matched)
    check("verdict: INVALID-COMPOSITION",
          verdict["category"] == VERDICT_INVALID_COMPOSITION,
          f"got {verdict['category']}")

    gate_bad = _sums(seenE=100, gateE=50, chkE=100, passE=10, noFlagE=90)
    verdict = evaluate_verdict(make_windows(gate_bad, gate_bad), comp_matched)
    check("verdict: INVALID-NON-GATE (gate_share>0.15)",
          verdict["category"] == VERDICT_INVALID_NON_GATE, f"got {verdict['category']}")

    insufficient = _sums(seenE=10, chkE=50, passE=10, noFlagE=40, tickChkE=10,
                         tickEvE=5, evPosE=20, ev0E=30)
    verdict = evaluate_verdict(make_windows(insufficient, insufficient), comp_matched)
    check("verdict: INSUFFICIENT (chkE<100/tickChkE<30)",
          verdict["category"] == VERDICT_INSUFFICIENT, f"got {verdict['category']}")

    positioning = _sums(
        seenE=100, chkE=100, passE=60, noFlagE=20, noDelayE=10, min0E=10,
        evPosE=80, ev0E=20, tickChkE=40, tickEvE=36, tickPassE=30,
        tickCandsE=20, tickChosenE=15, candsE=20, chosenE=15,
        d350E=40, d600E=10, d900E=5, d1300E=5,
        hurtE=30, hurtEHero=2, hurtEMatch=20, srcAnimE=20, srcCycE=40, srcPredE=20,
    )
    verdict = evaluate_verdict(make_windows(positioning, positioning), comp_matched)
    check("verdict: POSITIONING-DOMINANT (H2)",
          verdict["category"] == VERDICT_POSITIONING, f"got {verdict['category']}")

    mixed = _sums(
        seenE=100, chkE=100, passE=60, noFlagE=40,
        evPosE=65, ev0E=35, tickChkE=40, tickEvE=30,
        tickPassE=30, tickCandsE=20, tickChosenE=15, candsE=20, chosenE=15,
        d350E=30, d600E=10, d900E=5, d1300E=5,
        hurtE=30, hurtEHero=2, hurtEMatch=20, srcAnimE=20, srcCycE=20, srcPredE=20,
    )
    verdict = evaluate_verdict(make_windows(mixed, mixed), comp_matched)
    check("verdict: MIXED", verdict["category"] == VERDICT_MIXED,
          f"got {verdict['category']}")

    caution = _sums(seenE=100, gateE=10, chkE=100, passE=20, noFlagE=60,
                    noDelayE=10, min0E=10, evPosE=40, ev0E=60,
                    tickChkE=40, tickEvE=30)
    verdict = evaluate_verdict(make_windows(caution, caution), comp_matched)
    check("verdict: GATE-ACTIVE-CAUTION флаг, вердикт не отменён",
          FLAG_GATE_CAUTION in verdict["flags"] and verdict["category"] != VERDICT_INVALID_NON_GATE,
          f"flags={verdict['flags']} cat={verdict['category']}")

    comp_missing = {"verdict": None, "chosen_key": None, "verdicts": {}}
    verdict = evaluate_verdict(make_windows(sufficient, sufficient), None)
    check("verdict: UNVERIFIED-COMPOSITION warning при отсутствии comp-json",
          FLAG_UNVERIFIED_COMP in verdict["flags"]
          and verdict["checks"]["composition"]["ok"] is None)

    ledger_0300 = _sums(seenE=100, chkE=100, passE=20, noFlagE=80,
                        evPosE=40, ev0E=60, tickChkE=40, tickEvE=30)
    mixed_0600 = _sums(seenE=100, chkE=100, passE=60, noFlagE=40,
                       evPosE=65, ev0E=35, tickChkE=40, tickEvE=30,
                       d350E=30)
    verdict = evaluate_verdict(
        make_windows(ledger_0300, mixed_0600), comp_matched)
    check("verdict: UNSTABLE при расхождении 0-300/0-600",
          FLAG_UNSTABLE in verdict["flags"], f"flags={verdict['flags']}")

    # --- 6. JSON round-trip --------------------------------------------------
    sample_report = {"verdict": {"category": VERDICT_LEDGER,
                                 "flags": [FLAG_INVARIANT]},
                     "windows": [{"name": "0-600", "sums": {"chkE": 120}}]}
    dumped = json.dumps(sample_report, ensure_ascii=False)
    loaded = json.loads(dumped)
    check("json: round-trip сохраняет вердикт и суммы",
          loaded["verdict"]["category"] == VERDICT_LEDGER
          and loaded["windows"][0]["sums"]["chkE"] == 120)

    # --- 7. self-play парсер и ретро ----------------------------------------
    sp = parse_self_play_lines(_sample_session_lines())
    check("self-play: sessions == 2", len(sp["sessions"]) == 2,
          f"got {len(sp['sessions'])}")
    check("self-play: markers == 2", sp["markers_count"] == 2)
    sp_sess = sp["sessions"][0]
    sp_windows = [sp_window_metrics(sp_sess, w) for w in windows]
    sp_by_name = {w["name"]: w for w in sp_windows}
    check("self-play 0-300: prediction lines == 3",
          sp_by_name["0-300"]["prediction_lines"] == 3,
          f"got {sp_by_name['0-300']['prediction_lines']}")
    check("self-play 0-300: addedHits>0 == 2",
          sp_by_name["0-300"]["prediction_added_gt0"] == 2)
    check("self-play 0-300: last-hit lines == 2",
          sp_by_name["0-300"]["last_hit_lines"] == 2)
    check("self-play 0-300: allied/enemy == (1,1)",
          (sp_by_name["0-300"]["last_hit_allied"],
           sp_by_name["0-300"]["last_hit_enemy"]) == (1, 1))
    check("self-play 0-300: events==0 == 1",
          sp_by_name["0-300"]["last_hit_events0"] == 1)
    check("self-play 0-300: stats died/in_reach/ours/attempts == 8/3/1/2",
          (sp_by_name["0-300"]["stats"]["died"],
           sp_by_name["0-300"]["stats"]["in_reach"],
           sp_by_name["0-300"]["stats"]["ours"],
           sp_by_name["0-300"]["stats"]["attempts"]) == (8, 3, 1, 2))
    sp_scores = sp_score_metrics(sp_sess)
    check("self-play: LH@5 == 4 (first score clock>=300)",
          (sp_scores["lh5"] or {}).get("lh") == 4,
          f"got {sp_scores['lh5']}")
    check("self-play: LH@10 == 9", (sp_scores["lh10"] or {}).get("lh") == 9)
    check("self-play: final == 9", (sp_scores["final"] or {}).get("lh") == 9)
    check("self-play: control check n/a для не-архивного md5",
          check_retro_controls({"md5": "0" * 32}, sp_sess, sp_windows,
                               sp_scores)["applicable"] is False)

    # --- 8. ошибка контракта: missing key в не-хвостовой строке --------------
    bad_agg = _synthetic_agg_line("21:00:01", 1, 4).replace(" gateE=0", "")
    bad_lines = [bad_agg, "tail non-probe line"]
    raised = False
    try:
        parse_probe_lines(bad_lines)
    except ProbeParseError as exc:
        raised = exc.line_no == 1 and "gateE" in str(exc)
    check("parse: missing key вне хвоста -> ProbeParseError с номером строки", raised)

    bad_selector = False
    try:
        select_probe_session(parsed["sessions"], "99")
    except ToolError:
        bad_selector = True
    check("session: N вне диапазона -> ToolError", bad_selector)

    # --- 9. end-to-end: синтетические фикстуры + sample report ----------------
    try:
        os.makedirs(ANALYSIS_DIR, exist_ok=True)
        fixture_probe = os.path.join(ANALYSIS_DIR, "selftest_fixture_ledg2.log")
        fixture_comp = os.path.join(ANALYSIS_DIR, "selftest_fixture_comp.json")
        fixture_sp = os.path.join(ANALYSIS_DIR, "selftest_fixture_selfplay.log")
        sample_txt = os.path.join(ANALYSIS_DIR, "selftest_sample_report.txt")
        sample_json = os.path.join(ANALYSIS_DIR, "selftest_sample_report.json")
        retro_txt = os.path.join(ANALYSIS_DIR, "selftest_retro_sample.txt")

        write_text_file(
            fixture_probe,
            "# SYNTHETIC FIXTURE for ledger_probe_report --selftest; NOT a real probe log\n"
            + "\n".join(lines) + "\n",
        )
        write_json_file(fixture_comp, {
            "_note": "SYNTHETIC fixture for ledger_probe_report --selftest",
            "kind": "match",
            "session": "2026-11-23 22:00:00",
            "windows": {"lh5": {"verdict": "MATCHED"},
                        "lh10": {"verdict": "MATCHED"}},
            "verdict": "MATCHED",
        })
        write_text_file(
            fixture_sp,
            "# SYNTHETIC FIXTURE for ledger_probe_report --selftest; NOT a real self_play log\n"
            + "\n".join(_sample_session_lines()) + "\n",
        )

        code, report, _text = analyze_probe(
            fixture_probe, self_play_path=fixture_sp, comp_json_path=fixture_comp,
            selector="last", windows_spec=DEF_WINDOWS,
            out_txt=sample_txt, out_json=sample_json, console=False,
            synthetic=True,
        )
        check("e2e: analyze_probe exit 0", code == 0)
        check("e2e: sample txt создан и непуст",
              os.path.isfile(sample_txt) and os.path.getsize(sample_txt) > 1000,
              f"size={os.path.getsize(sample_txt) if os.path.isfile(sample_txt) else 'missing'}")
        check("e2e: sample json создан", os.path.isfile(sample_json))
        with open(sample_json, encoding="utf-8") as f:
            loaded_report = json.load(f)
        check("e2e: VERDICT == LEDGER-DOMINANT",
              loaded_report["verdict"]["category"] == VERDICT_LEDGER,
              f"got {loaded_report['verdict']['category']}")
        check("e2e: selected session == index 1",
              loaded_report["probe_parse"]["selected_session"]["index"] == 1)
        check("e2e: malformed/truncated в отчёте",
              loaded_report["probe_parse"]["malformed_lines"] == 2
              and loaded_report["probe_parse"]["truncated_lines"] == 1)
        check("e2e: invariant warning присутствует",
              any(not c["ok"] for c in loaded_report["windows"][-1]["invariants"]))
        check("e2e: self-play секция заполнена",
              loaded_report["self_play"] is not None
              and loaded_report["self_play"]["scores"]["lh5"] is not None)
        check("e2e: provenance содержит md5 probe",
              bool(loaded_report["inputs"]["probe"]["md5"]))
        check("e2e: comp-json сессия совпадает с self-play (нет mismatch-флага)",
              "COMP-SESSION-MISMATCH" not in loaded_report["honesty_flags"],
              f"flags={loaded_report['honesty_flags']}")
        check("e2e: sample report помечен как синтетический",
              loaded_report.get("synthetic") is True
              and "SYNTHETIC-FIXTURE" in loaded_report["honesty_flags"]
              and loaded_report["mode"] == "selftest-e2e")

        retro_code, retro_report, _retro_text = build_retro_report(
            fixture_sp, comp_json_path=fixture_comp, selector="0",
            windows_spec=DEF_WINDOWS, out_txt=retro_txt, out_json=None,
            console=False, synthetic=True,
        )
        check("e2e: retro exit 0", retro_code == 0)
        check("e2e: retro txt создан", os.path.isfile(retro_txt)
              and os.path.getsize(retro_txt) > 500)
        check("e2e: retro controls n/a (синтетический md5)",
              retro_report["controls"]["applicable"] is False)
        loaded_retro = json.loads(json.dumps(retro_report, ensure_ascii=False))
        check("e2e: retro JSON round-trip",
              loaded_retro["scores"]["lh5"]["lh"] == 4)
    except (ToolError, OSError, ValueError) as exc:
        check("e2e: без исключений", False, repr(exc))

    print("-" * 88)
    print(f"SELFTEST: PASS {passed} / FAIL {failed}")
    if failed:
        print("failures:")
        for failure in failures:
            print("  - " + failure)
        return 1
    print("SELFTEST OK (exit 0)")
    return 0


# ==============================================================================
# CLI
# ==============================================================================


class _CliParser(argparse.ArgumentParser):
    """argparse с exit code 1 на ошибку использования (спека: 0 ok / 1 tool error)."""

    def error(self, message):
        self.print_usage(sys.stderr)
        sys.stderr.write(f"{self.prog}: error: {message}\n")
        sys.exit(1)


def build_parser() -> argparse.ArgumentParser:
    parser = _CliParser(
        prog=TOOL_NAME + ".py",
        description=(
            "Анализатор замера не-гейтовых лимитеров LH: новый зонд [ledg2] "
            "(probe analysis), ретро-прокси по self_play-логу (--retro) и "
            "синтетический selftest (--selftest)."
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "Примеры:\n"
            "  python ledger_probe_report.py --probe probe_ledger.log "
            "--self-play self_play.log --comp-json comp_filter_ledger.json "
            "--out-txt ledger_report.txt --out-json ledger_report.json\n"
            "  python ledger_probe_report.py --retro "
            "--self-play self_play.log.fsl3 --session last "
            "--out-txt retro_fsl3_ledger_proxies.txt\n"
            "  python ledger_probe_report.py --selftest\n"
            "\n"
            "Exit codes: 0 — анализ выполнен (вердикт в отчёте); "
            "1 — ошибка инструмента/парсинга."
        ),
    )
    parser.add_argument("--probe", default=None, metavar="PATH",
                        help="лог [ledg2] (агрегатные строки зонда)")
    parser.add_argument("--self-play", dest="self_play", default=None, metavar="PATH",
                        help="self_play-лог ([SelfPlay score]/prediction/last hit/stats)")
    parser.add_argument("--comp-json", dest="comp_json", default=None, metavar="PATH",
                        help="JSON tools/comp_filter.py --json (composition verdict)")
    parser.add_argument("--session", default="last", metavar="last|N|auto",
                        help="выбор сессии: last (default), 0-based N или auto (max clock)")
    parser.add_argument("--windows", default=DEF_WINDOWS, metavar="LO-HI,...",
                        help=f"окна в секундах match-clock (default {DEF_WINDOWS})")
    parser.add_argument("--out-txt", dest="out_txt", default=None, metavar="PATH",
                        help="куда сохранить текстовый отчёт (UTF-8)")
    parser.add_argument("--out-json", dest="out_json", default=None, metavar="PATH",
                        help="куда сохранить JSON-отчёт (provenance + метрики)")
    parser.add_argument("--retro", action="store_true",
                        help="ретро-режим: только --self-play, [ledg2] не нужен")
    parser.add_argument("--selftest", action="store_true",
                        help="синтетический selftest (все ветки вердикта + e2e), exit 0")
    parser.add_argument("--version", action="version",
                        version=f"{TOOL_NAME} {TOOL_VERSION} ({TOOL_DATE})")
    return parser


def main(argv=None) -> int:
    _configure_streams()
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        if args.selftest:
            return run_selftest()
        if not RE_SESSION_SELECTOR.match(str(args.session)):
            raise ToolError(f"--session {args.session!r}: ожидается last|auto|N")
        if args.retro:
            if not args.self_play:
                raise ToolError("--retro требует --self-play PATH")
            if args.probe:
                sys.stderr.write("NOTE: --probe игнорируется в режиме --retro\n")
            code, _report, _text = build_retro_report(
                args.self_play, comp_json_path=args.comp_json,
                selector=args.session, windows_spec=args.windows,
                out_txt=args.out_txt, out_json=args.out_json, console=True,
            )
            return code
        if not args.probe:
            raise ToolError("нужен --probe PATH (или --retro/--selftest)")
        code, _report, _text = analyze_probe(
            args.probe, self_play_path=args.self_play,
            comp_json_path=args.comp_json, selector=args.session,
            windows_spec=args.windows, out_txt=args.out_txt,
            out_json=args.out_json, console=True,
        )
        return code
    except ToolError as exc:
        sys.stderr.write(f"ERROR: {exc}\n")
        return 1
    except OSError as exc:
        sys.stderr.write(f"ERROR: {exc}\n")
        return 1


if __name__ == "__main__":
    sys.exit(main())