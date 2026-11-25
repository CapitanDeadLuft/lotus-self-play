# REFERENCE BEHAVIOR — эталон оригинала (для поведенческого паритета)

Источник: `C:\Users\USER\AppData\Roaming\xYjGsPeqoWTEzbif\self_play.log` (лог ОРИГИНАЛЬНОГО Umbrella).
Формат строк — тот же, что пишет скрипт (наши запуски пользуются тем же `self_play/log.lua`).

## Метрики эталона (реальные матчи, Nov 17)

| Last hits к минуте | максимум по сессиям (оригинал) |
|---|---|
| 0–5 мин | 6 |
| 5–10 мин | 10 |
| 10–15 мин | 43 |
| 15–20 мин | 19 |
| 20–25 мин | 24 |

Распределение приказов (по строкам `[SelfPlay] ... order=…`):
`move 3950`, `hold 682`, `cast 560`, **`attack 312`**.

Распределение режимов (`mode=`):
```
Dead: wait for respawn                 1434
Support lane: deny and protect          772
Escort allied core                      725
Break enemy contact                     364
Protect allied core                     293
Travel to ward position                 285
Prepare support stack                   183
Travel to available lane farm           128
Regenerate near lane in safety          119
Support lane: deny and protect (safer)  117
```

## Как измерять наш порт (одинаковые метрики)

Скрипт пишет один и тот же трейс, если включён `Display/Write decision diagnostics=1`
(у нас в `D:\hake\lotus\configs\self_play_menu.ini` уже `=1` и `Display/Write log to self_play.log=1`).
Файл пишется в `Engine.GetCheatDirectory() + "/self_play.log"`.
Если каталог не определён — строки уходят в `host.log` через `Log.Write`.

**Строки для сравнения (на тик/интервал):**
- `[SelfPlay score] clock=… lastHits= denies= networth= gold= xp= heroDamage= laneGold= jungleGold= …`
- `[SelfPlay] role= lane= mode=… hp= pos= busy= attacks= cancelled= build= buy= cast= provider= order=…`
- `[SelfPlay actions] time= target= lock= creepAggro= candidates= lastSwing=`
- `[SelfPlay fight task]`, `[SelfPlay prediction]`, `[SelfPlay value]`

## Найденный разрыв (замер 18.11, матч с v4o)

| Метрика | Оригинал | Наш порт | Разрыв |
|---|---|---|---|
| Приказы `ATTACK_TARGET`/`ATTACK_MOVE` | 312 строк `order=attack` | **0 из 407 приказов** | комбат/фарм не запускается |
| Строки `[SelfPlay score]` | 372 записи | **0** | трейс решений не пишется/не доходит |
| Кандидаты в цели (`candidates=`) | есть | неизвестно | не измерено |
| Режимы | deny/protect, escort, break contact | только `Farming the lane`/`going home` | до комбата не доходит |

## План паритетного прогона

1. Наш матч с включённым трейсом → получить те же строки.
2. Построить те же агрегаты (lastHits по минутам, распределение order/mode).
3. Дифф по полям: `mode`, `order`, `attacks`, `candidates`, `target`, `lastSwing`, `buy`, `cast`.
4. Каждое расхождение → гипотеза «какая функция API отдаёт неверное значение» → закрыть функцию по правилу
   (полная реализация или согласованный блокер) → повторный замер.

## Ограничения

- Оригинальные сессии — с героем `axe`, роль 3/4; наши — `treant`, роль 4. Сравнивать нужно
  структурные метрики (наличие attack-ордеров, покрытие режимов, темп lastHits), а не абсолютные значения.
- Сейчас в том же логе лежат и наши сессии → разбор по заголовкам `===== Self Play session <date> =====`.
## ЭТАЛОН ДЛЯ НАШЕГО СЦЕНАРИЯ (Treant, role 4, lane 1) — из лога оригинала

Извлечено 18.11.2026 из `self_play.log` (369 in-game записей `hero=npc_dota_hero_treant role=4 lane=1`;
сырой дамп: `reference_treant.jsonl`).

**Контрольные точки (максимум, достигнутый оригиналом к минуте):**

| Минута | lastHits | XP | heroDamage |
|---|---|---|---|
| 1 | 4 | 354 | 483 |
| 2 | 4 | 1068 | 731 |
| 3 | 6 | 1579 | 1004 |
| 4 | 6 | 1884 | 1228 |
| 5 | 6 | 2882 | 1533 |
| 6 | 8 | 3937 | 1954 |
| 8 | 9 | 6700 | 2024 |
| 10 | 12 | 10878 | 2689 |

**Распределение приказов (Treant-сессии):** `move 5131`, `hold 1082`, `cast 859`, **`attack 520`**.

**Покрытие режимов (Treant-сессии):**
```
Dead: wait for respawn                 1434
Support lane: deny and protect          772
Escort allied core                      725
Break enemy contact                     364
Protect allied core                     293
Travel to ward position                 285
Approach enemy in allied fight          240
Prepare support stack                   183
```

**Эталонные строки (пример из матча):**
```
[0:39] [SelfPlay] role=4 lane=1 mode=Fight with allies: focus confirmed opponent hp=1.00 pos=-6066,3698 busy=0.00 attacks=2 cancelled=0 build=Build Brain 7.41f pos 4 buy=arcane_boots > recipe_ring_of_basilius cast=treant_leech_seed provider=ok order=attack
[1:12] [SelfPlay score] clock=72.3 lastHits=1 denies=2 networth=1104 gold=554 xp=341 heroDamage=483 laneGold=68
[1:03] [SelfPlay] mode=Fight with allies … attacks=7 cast=treant_natures_grasp order=move
```

**Приёмочные критерии нашего порта (Treant, role 4, lane 1, одиночная игра против ботов):**
1. К 1:00 — есть хотя бы один `order=attack`, `attacks > 0`, `heroDamage > 0`, `lastHits >= 1`.
2. К 5:00 — `lastHits >= 5`, `XP >= 1500`, покрытие режимов включает `Support lane: deny and protect` и хотя бы один `cast=` (не только подхил).
3. К 10:00 — `lastHits >= 10`, `XP >= 6000`, `attack`-ордера присутствуют, `candidates` в `[SelfPlay actions]` > 0.
4. `[SelfPlay score]` строки присутствуют (трейс включён) — иначе прогон невалиден для сравнения.
