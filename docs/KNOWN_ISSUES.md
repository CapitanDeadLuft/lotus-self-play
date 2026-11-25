# KNOWN ISSUES — реестр дефектов порта

Актуально на 21.11.2026. Каждый дефект привязан к **слою** (см. `PORT_PLAN.md §0`).
Правило: чинить в слое причины, после фикса перепроверять слой и всё выше.

## A. Открытые дефекты (по приоритету)

### AI-19. `NPC.GetAttackAnimPoint` отдавал СЕКУНДЫ вместо доли цикла → замах в BAT раз длиннее (слой 2) — ИСПРАВЛЕНО 22.11
- **Симптом:** `lastHit`-конверсия почти нулевая (lh=1 к 5:47), бот «мажет» по таймингу, хотя попытки есть.
- **Корень:** все потребители Self Play считают замах как `GetAttackAnimPoint(unit) / GetAttackSpeed(unit)`
  (`last_hit.lua:36/114/166/363/393`, `heroes/common.lua:185`, `engagement.lua:66`), т.е. API обязан
  возвращать **долю цикла атаки**. Мы возвращали сырой KV `AttackAnimationPoint` в секундах (Treant 0.6),
  поэтому замах считался 0.6/0.5578 = **1.14 с** вместо реальных **0.566 с** — выстрел начинался
  на ~0.57 с раньше нужного и урон приходил до окна добивания.
- **Фикс (api.lua):** `GetAttackAnimPoint = AttackAnimationPoint / BaseAttackTime`
  (алгебра: fraction/aps = (AAP/BAT)/((1+IAS)/BAT) = AAP/(1+IAS) — реальный windup).
- **Верификация (live, зонд `[armor]`: `animPt` и `windup`):**
  - Treant lvl1: `animPt=0.3158`, **windup=0.566 с** (было 1.14) ✓
  - melee lane creep: `animPt=0.4670`, windup=0.467 с ✓
  - ranged lane creep: `animPt=0.5000`, windup=0.500 с ✓
- **Эффект:** Treant role 4 lane 1 — **lh=6 к 3:27** (до фикса lh=1 к 5:47), совпадает с эталонной
  контрольной точкой (6 к 3 мин); `[SelfPlay prediction] addedHits>0` 41% → **54%**.

### AI-20. Причина нулевых ЛХ измерена: два разных гейта (слой 2/позиционка)
Зонд `[plan]` внутри `lastHit.plan` (бэкап `backup_scripts_.../last_hit.lua.bak_20261122b`,
восстановлен после замера) показал по матчам:
- **Матч A (17:55):** `creeps=6 seen=6 allied=3 gateBlocked=3 cands=0` — **все** вражеские крипы
  сняты гейтом `laneRules.canLastHit` (уступка фарма core-союзнику в 1200). Это штатная логика
  оригинала; при core-партнёре в линии role-4 обязан уступать → lh≈0 ожидаем, и это НЕ баг.
- **Матч B (18:06-18:09, без core рядом):** `gateBlocked=0`, отказы на гейте
  `health < damage*2 or #events > 0` (`noFlag` 2–7 за тик), изредка `cands=1 chosen=true`.
  Т.е. дальше лимитирует **покрытие ledger** (предсказание смертей крипов) — измерено косвенно
  по `addedHits` (54% строк >0).
- **Вывод для acceptance:** контрольная точка «lh≥5 к 5 мин» из `REFERENCE_BEHAVIOR.md` сравниваема
  только при сопоставимой композиции линии (в эталоне, судя по lh=6 к 3 мин, core рядом не фармил).
  Иначе метрика занижается штатной уступкой фарма.
- **2026-11-23 (формализовано, статус закрыт как «не дефект»):** `canLastHit` оставлен
  эталонным (MD5 `BEC5932A1C125C9A4E9C6541355D0CE1`), правок слоя 2 нет. Метрика
  **LH@5≥6 сравнивается только на composition-matched** матчах (партнёр линии — support
  по `lane_choice.isSupport`, либо solo). Отбор — `tools/comp_filter.py`; правило и
  run-book — `docs/ACCEPTANCE_2026-11-23.md §10`; разбор и ретро-классификация —
  `docs/LAYER2_2026-11-23.md §10`.

