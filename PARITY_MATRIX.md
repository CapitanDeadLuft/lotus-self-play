# PARITY MATRIX — поведенческий паритет API (рабочий контракт)

**Правило (принято Lead'ом, 18.11.2026):**
«Точь-в-точь» = идентичное поведение с точки зрения вызывающего скрипта: те же входы и их обработка,
те же возвраты (тип/структура/смысл), те же побочные эффекты, те же ошибки в тех же ситуациях, те же тайминги.
Заглушка ≠ реализация. Заглушка допустима только как явная отметка с блокером (почему нет аналога,
что пробовали, что нужно для снятия). Скрывать отсутствие реализации за заглушкой нельзя.
Закрываем по одной функции; после каждой — проверка эквивалентности (норма / границы / ошибки).

Источник истины по «используемым» функциям: сканирование `C:\Users\USER\AppData\Roaming\xYjGsPeqoWTEzbif\scripts`
(regex по Namespace.Symbol). Источник истины по «реализованным»: `src/*.lua` (regex по `function NS.Sym(`).

## Сводка (замер 18.11.2026, 02:05)

| Метрика | Значение |
|---|---|
| Символов API, используемых скриптами | **208** |
| Есть явная реализация в `src/` | **183** |
| Только catch-all (`stubNS`) — скрытые заглушки | **25** |
| Реально «дёрнутых» заглушек в живых матчах (по host.log) | **2** (`Panorama.GetPanelByName` — намеренно nil, `TempTrees.InRadius` — таблица) |

## Таблица соответствия: 25 незакрытых (статус = блокер-заглушка)

Легенда статуса: `TODO-impl` — реализуемо из имеющихся примитивов (нужна проверка на живом матче),
`BLOCKER-offset` — нужен новый оффсет/поле схемы (не найден), `BLOCKER-engine` — нужен движковый вызов,
которого у нас нет, `BLOCKER-src` — нужен источник данных (GC/локализация).

| # | Функция | Используется в | Статус | План / блокер |
|---|---|---|---|---|
| 1 | `Ability.GetAutoCastState` | self_play (spell_policy) | TODO-impl | флаг autocast у абилки; найти поле в `C_DOTABaseAbility`, иначе BLOCKER-offset |
| 2 | `Ability.GetChannelStartTime` | self_play (brain) | BLOCKER-offset | время начала канала; поле не найдено в схеме — нужен реверс |
| 3 | `Ability.GetOwner` | common/hero units | TODO-impl | владелец = `C_BaseEntity::m_hOwnerEntity` → entity |
| 4 | `Ability.IsAttributes` | planner/catalog | BLOCKER-offset | «это атрибуты» = ability index 0..2; можно эмулировать по индексу (уточнить) |
| 5 | `Ability.IsOwnersManaEnough` | spell_policy | TODO-impl | сравнить `Ability.GetManaCost` с `NPC.GetMana` владельца |
| 6 | `Engine.GetDisplayNameByUnitName` | HUD/session | BLOCKER-src | локализация имён; можно вернуть unit name как fallback (согласовать) |
| 7 | `Engine.PlayVol` | HUD/звук | BLOCKER-engine | воспроизведение звука — у нас нет аудио-канала; вернуть no-op с фиксацией |
| 8 | `Entity.GetAbsOriginXYZ` | common | TODO-impl | вернуть x,y,z из `Entity.GetAbsOrigin` |
| 9 | `Entity.IsAbility` | common | TODO-impl | проверка типа сущности (ability vs npc) по схеме/классу |
| 10 | `GameRules.ChatMessage` | session/чат | BLOCKER-engine | отправка чата через движок; можно `engine cmd say` — требует проверки |
| 11 | `GameRules.GetDOTATime` | brain/timers | TODO-impl | вывести из `GameRules.GetGameTime`/`GetGameState` |
| 12 | `GameRules.GetGameEndTime` | session | BLOCKER-offset | время конца игры; поле не найдено |
| 13 | `GameRules.GetLobbyID` | session | BLOCKER-src | ID лобби из GC — нет доступа |
| 14 | `Hero.GetStrengthTotal` | heroes/*, common | TODO-impl | сумма силы; candidate: `DataTeamPlayer` или hero stats |
| 15 | `Heroes.InRadius` | **combat/targeting** | TODO-impl | перебор `Heroes.GetAll` + дистанция по `GetAbsOrigin`/`GetHullRadius` |
| 16 | `NPC.GetAttackTime` | last_hit/combat | TODO-impl | из `NPC.GetAttackSpeed` (интервал = 1/speed с учётом BAT) |
| 17 | `NPC.GetBaseSpellAmp` | spell_policy | BLOCKER-offset | базовая spell amp; поле не найдено |
| 18 | `NPC.GetCastRangeBonus` | cast_geometry | BLOCKER-offset | бонус к радиусу каста; поле не найдено |
| 19 | `NPC.GetMagicalArmorValue` | combat | TODO-impl | из `DataTeamPlayer`/NPC-полей; проверить на живом матче |
| 20 | `NPC.GetPhysicalArmorValue` | combat | TODO-impl | из `DataTeamPlayer` (armor) или NPC-поля; проверить |
| 21 | `NPC.GetSpellAmplification` | spell_policy | TODO-impl | из hero attributes/DataTeamPlayer |
| 22 | `NPC.IsBuilding` | **targeting** | TODO-impl | класс `C_DOTA_BaseNPC_Building` через схемный тест |
| 23 | `NPC.IsPositionInRange` | **combat/cast** | TODO-impl | дистанция `GetAbsOrigin` + radius; уточнить семантику (cast vs attack range) |
| 24 | `Players.Count` | session/player list | TODO-impl | из массива игроков (`m_vecPlayerTeamData`, `m_playerIDToPlayer`) |
| 25 | `Players.Get` | session/player list | TODO-impl | из того же массива по индексу |

## Гипотеза по «бот не атакует» (проверяется в след. матче)

В живом матче зафиксировано **0 приказов** `ATTACK_TARGET`/`ATTACK_MOVE` из 407 отправленных
(только MOVE/HOLD/CAST/PURCHASE/TRAIN). Слой решения до атаки не доходит.
Наиболее вероятная причина — заглушки, через которые комбат-слой ищет цели:
`Heroes.InRadius` (пустая таблица), `NPC.IsPositionInRange` (false), `NPC.IsBuilding` (false),
`Players.Get/Count` (0). Они закрываются первым батчем (№8, 15, 22, 23, 24, 25).

## Порядок закрытия (батчи)

**Батч 1 (разблокирует комбат/фарм):** 8, 15, 22, 23, 24, 25, 11, 16, 3, 5
**Батч 2 (боевые числа):** 19, 20, 21, 14, 1
**Батч 3 (блокеры — только после согласования):** 2, 4, 6, 7, 10, 12, 13, 17, 18

Проверка для каждой закрытой функции: (а) юнит-тест на живом матче (значение сравнивается с тем,
что видно в игре/HUD), (б) граничные случаи (nil-сущность, мёртвый юнит, отсутствие маны),
(в) ошибки (несуществующий индекс → тот же тип возврата, что и в оригинале), (г) запись в этот файл.