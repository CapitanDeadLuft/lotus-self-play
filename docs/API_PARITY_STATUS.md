# API PARITY STATUS — текущее состояние API-паритета

Актуально на 21.11.2026. Переаудит списка из 25 заглушек (`../PARITY_MATRIX.md`).
Метод: regex по `src/*.lua` (`function NS.Fn(` и `NS.Fn = function(`).

## Сводка (УТОЧНЕНО 21.11, живые данные)
- **В рантайме Self Play дёргает лишь 2 catch-all заглушки** (по `stubNS:` строкам
  host.log за все сессии): `Panorama.GetPanelByName` (намеренно nil) и
  `TempTrees.InRadius`. Обе **вне скоупа** (AD-5 / не влияют на «бот играет»).
- Прочие функции, которые regex-отчёт числил «missing», **реализованы** через
  `define()`/`forceDefine()` в loader.lua либо через nav.installGlobal:
  Item.GetCost (loader:525), Modifier.GetName (615), Couriers.GetLocal (749),
  World.GetGroundZ (348), Tower.GetAttackTarget (733), Input.IsInputCaptured (701),
  NPCs.GetAll (forceDefine), GridNav.* (nav). Regex `function NS.Fn(` их не ловит.
- **Список «25 заглушек» в `PARITY_MATRIX.md` получен сканированием ВСЕЙ папки
  scripts (все скрипты), а не только Self Play.** Функции «батча 1»
  (Heroes.InRadius, NPC.IsPositionInRange, NPC.IsBuilding, Players.Get/Count,
  Entity.GetAbsOriginXYZ, NPC.GetAttackTime, Ability.GetOwner/IsOwnersManaEnough,
  GameRules.GetDOTATime) **НЕ вызываются Self Play** — только LDfarm/shaman_combo/
  stacker/behaviorscorehelper/gank_threat/dominator_autofarm. Для этого порта они
  **не нужны**. Реализовывать их — значит тратить effort не на тот скрипт.
- **Вывод:** API-поверхность Self Play по сути реализована. Фаза 1 — это не
  «закрыть заглушки», а **проверить КОРРЕКТНОСТЬ значений** decision-critical
  функций (боевая математика, состояния, счёт игрока). Заглушка может быть
  реализована, но возвращать неверное значение (как IsAttacking/HasState до фикса).

## Реальные остаточные заглушки (вне скоупа, не блокируют)
| Функция | Статус |
|---|---|
| `Panorama.GetPanelByName` | намеренно nil (драфт-UI, не нужен для игры) |
| `TempTrees.InRadius` | таблица-приближение (временные деревья; проверить влияние на nav) |

## Приоритет фазы 1 (корректность, а не реализация)
1. **Боевая математика** (кормит ластхит/бой): GetTrueDamage/GetTrueMaximumDamage,
   GetAttackSpeed, GetSecondsPerAttack, GetAttackRange(+Bonus), GetAttackAnimPoint,
   GetPhysicalArmorValue, GetArmorDamageMultiplier — сверить с HUD/известными значениями.
2. **Счёт игрока** `Player.GetTeamPlayer` (DataTeamPlayer_t) — сейчас мусор
   (denies=693..2372, networth=0, heroDamage=0). Кормит win model/buy. См. AI-3.
3. **Состояния/модификаторы** — HasState/IsAttacking/GetModifiers уже исправлены
   21.11; перепроверить на стабильном прогоне.

## Связанные реализованные функции (есть, использовать как образцы)
`Entity.GetHeroesInRadius`, `NPC.GetArmorDamageMultiplier`, `Players.GetAll`,
`NPC.GetAttackSpeed` (читает m_flAgilityTotal для героев), `Entity.GetAbsOrigin`.

## Вне скоупа (AD-5, пока одиночная игра)
`GC.GetSteamID/SendMessage`, `HTTP.Request`, `Panorama.GetPanelByName`, matchmaking.
Явные блокеры, не требуются для теста «бот играет против ботов».

## Правило закрытия (из PARITY_MATRIX)
Каждая функция: (а) юнит-тест на живом матче (значение vs HUD), (б) граничные случаи
(nil, мёртвый юнит, нет маны), (в) ошибки (несуществующий индекс → тот же тип возврата),
(г) запись в этот файл. **Заглушка ≠ реализация**; заглушка только как явный блокер.

## Следующий шаг
Фаза 1 = **корректность значений**, не реализация заглушек. Начать с боевой
математики (урон/скорость атаки/дальность/броня vs HUD) и `Player.GetTeamPlayer`
(счёт игрока, AI-3). После каждой — зонд + перепроверка зависимого слоя
(ластхит/win model). Функции «батча 1» из PARITY_MATRIX для Self Play не нужны.