### ОПС-ЗАМЕТКА (важно для зондов). Клиент перезаписывает `scripts/`
22.11 зафиксировано: правки в `C:\Users\USER\AppData\Roaming\xYjGsPeqoWTEzbif\scripts\` **пропали**
после перезапуска клиента (зонды `[harass]`/`[engprobe]` исчезли, `planprobe` в файле = 0), хотя в
другой раз патч выжил. Правило: после каждого перезапуска клиента проверять наличие зонда в файле
(`Select-String planprobe`) и при необходимости копировать пропатченный файл из `D:\hake\lotus\patches\`.
Наши правки в `D:\hake\lotus\src\*.lua` (api/loader/orders) от этого не страдают.

### ОПС-ЗАМЕТКА (UI). Панель «Играть»: боты открываются отдельным пунктом
Актуальный поток (проверено 22.11): ИГРАТЬ (1685,1025) → **ИГРА ПРОТИВ БОТОВ (1711,550)** →
СИЛЫ СВЕТА (1624,682) → **ИГРА С БОТАМИ (1688,1034)**. Важно: (1700,1035) при НЕоткрытой секции
ботов попадает в «НАЙТИ ИГРУ» и запускает поиск РЕАЛЬНОЙ игры (дважды случилось, оба раза отменено).
Пик Treant: (213,658) → проверить имя в предпросмотре (кроп 1345,190,380,60) → ВЫБРАТЬ (1485,828)
→ экран стратегии должен показать TREANT PROTECTOR.

### AI-16. Броня считалась без агилы → бот отказывался от любых боёв (слой 1) — ИСПРАВЛЕНО 22.11
- **Симптом:** `heroDamage=0` первые 9–10 минут каждого матча (эталон: 483 к 1:00,
  1533 к 5:00). `[engprobe]` показывал `incoming=673..832` при hp 443–620 →
  `remaining=-220..-344` → `safe=false` всегда, `killTime=15.5s > 8`.
- **Корневая причина:** `NPC.GetArmorDamageMultiplier` читал
  `C_DOTA_BaseNPC::m_flPhysicalArmorValue` (0x16A4, есть в схеме) как ИТОГОВУЮ броню.
  Живая сверка с HUD 22.11: Weaver lvl10 — HUD броня **8**, поле **1.0**, агила 48;
  Weaver lvl14 — HUD **11**, поле всё ещё **1.0**. То есть поле = броня БЕЗ агилы.
  Отсюда множитель 0.943 вместо 0.676 → весь входящий физический урон завышался на
  ~40% → бот считал любой бой смертельным.
- **Фикс (api.lua):**
  - `NPC.GetArmorValueTotal` = поле + `m_flAgilityTotal`(0x1B78) × 0.14 (героям);
  - `NPC.GetArmorDamageMultiplier` использует total и правильную ветку для
    отрицательной брони (A<0: `1 - 0.06A/(1-0.06|A|)`);
  - добавлены недостающие API Umbrella: `GetPhysicalArmorMainValue`,
    `GetPhysicalArmorValue(e, excludeWhiteArmor)`, `GetMagicalArmorValue`.
- **Верификация (22.11, live):**
  - Крипы: поле=main=total=**2.00**, mult=0.893 — совпадает с реальной бронёй
    melee lane creep (2) ✓.
  - Герой Dark Willow lvl3: наш total **3.39**, HUD **4** → ошибка множителя 0.5%
    (было 21% при field-only).
  - **Поведение:** heroDamage 0 → **140 / 372 / 593 / 956** к 0:21/1:23/2:24/3:25;
    в режимах первых 5 мин появились `Fight with allies: focus confirmed opponent` (13)
    и `Approach enemy in allied fight` (4) — ровно та лексика эталона, которой не было.
- **Остаток (документированный гэп B-2):** броня от предметов и бонусный MR берутся из
  модификаторов и в клиентских полях отсутствуют. Ошибка: броня ~0.6 (Dark Willow),
  ~1.2 (Weaver lvl14); MR: наше 25% против HUD 29–46%. Требует `GetModifierProperty`
  (blocker B-2).

### AI-17. `NPC.GetMoveSpeed` возвращает базовый MS без предметов (слой 1)
- **Данные:** Weaver — наш **275**, HUD **325**; Dark Willow — наш 275/290, HUD **290**.
  `m_iMoveSpeed` (0xD40) = базовый MS; бонусы обуви/предметов идут модификаторами.
- **Влияние:** недооценка своей/чужой скорости → ошибки в оценках времени подхода и
  позиционки (`spacing`, `navigation`). Не блокер, но точность ниже.
- **Закрытие:** тот же B-2 (модификаторы) либо поиск иного поля.

### AI-18. `Ability.GetDamageType` — константа 0, ability/item KV без значений урона (слой 1)
- **Данные:** `[kv]` зонд: для всех абилок Weaver `GetDamage=0`, `GetDamageType=0`,
  в KV нет ни одного ключа с "damage". Значит `awareness.burst` живёт только на
  статическом каталоге Self Play (`effect.damage`), а митигация урона заклинаний не
  применяется ни в одну сторону.
- **Влияние:** оценка магического burst/входящего урона героев смещена.
- **Закрытие:** нужен источник значений абилок (KV/`AbilityValues` в игре) — отдельная
  задача; до тех пор задокументированная аппроксимация.

### AI-14. КРАШИ role 4 — ЗАКРЫТ 22.11 (PUO trailing-param garbage → dangling после p_close)
- **Симптом:** Dota падает через ~5–30 мин role 4 матча.
- **Три дампа:**
  - 21.11 03:56:35 — FFI PUO→client AV.
  - 21.11 04:12:48 — поток игры, `call [rax+398h]` rax=0 (нулевой target).
  - **22.11 01:03:45** (`dota2_2026_1122_010345_0_accessviolation.mdmp`, game 5:50 чистого
    прогона): AV c0000005, **rip=0x4e5`52080300 — ВНЕ client/engine2, в малом heap-регионе
    (1.27 kB), исполняемом как код** (LuaJIT mcode / callback-трамплин). Caller:
    **client+0x1981e6b** → client+0x19eea38 → engine2!Source2Main (game main loop).
    Регистры-маски entity: r14=0x7fff, rsi=0xffff, rbp=ffffffff00000000.
