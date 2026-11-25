# API STUBS — закрытые и блокеры (21.11.2026)

Правило паритета: каждая используемая функция = полная реализация ИЛИ явный блокер
(почему нет аналога, что пробовали, что нужно для снятия). Скрытые заглушки запрещены.

## Закрытые заглушки (21.11)
| Функция | Было | Стало |
|---|---|---|
| `Input.IsInputCaptured` | always false | реальное состояние ClickGUI (overlay.isMenuOpen) |
| `NetChannel.GetLatency` | always 0 | делегирует GetAvgLatency (m_flLastUnitOrdersTotalLatency@0x948 /2) |
| `Humanizer.GetOrderQueue` | absent (catch-all) | orders.getQueue(): вектор m_unitorders@0x9A0, stride 0x40 |
| `Tree.IsActive` | always true | валидность instance дерева (ent.instance > 0x10000) |
| `Rune.GetRuneType` | always 0 | schema m_nRuneType (C_DOTA_Item_RuneSpawner_Powerup), fallback 0xC10 |

Ранее закрытые (см. KNOWN_ISSUES): IsAttacking, HasState, модификаторы (buffObjects),
GetClassName (index+cache), счёт игрока (DataTeamPlayer), pre-game GetGameTime,
ложная пауза (own seq), guard'ы приказов.

## Открытые блокеры (нужны данные/хуки, которых нет в schema)

### B-1. NPC.GetBarriers(e) → nil
- **Используется:** last_hit.lua (timeline.predict barrier), combat.
- **Почему блокер:** барьеры — это модификаторы (modifier_item_crimson_guard,
  modifier_abaddon_aphotic_shield и т.п.) с суммой поглощения. Клиентская schema не
  содержит определений модификаторов и их барьер-значений.
- **Влияние:** для крипов без барьеров nil→barrier=0 КОРРЕКТНО (денай/ластхит крипов
  не страдает). Страдает предсказание урона по героям с барьерами.
- **Что нужно:** парсинг модификаторов юнита + таблица барьер-модификаторов с суммами.

### B-2. NPC.GetModifierProperty(e, prop) → только 2 свойства
- **Используется:** laneRules.denyable (CREEP_DENY_PERCENT), combat.
- **Сейчас:** MOD_PROP_BASE[337]=50 (CREEP_DENY_PERCENT), [178]=0 (DISABLE_HEALING),
  остальное 0.
- **Почему блокер:** полное вычисление свойства требует определений модификаторов
  (не в schema). Для обычных крипов порог денаев 50% КОРРЕКТЕН.
- **Влияние:** денаи обычных крипов работают с правильным порогом; модифицированные
  пороги (способности) не учитываются.
- **Что нужно:** evaluasi свойств модификаторов юнита.

### B-3. FogOfWar.IsVisible / IsPointVisible → false
- **Используется:** awareness (fogPosition/memory), detection, jungle, runes, support_camps.
- **Почему блокер:** нет Lua-читаемой клиентской FOW-маски на этой сборке; нужен
  native-хук к fog-of-war сетке клиента.
- **Влияние:** conservative «fogged». awareness.memory трактует позиции как видимые
  через NPC-видимость (не FOW), runes не детектит пустые спавны по FOW.
- **Что нужно:** native FOW mask hook (реверс клиентской fog-of-war текстуры/сетки).
- **Примечание:** NPC-видимость (m_bNPCVisibleState bitmask) РЕАЛИЗОВАНА separately
  (Entity.IsDormant/scan), так что видимость юнитов корректна; блокер только про FOW точки.

### B-4. Bottle.GetRuneType → 0
- **Используется:** combat.lua:83 (bottle rune logic).
- **Почему блокер:** руна в бутылке хранится в модификаторе modifier_bottle_rune_*;
  нужен парсинг модификаторов бутылки.
- **Что нужно:** читать модификаторы бутылки, маппить имя→тип руны.

### B-5. PowerTreads.GetStats → {}
- **Используется:** consumables.lua:229 (переключение treads).
- **Почему блокер:** стат-бонус treads в модификаторе modifier_item_power_treads;
  нужен парсинг модификаторов.
- **Что нужно:** читать активный стат treads из модификатора.

### B-6. Panorama.GetPanelByName → nil (вне скоупа)
- **Используется:** draft.lua:253 (draft UI).
- **Статус:** намеренно nil; UI-панели Panorama не нужны для одиночной бот-игры.

## Приоритет снятия
Для денаев/ластхита крипов B-1/B-2 возвращают КОРРЕКТНЫЕ дефолты (барьер 0, порог 50%)
— снятие не изменит поведение на обычных крипах. Реальный остаток денаев — тайминг/
позиционирование/farmSafe (см. KNOWN_ISSUES AI-1), не заглушки.
B-3 (FOW) — наибольший поведенческий gap (awareness/runes), требует native-хука.