# ARCHITECTURE — устройство порта Self Play

Актуально на 21.11.2026. Описывает, как оригинальный Lua-скрипт работает на нашем лоадере.

## 1. Рантайм и жизненный цикл

```
Dota2 (HIGH integrity)
 └─ host16.dll (инжект через src\inject_elevated.bat <pid>)
     ├─ DllMain → HostThread: watchdog читает D:\hake\lotus\run.txt
     ├─ run.txt = путь к скрипту → запуск в НОВОМ Lua-state (LuaJIT 2.1)
     ├─ stop.txt → остановка цикла (проверяется В НАЧАЛЕ итерации!)
     ├─ экспорт RunHost → перезапуск скрипта БЕЗ перезапуска Dota
     │   (src\call_elevated.bat <pid>)
     └─ Present hook: патч vtable slot 8 реального DXGI swapchain (рендер HUD)
```

- **Один цикл за раз.** Несколько состояний = конкуренция за тик и «медленные тики».
- **Остановка:** `stop.txt` → ждать (тики могут быть до 47 с в тяжёлых состояниях;
  после оптимизации ~150 мс, достаточно 15 с) → убедиться, что host.log не растёт →
  удалить stop.txt → запускать ровно один `call_elevated.bat`.
- Lua-правки: перезапись run.txt + RunHost = hot reload, без перезапуска Dota.
- Native-правки (host.cpp/render11.cpp): rebuild + перезапуск Dota (убивает матч).
  Только один член команды rebuild'ит; согласование с Lead.

## 2. Слои и файлы (src/)

| Файл | Роль |
|---|---|
| `host.cpp` | watchdog, Lua-host, DXGI Present hook, экспорт RunHost |
| `render11.cpp` | D3D11 рендер HUD/ClickGUI/маркеров, input hooks |
| `overlay.lua` | мост рисования: команды HUD → render11; pump() ввода |
| `menu.lua` | Umbrella-совместимые Menu/Widget (ClickGUI скрипта); персист в configs/self_play_menu.ini |
| `render.lua` | namespace Render (Text/Line/Rect/Circle/WorldToScreen…) |
| `entity.lua` | список сущностей: head/re-anchor, iter()/instance()/designerName(), byHandle; guarded reads |
| `api.lua` | основная API-поверхность: Entity/NPC/Hero/Heroes/Player/Players/Ability/Item/GameRules/Engine… |
| `loader.lua` | загрузка скрипта, globals/stubs (stubNS/define/forceDefine), **синтезатор событий**, tick |
| `globals.lua` | LaneGroupsManager и прочие глобальные менеджеры поверх scan |
| `orders.lua` | PrepareUnitOrders: прямой вызов функции игры (RVA), own-seq маркировка |
| `nav.lua` | GridNav: сетка препятствий, A* BuildPath, IsTraversable, CreateNpcMap, laneRoutes |
| `mathx.lua` | Vector/Vec2/Color/Angle (Umbrella-совместимые) |
| `schema.lua` | schema.offsetOf(cls, field) — живые оффсеты из дампа |
| `xhelpers.lua` | KV-данные (npc_abilities, npc_units, items) через xkv |
| `flags.lua` | features.txt: off=/stub= переключатели для бисекции |
| `enums.lua` | перечисления (GameActivity, ModifierState, UnitOrder…) |
| `bot_loop_run.lua` | драйвер: load Self Play, форс Role=1, включение свитчей, тик-цикл |
| `check_build.py` | сверка сборки: steam.inf + PUO-сигнатура + offsets.json vs KNOWN |
| `parity_diff.py` | дифф нашего self_play.log против эталона → PARITY_DIFF.md |
| `audit_offsets.py` | аудит захардкоженных fallback-оффсетов против дампа |
| `diag_*.lua` | ~46 живых зондов (см. TEST_PROTOCOL.md) |

