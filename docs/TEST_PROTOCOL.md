# TEST PROTOCOL — как запускать, останавливать и мерить порт

Актуально на 21.11.2026. Обязателен перед любым live-запуском.

## 1. Жёсткие правила теста (от Lead/PM, не обсуждаются)
- Только **одиночная игра против ботов** (никаких рейтинговых/онлайн матчей).
- Герой для теста — **Treant Protector** (Clockwerk/другие — случайно, не эталон).
- Роль для приёмки — **role 4, lane 1** (эталон `REFERENCE_BEHAVIOR.md`);
  отладочные прогоны могут форсить Role=1 (Carry) через `bot_loop_run.lua`.
- **Один Lua-state за раз.** Несколько состояний = конкуренция и «медленные тики».
- Доказательства (логи/дампы/хэши) важнее предположений. Без зонда — не чиним.

## 2. Регрессионный минимум ПЕРЕД каждым live-запуском
Выполнять по порядку, не пропускать:
1. `python src\check_build.py` → должно быть «OK: build matches baseline».
   Если «BUILD CHANGED» → сначала `BUILD_MIGRATION.md`, не запускать бота.
2. Зонд субстрата: `diag_micro.lua` или entity-дамп → `iter n≈5600`, не 1–4.
3. Зонд боевой математики (фаза 1): урон/скорость атаки/дальность vs HUD.
4. Зонд событий/ledger (фаза 2): `[hits] events/cycles` наполняются в бою.
5. Только затем — бот (`bot_loop_run.lua`).

## 3. Запуск игры и инжект
```powershell
# 1. Запуск Dota
Start-Process 'steam://rungameid/570'; Start-Sleep 100
$p = Get-Process dota2
# 2. Инжект (elevated, т.к. Dota HIGH integrity)
Start-Process D:\hake\lotus\src\inject_elevated.bat -ArgumentList $p.Id -Verb RunAs -Wait
# 3. Проверка инжекта
Get-Content D:\hake\lotus\src\inject_result.txt | Select-Object -Last 2
# 4. Запуск скрипта (run.txt = путь)
Set-Content D:\hake\lotus\run.txt 'D:\hake\lotus\src\bot_loop_run.lua' -NoNewline
Start-Process D:\hake\lotus\src\call_elevated.bat -ArgumentList $p.Id -Verb RunAs -Wait
```
- Синтетический ввод тоже elevated: `synth_click_elevated.bat X,Y`,
  `synth_key_elevated.bat -Keys 0x2E,90`.
- Проверка модулей: `modcheck_elevated.bat <pid>`.

## 4. Перезапуск скрипта БЕЗ перезапуска Dota (hot reload)
```powershell
Set-Content D:\hake\lotus\stop.txt 'stop' -NoNewline
Start-Sleep 15            # тики ~150 мс после оптимизации; в тяжёлых состояниях до 47 с → ждать до 80 с
Remove-Item D:\hake\lotus\stop.txt -Force
# УБЕДИТЬСЯ, что все состояния вышли: лог не растёт
$c1=(Get-Content D:\hake\lotus\host.log).Count; Start-Sleep 8
$c2=(Get-Content D:\hake\lotus\host.log).Count; "delta=$($c2-$c1)"   # должно быть 0
Set-Content D:\hake\lotus\run.txt 'D:\hake\lotus\src\bot_loop_run.lua' -NoNewline
Start-Process D:\hake\lotus\src\call_elevated.bat -ArgumentList $p.Id -Verb RunAs -Wait
# Проверить, что поднялось РОВНО ОДНО состояние:
#   в host.log после старта ровно один маркер "=== BOT LOOP ==="
```
**Критично:** `stop.txt` проверяется в НАЧАЛЕ итерации. Если тик долгий (47 с),
старое состояние живёт ещё десятки секунд после записи stop.txt. Не дождавшись,
получим два бота. Всегда проверять «log delta=0» и «один BOT LOOP маркер».

