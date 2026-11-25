# PARITY DIFF — наш порт vs оригинал (Self Play, Treant role 4)

Источники: оригинал — `self_play.log` Umbrella (sessions Nov 17 + live), наш — `D:\hake\lotus\self_play.log`.

## Контрольные точки (последнее значение к минуте)

| Минута | Оригинал lastHits/XP/heroDmg | Наш порт lastHits/XP/heroDmg |
|---|---|---|
| 1 | 0 / 16 / 0 | 0 / 0 / 0 |
| 3 | 0 / 656 / 112 | 0 / 421 / 0 |
| 5 | 3 / 4522 / 859 | 0 / 1033 / 571 |
| 10 | 7 / 8301 / 2459 | 0 / 2477 / 862 |
| 15 | 11 / 28894 / 5846 | 0 / 2708 / 862 |

## Приказы (строки mode ... order=)

| order | оригинал | наш порт |
|---|---|---|
| move | 9768 | 137 |
| hold | 2158 | 62 |
| cast | 1735 | 2 |
| attack | 1193 | 7 |

## Покрытие режимов (топ-10)

| mode | оригинал | наш порт |
|---|---|---|
| Support lane: deny and protect | 1555 | 49 |
| Break enemy contact | 768 | 4 |
| Fight with allies: focus confirmed opponent | 324 | 3 |
| Support lane: deny and protect (safer spot) | 267 | 26 |
| Lane spacing: hold covered attack access | 241 | 16 |
| Lane spacing: approach covered attack access | 211 | 5 |
| Regenerate near lane in safety | 191 | 0 |
| Prepare support stack | 143 | 6 |
| Draw melee creeps toward allied ranged creep | 125 | 17 |
| Stop short, enemy heroes ahead: Support lane: deny and protect | 138 | 4 |
| Step out of enemy attack reach | 110 | 3 |
| Last hit: reach creep window | 105 | 2 |

## Метрики

| метрика | оригинал | наш порт |
|---|---|---|
| score-строк | 729 | 11 |
| mode-строк | 14881 | 210 |
| max attacks (в строке mode) | 157 | 30 |
| [SelfPlay actions] строк | 14881 | 210 |
| actions с candidates>0 | 691 | 12 |

## Решения (decide ran=)

| ran | оригинал | наш порт |
|---|---|---|
| fight | 1082 | 6 |
| hunt | 208 | 1 |
| initiate | 1 | 0 |
| lane | 7253 | 191 |
| retreat | 1355 | 6 |
| ward | 492 | 0 |