Оригинальные скрипты (ЭТАЛОН, не редактировать как «фикс»):
`C:\Users\USER\AppData\Roaming\xYjGsPeqoWTEzbif\scripts\Self Play.lua` + `self_play/**`.
Бэкапы: `D:\hake\lotus\backup_scripts_20261116_023749\`.

## 3. Источники данных и их приоритет

1. **Дампер схемы** (`dumper\dota2_dumper.exe`, elevated, живая игра) →
   `dumper\dota2_dump\offsets.json`. Отдаёт **только 13 классов** (в т.ч.
   `C_DOTA_BaseNPC`, `C_DOTABaseAbility`, `C_BaseEntity`, `C_DOTAPlayerController`).
   `schema.offsetOf` читает его в рантайме.
2. **client.dll.hpp** (`dumper\dota2_dump\client.dll.hpp`) — все netvar-классы/поля;
   используется для class-name resolution и hppField fallback.
3. **KV** (xhelpers/xkv) — AttackAnimationPoint, ProjectileSpeed, AttackRange,
   AbilityManaCost,.item-данные и т.п.
4. **Захардкоженные оффсеты** — fallback, когда поля нет в дампе.
   **Зона риска:** классы `C_DOTAGamerules`, `C_GameRules`, `CBasePlayerController`
   В ДАМПЕ ОТСУТСТВУЮТ → для них работают только хардкоды (gameState 0x7C,
   gameStartTime 0x594, paused 0x38). При смене сборки проверять вручную.
   `audit_offsets.py` показывает расхождения fallback vs схема.

**Приоритет чтения поля:** `offOfFb(cls, name, fb)` сначала спрашивает схему,
fallback — только если схемы нет. Поэтому устаревший fallback для класса из дампа
не влияет; для класса вне дампа — влияет критически.

## 4. Синтезатор событий (loader.lua)

Оригинальный Umbrella получает события из движка. Мы **синтезируем** их поллингом
(AD-6: точный payload-контракт, без оптимистичной фабрикации):

```
scan(s, now) — один проход по списку сущностей за тик:
  для каждого npc_dota_*: rec{hp, life, team, act, seq, lat, x/y/z, yaw, ranged, dormant}
  ├─ hp упал vs прошлый тик        → OnEntityHurt {source, target, damage} (атрибуция по attackTargets)
  ├─ life 0→≠0                     → OnNpcDying (после hurt, чтобы lastSource был заполнен)
  ├─ act сменился на attack (1503/1504/1505/1570) рядом с героем
  │                                → OnUnitAnimation {unit, activity, castpoint, lag_compensation_time}
  │                                  castpoint = unitStats(name).point (KV или fallback)
  │                                  + scheduleProjectile (due = swingStart + castpoint)
  ├─ act ушёл из attack/cast       → OnUnitAnimationEnd
  └─ due projectile                → OnProjectile {source, target, moveSpeed, isAttack=true}
```

Скрипт потребляет события через `selfPlay.OnEntityHurt/OnUnitAnimation/OnProjectile/…`
→ `last_hit.lua` наполняет ledger (`ctx.hits.events/cycles`) → план ластхита.

**Контрактные тонкости:**
- `ATTACK_ACT = {1503,1504,1505,1570}`; **1502 = RUN, не атака** (баг 21.11).
- identity в payload — number (адрес identity); скрипт сравнивает `==` → типы должны
  совпадать с типами в ctx (number vs cdata mismatch ломает ledger молча).
- `m_flLastAttackTime` бывает в другой временной шкале (больше GameTime) — принимать
  только значения в прошлом на той же шкале.

## 5. Пайплайн приказов (orders.lua)

```
Player.PrepareUnitOrders(player, orderType, target, position, ability, issuer, unit, queue, …)
  → orders.prepare(type, targetIdx, vec3, abilityIdx, issuerInstance, queue, effects)
    → прямой вызов PrepareUnitOrders игры (RVA из сигнатуры, check_build.py)
    → orderMode="direct": marking _G.__botOwnSeq сразу (queue-drain не успевает)
