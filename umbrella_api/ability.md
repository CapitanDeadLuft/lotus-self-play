> For the complete documentation index, see [llms.txt](https://uczone.gitbook.io/api-v2.0/llms.txt). Markdown versions of documentation pages are available by appending `.md` to page URLs; this page is available as [Markdown](https://uczone.gitbook.io/api-v2.0/game-components/core/ability.md).

# Ability

Table to work with `CAbility`.

<mark style="color:purple;">**`CAbility`**</mark> extends <mark style="color:purple;">**`CEntity`**</mark>

## <sub>GetOwner</sub>

`Ability.GetOwner(ability):` [<mark style="color:purple;">**`CEntity`**</mark>](/api-v2.0/game-components/core/entity.md) | <mark style="color:purple;">**`nil`**</mark>

| Name        | Type                                                                                           | Description |
| ----------- | ---------------------------------------------------------------------------------------------- | ----------- |
| **ability** | [<mark style="color:purple;">**`CAbility`**</mark>](/api-v2.0/game-components/core/ability.md) |             |

Returns the ability owner.

## <sub>IsBasic</sub>

`Ability.IsBasic(ability):` <mark style="color:purple;">**`boolean`**</mark>

| Name        | Type                                                                                           | Description |
| ----------- | ---------------------------------------------------------------------------------------------- | ----------- |
| **ability** | [<mark style="color:purple;">**`CAbility`**</mark>](/api-v2.0/game-components/core/ability.md) |             |

Returns `true` if the ability is basic.

## <sub>IsUltimate</sub>

`Ability.IsUltimate(ability):` <mark style="color:purple;">**`boolean`**</mark>

| Name        | Type                                                                                           | Description |
| ----------- | ---------------------------------------------------------------------------------------------- | ----------- |
| **ability** | [<mark style="color:purple;">**`CAbility`**</mark>](/api-v2.0/game-components/core/ability.md) |             |

Returns `true` if the ability is an ultimate.

## <sub>IsAttributes</sub>

`Ability.IsAttributes(ability):` <mark style="color:purple;">**`boolean`**</mark>

| Name        | Type                                                                                           | Description |
| ----------- | ---------------------------------------------------------------------------------------------- | ----------- |
| **ability** | [<mark style="color:purple;">**`CAbility`**</mark>](/api-v2.0/game-components/core/ability.md) |             |

Returns `true` if the ability is an attribute or a talent.

## <sub>GetType</sub>

`Ability.GetType(ability):` [<mark style="color:purple;">**`Enum.AbilityTypes`**</mark>](https://uczone.gitbook.io/api-v2.0/game-components/core/pages/VwVljl88Qnl7u9hhqRdw#enum.abilitytypes)

| Name        | Type                                                                                           | Description |
| ----------- | ---------------------------------------------------------------------------------------------- | ----------- |
| **ability** | [<mark style="color:purple;">**`CAbility`**</mark>](/api-v2.0/game-components/core/ability.md) |             |

Returns the ability type.

## <sub>GetBehavior</sub>

`Ability.GetBehavior(ability, [from_static_data]):` [<mark style="color:purple;">**`Enum.AbilityBehavior`**</mark>](https://uczone.gitbook.io/api-v2.0/game-components/core/pages/VwVljl88Qnl7u9hhqRdw#enum.abilitybehavior)

| Name                                                                     | Type                                                                                           | Description                                                      |
| ------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------- | ---------------------------------------------------------------- |
| **ability**                                                              | [<mark style="color:purple;">**`CAbility`**</mark>](/api-v2.0/game-components/core/ability.md) |                                                                  |
| **from\_static\_data&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`boolean`**</mark>                                               | if `true` will check from ability static data `(default: false)` |

Returns the ability type.

## <sub>IsPassive</sub>

`Ability.IsPassive(ability, [from_static_data]):` <mark style="color:purple;">**`boolean`**</mark>

| Name                                                                     | Type                                                                                           | Description                                                      |
| ------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------- | ---------------------------------------------------------------- |
| **ability**                                                              | [<mark style="color:purple;">**`CAbility`**</mark>](/api-v2.0/game-components/core/ability.md) |                                                                  |
| **from\_static\_data&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`boolean`**</mark>                                               | if `true` will check from ability static data `(default: false)` |

Returns `true` if the ability is passive.

## <sub>GetTargetTeam</sub>

`Ability.GetTargetTeam(ability, [from_static_data]):` [<mark style="color:purple;">**`Enum.TargetTeam`**</mark>](https://uczone.gitbook.io/api-v2.0/game-components/core/pages/VwVljl88Qnl7u9hhqRdw#enum.targetteam)

| Name                                                                     | Type                                                                                           | Description                                                      |
| ------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------- | ---------------------------------------------------------------- |
| **ability**                                                              | [<mark style="color:purple;">**`CAbility`**</mark>](/api-v2.0/game-components/core/ability.md) |                                                                  |
| **from\_static\_data&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`boolean`**</mark>                                               | if `true` will check from ability static data `(default: false)` |

Returns the target team of this Ability.

## <sub>GetTargetType</sub>

`Ability.GetTargetType(ability, [from_static_data]):` [<mark style="color:purple;">**`Enum.TargetType`**</mark>](https://uczone.gitbook.io/api-v2.0/game-components/core/pages/VwVljl88Qnl7u9hhqRdw#enum.targettype)

| Name                                                                     | Type                                                                                           | Description                                                      |
| ------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------- | ---------------------------------------------------------------- |
| **ability**                                                              | [<mark style="color:purple;">**`CAbility`**</mark>](/api-v2.0/game-components/core/ability.md) |                                                                  |
| **from\_static\_data&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`boolean`**</mark>                                               | if `true` will check from ability static data `(default: false)` |

Returns the target type of this Ability.

## <sub>GetTargetFlags</sub>

`Ability.GetTargetFlags(ability):` [<mark style="color:purple;">**`Enum.TargetFlags`**</mark>](https://uczone.gitbook.io/api-v2.0/game-components/core/pages/VwVljl88Qnl7u9hhqRdw#enum.targetflags)

| Name        | Type                                                                                           | Description |
| ----------- | ---------------------------------------------------------------------------------------------- | ----------- |
| **ability** | [<mark style="color:purple;">**`CAbility`**</mark>](/api-v2.0/game-components/core/ability.md) |             |

Returns the target flags of this Ability.

## <sub>GetDamageType</sub>

`Ability.GetDamageType(ability):` [<mark style="color:purple;">**`Enum.DamageTypes`**</mark>](https://uczone.gitbook.io/api-v2.0/game-components/core/pages/VwVljl88Qnl7u9hhqRdw#enum.damagetypes)

| Name        | Type                                                                                           | Description |
| ----------- | ---------------------------------------------------------------------------------------------- | ----------- |
| **ability** | [<mark style="color:purple;">**`CAbility`**</mark>](/api-v2.0/game-components/core/ability.md) |             |

Returns the damage type of this Ability.

## <sub>GetImmunityType</sub>

`Ability.GetImmunityType(ability, [from_static_data]):` [<mark style="color:purple;">**`Enum.ImmunityTypes`**</mark>](https://uczone.gitbook.io/api-v2.0/game-components/core/pages/VwVljl88Qnl7u9hhqRdw#enum.immunitytypes)

| Name                                                                     | Type                                                                                           | Description                                                      |
| ------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------- | ---------------------------------------------------------------- |
| **ability**                                                              | [<mark style="color:purple;">**`CAbility`**</mark>](/api-v2.0/game-components/core/ability.md) |                                                                  |
| **from\_static\_data&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`boolean`**</mark>                                               | if `true` will check from ability static data `(default: false)` |

Returns the immunity type of this Ability.

## <sub>GetDispellableType</sub>

`Ability.GetDispellableType(ability, [from_static_data]):` [<mark style="color:purple;">**`Enum.DispellableTypes`**</mark>](https://uczone.gitbook.io/api-v2.0/game-components/core/pages/VwVljl88Qnl7u9hhqRdw#enum.dispellabletypes)

| Name                                                                     | Type                                                                                           | Description                                                      |
| ------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------- | ---------------------------------------------------------------- |
| **ability**                                                              | [<mark style="color:purple;">**`CAbility`**</mark>](/api-v2.0/game-components/core/ability.md) |                                                                  |
| **from\_static\_data&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`boolean`**</mark>                                               | if `true` will check from ability static data `(default: false)` |

Returns the dispel type of this Ability.

## <sub>GetLevelSpecialValueFor</sub>

`Ability.GetLevelSpecialValueFor(ability, name, [lvl]):` <mark style="color:purple;">**`number`**</mark>

| Name                                                      | Type                                                                                           | Description                                                                                 |
| --------------------------------------------------------- | ---------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| **ability**                                               | [<mark style="color:purple;">**`CAbility`**</mark>](/api-v2.0/game-components/core/ability.md) |                                                                                             |
| **name**                                                  | <mark style="color:purple;">**`string`**</mark>                                                | Special value name. Can be found in the ability KV file. (`assets/data/npc_abilities.json`) |
| **lvl&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`integer`**</mark>                                               | Ability level, if -1 will automatically get lvl. `(default: -1)`                            |

WRONG API FIX ME IT MUST BE GetSpecialValueFor.

## <sub>IsReady</sub>

`Ability.IsReady(ability):` <mark style="color:purple;">**`boolean`**</mark>

| Name        | Type                                                                                           | Description |
| ----------- | ---------------------------------------------------------------------------------------------- | ----------- |
| **ability** | [<mark style="color:purple;">**`CAbility`**</mark>](/api-v2.0/game-components/core/ability.md) |             |

Returns `true` if the ability is ready to use.

## <sub>SecondsSinceLastUse</sub>

`Ability.SecondsSinceLastUse(ability):` <mark style="color:purple;">**`number`**</mark>

| Name        | Type                                                                                           | Description |
| ----------- | ---------------------------------------------------------------------------------------------- | ----------- |
| **ability** | [<mark style="color:purple;">**`CAbility`**</mark>](/api-v2.0/game-components/core/ability.md) |             |

Returns the number of seconds passed from the last usage of the ability. Will return -1 if\
the ability is not on the cooldown.

## <sub>GetDamage</sub>

`Ability.GetDamage(ability):` <mark style="color:purple;">**`number`**</mark>

| Name        | Type                                                                                           | Description |
| ----------- | ---------------------------------------------------------------------------------------------- | ----------- |
| **ability** | [<mark style="color:purple;">**`CAbility`**</mark>](/api-v2.0/game-components/core/ability.md) |             |

Returns the ability damage from assets/data/npc\_abilities.json field. Will return 0.0 if the\
ability doesn't contain this field.

## <sub>GetHealthCost</sub>

`Ability.GetHealthCost(ability):` <mark style="color:purple;">**`number`**</mark>

| Name        | Type                                                                                           | Description |
| ----------- | ---------------------------------------------------------------------------------------------- | ----------- |
| **ability** | [<mark style="color:purple;">**`CAbility`**</mark>](/api-v2.0/game-components/core/ability.md) |             |

Returns the ability's health cost.

## <sub>GetLevel</sub>

`Ability.GetLevel(ability):` <mark style="color:purple;">**`integer`**</mark>

| Name        | Type                                                                                           | Description |
| ----------- | ---------------------------------------------------------------------------------------------- | ----------- |
| **ability** | [<mark style="color:purple;">**`CAbility`**</mark>](/api-v2.0/game-components/core/ability.md) |             |

Returns the current ability level.

## <sub>GetCastPoint</sub>

`Ability.GetCastPoint(ability, [include_modifiers]):` <mark style="color:purple;">**`number`**</mark>

| Name                                                                     | Type                                                                                           | Description       |
| ------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------- | ----------------- |
| **ability**                                                              | [<mark style="color:purple;">**`CAbility`**</mark>](/api-v2.0/game-components/core/ability.md) |                   |
| **include\_modifiers&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`boolean`**</mark>                                               | `(default: true)` |

Gets the cast delay of this Ability.

## <sub>GetCastPointModifier</sub>

`Ability.GetCastPointModifier(ability):` <mark style="color:purple;">**`number`**</mark>

| Name        | Type                                                                                           | Description |
| ----------- | ---------------------------------------------------------------------------------------------- | ----------- |
| **ability** | [<mark style="color:purple;">**`CAbility`**</mark>](/api-v2.0/game-components/core/ability.md) |             |

Gets the cast delay modifier of this Ability.

## <sub>IsCastable</sub>

`Ability.IsCastable(ability, [mana]):` <mark style="color:purple;">**`boolean`**</mark>

| Name                                                       | Type                                                                                           | Description      |
| ---------------------------------------------------------- | ---------------------------------------------------------------------------------------------- | ---------------- |
| **ability**                                                | [<mark style="color:purple;">**`CAbility`**</mark>](/api-v2.0/game-components/core/ability.md) |                  |
| **mana&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`number`**</mark>                                                | `(default: 0.0)` |

Returns `true` if the ability is currently castable. Checks for mana cost, cooldown, level,\
and slot for items.

## <sub>IsChannelling</sub>

`Ability.IsChannelling(ability):` <mark style="color:purple;">**`boolean`**</mark>

| Name        | Type                                                                                           | Description |
| ----------- | ---------------------------------------------------------------------------------------------- | ----------- |
| **ability** | [<mark style="color:purple;">**`CAbility`**</mark>](/api-v2.0/game-components/core/ability.md) |             |

Returns `true` if the ability is in channeling state. Example: teleport, rearm, powershot\
etc.

## <sub>GetName</sub>

`Ability.GetName(ability):` <mark style="color:purple;">**`string`**</mark>

| Name        | Type                                                                                           | Description |
| ----------- | ---------------------------------------------------------------------------------------------- | ----------- |
| **ability** | [<mark style="color:purple;">**`CAbility`**</mark>](/api-v2.0/game-components/core/ability.md) |             |

Returns the ability name or empty string.

## <sub>GetBaseName</sub>

`Ability.GetBaseName(ability):` <mark style="color:purple;">**`string`**</mark>

| Name        | Type                                                                                           | Description |
| ----------- | ---------------------------------------------------------------------------------------------- | ----------- |
| **ability** | [<mark style="color:purple;">**`CAbility`**</mark>](/api-v2.0/game-components/core/ability.md) |             |

Returns the ability base name or empty string.

## <sub>IsInnate</sub>

`Ability.IsInnate(ability):` <mark style="color:purple;">**`boolean`**</mark>

| Name        | Type                                                                                           | Description |
| ----------- | ---------------------------------------------------------------------------------------------- | ----------- |
| **ability** | [<mark style="color:purple;">**`CAbility`**</mark>](/api-v2.0/game-components/core/ability.md) |             |

Returns `true` if the ability is innate.

## <sub>IsInnatePassive</sub>

`Ability.IsInnatePassive(ability):` <mark style="color:purple;">**`boolean`**</mark>

| Name        | Type                                                                                           | Description |
| ----------- | ---------------------------------------------------------------------------------------------- | ----------- |
| **ability** | [<mark style="color:purple;">**`CAbility`**</mark>](/api-v2.0/game-components/core/ability.md) |             |

Returns `true` if the ability is passive innate.

## <sub>GetMaxLevel</sub>

`Ability.GetMaxLevel(ability):` <mark style="color:purple;">**`integer`**</mark>

| Name        | Type                                                                                           | Description |
| ----------- | ---------------------------------------------------------------------------------------------- | ----------- |
| **ability** | [<mark style="color:purple;">**`CAbility`**</mark>](/api-v2.0/game-components/core/ability.md) |             |

Returns ability's max level.

## <sub>IsGrantedByFacet</sub>

`Ability.IsGrantedByFacet(ability):` <mark style="color:purple;">**`boolean`**</mark>

| Name        | Type                                                                                           | Description |
| ----------- | ---------------------------------------------------------------------------------------------- | ----------- |
| **ability** | [<mark style="color:purple;">**`CAbility`**</mark>](/api-v2.0/game-components/core/ability.md) |             |

Returns `true` when abiliti is granted by facet.

## <sub>CanBeExecuted</sub>

`Ability.CanBeExecuted(ability):` [<mark style="color:purple;">**`Enum.AbilityCastResult`**</mark>](https://uczone.gitbook.io/api-v2.0/game-components/core/pages/VwVljl88Qnl7u9hhqRdw#enum.abilitycastresult)

| Name        | Type                                                                                           | Description |
| ----------- | ---------------------------------------------------------------------------------------------- | ----------- |
| **ability** | [<mark style="color:purple;">**`CAbility`**</mark>](/api-v2.0/game-components/core/ability.md) |             |

Returns `-1` if ability can be executed.

## <sub>IsOwnersManaEnough</sub>

`Ability.IsOwnersManaEnough(ability):` <mark style="color:purple;">**`boolean`**</mark>

| Name        | Type                                                                                           | Description |
| ----------- | ---------------------------------------------------------------------------------------------- | ----------- |
| **ability** | [<mark style="color:purple;">**`CAbility`**</mark>](/api-v2.0/game-components/core/ability.md) |             |

Returns `true` if enough mana for cast.

## <sub>CastNoTarget</sub>

`Ability.CastNoTarget(ability, [queue], [push], [execute_fast], [identifier]):` <mark style="color:purple;">**`nil`**</mark>

| Name                                                                | Type                                                                                           | Description                                                                             |
| ------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| **ability**                                                         | [<mark style="color:purple;">**`CAbility`**</mark>](/api-v2.0/game-components/core/ability.md) |                                                                                         |
| **queue&#x20;**<mark style="color:orange;">**`[?]`**</mark>         | <mark style="color:purple;">**`boolean`**</mark>                                               | Will add order to the cast queue. `(default: false)`                                    |
| **push&#x20;**<mark style="color:orange;">**`[?]`**</mark>          | <mark style="color:purple;">**`boolean`**</mark>                                               | Will push order to the OnPrepareUnitOrders callback. `(default: false)`                 |
| **execute\_fast&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`boolean`**</mark>                                               | Will push order to start of the order's list. `(default: false)`                        |
| **identifier&#x20;**<mark style="color:orange;">**`[?]`**</mark>    | <mark style="color:purple;">**`string`**</mark>                                                | The identifier which will be passed to `OnPrepareUnitOrders` callback. `(default: nil)` |

Casts the ability that doesn't require a target or position.

## <sub>CastPosition</sub>

`Ability.CastPosition(ability, pos, [queue], [push], [execute_fast], [identifier], [force_minimap]):` <mark style="color:purple;">**`nil`**</mark>

| Name                                                                 | Type                                                                                                           | Description                                                                             |
| -------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| **ability**                                                          | [<mark style="color:purple;">**`CAbility`**</mark>](/api-v2.0/game-components/core/ability.md)                 |                                                                                         |
| **pos**                                                              | [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md) | Order position.                                                                         |
| **queue&#x20;**<mark style="color:orange;">**`[?]`**</mark>          | <mark style="color:purple;">**`boolean`**</mark>                                                               | Will add order to the cast queue. `(default: false)`                                    |
| **push&#x20;**<mark style="color:orange;">**`[?]`**</mark>           | <mark style="color:purple;">**`boolean`**</mark>                                                               | Will push order to the OnPrepareUnitOrders callback. `(default: false)`                 |
| **execute\_fast&#x20;**<mark style="color:orange;">**`[?]`**</mark>  | <mark style="color:purple;">**`boolean`**</mark>                                                               | Will push order to start of the order's list. `(default: false)`                        |
| **identifier&#x20;**<mark style="color:orange;">**`[?]`**</mark>     | <mark style="color:purple;">**`string`**</mark>                                                                | The identifier which will be passed to `OnPrepareUnitOrders` callback. `(default: nil)` |
| **force\_minimap&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`boolean`**</mark>                                                               | If true, the order will be forced by the minimap if possible. `(default: true)`         |

Casts the ability at a specified position.

## <sub>CastTarget</sub>

`Ability.CastTarget(ability, target, [queue], [push], [execute_fast], [identifier]):` <mark style="color:purple;">**`nil`**</mark>

| Name                                                                | Type                                                                                           | Description                                                                             |
| ------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| **ability**                                                         | [<mark style="color:purple;">**`CAbility`**</mark>](/api-v2.0/game-components/core/ability.md) |                                                                                         |
| **target**                                                          | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md)         | Order target.                                                                           |
| **queue&#x20;**<mark style="color:orange;">**`[?]`**</mark>         | <mark style="color:purple;">**`boolean`**</mark>                                               | Will add order to the cast queue. `(default: false)`                                    |
| **push&#x20;**<mark style="color:orange;">**`[?]`**</mark>          | <mark style="color:purple;">**`boolean`**</mark>                                               | Will push order to the OnPrepareUnitOrders callback. `(default: false)`                 |
| **execute\_fast&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`boolean`**</mark>                                               | Will push order to start of the order's list. `(default: false)`                        |
| **identifier&#x20;**<mark style="color:orange;">**`[?]`**</mark>    | <mark style="color:purple;">**`string`**</mark>                                                | The identifier which will be passed to `OnPrepareUnitOrders` callback. `(default: nil)` |

Casts the ability on a specified target.

## <sub>Toggle</sub>

`Ability.Toggle(ability, [queue], [push], [execute_fast], [identifier]):` <mark style="color:purple;">**`nil`**</mark>

| Name                                                                | Type                                                                                           | Description                                                                             |
| ------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| **ability**                                                         | [<mark style="color:purple;">**`CAbility`**</mark>](/api-v2.0/game-components/core/ability.md) |                                                                                         |
| **queue&#x20;**<mark style="color:orange;">**`[?]`**</mark>         | <mark style="color:purple;">**`boolean`**</mark>                                               | Will add order to the cast queue. `(default: false)`                                    |
| **push&#x20;**<mark style="color:orange;">**`[?]`**</mark>          | <mark style="color:purple;">**`boolean`**</mark>                                               | Will push order to the OnPrepareUnitOrders callback. `(default: false)`                 |
| **execute\_fast&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`boolean`**</mark>                                               | Will push order to start of the order's list. `(default: false)`                        |
| **identifier&#x20;**<mark style="color:orange;">**`[?]`**</mark>    | <mark style="color:purple;">**`string`**</mark>                                                | The identifier which will be passed to `OnPrepareUnitOrders` callback. `(default: nil)` |

Toggles the ability. Example: Armlet.

## <sub>ToggleMod</sub>

`Ability.ToggleMod(ability, [queue], [push], [execute_fast], [identifier]):` <mark style="color:purple;">**`nil`**</mark>

| Name                                                                | Type                                                                                           | Description                                                                             |
| ------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| **ability**                                                         | [<mark style="color:purple;">**`CAbility`**</mark>](/api-v2.0/game-components/core/ability.md) |                                                                                         |
| **queue&#x20;**<mark style="color:orange;">**`[?]`**</mark>         | <mark style="color:purple;">**`boolean`**</mark>                                               | Will add order to the cast queue. `(default: false)`                                    |
| **push&#x20;**<mark style="color:orange;">**`[?]`**</mark>          | <mark style="color:purple;">**`boolean`**</mark>                                               | Will push order to the OnPrepareUnitOrders callback. `(default: false)`                 |
| **execute\_fast&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`boolean`**</mark>                                               | Will push order to start of the order's list. `(default: false)`                        |
| **identifier&#x20;**<mark style="color:orange;">**`[?]`**</mark>    | <mark style="color:purple;">**`string`**</mark>                                                | The identifier which will be passed to `OnPrepareUnitOrders` callback. `(default: nil)` |

Toggles the ability modifier. Example: Frost Arrows, Medusa's Shield.

## <sub>GetDefaultName</sub>

`Ability.GetDefaultName(ability_name):` <mark style="color:purple;">**`string`**</mark> | <mark style="color:purple;">**`nil`**</mark>

| Name              | Type                                            | Description |
| ----------------- | ----------------------------------------------- | ----------- |
| **ability\_name** | <mark style="color:purple;">**`string`**</mark> |             |

Returns the default ability icon name from items\_game.txt

## <sub>CanBeUpgraded</sub>

`Ability.CanBeUpgraded(ability):` <mark style="color:purple;">**`boolean`**</mark>

| Name        | Type                                                                                           | Description |
| ----------- | ---------------------------------------------------------------------------------------------- | ----------- |
| **ability** | [<mark style="color:purple;">**`CAbility`**</mark>](/api-v2.0/game-components/core/ability.md) |             |

Returns if the ability is upgradable with a specific reason.

## <sub>GetAbilityID</sub>

`Ability.GetAbilityID(ability):` <mark style="color:purple;">**`integer`**</mark>

| Name        | Type                                                                                           | Description |
| ----------- | ---------------------------------------------------------------------------------------------- | ----------- |
| **ability** | [<mark style="color:purple;">**`CAbility`**</mark>](/api-v2.0/game-components/core/ability.md) |             |

Returns ability id

## <sub>GetIndex</sub>

`Ability.GetIndex(ability):` <mark style="color:purple;">**`integer`**</mark>

| Name        | Type                                                                                           | Description |
| ----------- | ---------------------------------------------------------------------------------------------- | ----------- |
| **ability** | [<mark style="color:purple;">**`CAbility`**</mark>](/api-v2.0/game-components/core/ability.md) |             |

Returns the index of the ability in the ability owner's list. The index can be used in\
NPC.GetAbilityByIndex later.

## <sub>GetCastRange</sub>

`Ability.GetCastRange(ability):` <mark style="color:purple;">**`number`**</mark>

| Name        | Type                                                                                           | Description |
| ----------- | ---------------------------------------------------------------------------------------------- | ----------- |
| **ability** | [<mark style="color:purple;">**`CAbility`**</mark>](/api-v2.0/game-components/core/ability.md) |             |

Returns the cast range of the ability.

## <sub>IsHidden</sub>

`Ability.IsHidden(ability):` <mark style="color:purple;">**`boolean`**</mark>

| Name        | Type                                                                                           | Description |
| ----------- | ---------------------------------------------------------------------------------------------- | ----------- |
| **ability** | [<mark style="color:purple;">**`CAbility`**</mark>](/api-v2.0/game-components/core/ability.md) |             |

Returns `true` if ability is hidden. Example: Zeus's Nimbus before purchasing agh.

## <sub>IsActivated</sub>

`Ability.IsActivated(ability):` <mark style="color:purple;">**`boolean`**</mark>

| Name        | Type                                                                                           | Description |
| ----------- | ---------------------------------------------------------------------------------------------- | ----------- |
| **ability** | [<mark style="color:purple;">**`CAbility`**</mark>](/api-v2.0/game-components/core/ability.md) |             |

Returns `true` if the ability is in an activated state.

## <sub>GetDirtyButtons</sub>

`Ability.GetDirtyButtons(ability):` <mark style="color:purple;">**`integer`**</mark>

| Name        | Type                                                                                           | Description |
| ----------- | ---------------------------------------------------------------------------------------------- | ----------- |
| **ability** | [<mark style="color:purple;">**`CAbility`**</mark>](/api-v2.0/game-components/core/ability.md) |             |

Returns we don't know what :).

## <sub>GetToggleState</sub>

`Ability.GetToggleState(ability):` <mark style="color:purple;">**`boolean`**</mark>

| Name        | Type                                                                                           | Description |
| ----------- | ---------------------------------------------------------------------------------------------- | ----------- |
| **ability** | [<mark style="color:purple;">**`CAbility`**</mark>](/api-v2.0/game-components/core/ability.md) |             |

Returns if the ability is toggled. Example: Medusa's Shield.

## <sub>IsInAbilityPhase</sub>

`Ability.IsInAbilityPhase(ability):` <mark style="color:purple;">**`boolean`**</mark>

| Name        | Type                                                                                           | Description |
| ----------- | ---------------------------------------------------------------------------------------------- | ----------- |
| **ability** | [<mark style="color:purple;">**`CAbility`**</mark>](/api-v2.0/game-components/core/ability.md) |             |

Returns `true` if the ability is in the cast state. Examples: Nature's Prophet's Teleport,\
Meepo's Poof.

## <sub>GetCooldown</sub>

`Ability.GetCooldown(ability):` <mark style="color:purple;">**`number`**</mark>

| Name        | Type                                                                                           | Description |
| ----------- | ---------------------------------------------------------------------------------------------- | ----------- |
| **ability** | [<mark style="color:purple;">**`CAbility`**</mark>](/api-v2.0/game-components/core/ability.md) |             |

Returns the amount of time before the ability can be cast.

## <sub>GetCooldownLength</sub>

`Ability.GetCooldownLength(ability):` <mark style="color:purple;">**`number`**</mark>

| Name        | Type                                                                                           | Description |
| ----------- | ---------------------------------------------------------------------------------------------- | ----------- |
| **ability** | [<mark style="color:purple;">**`CAbility`**</mark>](/api-v2.0/game-components/core/ability.md) |             |

Returns the amount of time the ability couldn't be cast after being used.

## <sub>GetManaCost</sub>

`Ability.GetManaCost(ability):` <mark style="color:purple;">**`number`**</mark>

| Name        | Type                                                                                           | Description |
| ----------- | ---------------------------------------------------------------------------------------------- | ----------- |
| **ability** | [<mark style="color:purple;">**`CAbility`**</mark>](/api-v2.0/game-components/core/ability.md) |             |

Returns the ability mana cost.

## <sub>GetAutoCastState</sub>

`Ability.GetAutoCastState(ability):` <mark style="color:purple;">**`boolean`**</mark>

| Name        | Type                                                                                           | Description |
| ----------- | ---------------------------------------------------------------------------------------------- | ----------- |
| **ability** | [<mark style="color:purple;">**`CAbility`**</mark>](/api-v2.0/game-components/core/ability.md) |             |

Returns the autocast state of the ability.

## <sub>GetAltCastState</sub>

`Ability.GetAltCastState(ability):` <mark style="color:purple;">**`boolean`**</mark>

| Name        | Type                                                                                           | Description |
| ----------- | ---------------------------------------------------------------------------------------------- | ----------- |
| **ability** | [<mark style="color:purple;">**`CAbility`**</mark>](/api-v2.0/game-components/core/ability.md) |             |

Returns the alt cast state of the ability. Example: Doom's Devour.

## <sub>GetChannelStartTime</sub>

`Ability.GetChannelStartTime(ability):` <mark style="color:purple;">**`number`**</mark>

| Name        | Type                                                                                           | Description |
| ----------- | ---------------------------------------------------------------------------------------------- | ----------- |
| **ability** | [<mark style="color:purple;">**`CAbility`**</mark>](/api-v2.0/game-components/core/ability.md) |             |

Returns the gametime the channeling of the ability will start. Requires the ability to be in\
the cast state when called.

## <sub>GetCastStartTime</sub>

`Ability.GetCastStartTime(ability):` <mark style="color:purple;">**`number`**</mark>

| Name        | Type                                                                                           | Description |
| ----------- | ---------------------------------------------------------------------------------------------- | ----------- |
| **ability** | [<mark style="color:purple;">**`CAbility`**</mark>](/api-v2.0/game-components/core/ability.md) |             |

Returns the gametime the ability will be casted. Requires the ability to be in the cast state\
when called.

## <sub>IsInIndefinateCooldown</sub>

`Ability.IsInIndefinateCooldown(ability):` <mark style="color:purple;">**`boolean`**</mark>

| Name        | Type                                                                                           | Description |
| ----------- | ---------------------------------------------------------------------------------------------- | ----------- |
| **ability** | [<mark style="color:purple;">**`CAbility`**</mark>](/api-v2.0/game-components/core/ability.md) |             |

Returns `true` if the cooldown of the ability is indefinite.

## <sub>IsFrozenCooldown</sub>

`Ability.IsFrozenCooldown(ability):` <mark style="color:purple;">**`boolean`**</mark>

| Name        | Type                                                                                           | Description |
| ----------- | ---------------------------------------------------------------------------------------------- | ----------- |
| **ability** | [<mark style="color:purple;">**`CAbility`**</mark>](/api-v2.0/game-components/core/ability.md) |             |

Returns `true` if the cooldown of the ability is frozen.

## <sub>GetOverrideCastPoint</sub>

`Ability.GetOverrideCastPoint(ability):` <mark style="color:purple;">**`number`**</mark>

| Name        | Type                                                                                           | Description |
| ----------- | ---------------------------------------------------------------------------------------------- | ----------- |
| **ability** | [<mark style="color:purple;">**`CAbility`**</mark>](/api-v2.0/game-components/core/ability.md) |             |

Returns the overridden cast point. Example: Arcane Blink.

## <sub>IsStolen</sub>

`Ability.IsStolen(ability):` <mark style="color:purple;">**`boolean`**</mark>

| Name        | Type                                                                                           | Description |
| ----------- | ---------------------------------------------------------------------------------------------- | ----------- |
| **ability** | [<mark style="color:purple;">**`CAbility`**</mark>](/api-v2.0/game-components/core/ability.md) |             |

Returns `true` if the ability is stolen.

## <sub>GetCurrentCharges</sub>

`Ability.GetCurrentCharges(ability):` <mark style="color:purple;">**`integer`**</mark>

| Name        | Type                                                                                           | Description |
| ----------- | ---------------------------------------------------------------------------------------------- | ----------- |
| **ability** | [<mark style="color:purple;">**`CAbility`**</mark>](/api-v2.0/game-components/core/ability.md) |             |

Returns the number of charges available.

## <sub>ChargeRestoreTimeRemaining</sub>

`Ability.ChargeRestoreTimeRemaining(ability):` <mark style="color:purple;">**`integer`**</mark>

| Name        | Type                                                                                           | Description |
| ----------- | ---------------------------------------------------------------------------------------------- | ----------- |
| **ability** | [<mark style="color:purple;">**`CAbility`**</mark>](/api-v2.0/game-components/core/ability.md) |             |

Returns the remaining time for the next charge to restore.

## <sub>GetKeybind</sub>

`Ability.GetKeybind(ability):` <mark style="color:purple;">**`string`**</mark>

| Name        | Type                                                                                           | Description |
| ----------- | ---------------------------------------------------------------------------------------------- | ----------- |
| **ability** | [<mark style="color:purple;">**`CAbility`**</mark>](/api-v2.0/game-components/core/ability.md) |             |

Returns the keybind of the ability.