## 5. Остановка и закрытие
```powershell
Set-Content D:\hake\lotus\stop.txt 'stop' -NoNewline
Start-Sleep 15; Remove-Item D:\hake\lotus\stop.txt -Force
# дождаться log delta=0, затем при необходимости закрыть игру
Get-Process dota2 | Stop-Process -Force
```
Не оставлять half-swapped DLL и не оставлять несколько состояний.

## 6. Диагностика (зонды)
Запуск зонда: `Set-Content run.txt 'src\diag_X.lua'` + `call_elevated.bat <pid>`.
**Важно:** свежий diag-state НЕ разделяет scan бота. Зонды, читающие мир, должны
сами вызвать `loader.tick()`/`loader.updateGlobals()`, иначе `NPCs.GetAll()` пуст.

Ключевые зонды:
| Зонд | Что показывает |
|---|---|
| `diag_micro.lua` | микробенчмарк API (мкс/вызов), субстрат |
| `diag_api_parity.lua` | API-паритет early-game path: OK/GARBAGE/STUB/MISSING |
| `diag_attack.lua` / `diag_cd.lua` | сырые поля атаки/кулдауна, IsAttacking |
| `diag_abil.lua` | абилки, мана, модификаторы героя |
| `diag_dormant.lua` | дормантность/видимость крипов |
| `diag_towers.lua` / `diag_route.lua` | имена вышек, BuildPath между вышками |
| `diag_lh.lua` | lastHit.plan + per-creep фильтры |
| `diag_stats.lua` | боевые статы героя/крипа |
| `diag_cast.lua` | прямой тест каста (мана/кд до/после) |
| `audit_offsets.py` | fallback-оффсеты vs дамп схемы |
| `parity_diff.py` | наш self_play.log vs эталон → PARITY_DIFF.md |

Временные логи в скрипте (с бэкапом, откатывать после): `[perfdbg]`, `[routedbg]`,
`[lhrow]`, `[hits]`, `[blockrun]`, `[blockmove]`, `[move]`. Бэкапы оригиналов:
`backup_scripts_20261116_023749\`.

## 7. Приёмочный прогон (поведенческий паритет)
1. Очистить инструментацию (см. `KNOWN_ISSUES.md AI-13`): откатить оригинальные
   скрипты из бэкапа, убрать обёртки/дампы из раннера и loader.
2. Включить трейс: `configs/self_play_menu.ini` →
   `Display/Write decision diagnostics=1`, `Display/Write log to self_play.log=1`.
3. Одиночная игра против ботов, **Treant, role 4, lane 1**.
4. Дать матчу идти ≥ 10 минут, не выходить.
5. Собрать `self_play.log`, прогнать `parity_diff.py` против `REFERENCE_BEHAVIOR.md`.
6. Проверить контрольные точки:
   - 1:00: ≥1 `order=attack`, `attacks>0`, `heroDamage>0`, `lastHits>=1`.
   - 5:00: `lastHits>=5`, `XP>=1500`, есть `cast=`.
   - 10:00: `lastHits>=10`, `XP>=6000`, `candidates>0`.
   - `[SelfPlay score]` строки присутствуют (иначе прогон невалиден).
   > **2026-11-23:** LH/XP-чекпоинты сравнимы только на composition-matched матчах
   > (партнёр линии — support/solo, гейт `canLastHit` не активен): правило и фильтр —
   > `docs/ACCEPTANCE_2026-11-23.md §10`, `tools/comp_filter.py`. Иначе LH-строки — N/A.
7. Записать результат + хэши в `STATUS` и `KNOWN_ISSUES.md`.

## 8. Дисциплина доказательств
- Атрибутировать окна host.log по индексу строки/времени; не смешивать состояния.
- Считать только подписанные хэши; фиксировать хэш файла после каждого изменения.
- Reviewer PASS до QA-доказательства; не принимать «на глаз».
- Каждое расхождение с эталоном → гипотеза «какая функция API врёт» → зонд →
  фикс в слое причины → повторный замер (анти-whack-a-mole, `PORT_PLAN.md §1`).