```
- `pollOrders` в loader сверяет seq delta с `SYN.ownSeq` + `_G.__botOwnSeq` →
  отличает приказы бота от человеческих (пауза manual control).
- Сигнатура PUO: 25 байт `4C 89 4C 24 20 44 89 44 24 18 89 54 24 10 48 89 4C 24 08 55 53 56 57 41 56`.

## 6. Паритет-контракт и заглушки

- `stubNS(name, defaults)` — namespace с catch-all `__index`, который создаёт
  заглушку при первом обращении (логирует `stubNS: NS.Fn -> …`).
- `define(ns, f, fn)` — **НЕ перезаписывает** существующее raw-поле (защита от
  случайного перекрытия). Если заглушка уже создалась как raw-поле — define её не заменит.
- `forceDefine()` (rawset) — для принудительной замены заглушки реализацией
  (так чинили Entities.GetAll / NPCs.GetAll).
- **Правило:** любая used-функция = полная реализация ИЛИ явный блокер
  (почему нет аналога, что пробовали, что нужно). Скрытые заглушки запрещены (AD-7).

## 7. Ограничения LuaJIT (грабли, на которые мы наступали)

1. **200 локалов на чанк/функцию.** api.lua у лимита → новые локалы паковать в
   IIFE-фабрики (`local x = (function() … end)()`), иначе модуль не грузится.
2. **FFI access violation НЕ ловится pcall.** Разыменование нечитаемого указателя
   убивает игру. Все чтения — через page guard (`readable`/`pgOk`, VirtualQuery +
   кэш регионов). Никаких «сырых» pointer-walk без guard.
3. **Arity возвратов.** Обёртки `return a, b, c` с хвостовыми nil расширяют
   аргументы вызова (`math.max(0.3, f())` → «bad argument #3»). Тайминг-обёртки
   обязаны использовать `table.pack/table.unpack` (точное число возвратов).
4. **cdata vs number identity.** `ffi.cast` указатель ≠ Lua number в `==`, даже если
   адрес один. Нормализовать через `tonumber` на границах API.
5. **Lua 5.4 → 5.1 шимы:** utf8, table.unpack/pack, math.type/tointeger (loader.lua).

## 8. Производительность (дизайн кэшей)

- Список сущностей: один walk за тик (`beginTick` → re-anchor head, iter snapshot).
- `classCache` (TTL 3600 с) + `classNameIndex` (одноразовый нормализованный индекс) +
  negative-cache по designer — GetClassName был 40 с/тик, стал ~мкс.
- `buffCache` (0.1 с), `buffNameCache` (1 с), `indexMap` (0.25 с), hmap (0.5 с).
- `readable()`: кэш 32 регионов VirtualQuery.
- Инструментация: `APITOP[…]` (топ-8 API по времени), `[perf] tick` (фазы),
  `[api] calls/5s` (счётчики + vnew/nav/mem/fullGC). Микробенчмарк: `diag_micro.lua`.
- Текущий тик в матче: ~150–200 мс (было 45–48 с). Сырые API-вызовы: 0.5–1 мкс.

## 9. Хэши (21.11.2026, сборка 6986)

```
45D47A1FE3EEC76913283DA5AA08B94F  src\host16.dll   (INSERT+DELETE menu, /O2, 221 184 B)
E38AFFA61B0EDE13D6338CE7D32C2EA6  src\api.lua
5C84B2E50CF1E2FF60A9BA62EFDFFB72  src\entity.lua
AC8E325A792D45CA48521F46619A89C8  src\loader.lua
887E4947B159EEBA11A3AA4B2B475D41  src\orders.lua
FF9056D189A60765B4F987C08B7BCDA8  src\nav.lua
40F3FACD47993D581A66989E0D6F5D62  src\globals.lua
AC2D3701C9B2CD7E8CC3BD4AD6B54512  src\menu.lua
65625603D1D333FF010919F313E02ED9  src\overlay.lua
A6CD02F3B365DBC68073D1A9AB67DBE1  src\bot_loop_run.lua
D3D4F508F837887471AF7162CDC1DBC3  src\flags.lua
```
Ключевые RVA сборки 6986: PUO `0x1C19230`, dwLocalPlayerController `0x63E30A0`,
dwEntityList `0x66493F0`.

