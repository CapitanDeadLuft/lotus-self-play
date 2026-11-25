# Документация порта Self Play — индекс

**Актуальный авторитетный комплект на 21.11.2026.** Читать в этом порядке:

| # | Документ | О чём |
|---|---|---|
| 1 | [`PORT_PLAN.md`](PORT_PLAN.md) | **Главный.** Поэтапный план порта, карта зависимостей слоёв, анти-whack-a-mole протокол, критерии приёмки каждой фазы. |
| 2 | [`ARCHITECTURE.md`](ARCHITECTURE.md) | Как устроен порт: рантайм, слои/файлы, источники данных, синтезатор событий, пайплайн приказов, ограничения LuaJIT, кэши, хэши. |
| 3 | [`KNOWN_ISSUES.md`](KNOWN_ISSUES.md) | Реестр дефектов: открытые (по приоритету, с привязкой к слою) и исправленные (с корневыми причинами). |
| 4 | [`TEST_PROTOCOL.md`](TEST_PROTOCOL.md) | Как запускать/останавливать/мерить: правила теста, регрессионный минимум, hot reload, зонды, приёмочный прогон. |
| 5 | [`BUILD_MIGRATION.md`](BUILD_MIGRATION.md) | Что делать при обновлении сборки Dota: детект, дампер, обновление RVA, зона риска GameRules. |
| 6 | [`API_PARITY_STATUS.md`](API_PARITY_STATUS.md) | Текущее состояние API-паритета: переаудит 25 заглушек (2 закрыты, 23 открыты), батчи. |
| 7 | [UI_AUTOSTART.md](UI_AUTOSTART.md) | Скрипт автозапуска бот-матча за Treant (ИГРАТЬ→ИГРА С БОТАМИ→Treant→ВЫБРАТЬ), координаты, запуск. |
| 8 | [API_STUBS_BLOCKERS.md](API_STUBS_BLOCKERS.md) | Закрытые заглушки API и явные блокеры (GetBarriers/GetModifierProperty/FogOfWar/Bottle/Treads). |
| 9 | [ACCEPTANCE_2026-11-23.md](ACCEPTANCE_2026-11-23.md) | Приёмка после AI-13: очистка зондов (хэши), чистый прогон 10 мин (Treant role4 lane1), результаты vs S26/эталон, parity_diff, ограничения. **§10 (2026-11-23):** `canLastHit` эталонный, LH@5≥6 — только composition-matched (`tools/comp_filter.py`). |

## Ключевая идея плана
Self Play — слоёная система: **субстрат → значения API → события → модель мира →
ластхит → передвижение → бой → магазин → макро**. Передвижение *потребляет* цели
ластхита и модель мира, поэтому «бот странно бегает» — следствие нижних слоёв,
а не отдельный баг. Чинить снизу вверх, доказывать зондом, перепроверять всё выше.
Подробности и текущий фокус — `PORT_PLAN.md §0, §3`.

## Исторические документы (корень `D:\hake\lotus\`)
Оставлены как история/справка, **не заменяют** этот комплект в части очереди и приёмки:
- `../PORT_BRIEF.md` — исходный бриф (цель, layout, правила). Актуален как справочник.
- `../REFERENCE_BEHAVIOR.md` — **эталонные метрики и контрольные точки** (используется планом).
- `../PARITY_MATRIX.md` — правило паритета + список 25 заглушек (статус обновлён в `API_PARITY_STATUS.md`).
- `../ARCH_DECISIONS.md` — архитектурные решения AD-1…AD-12 (тест-протокол, события, заглушки).
- `../TEAM_PROTOCOL.md` — роли и write-scope команды.
- `PLAN.md`, `EVENING_PLAN.md`, `PM_STATUS.md`, `QA_REPORT.md`, `REVIEW.md`,
  `API_PARITY*.md`, `STATUS_2026-11-19.md` — история итераций 16–20.11.

## Где что лежит
- Наш лоадер: `D:\hake\lotus\src\` (host.cpp, api.lua, loader.lua, entity.lua, orders.lua, nav.lua, …).
- Оригинал-эталон (НЕ редактировать как фикс): `C:\Users\USER\AppData\Roaming\xYjGsPeqoWTEzbif\scripts\`.
- Бэкапы оригиналов: `D:\hake\lotus\backup_scripts_20261116_023749\`.
- Логи: `D:\hake\lotus\host.log` (наш), `…\xYjGsPeqoWTEzbif\self_play.log` (трейс скрипта).
- Дамп схемы: `D:\hake\lotus\dumper\dota2_dump\offsets.json` + `client.dll.hpp`.
