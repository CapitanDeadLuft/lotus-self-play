# ПЛАН НА ВЕЧЕР (после стабилизации патчей Dota и Umbrella)

Договорились: пока обе стороны патчатся, живые прогоны не делаем. Всё готово,
чтобы вечером пройти по шагам без импровизации.

## 0. Что уже сделано (19.11, ночь)
- Пересчитаны оффсеты под сборку **988312-1dd77a06d103d1a**:
  `dwLocalPlayerController=0x63E10A0`, `PrepareUnitOrders=0x1C17410`.
- Мир снова виден в живом матче: `ally_creeps=26, enemy_creeps=15`, видимость `114/150`.
- Починена ложная пауза «ручной приказ» (помечаем свои sequence — `_G.__botOwnSeq`).
- Меню сохраняется в `configs/self_play_menu.ini` (включает трейс решений).
- Все сырые чтения обёрнуты `readable()`.
- Остался детерминированный краш `lua51!lj_cconv_ct_ct` через ~2 с после старта
  Self Play → лечим бисекцией (инструмент готов, см. шаг 3).

## 1. Проверить, не сменилась ли сборка (30 секунд)
```powershell
python D:\hake\lotus\src\check_build.py
```
- `OK: build matches ...` → можно сразу к шагу 2.
- `!! BUILD CHANGED` → выполнить шаги из вывода:
  1) `dumper\dota2_dumper.exe` (elevated, при живой игре) — новые `offsets.json`;
  2) обновить `M.gamerulesRVA` в `src/entity.lua` и строку gamerules в `src/api.lua`
     значением `dwLocalPlayerController`;
  3) `src/orders.lua` → `M.prepareUnitOrdersRVA` = PUO rva из вывода скрипта;
  4) поправить `KNOWN` в `check_build.py`.

## 2. Запуск (как обычно)
```powershell
Set-Content D:\hake\lotus\run.txt 'D:\hake\lotus\src\bot_loop_run.lua' -NoNewline
Start-Process 'steam://rungameid/570'; # дождаться окна, затем:
Start-Process D:\hake\lotus\src\inject_elevated.bat -ArgumentList <pid> -Verb RunAs -Wait
```
Герой — **Treant**, одиночная игра против ботов (правило тестов).
Перезапуск скрипта без перезапуска игры: `stop.txt` → удалить → `call_elevated.bat <pid>` (RunHost).

## 3. Если снова краш через ~2 с — бисекция через `D:\hake\lotus\features.txt`
Файл читается на лету (`src/flags.lua`), править код не нужно:
```
off=events_projectile      # не доставлять OnProjectile скриптам
off=visibility_mask        # не использовать маску видимости (fallback на dormancy)
stub=Player.GetTeamPlayer  # функция API вернёт nil (без чтения памяти)
stub=Entity.IsDormant      # то же для dormancy
```
Менять **по одному**, после каждого — RunHost и смотреть, исчез ли краш.
Порядок из наблюдений: события → GetTeamPlayer → visibility_mask → IsDormant.
Как только краш исчез — сузить до конкретной функции и починить по новой схеме
(`dumper\dota2_dump\offsets.json`).

## 4. Когда краша нет — приёмочный прогон
1. Матч Treant role 4 (конфиг: `configs/self_play_menu.ini`, Role=1 Carry или 4).
2. 10 минут игры, затем:
```powershell
python D:\hake\lotus\src\parity_diff.py     # наш трейс vs эталон
```
3. Смотреть контрольные точки из `REFERENCE_BEHAVIOR.md`:
   к 1:00 — есть `order=attack`/`attacks>0`; к 5:00 — `lastHits>=5`, `XP>=1500`,
   режим `Support lane: deny and protect`; к 10:00 — `lastHits>=10`, `XP>=6000`.
4. Записать md5 `host16.dll` до/после и строку в `src/host16.dll.md5.txt`.

## 5. Текущее состояние
- Dota закрыта, ничего не запущено.
- Активный `src\host16.dll` = **BB36C1CBE5401AAD6A7F602D357E71D7** (v4o), бэкап 422751ED рядом.
- `run.txt` → `bot_loop_run.lua`; `features.txt` — пустой шаблон с комментариями.
- Справка: `STATUS_2026-11-19.md`, `PARITY_MATRIX.md`, `REFERENCE_BEHAVIOR.md`.