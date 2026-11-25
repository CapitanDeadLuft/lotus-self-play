# BUILD MIGRATION — что делать при обновлении сборки Dota

Valve катит хотфиксы почти ежедневно (за 19–20.11: 987800→988312→6979→6983→6984→6985→6986).
Смещение оффсетов → краши или «бот слепой». **Не запускать бота, пока миграция не завершена.**

## 1. Детект смены сборки
```powershell
python D:\hake\lotus\src\check_build.py
```
Скрипт сравнивает `steam.inf` (ClientVersion/SourceRevision), PUO-сигнатуру и
`offsets.json` против KNOWN-baseline. Вывод «BUILD CHANGED» = нужна миграция.
Он же печатает новый PUO RVA (сигнатурный поиск) и engine RVA из дампера.

## 2. Процедура миграции (по порядку)
1. **Запустить Dota** (инжект не обязателен для дампера, но игра должна быть жива).
2. **Дампер** (elevated, живая игра):
   ```powershell
   Start-Process D:\hake\lotus\dumper\dota2_dumper.exe -WorkingDirectory D:\hake\lotus\dumper -Verb RunAs -Wait
   ```
   Обновит `dumper\dota2_dump\offsets.json` (engine RVA + 13 классов схемы).
   Сохранить предыдущий: `Copy-Item offsets.json offsets_prev_<ts>.json`.
3. **PUO RVA** — взять из сигнатурного поиска `check_build.py` (уникальная 25-байт
   сигнатура). Обновить `src\orders.lua`: `M.prepareUnitOrdersRVA = <новый>`.
4. **dwLocalPlayerController** — из дампера (`engine.dwLocalPlayerController`).
   Обновить ДВА места:
   - `src\entity.lua`: `M.gamerulesRVA = <новый>`
   - `src\api.lua`: строка `gamerules()` → `clientBaseCache + <новый>`
5. **dwEntityList** — из дампера; обновить KNOWN в `check_build.py` (и entity.lua,
   если там есть хардкод).
6. **KNOWN-baseline** в `check_build.py`: `client_version`, `puo_rva`,
   `local_player_controller_rva`, `entity_list_rva`.
7. **Проверка:** `python src\check_build.py` → «OK: build matches baseline».
8. **Аудит оффсетов:** `python src\audit_offsets.py` → xem расхождения fallback vs схема.
   Для классов ИЗ дампа схема приоритетна (fallback не влияет). Для классов ВНЕ дампа
   (GameRules/PlayerController) — проверить хардкоды вручную (см. ниже).

## 3. Зона риска: классы вне дампера
Дампер отдаёт только 13 классов. **`C_DOTAGamerules`, `C_GameRules`,
`CBasePlayerController` отсутствуют** → их оффсеты только захардкожены:
- `C_DOTAGamerules.m_nGameState = 0x7C`
- `C_DOTAGamerules.m_flGameStartTime = 0x594`
- `C_GameRules.m_bGamePaused = 0x38`
- `C_DOTAGamerules.m_fGoodGlyphCooldown / m_fBadGlyphCooldown`, `m_hGameModeEntity`

При смене сборки эти значения могут уехать → часы/состояние игры сломаются молча.
**Верификация зондом:** `[clock]` строки (gt/gs/state/in_game) должны быть осмысленны
(`in_game = gt - gs` растёт, state соответствует PRE_GAME/IN_PROGRESS). Если часы
«застряли» или state неверный — искать новые оффсеты GameRules (реверс/сигнатуры).
Желательно расширить дампер этими классами (задача на будущее).

## 4. Поля, которые уже «уезжали» (история, проверять при миграции)
| Поле | Старое | Новое (6986) | Где |
|---|---|---|---|
| m_NetworkActivity | 0x18E8 | 0x1960 | IsAttacking |
| m_flLastAttackTime | 0x13C8 | 0x1440 | IsAttacking |
| m_nUnitState64 | 0x12B8 | 0x1330 | HasState |
| m_ModifierManager | 0xE30 | 0xE98 | buffObjects |
| m_bIsWaitingToSpawn | 0x1730 | 0x17A8 | IsWaitingToSpawn (семантика под вопросом) |
| m_flMana | 0xCFC | 0xD60 | GetMana |
| m_iAttackRange | 0xCC8 | 0xD28 | GetAttackRange |
| m_flBaseAttackTime | 0xCE8 | 0xD48 | GetAttackSpeed |
| m_flHullRadius | 0xD60 | 0xDC8 | GetHullRadius |
| m_iDamageMin/Max | 0xE18/0xE1C | 0xE80/0xE84 | GetTrueDamage |

Большинство теперь читаются через `offOfFb` (схема приоритетна) — миграция дампера
их лечит автоматически. **Хардкоды вне схемы — лечить вручную.**

## 5. После миграции
- Прогнать регрессионный минимум (`TEST_PROTOCOL.md §2`).
- Зонд субстрата (entity count), боевой математики, событий.
- Только затем бот. Записать новые RVA/хэши в `STATUS` и `ARCHITECTURE.md §9`.

## 6. Сборка host16.dll (если менялся native)
```
cmd /c "call ""C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvarsall.bat"" x64 >nul && cd /d D:\hake\lotus\src && cl /O2 /LD /EHsc host.cpp /Fe:host16.dll /link user32.lib gdi32.lib d3d11.lib dxgi.lib ole32.lib d3dcompiler.lib"
```
- Native-правки требуют перезапуска Dota (убивает матч). Только один член команды
  rebuild'ит; согласование с Lead.
- Записать хэш `host16.dll` в `src/host16.dll.md5.txt`; не оставлять half-swapped DLL.
- Текущий рабочий: `BB36C1CBE5401AAD6A7F602D357E71D7` (v4o).