- **Гипотеза (22.11):** игра вызывает зарегистрированный callback/function-pointer,
  указывающий на freed/invalid LuaJIT mcode (освобождённое состояние или GC-трамплин),
  либо FFI-итерация entity с битым указателем внутри mcode. Это НЕ путь выдачи приказов
  (guard'ы orders его не покрывают) — другой механизм, чем дампы 21.11.
- **Guard'ы 21.11 (orders/api) остаются** (защита PUO/null-target), но этот краш мимо них.
- **Механизм-кандидат (22.11, host.cpp):** `RunScript` (host.cpp:47-61) на каждый запуск
  создаёт `p_newstate()`, а при выходе цикла (stop.txt) делает **`p_close(L)`** —
  освобождает Lua-state и ВЕСЬ его JIT-mcode. В этой сессии было ~6 рестартов state.
  Если игра держит function-pointer в mcode закрытого state (PUO-callback, ffi.cast
  closure, GC-освобожденный trace) → отложенный вызов из game-потока → AV в freed mcode
  (сигнатура дампа 01:03:45). loader синтезирует события поллингом (native-регистрации
  нет), но orders.lua передаёт `callback` в PrepareUnitOrders, render.lua:45 кастует
  Lua-closure в `R_EnumProc`.
- **Нужно (приоритет = блокер):**
  1. Идентифицировать client+0x1981e6b (что за callback: order-completion / panel / event).
  2. Аудит: какие Lua-указатели игра сохраняет (PUO callback param, ffi.cast closure).
  3. Тест гипотезы: прогон БЕЗ рестартов state (один state с горна) — если краш уйдёт,
     виноват p_close/dangling; если останется — GC trace или живой callback.
  4. Фикс-кандидаты: не делать p_close (переиспользовать state), либо deregister/обнулить
     game-held callback перед close, либо держать mcode живым.
- **Влияние:** длинные acceptance-прогоны (≥10 мин) нестабильны → паритет-метрики 10 мин
  не собрать надёжно, пока не закрыто. Короткие прогоны (<5 мин) пригодны для лейнинг-диагностики.
- **ТЕСТ БЕЗ РЕСТАРТОВ (22.11 01:30–01:42): ПОДТВЕРЖДЕНИЕ гипотезы.** Свежая Dota
  (PID 15288, инжект 1 раз, state 1, `p_close` НЕ было) → матч с горна прожил
  **11:37 игрового времени БЕЗ краша** ( Responding=True, нового mdmp нет). Все предыдущие
  краши (3–8 мин и 5:50) происходили в процессах с ПРЕДЫДУЩИМИ рестартами state (p_close).
  Caller краша идентифицирован: `client+0x1981e65 call [rax+3A0h]` — виртуальный метод 116
  в цикле итерации entity игры; rdi=heap-объект, vtable=heap → указатель в freed LuaJIT mcode.
- **Источник game-held указателя (кандидат):** orders.lua вызывает нативный PUO с **9
  аргументами**, а нативный PUO читает стековые параметры до arg13+ (пролог: home arg1-4,
  читает [rbp+80h]=arg7 issuer, далее arg8-13). Наш cdef endet на showEffects(arg9) →
  **arg10+ (callback/executeFast/identifier/forceMinimap) = мусор со стека**. Если мусор —
  указатель в Lua-память, игра сохраняет его (order callback/identifier) и диспатчит во
  время think → после p_close указатель dangling → AV. Umbrella doc: callback=bool,
  identifier=string (player.md:22-24).
- **ФИКС (предложен):** передать явные дефолты trailing-параметров PUO
  (callback=false, executeFast=false, identifier=NULL, forceMinimap=false) → игра не
  сохраняет мусорные указатели. Дополнительно/альтернатива: не делать p_close (держать
  state/mcode живым) либо deregister перед close. Верификация: restart-heavy прогон.
- **ФИКС РЕАЛИЗОВАН И ПОДТВЕРЖДЁН (22.11):**
  - orders.lua: cdef PrepareUnitOrdersFn расширен 4×uint64_t (arg10-13), вызов PUO
    передаёт `0,0,0,0` (явные дефолты). host.cpp: PUO_fn typedef + вызов g_puo в
    PresentCore расширены аналогично (`0ULL×4`). **Важно:** комментарии внутри ffi.cdef
    только `//` (LuaJIT C-парсер не принимает `--` → "declaration specifier expected").
  - host16.dll пересобран: **60C50197AC1F7E60C2135AE33A7C6711** (221184 B), бэкап
    pre-fix 45D47A1F… = host16.dll.bak_pre_puofix. orders.lua=2735A8C41BAE42AE49DA1C8A0B225462,
    host.cpp=3D5E697D381EAFC74CA93C48C80E445C.
  - **Верификация restart-heavy:** свежая Dota PID 2352, fix-DLL, матч с горна +
    **3 рестарта state (p_close×3)** → прожил **17:06 игрового времени БЕЗ краша**
    (Responding=True, нового mdmp нет; score lh6/dn9/hd188/xp5357). Для сравнения:
    до фикса рестарты давали краш за 3–8 мин (и 5:50). Контроль без рестартов (до фикса,
    чистый process) тоже жил 11:37 → триггер именно p_close+мусорный указатель, не gameplay.
  - **Вывод:** корень = нативный PUO читает стековые arg10+; 9-arg вызов оставлял мусор,
    иногда указатель в LuaJIT-память → игра сохраняла → после p_close dangling → AV в
    итерации entity (call [vtable+3A0h]). Явные нули устраняют источник. **Блокер acceptance снят.**

### AI-15. Ложная пауза «Paused: manual control» — ИСПРАВЛЕНО 21.11 (подтверждено)
- **Причина:** m_nNextOutgoingOrderSequenceNumber@0x9B8 инкрементится при ОТПРАВКЕ
  приказа (след. кадр), не синхронно в PUO; markOwnSeq сразу после PUO читал старое
  значение → не отмечал → pollOrders видел свой приказ как human=1 → вечная пауза.
- **Фикс:** оптимистично mark seqBefore+1 (orders.lua issueNative, direct mode).
- **Подтверждено:** в role 4 матче новых «human order armed» нет, бот не залипает.

### AI-1. Денаи/ластхиты роли 4 — ЗАРАБОТАЛИ 21.11 (корень = производительность)
- **Итог:** denies 1→2→3 к 5:32, lastHits=3, stacked=1, heroDamage=457 (role 4 lane 3).
  Бот денаит своих крипов, ластхитит, стакает, дерётся — как эталон.
- **КОРЕНЬ был производительность:** readable() кэш регионов VirtualQuery=32 → thrash
  при скане 5766 сущностей → тики 2–30 с → бот не успевал действовать (denies=0,
  mode=Deny=0, «стоит»). ФИКС: кэш 32→512 (entity.lua+api.lua) + reuse API_MBI →
  тики 87–224 мс (avg 13–31 мс). Ниже — исторический анализ (заглушки/логика были НЕ при чём).
- **Остаток:** темп сверить с эталоном role 4 lane 1 (наш lane 3); позиционирование
  (eligible часто 0 — крипы не ниже 50% в快照). Зонды [denylane]/[denyexec] в probe.log.
- **Что работает:** счёт (AI-3) исправлен; события синтезируются (castpoint крипа 0.467);
  ledger наполняется (events до 6); герой атакует (confirmed=2); боевая математика сходится.
- **Механика отказа (зонд `[lhwhy]`):** `lastHit.plan` → `window()` возвращает `impact=nil`
  при `farmSafe=true` → кандидат не добавляется. `window` ищет момент, когда
  `timeline.canKill(low, high, collision, damage)` = `low>0 and high<=damage and not collision`.
  `high` = предсказанный HP крипа после входящего урона (события ledger) + regen.
- **Две гипотезы (РАЗРЕШИТЬ зондом `[lhdiag]`):**
  1. **Данные (слой 1/2):** события ledger несут неверный урон (`ev.minimum/maximum` = 0
     или мусор) → `high` никогда не падает ниже `damage` → canKill всегда false.
     Проверить `NPC.GetTrueDamage` крипа-источника и `evMin/evMax` в `[lhdiag]`.
  2. **Позиционирование (слой 5):** крипы умирают раньше, чем герой доходит
     (`inRange=false, approach=2–3 с`) → collision/low<=0 → canKill false.
- **Готовый зонд:** `[lhdiag]` в Self Play.lua (core.tick, после helpers.sample) — по каждому
  вражескому крипу: hp, GetTrueDamage, GetTrueMaximumDamage, GetHealthRegen,
  GetArmorDamageMultiplier + события ledger (evN, evMin, evMax, evImp). Ждёт живого матча.
- **Следующий шаг:** запустить матч, прочитать `[lhdiag]`: если evMin/evMax=0 → баг данных
  (чинить урон событий); если evMin/evMax нормальные (~20) → позиционирование (фаза 5).
- **Скорость атаки:** base=90 bat=1.9 agi=27 (hpp-оффсеты корректны), secAtk=1.62 — сверить с HUD.

### AI-2. Передвижение «странное» (слой 5) — НЕ ЧИНИТЬ ДО AI-1
- **Симптом:** бот странно бегает; creep block стартует на ~55 с; уходит далеко
  вперёд волны; якоря линии пустые (`ctx.waves` → `rawLaneAnchor` у своей базы).
- **Причина:** следствие незакрытых фаз 3–4. Цели движения приходят из ластхита и модели мира.
- **Нужно:** сначала AI-1, затем проверить `navigation.goal`, `lane_geometry.route`,
  `creep_block.stage`, `waveGroups.enemy` (enemyWaves появляется поздно).
- **Статус:** ожидаемое следствие, не отдельный баг.

### AI-3. Счёт игрока — мусор (слой 1) — ИСПРАВЛЕНО 21.11, ждёт живой сверки
- **Симптом:** `[SelfPlay score] denies=693..2372, networth=0, heroDamage=0,
  observers=-1, gold=8872 при clock=0.3`.
- **Корневая причина (найдена 21.11 по hpp):** в новой сборке в `DataTeamPlayer_t`
  вставлено поле `m_iMidasGold` на 0x90 → все оффсеты от networth и дальше сдвинулись
  на +4…+8. Наши значения были из старого билда: networth читал m_iMidasGold (0x90
  вместо 0x94), deny_count читал networth (0x94 вместо 0x98), lasthit читал deny
  (0x98 вместо 0x9C) и т.д. Отсюда «denies=693» (на самом деле networth) и «networth=0».
- **Фикс:** `Player.GetTeamPlayer` переписан по авторитетному hpp
  (`dumper/dota2_dump/client.dll.hpp`, namespace DataTeamPlayer_t): networth 0x94,
  deny 0x98, lasthit 0x9C, hero_damage 0x10C, gold_lost_to_death 0xFA0, madstone 0xFC8/0xFCC,
  NeutralChoices 0xFD0. Страйд `DTP_STRIDE` 0x12F0→0x12A0 (hpp size; для локального
  игрока slot 0 страйд не важен — проверить для slot>0 вживую).
- **Статус:** код исправлен (api.lua хэш 910EAF07…), синтаксис OK. **Нужна живая сверка**
  в матче: lastHits/denies/networth/gold/xp должны совпасть с HUD.
- **Влияние:** win model, buy-решения, оценка эффективности.

### AI-4. Спам кастов (слой 6)
- **Симптом:** Living Armor кастуется каждый тик (~5–7 с) на цель, которую игра
  не принимает; кд не стартует → `IsReady` остаётся true.
- **Доказательство:** прямой тест каста РАБОТАЕТ (мана 387→119, кд 23.9 с) —
  значит проблема в выборе цели/условиях `tactics.cast`, не в приказах.
- **Нужно:** лог в `tactics.cast` (цель, валидность, `api.cast` результат, кд после);
  проверить `common.visible`, `api.allowed`, дистанцию, `HasModifier` цели.

### AI-5. Залипание сташа/доставки (слой 7)
- **Симптом:** `buy=Collect items from stash at base` / `Await paid item delivery`
  надолго; бот стоит на базе.
- **Нужно:** проверить `shop.courier` логику (`hasStash/hasItems/stashFits`),
  видимость слотов 9–14 (сташ) через `NPC.GetItemByIndex`, команды курьера.

### AI-6. ТП не используется (слой 6/7)
- **Симптом:** `[SelfPlay travel] lane: no scroll ready; gate on cooldown`.
- **Нужно:** проверить видимость тп-свитка в инвентаре/сташе, `teleports` логику,
  кулдаун гейта.

### AI-7. IsWaitingToSpawn — временный false (слой 1/3)
- **Симптом:** схемный байт `m_bIsWaitingToSpawn` (0x17A8) = 1 у ВСЕХ живых крипов →
  `helpers.scan` отсекал весь мир.
- **Временное решение:** `NPC.IsWaitingToSpawn -> false` (мёртвые отсекаются IsAlive).
- **Нужно:** найти корректную семантику (возможно, поле сменило смысл/оффсет в 6986;
  сверить с поведением оригинала). Помечено как TEMP в api.lua.

### AI-8. GameRules-классы вне дампа (слой 0) — ВЕРИФИЦИРОВАНО 22.11, остаточный риск
- **Симптом:** `C_DOTAGamerules`, `C_GameRules`, `CBasePlayerController` отсутствуют
  в offsets.json (дампер отдаёт 13 классов).
- **22.11:** все хардкоды этих классов сверены с client.dll.hpp билда 6989:
  m_nGameState=0x7C ✓, m_flGameStartTime=0x594 ✓, m_iGameMode=0xE4 ✓,
  m_fGoodGlyphCooldown=0x5B8 ✓, m_fBadGlyphCooldown=0x5BC ✓, m_hGameModeEntity=0xE8 ✓,
  m_iszPlayerName=0x6E4 ✓, m_bIsLocalPlayerController=0x778 ✓.
  **Найдены и исправлены 2 ошибки:** m_bGamePaused 0x38→**0x3C** (C_GameRules),
  m_unMatchID64 0x858→**0x958**. Остальные хардкоды (player resource 0x760/0x960,
  controller m_nSelectedUnits 0x9C8/seq 0x9B8, team-data 0x108/0xC0/0xC4/0xA0)
  сверены с hpp — корректны.
- **Остаточный риск:** при смене сборки классы вне схемы могут уехать молча.
  **Нужно:** расширить дампер этими классами ИЛИ прогонять hpp-сверку при каждой
  миграции (`BUILD_MIGRATION.md` + audit_offsets.py).

### AI-9. Остаточная производительность (слой 0)
- **Симптом:** тик ~150–200 мс; `base_defense.update` 1.5–2.3 с, `runes.observe` 1.7 с,
  `decide.run` 1 с (замеры ДО кэш-фиксов — перемерить).
- **Нужно:** перемерить APITOP после фиксов; профилировать внутренние циклы
  base_defense/runes/decide; убрать оверхед тайминг-обёрток для acceptance-прогона.

### AI-10. Engine.ExecuteCommand — заглушка (слой 1)
- **Симптом:** только пишет в лог; консольные команды не исполняются.
- **Влияние:** нельзя автостарт бот-матча (`dota_start_ai_game`), camera-команды.
- **Нужно:** реверс engine command dispatch (блокер-engine, согласовать).

### AI-11. Humanizer.GetOrderQueue — заглушка (слой 2)
- **Влияние:** `creep_block.waitingOrder` не видит очередь приказов.
- **Нужно:** читать очередь из контроллера (order vector 0x9A0 / next seq 0x9B8 —
  оффсеты старого билда, перепроверить).

### AI-12. Matchmaking/GC/HTTP — вне скоупа (AD-5)
- Пока тестовое правило — одиночная игра против ботов, не требуется.
- Заглушки: GC.GetSteamID/SendMessage, HTTP.Request, Panorama. Явные блокеры.

### AI-13. Очистка инструментации перед acceptance (процесс)
- В скриптах и раннере временные зонды: `[perfdbg]/[routedbg]/[lhrow]/[hits]`
  (Self Play.lua, last_hit.lua, creep_block.lua), APITIME-обёртки (bot_loop_run.lua),
  `[npcs]` one-shot логи (loader.lua), PROBE/LANE дампы.
- **Нужно:** перед приёмочным прогоном откатить оригинальные скрипты из бэкапа
  (`backup_scripts_20261116_023749`), убрать обёртки/дампы из раннера и loader.
- **Решить:** fallback в awareness.lua:52 (`lv or 0`) — корневая причина была в
  arity обёрток (исправлено); вероятно, откатить к оригиналу для чистоты эталона.
- **Статус 23.11.2026 — очистка ВЫПОЛНЕНА:** удалены `[roster]/[laneprobe]/[lh5]/
  [armor]/[kv]/[support]/[aspd]/[pregame]`, per-tick `loop`, `LANE` dump,
  `[apitime]`/perf-обёртки, `[synTgt]`, `[npcs]`, probe2 `[ledger]`; `last_hit.lua`
  восстановлен из бэкапа `F52C068C…`; `Self Play.lua` не менялся. Хэши и проверка
  (0 probe-строк в логах, 1 `BOT LOOP`) — `docs/ACCEPTANCE_2026-11-23.md`.
- **Результат acceptance 23.11 (10:17, role=4 lane=1):** LH 0/0/0 на 1/5/10 мин
  (S26: 0/5/12), XP 2477@10 (S26: 7955), heroDamage 862@10 (S26: 2496);
  все 11 решений `[SelfPlay last hit]` — денаи союзных крипов, 0 по вражеским;
  свича линии нет (S26: 6:24). PASS: режимы deny/protect, касты, attack-ордера,
  candidates>0. Отчёт: `docs/ACCEPTANCE_2026-11-23.md`.

### AI-21. Синтез OnUnitAnimation: цель резолвится не всегда (слой 2) — БЕЗОПАСНЫЙ ФИКС 23.11
- **Симптом (измерение, не догадка):** на канал синтеза приходится 128–131% событий positive-ledger,
  но из принятых анимаций инсертится **85.4%**: `no-target` **8.3%** (напр. `npc_dota_creep_badguys_ranged`,
  `IsAttacking=true`, yaw осмысленный, но `FindFacingNPC`-конус не находит цель), reject по
  `NPC.IsAttacking=false` **5.3%**, far 0.9% (2 окна, ~95с, 302 события).
- **Влияние:** пропущенное событие → нет ни ledger-события, ни DP-записи (`unit_attack`), т.к. оба канала
  резолвят цель одной и той же геометрией. В `ev0act` (крип недавно получал урон, событий нет):
  цель→self 0%, →другое существо 31%, nil 69%; будущих DP-ударов 0% → разрыв ВЫШЕ `prediction.merge`.
- **Фикс (23.11, безопасный вариант, измерен):**
  1. `loader.lua`: инвалидация `SYN.attackTargets` (и `SYN.unitAttack`) по `OnEntityDestroy` —
     записи, ссылающиеся на уничтоженный idn (как атакующий idx, так и source/target), удаляются
     ДО диспатча; сброс матча чистит таблицу IN PLACE (глобал не устаревает).
  2. `loader.lua`: `findTarget`+запись таргета ПЕРЕНЕСЕНЫ ДО `fire(OnUnitAnimation)` — раньше запись
     отставала на один замах, и первый замах по новой цели (главный случай промаха конуса) не имел записи.
  3. `api.lua FindFacingNPC`: приоритет `_G.SYN_attackTargets[idx]` с guard `readable(idn,0x20)` +
     `inst>0x10000` ДО `designer()/origin()`, TTL 1.5с, те же team/alive/range проверки; конус не требуется
     (наблюдаемая цель — ground truth синтеза). Временные счётчики `[synTgt]` (убрать при приёмке, AI-13).
- **Замер (матч 3, Radiant/Treant/role4/lane1, 302 окна, 0–6:30):** animNoTgt **6.07%** принятых
  (baseline 8.3%, v1 без реордера 7.9%); insert **93.9%** (85.4%); evPos/chk 53.9% (53.8%);
  SYN-путь hit **91.7%** (10820/11800), guard-реджектов **0**, ttl 4.6%, dead 2.5%, dist 1.2%.
  LH к 5:25 = **2**, denies 1 (эталон lane1: 0–6, гейт `canLastHit` при core-союзнике <1200 — оригинальная логика).
- **Остаток 6%:** случаи, где сам `findTarget` не находит цель (reach/loose-cone), плюс ttl-пропуски;
  для полного нуля нужен engine-true target (schema-поле) — отдельная задача.

### AI-22. Краш 22.11 22:50:23 = lifetime-unsafe idn из SYN_attackTargets в FFI (ЗАКРЫТ safe-фиксом)
- **Дамп:** `E:\SteamLibrary\...\game\bin\win64\dota2_2026_1122_225023_0_accessviolation.mdmp` (5.3 МБ).
- **Стек:** `VCRUNTIME140!memcpy+0x10d ← lua51!lj_cconv_tv_ct+0x14b ← lua51!lj_cdata_get+0xf0 ←
  lua51!lj_cf_ffi_meta___index+0xa8 ← lua51!lj_BC_FUNCC ← lua51!lua_pcall+0xaa ← host16+0x7fb9 ← host16+0x398a`;
  `READ_ADDRESS 0x458216e05d8` (невалидный). Падение — в НАШЕМ Lua-состоянии внутри event-pcall
  (FFI-AV не ловится pcall), а не в игровом потоке.
- **Причина:** фикс AI-21 возвращал `idn` из `SYN_attackTargets`; запись не инвалидируется при
  уничтожении юнита, и мёртвый handle доходил до `designer()/origin()` без guard.
- **Статус 23.11:** безопасный вариант внедрён (AI-21): инвалидация по destroy + readable/inst guard.
  Матч 3 (6.5 мин) и матч 1 (15 мин) — guard-реджектов 0, крашей нет. Дополнительно ужесточены
  строковые guard'ы: `entity.cstr`/`api.cstrAt`/`loader.cstrAt`/`Modifier.GetName` проверяют ПОЛНОЕ
  окно (96/128 байт) перед `ffi.string`, а не 1 байт (закрыт класс cross-page memcpy-AV).

### AI-23. Краш 23.11 23:52:46 (прегейм матча 2) = ffi.string → lj_str_new → hash_sparse (ОТКРЫТ)
- **Дамп:** `dota2_2026_1122_235246_0_accessviolation.mdmp`.
- **Стек:** `lua51!hash_sparse+0x21 (mov ecx,[rax+r9-2], rax=0x30) ← lua51!lj_str_new+0x4c ←
  lua51!lj_cf_ffi_string+0xbe ← lua51!lj_BC_FUNCC ← lua51!lua_pcall+0xaa ← host16+0x7fb9 (fire) ← host16+0x398a`.
  READ_ADDRESS `0x47f0b72efde` (unmapped). Интернирование строки после успешного копирования ffi.string.
- **Контекст:** прегейм (state=4, gt≈59), новых путей фикса на стеке НЕТ (SYN-записей в прегейме нет,
  реордер/инвалидация — чистая Lua). Перед крашем `OnEntityDestroy=3` (колбэк читает имена умирающих
  сущностей — гонка с освобождением памяти игровым потоком). Lua однопоточна (drawOnly в скрипт-потоке) —
  межпоточная гонка Lua-состояния исключена.
- **Меры:** полное окно readable перед ffi.string (см. AI-22). Матч 3 после hardening — 6.5 мин без краша.
- **Статус:** сигнатура новая, корень до конца не доказан; при рецидиве — дамп + анализ аллокатора/GC.
  Исторические краши 01:03 (engine2, игровой поток) и 04:12 (дамп удалён) — другие сигнатуры.

---

## B. Исправленные дефекты (история, с корневыми причинами)

| Дата | Дефект | Корневая причина | Фикс |
|---|---|---|---|
| 18.11 | tier0 AV при приказах | устаревший PUO RVA 0x1B5F860 | сигнатурный поиск + check_build.py |
| 19.11 | краш lj_cconv_ct_ct | unguarded FFI deref (pcall не ловит AV) | page guards readable/pgOk во всех чтениях |
| 19.11 | VirtualQuery «struct 233» | два разных cdef символа | единый API_MBI cdef во всех модулях |
| 19.11 | NPCs.GetAll=0 | define() не перезаписывает raw-заглушку | forceDefine (rawset) |
| 19.11 | инвентарь невидим, спам покупок | слотовые оффсеты устарели | перечисление item_* по владельцу (itemAt) |
| 19.11 | «human order armed» на своих приказах | queue-drain не успевает маркировать | __botOwnSeq + orderMode=direct |
| 20.11 | сборка 6979→6986 | ежедневный churn Valve | дампер + 4 файла + check_build (процедура) |
| 20.11 | краш в лобби (0xDC8) | hullRadius: inst=0 truthy в Lua | проверка inst > 0x10000 |
| 20.11 | iter()=1–4 вместо 5700 | ensureList не re-anchor'ил при headAt=0 | условие `(not head) or headAt==0` |
| 20.11 | IsAttacking=true на бегущих | 1502=RUN считался атакой | атака = 1503/1504/1505 |
| 20.11 | новые крипы «атакующие» | m_flLastAttackTime > GameTime попадал в допуск | принимать только t<=now и now-t<0.3 |
| 20.11 | тик 40–48 с | GetClassName сканировал все классы на каждый entity, кэш 3 с, промахи не кэшировались | classNameIndex + negative-cache + TTL 3600 |
| 20.11 | несколько ботов одновременно | stop.txt проверяется в начале итерации, тики до 47 с | процедура stop+wait+verify |
| 21.11 | HasState читал мусор | оффсет 0x12B8 устарел | schema m_nUnitState64=0x1330 |
| 21.11 | модификаторы всегда пусты | MOD_MGR_OFF 0xE30 устарел + раскладка vector | schema 0xE98 + перебор раскладок с проверкой имени |
| 21.11 | «bad argument #3 to max/min» в 5 модулях | тайминг-обёртки возвращали хвостовые nil (arity expansion) | table.pack/table.unpack во всех обёртках |
| 21.11 | api.lua не грузится (>200 локалов) | новые chunk-locals в buffObjects | IIFE-фабрика |
| 21.11 | тики 2–30 с, бот не денаит/не ластхитит | readable() кэш регионов VirtualQuery=32 thrash на 5766 сущностях | кэш 32→512 + reuse API_MBI → тики ~100 мс; денаи/ластхиты/стакинг заработали |
| 21.11 | бот стоит все ~90с pre-game, не закупается/не блокирует | `GetGameTime` возвращал **-1** при state<5 → ctx.now=-1 ломал тайминги | монотонные wall-часы для state 2–4 (cs.pregameWall), сброс при горне; подтверждено: бот двигается и стагит блок до горна |
| 22.11 | после рестарта state часы показывают ~0:58 вместо реальных ~14:30 (src=wall, samples=0) | attackClockSample хардкодил 0x13C8/0x13C4 (в 6989 это pose-параметры анимации) → max-атак-время не находилось → wall-fallback | schema-first offOfFb m_flLastAttackTime=0x1440/m_flLastDamageTime=0x143C; подтверждено: src=atk, samples=74/10s, in_game совпадает с HUD |
| 22.11 | GetStatesDuration всегда 0 (станы/состояния «не активны») | маска состояний читалась по старому 0x12B8 (в 6989 = m_nAnimationTransitionPoseParameters) | offOfFb m_nUnitState64=0x1330 (схема) |
| 22.11 | бот role 4 Radiant ушёл в bottom (lane 3) вместо offlane top | configs/self_play_menu.ini хранил Bot/Lane=3 (из Dire-сессии); helpers.lane() отдаёт ui.lane:Get() как есть | ini Lane=0 + раннер форсит laneWidget:Set(1) (Top=lane 1, эталон); ctx переинициализируется при смене laneSetting (Self Play.lua:1812) |
| 22.11 | синт-клавиши (ESC/`) не достигают игры | keybd_event со scan=0; SDL/Source2 читает scan-коды | MapVirtualKeyA(vk,0) → scan в keybd_event (synth_key.ps1) |
| 22.11 | 58 fallback-констант offOfFb/field/offO устарели относительно схемы 6989 | латентный риск: при отказе схемы читались бы неверные поля | src/fix_fallbacks.py синхронизировал все 58; audit_offsets.py → 0 mismatch |

**Классы ошибок (повторяются):**
1. **Устаревшие оффсеты после смены сборки** → процедура `BUILD_MIGRATION.md` + audit_offsets.py.
2. **Unguarded FFI** → всегда page guard.
3. **Заглушка перекрыла реализацию (define semantics)** → forceDefine + аудит stubNS.
4. **Arity/типы на границах API** → table.pack/unpack, tonumber-нормализация.
5. **Lua truthy (0=true)** → явные проверки указателей > 0x10000.

