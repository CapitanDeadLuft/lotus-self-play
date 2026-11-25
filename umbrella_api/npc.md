> For the complete documentation index, see [llms.txt](https://uczone.gitbook.io/api-v2.0/llms.txt). Markdown versions of documentation pages are available by appending `.md` to page URLs; this page is available as [Markdown](https://uczone.gitbook.io/api-v2.0/game-components/core/npc.md).

# NPC

Table to work with `CNPC`. <mark style="color:purple;">**`CNPC`**</mark> extends <mark style="color:purple;">**`CEntity`**</mark>

## <sub>GetOwnerNPC</sub>

`NPC.GetOwnerNPC(npc):` [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | <mark style="color:purple;">**`nil`**</mark>

| Name    | Type                                                                                   | Description           |
| ------- | -------------------------------------------------------------------------------------- | --------------------- |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | npc to get owner from |

Returns owner of the `CNPC`. Works for spirit bear.

## <sub>GetItem</sub>

`NPC.GetItem(npc, name, [isReal]):` [<mark style="color:purple;">**`CItem`**</mark>](/api-v2.0/game-components/core/item.md) | <mark style="color:purple;">**`nil`**</mark>

| Name                                                         | Type                                                                                   | Description                                                                                                                    |
| ------------------------------------------------------------ | -------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| **npc**                                                      | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | npc to get item from                                                                                                           |
| **name**                                                     | <mark style="color:purple;">**`string`**</mark>                                        | name of the item                                                                                                               |
| **isReal&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`boolean`**</mark>                                       | if true, returns only 1-6 slots and neutral item, otherwise returns all items (including backpack and stash) `(default: true)` |

Returns `CItem` by name.

## <sub>HasItem</sub>

`NPC.HasItem(npc, name, [isReal]):` <mark style="color:purple;">**`boolean`**</mark>

| Name                                                         | Type                                                                                   | Description                                                                                                                    |
| ------------------------------------------------------------ | -------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| **npc**                                                      | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | npc to check                                                                                                                   |
| **name**                                                     | <mark style="color:purple;">**`string`**</mark>                                        | name of the item                                                                                                               |
| **isReal&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`boolean`**</mark>                                       | if true, returns only 1-6 slots and neutral item, otherwise returns all items (including backpack and stash) `(default: true)` |

Returns `true` if the `CNPC` has item with specified name.

## <sub>HasModifier</sub>

`NPC.HasModifier(npc, name):` <mark style="color:purple;">**`boolean`**</mark>

| Name     | Type                                                                                   | Description          |
| -------- | -------------------------------------------------------------------------------------- | -------------------- |
| **npc**  | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | npc to check         |
| **name** | <mark style="color:purple;">**`string`**</mark>                                        | name of the modifier |

Returns `true` if the `CNPC` has modifier with specified name.

## <sub>GetModifier</sub>

`NPC.GetModifier(npc, name):` [<mark style="color:purple;">**`CModifier`**</mark>](/api-v2.0/game-components/core/modifier.md) | <mark style="color:purple;">**`nil`**</mark>

| Name     | Type                                                                                   | Description              |
| -------- | -------------------------------------------------------------------------------------- | ------------------------ |
| **npc**  | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | npc to get modifier from |
| **name** | <mark style="color:purple;">**`string`**</mark>                                        | name of the modifier     |

Returns `CModifier` by name.

## <sub>GetModifiers</sub>

\`poperty\_filter\` doesn\`t filter all modifiers every call, it uses already prefiltered list. {% endhint %} \`NPC.GetModifiers(npc, \[poperty\_filter]):\` \[<mark style="color:purple;">\*\*\`CModifier\[]\`\*\*</mark>]\(Modifier.md)

| Name                                                                  | Type                                                                                                                                                                       | Description                                                                                         |
| --------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| **npc**                                                               | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md)                                                                                     | npc to get modifiers from                                                                           |
| **poperty\_filter&#x20;**<mark style="color:orange;">**`[?]`**</mark> | [<mark style="color:purple;">**`Enum.ModifierFunction`**</mark>](https://uczone.gitbook.io/api-v2.0/game-components/core/pages/VwVljl88Qnl7u9hhqRdw#enum.modifierfunction) | Filter modifiers by specified property `(default: Enum.ModifierFunction.MODIFIER_FUNCTION_INVALID)` |

Returns an array of all NPC's `CModifier`s.

## <sub>HasAnyModifier</sub>

`NPC.HasAnyModifier(npc, names):` <mark style="color:purple;">**`boolean`**</mark>

| Name      | Type                                                                                                                 | Description |
| --------- | -------------------------------------------------------------------------------------------------------------------- | ----------- |
| **npc**   | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md)                               |             |
| **names** | <mark style="color:purple;">**`string[]`**</mark> \| <mark style="color:purple;">**`table<string, boolean>`**</mark> |             |

Returns `true` if the NPC has any modifier from the given set.\
Accepts either an array `{"mod_a", "mod_b"}` or a hash set `{mod_a = true, mod_b = true}`.\
The hash set form is faster: O(M) hash lookups vs O(M\*N) strcmp, where M = modifier count, N = names count.

## <sub>GetModifierByIndex</sub>

`NPC.GetModifierByIndex(npc, index):` [<mark style="color:purple;">**`CModifier`**</mark>](/api-v2.0/game-components/core/modifier.md) | <mark style="color:purple;">**`nil`**</mark>

| Name      | Type                                                                                   | Description   |
| --------- | -------------------------------------------------------------------------------------- | ------------- |
| **npc**   | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) |               |
| **index** | <mark style="color:purple;">**`integer`**</mark>                                       | 1-based index |

Returns the modifier at the given 1-based index, or nil if out of range.\
Use with `NPC.GetModifiers` count or iterate until nil.

## <sub>HasInventorySlotFree</sub>

`NPC.HasInventorySlotFree(npc, [isReal]):` <mark style="color:purple;">**`boolean`**</mark>

| Name                                                         | Type                                                                                   | Description                                                                                                                    |
| ------------------------------------------------------------ | -------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| **npc**                                                      | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | npc to check                                                                                                                   |
| **isReal&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`boolean`**</mark>                                       | if true, returns only 1-6 slots and neutral item, otherwise returns all items (including backpack and stash) `(default: true)` |

Returns `true` if the `CNPC` has free inventory slot.

## <sub>HasState</sub>

`NPC.HasState(npc, state):` <mark style="color:purple;">**`boolean`**</mark>

| Name      | Type                                                                                                                                                                 | Description    |
| --------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------- |
| **npc**   | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md)                                                                               | npc to check   |
| **state** | [<mark style="color:purple;">**`Enum.ModifierState`**</mark>](https://uczone.gitbook.io/api-v2.0/game-components/core/pages/VwVljl88Qnl7u9hhqRdw#enum.modifierstate) | state to check |

Returns `true` if the `CNPC` has state. The best way to check if the `CNPC` is stunned, silenced, hexed, has BKB immune etc.

## <sub>GetStatesDuration</sub>

`NPC.GetStatesDuration(npc, states, [only_active_states]):` <mark style="color:purple;">**`table<Enum.ModifierState, number>`**</mark>

| Name                                                                       | Type                                                                                   | Description                                                                                                                         |
| -------------------------------------------------------------------------- | -------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| **npc**                                                                    | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | npc to check                                                                                                                        |
| **states**                                                                 | <mark style="color:purple;">**`table<Enum.ModifierState, boolean>`**</mark>            | states to check; the keys are read, the values are ignored                                                                          |
| **only\_active\_states&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`boolean`**</mark>                                       | if `true` then check only states that active on unit, otherwise check all states. e.g. rooted while debuff immune `(default: true)` |

Returns table of remaining modifier states duration. See the example

#### Example

```lua
local states_to_check = {
		[Enum.ModifierState.MODIFIER_STATE_STUNNED] = true,
		[Enum.ModifierState.MODIFIER_STATE_HEXED] = true,
}
local states = NPC.GetStatesDuration(unit, states_to_check)
local hex_duration = states[Enum.ModifierState.MODIFIER_STATE_HEXED]
local stun_duration = states[Enum.ModifierState.MODIFIER_STATE_STUNNED]
```

## <sub>IsWaitingToSpawn</sub>

`NPC.IsWaitingToSpawn(npc):` <mark style="color:purple;">**`boolean`**</mark>

| Name    | Type                                                                                   | Description  |
| ------- | -------------------------------------------------------------------------------------- | ------------ |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | npc to check |

Returns `true` if waiting to spawn. For example, creeps are waiting to spawn under the ground near the barracks.

## <sub>IsIllusion</sub>

`NPC.IsIllusion(npc):` <mark style="color:purple;">**`boolean`**</mark>

| Name    | Type                                                                                   | Description  |
| ------- | -------------------------------------------------------------------------------------- | ------------ |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | npc to check |

Returns `true` if the `CNPC` is illusion.

## <sub>IsVisible</sub>

`NPC.IsVisible(npc):` <mark style="color:purple;">**`boolean`**</mark>

| Name    | Type                                                                                   | Description  |
| ------- | -------------------------------------------------------------------------------------- | ------------ |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | npc to check |

Returns `true` if the `CNPC` is visible to local player.

## <sub>IsVisibleToEnemies</sub>

`NPC.IsVisibleToEnemies(npc):` <mark style="color:purple;">**`boolean`**</mark>

| Name    | Type                                                                                   | Description  |
| ------- | -------------------------------------------------------------------------------------- | ------------ |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | npc to check |

Returns `true` if the `CNPC` is visible enemies.

## <sub>IsCourier</sub>

`NPC.IsCourier(npc):` <mark style="color:purple;">**`boolean`**</mark>

| Name    | Type                                                                                   | Description  |
| ------- | -------------------------------------------------------------------------------------- | ------------ |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | npc to check |

Returns `true` if the `CNPC` is a courier.

## <sub>IsRanged</sub>

`NPC.IsRanged(npc):` <mark style="color:purple;">**`boolean`**</mark>

| Name    | Type                                                                                   | Description  |
| ------- | -------------------------------------------------------------------------------------- | ------------ |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | npc to check |

Returns `true` if the `CNPC` is a ranged unit.

## <sub>IsCreep</sub>

`NPC.IsCreep(npc):` <mark style="color:purple;">**`boolean`**</mark>

| Name    | Type                                                                                   | Description  |
| ------- | -------------------------------------------------------------------------------------- | ------------ |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | npc to check |

Returns `true` if the `CNPC` is a creep.

## <sub>IsLaneCreep</sub>

`NPC.IsLaneCreep(npc):` <mark style="color:purple;">**`boolean`**</mark>

| Name    | Type                                                                                   | Description  |
| ------- | -------------------------------------------------------------------------------------- | ------------ |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | npc to check |

Returns `true` if the `CNPC` is a lane creep.

## <sub>IsStructure</sub>

`NPC.IsStructure(npc):` <mark style="color:purple;">**`boolean`**</mark>

| Name    | Type                                                                                   | Description  |
| ------- | -------------------------------------------------------------------------------------- | ------------ |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | npc to check |

Returns `true` if the `CNPC` is a structure.

## <sub>IsTower</sub>

`NPC.IsTower(npc):` <mark style="color:purple;">**`boolean`**</mark>

| Name    | Type                                                                                   | Description  |
| ------- | -------------------------------------------------------------------------------------- | ------------ |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | npc to check |

Returns `true` if the `CNPC` is a tower.

## <sub>GetUnitType</sub>

`NPC.GetUnitType(npc):` [<mark style="color:purple;">**`Enum.UnitTypeFlags`**</mark>](https://uczone.gitbook.io/api-v2.0/game-components/core/pages/VwVljl88Qnl7u9hhqRdw#enum.unittypeflags)

| Name    | Type                                                                                   | Description  |
| ------- | -------------------------------------------------------------------------------------- | ------------ |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | npc to check |

Returns unit type flags.

## <sub>IsConsideredHero</sub>

`NPC.IsConsideredHero(npc):` <mark style="color:purple;">**`boolean`**</mark>

| Name    | Type                                                                                   | Description  |
| ------- | -------------------------------------------------------------------------------------- | ------------ |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | npc to check |

Returns `true` if it is unit a considered a hero for targeting purposes.

## <sub>IsBarracks</sub>

`NPC.IsBarracks(npc):` <mark style="color:purple;">**`boolean`**</mark>

| Name    | Type                                                                                   | Description  |
| ------- | -------------------------------------------------------------------------------------- | ------------ |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | npc to check |

Returns `true` if the `CNPC` is a barracks.

## <sub>IsFort</sub>

`NPC.IsFort(npc):` <mark style="color:purple;">**`boolean`**</mark>

| Name    | Type                                                                                   | Description  |
| ------- | -------------------------------------------------------------------------------------- | ------------ |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | npc to check |

Returns `true` if the `CNPC` is the Ancient/Throne building (the win-condition structure).\
Distinct from `IsAncient`, which checks for ancient-tier neutral camps.

## <sub>IsBoss</sub>

`NPC.IsBoss(npc):` <mark style="color:purple;">**`boolean`**</mark>

| Name    | Type                                                                                   | Description  |
| ------- | -------------------------------------------------------------------------------------- | ------------ |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | npc to check |

Returns `true` if the `CNPC` is a boss-like unit (TYPE\_BOSS bit).

## <sub>IsTormentor</sub>

`NPC.IsTormentor(npc):` <mark style="color:purple;">**`boolean`**</mark>

| Name    | Type                                                                                   | Description  |
| ------- | -------------------------------------------------------------------------------------- | ------------ |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | npc to check |

Returns `true` if the `CNPC` is a Tormentor / mini-boss. Renders with the\
siege-wide healthbar (same as Roshan).

## <sub>IsAncient</sub>

`NPC.IsAncient(npc):` <mark style="color:purple;">**`boolean`**</mark>

| Name    | Type                                                                                   | Description  |
| ------- | -------------------------------------------------------------------------------------- | ------------ |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | npc to check |

Returns `true` if the `CNPC` is an ancient creeps.

## <sub>IsRoshan</sub>

`NPC.IsRoshan(npc):` <mark style="color:purple;">**`boolean`**</mark>

| Name    | Type                                                                                   | Description  |
| ------- | -------------------------------------------------------------------------------------- | ------------ |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | npc to check |

Returns `true` if the `CNPC` is a Roshan.

## <sub>IsNeutral</sub>

`NPC.IsNeutral(npc):` <mark style="color:purple;">**`boolean`**</mark>

| Name    | Type                                                                                   | Description  |
| ------- | -------------------------------------------------------------------------------------- | ------------ |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | npc to check |

Returns `true` if the `CNPC` is a neutral. Neutral creeps, ancient creeps.

## <sub>IsHero</sub>

`NPC.IsHero(npc):` <mark style="color:purple;">**`boolean`**</mark>

| Name    | Type                                                                                   | Description  |
| ------- | -------------------------------------------------------------------------------------- | ------------ |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | npc to check |

Returns `true` if the `CNPC` is a hero.

## <sub>IsWard</sub>

`NPC.IsWard(npc):` <mark style="color:purple;">**`boolean`**</mark>

| Name    | Type                                                                                   | Description  |
| ------- | -------------------------------------------------------------------------------------- | ------------ |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | npc to check |

Returns `true` if the `CNPC` is a ward.

## <sub>IsMeepoClone</sub>

`NPC.IsMeepoClone(npc):` <mark style="color:purple;">**`boolean`**</mark>

| Name    | Type                                                                                   | Description  |
| ------- | -------------------------------------------------------------------------------------- | ------------ |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | npc to check |

Returns `true` if the `CNPC` is a meepo clone.

## <sub>IsEntityInRange</sub>

`NPC.IsEntityInRange(npc, npc2, range):` <mark style="color:purple;">**`boolean`**</mark>

| Name      | Type                                                                                   | Description    |
| --------- | -------------------------------------------------------------------------------------- | -------------- |
| **npc**   | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | npc to check   |
| **npc2**  | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | npc to check   |
| **range** | <mark style="color:purple;">**`number`**</mark>                                        | range to check |

Returns `true` if the `CNPC` in range of other `CNPC`.

## <sub>IsPositionInRange</sub>

`NPC.IsPositionInRange(npc, pos, range, [hull]):` <mark style="color:purple;">**`boolean`**</mark>

| Name                                                       | Type                                                                                                           | Description                               |
| ---------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- | ----------------------------------------- |
| **npc**                                                    | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md)                         | npc to check                              |
| **pos**                                                    | [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md) | position to check                         |
| **range**                                                  | <mark style="color:purple;">**`number`**</mark>                                                                | range to check                            |
| **hull&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`number`**</mark>                                                                | hull just added to range `(default: 0.0)` |

Returns `true` if the `CNPC` in range of position.

## <sub>IsLinkensProtected</sub>

`NPC.IsLinkensProtected(npc):` <mark style="color:purple;">**`boolean`**</mark>

| Name    | Type                                                                                   | Description  |
| ------- | -------------------------------------------------------------------------------------- | ------------ |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | npc to check |

Returns `true` if the `CNPC` is protected by Linkens Sphere.

## <sub>IsMirrorProtected</sub>

`NPC.IsMirrorProtected(npc):` <mark style="color:purple;">**`boolean`**</mark>

| Name    | Type                                                                                   | Description  |
| ------- | -------------------------------------------------------------------------------------- | ------------ |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | npc to check |

Returns `true` if the `CNPC` is protected by Mirror Shield.

## <sub>IsChannellingAbility</sub>

{% hint style="info" %}
Do not work for items.
{% endhint %}

`NPC.IsChannellingAbility(npc):` <mark style="color:purple;">**`boolean`**</mark>

| Name    | Type                                                                                   | Description  |
| ------- | -------------------------------------------------------------------------------------- | ------------ |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | npc to check |

Returns `true` if the `CNPC` is channeling ability. Black Hole, Life Drain, etc.

## <sub>GetChannellingAbility</sub>

`NPC.GetChannellingAbility(npc):` [<mark style="color:purple;">**`CAbility`**</mark>](/api-v2.0/game-components/core/ability.md) | <mark style="color:purple;">**`nil`**</mark>

| Name    | Type                                                                                   | Description |
| ------- | -------------------------------------------------------------------------------------- | ----------- |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | target npc  |

Returns the currently channelling `CAbility`.

## <sub>IsRunning</sub>

`NPC.IsRunning(npc):` <mark style="color:purple;">**`boolean`**</mark>

| Name    | Type                                                                                   | Description |
| ------- | -------------------------------------------------------------------------------------- | ----------- |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | target npc  |

Returns `true` if the `CNPC` is running.

## <sub>IsAttacking</sub>

`NPC.IsAttacking(npc):` <mark style="color:purple;">**`boolean`**</mark>

| Name    | Type                                                                                   | Description |
| ------- | -------------------------------------------------------------------------------------- | ----------- |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | target npc  |

Returns `true` if the `CNPC` is attacking.

## <sub>IsSilenced</sub>

`NPC.IsSilenced(npc):` <mark style="color:purple;">**`boolean`**</mark>

| Name    | Type                                                                                   | Description |
| ------- | -------------------------------------------------------------------------------------- | ----------- |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | target npc  |

Returns `true` if the `CNPC` is silenced.

## <sub>IsStunned</sub>

`NPC.IsStunned(npc):` <mark style="color:purple;">**`boolean`**</mark>

| Name    | Type                                                                                   | Description |
| ------- | -------------------------------------------------------------------------------------- | ----------- |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | target npc  |

Returns `true` if the `CNPC` is stunned.

## <sub>HasAegis</sub>

`NPC.HasAegis(npc):` <mark style="color:purple;">**`boolean`**</mark>

| Name    | Type                                                                                   | Description |
| ------- | -------------------------------------------------------------------------------------- | ----------- |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | target npc  |

Returns `true` if the `CNPC` has aegis.

## <sub>IsKillable</sub>

`NPC.IsKillable(npc):` <mark style="color:purple;">**`boolean`**</mark>

| Name    | Type                                                                                   | Description |
| ------- | -------------------------------------------------------------------------------------- | ----------- |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | target npc  |

Returns `true` if the `CNPC` has killable. Example: false if affected by Eul.

## <sub>GetActivity</sub>

`NPC.GetActivity(npc):` [<mark style="color:purple;">**`Enum.GameActivity`**</mark>](https://uczone.gitbook.io/api-v2.0/game-components/core/pages/VwVljl88Qnl7u9hhqRdw#enum.gameactivity)

| Name    | Type                                                                                   | Description |
| ------- | -------------------------------------------------------------------------------------- | ----------- |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | target npc  |

Returns the `CNPC` activity, such as running, attacking, casting, etc.

## <sub>GetAnimationInfo</sub>

`NPC.GetAnimationInfo(npc):` <mark style="color:purple;">**`{sequence:integer, cycle:number, name:string`**</mark> | <mark style="color:purple;">**`nil, mdl_name:string}`**</mark>

| Name    | Type                                                                                   | Description |
| ------- | -------------------------------------------------------------------------------------- | ----------- |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | target npc  |

Returns information about the current animation of the `CNPC`.

## <sub>GetAttackRange</sub>

`NPC.GetAttackRange(npc):` <mark style="color:purple;">**`integer`**</mark>

| Name    | Type                                                                                   | Description |
| ------- | -------------------------------------------------------------------------------------- | ----------- |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | target npc  |

Returns the base attack range of the `CNPC`.

## <sub>GetAttackRangeBonus</sub>

`NPC.GetAttackRangeBonus(npc):` <mark style="color:purple;">**`integer`**</mark>

| Name    | Type                                                                                   | Description |
| ------- | -------------------------------------------------------------------------------------- | ----------- |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | target npc  |

Returns the bonus attack range of the `CNPC`.

## <sub>GetCastRangeBonus</sub>

`NPC.GetCastRangeBonus(npc):` <mark style="color:purple;">**`integer`**</mark>

| Name    | Type                                                                                   | Description |
| ------- | -------------------------------------------------------------------------------------- | ----------- |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | target npc  |

Returns the bonus cast range of the `CNPC`.

## <sub>GetPhysicalArmorValue</sub>

`NPC.GetPhysicalArmorValue(npc, [excludeWhiteArmor]):` <mark style="color:purple;">**`number`**</mark>

| Name                                                                    | Type                                                                                   | Description                           |
| ----------------------------------------------------------------------- | -------------------------------------------------------------------------------------- | ------------------------------------- |
| **npc**                                                                 | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | target npc                            |
| **excludeWhiteArmor&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`boolean`**</mark>                                       | exclude white armor `(default: true)` |

Returns the physical armor value of the `CNPC`.

## <sub>GetPhysicalDamageReduction</sub>

`NPC.GetPhysicalDamageReduction(npc):` <mark style="color:purple;">**`number`**</mark>

| Name    | Type                                                                                   | Description |
| ------- | -------------------------------------------------------------------------------------- | ----------- |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | target npc  |

Returns the physical damage reduction value of the `CNPC`.

## <sub>GetArmorDamageMultiplier</sub>

`NPC.GetArmorDamageMultiplier(npc):` <mark style="color:purple;">**`number`**</mark>

| Name    | Type                                                                                   | Description |
| ------- | -------------------------------------------------------------------------------------- | ----------- |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | target npc  |

Returns the physical damage multiplier value of the `CNPC`.

## <sub>GetMagicalArmorValue</sub>

`NPC.GetMagicalArmorValue(npc):` <mark style="color:purple;">**`number`**</mark>

| Name    | Type                                                                                   | Description |
| ------- | -------------------------------------------------------------------------------------- | ----------- |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | target npc  |

Returns the magical armor value of the `CNPC`.

## <sub>GetMagicalArmorDamageMultiplier</sub>

`NPC.GetMagicalArmorDamageMultiplier(npc):` <mark style="color:purple;">**`number`**</mark>

| Name    | Type                                                                                   | Description |
| ------- | -------------------------------------------------------------------------------------- | ----------- |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | target npc  |

Returns the magical damage multiplier value of the `CNPC`.

## <sub>GetIncreasedAttackSpeed</sub>

`NPC.GetIncreasedAttackSpeed(npc, [ignore_temp_attack_speed]):` <mark style="color:purple;">**`number`**</mark>

| Name                                                                              | Type                                                                                   | Description                                      |
| --------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------- | ------------------------------------------------ |
| **npc**                                                                           | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | target npc                                       |
| **ignore\_temp\_attack\_speed&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`boolean`**</mark>                                       | ignore temporary attack speed `(default: false)` |

Returns increased attack speed of the `CNPC`.

## <sub>GetAttacksPerSecond</sub>

`NPC.GetAttacksPerSecond(npc, [ignore_temp_attack_speed]):` <mark style="color:purple;">**`number`**</mark>

| Name                                                                              | Type                                                                                   | Description                                      |
| --------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------- | ------------------------------------------------ |
| **npc**                                                                           | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | target npc                                       |
| **ignore\_temp\_attack\_speed&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`boolean`**</mark>                                       | ignore temporary attack speed `(default: false)` |

Returns the number of attacks per second that the `CNPC` can deal.

## <sub>GetAttackTime</sub>

`NPC.GetAttackTime(npc):` <mark style="color:purple;">**`number`**</mark>

| Name    | Type                                                                                   | Description |
| ------- | -------------------------------------------------------------------------------------- | ----------- |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | target npc  |

Returns the amount of time needed for the `CNPC` to perform an attack.

## <sub>GetLastAttackTime</sub>

`NPC.GetLastAttackTime(npc):` <mark style="color:purple;">**`number`**</mark>

| Name    | Type                                                                                   | Description |
| ------- | -------------------------------------------------------------------------------------- | ----------- |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | target npc  |

Returns the game time of the `CNPC`'s last attack point. The value includes the sub-tick fraction of the attack cadence.

## <sub>GetAttackSpeed</sub>

`NPC.GetAttackSpeed(npc, [ignore_temp_attack_speed]):` <mark style="color:purple;">**`number`**</mark>

| Name                                                                              | Type                                                                                   | Description                                      |
| --------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------- | ------------------------------------------------ |
| **npc**                                                                           | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | target npc                                       |
| **ignore\_temp\_attack\_speed&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`boolean`**</mark>                                       | ignore temporary attack speed `(default: false)` |

Returns the attack speed of the `CNPC`.

## <sub>GetBaseAttackSpeed</sub>

`NPC.GetBaseAttackSpeed(npc):` <mark style="color:purple;">**`number`**</mark>

| Name    | Type                                                                                   | Description |
| ------- | -------------------------------------------------------------------------------------- | ----------- |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | target npc  |

Returns the base attack speed of the `CNPC`.

## <sub>GetHullRadius</sub>

`NPC.GetHullRadius(npc):` <mark style="color:purple;">**`number`**</mark>

| Name    | Type                                                                                   | Description |
| ------- | -------------------------------------------------------------------------------------- | ----------- |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | target npc  |

Returns the model interaction radius of the `CNPC`.

## <sub>GetPaddedCollisionRadius</sub>

`NPC.GetPaddedCollisionRadius(npc):` <mark style="color:purple;">**`number`**</mark>

| Name    | Type                                                                                   | Description |
| ------- | -------------------------------------------------------------------------------------- | ----------- |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | target npc  |

Returns the collision hull radius (including padding) of this `NPC`.

## <sub>GetCollisionPadding</sub>

`NPC.GetCollisionPadding(npc):` <mark style="color:purple;">**`number`**</mark>

| Name    | Type                                                                                   | Description |
| ------- | -------------------------------------------------------------------------------------- | ----------- |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | target npc  |

Returns the collision including padding of this `NPC`.

## <sub>GetRingRadius</sub>

`NPC.GetRingRadius(npc):` <mark style="color:purple;">**`number`**</mark>

| Name    | Type                                                                                   | Description |
| ------- | -------------------------------------------------------------------------------------- | ----------- |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | target npc  |

Returns the ring radius of this `NPC`.

## <sub>GetProjectileCollisionSize</sub>

{% hint style="info" %}
see: <https://dota2.fandom.com/wiki/Unit\\_Size#Collision\\_Size>
{% endhint %}

`NPC.GetProjectileCollisionSize(npc):` <mark style="color:purple;">**`number`**</mark>

| Name    | Type                                                                                   | Description |
| ------- | -------------------------------------------------------------------------------------- | ----------- |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | target npc  |

Returns the collision size of the `CNPC`. Collision size is the internal size that prevents other units from passing through.

## <sub>GetTurnRate</sub>

{% hint style="info" %}
see: <https://dota2.fandom.com/wiki/Turn\\_rate>
{% endhint %}

`NPC.GetTurnRate(npc):` <mark style="color:purple;">**`number`**</mark>

| Name    | Type                                                                                   | Description |
| ------- | -------------------------------------------------------------------------------------- | ----------- |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | target npc  |

Returns the turn rate, which is the speed at which the `CNPC` can turn.

## <sub>GetAttackAnimPoint</sub>

{% hint style="info" %}
see: <https://dota2.fandom.com/wiki/Attack\\_animation>
{% endhint %}

`NPC.GetAttackAnimPoint(npc):` <mark style="color:purple;">**`number`**</mark> | <mark style="color:purple;">**`nil`**</mark>

| Name    | Type                                                                                   | Description |
| ------- | -------------------------------------------------------------------------------------- | ----------- |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | target npc  |

Returns the attack animation point, `nil` if not found.

## <sub>GetAttackProjectileSpeed</sub>

{% hint style="info" %}
see: <https://dota2.fandom.com/wiki/Projectile\\_Speed>
{% endhint %}

`NPC.GetAttackProjectileSpeed(npc):` <mark style="color:purple;">**`integer`**</mark> | <mark style="color:purple;">**`nil`**</mark>

| Name    | Type                                                                                   | Description |
| ------- | -------------------------------------------------------------------------------------- | ----------- |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | target npc  |

Returns the attack projectile speed, `nil` if not found.

## <sub>IsTurning</sub>

`NPC.IsTurning(npc):` <mark style="color:purple;">**`boolean`**</mark>

| Name    | Type                                                                                   | Description |
| ------- | -------------------------------------------------------------------------------------- | ----------- |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | target npc  |

Returns true if the `CNPC` is turning.

## <sub>GetAngleDiff</sub>

{% hint style="info" %}
doesn't work for creeps
{% endhint %}

`NPC.GetAngleDiff(npc):` <mark style="color:purple;">**`integer`**</mark>

| Name    | Type                                                                                   | Description |
| ------- | -------------------------------------------------------------------------------------- | ----------- |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | target npc  |

Returns the remaining degree angle needed to complete the turn of the `CNPC`.

## <sub>GetPhysicalArmorMainValue</sub>

`NPC.GetPhysicalArmorMainValue(npc):` <mark style="color:purple;">**`number`**</mark>

| Name    | Type                                                                                   | Description |
| ------- | -------------------------------------------------------------------------------------- | ----------- |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | target npc  |

Returns the (main) white armor of the `CNPC`.

## <sub>GetTimeToFace</sub>

`NPC.GetTimeToFace(npc, target):` <mark style="color:purple;">**`number`**</mark>

| Name       | Type                                                                                   | Description |
| ---------- | -------------------------------------------------------------------------------------- | ----------- |
| **npc**    | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | source npc  |
| **target** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | target npc  |

Returns the amount of time needed for the source `CNPC` to face the target `CNPC`.

## <sub>FindRotationAngle</sub>

`NPC.FindRotationAngle(npc, pos):` <mark style="color:purple;">**`number`**</mark>

| Name    | Type                                                                                                           | Description                         |
| ------- | -------------------------------------------------------------------------------------------------------------- | ----------------------------------- |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md)                         | source npc                          |
| **pos** | [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md) | position to find the rotation angle |

Returns the rotation angle of the `CNPC`.

## <sub>GetTimeToFacePosition</sub>

`NPC.GetTimeToFacePosition(npc, pos):` <mark style="color:purple;">**`number`**</mark>

| Name    | Type                                                                                                           | Description     |
| ------- | -------------------------------------------------------------------------------------------------------------- | --------------- |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md)                         | source npc      |
| **pos** | [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md) | target position |

Returns the amount of time needed for the source `CNPC` to face a specific position.

## <sub>FindFacingNPC</sub>

`NPC.FindFacingNPC(npc, ignoreNpc, [team_type], [angle], [distance]):` [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | <mark style="color:purple;">**`nil`**</mark>

| Name                                                             | Type                                                                                                                                                       | Description                            |
| ---------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------- |
| **npc**                                                          | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md)                                                                     | source npc                             |
| **ignoreNpc**                                                    | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md)                                                                     | ignore npc                             |
| **team\_type&#x20;**<mark style="color:orange;">**`[?]`**</mark> | [<mark style="color:purple;">**`Enum.TeamType`**</mark>](https://uczone.gitbook.io/api-v2.0/game-components/core/pages/VwVljl88Qnl7u9hhqRdw#enum.teamtype) | team type `(default: TEAM_BOTH)`       |
| **angle&#x20;**<mark style="color:orange;">**`[?]`**</mark>      | <mark style="color:purple;">**`number`**</mark>                                                                                                            | max angle to check `(default: 0.0)`    |
| **distance&#x20;**<mark style="color:orange;">**`[?]`**</mark>   | <mark style="color:purple;">**`number`**</mark>                                                                                                            | max distance to check `(default: 0.0)` |

Returns the `CNPC` that the source `CNPC` is currently facing.

## <sub>GetBaseSpeed</sub>

`NPC.GetBaseSpeed(npc):` <mark style="color:purple;">**`integer`**</mark>

| Name    | Type                                                                                   | Description |
| ------- | -------------------------------------------------------------------------------------- | ----------- |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | target npc  |

Returns the base move speed of the `CNPC`.

## <sub>GetMoveSpeed</sub>

`NPC.GetMoveSpeed(npc):` <mark style="color:purple;">**`number`**</mark>

| Name    | Type                                                                                   | Description |
| ------- | -------------------------------------------------------------------------------------- | ----------- |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | target npc  |

Returns the move speed of the `CNPC`.

## <sub>GetMinDamage</sub>

`NPC.GetMinDamage(npc):` <mark style="color:purple;">**`number`**</mark>

| Name    | Type                                                                                   | Description |
| ------- | -------------------------------------------------------------------------------------- | ----------- |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | target npc  |

Returns the minumum attack damage of the `CNPC`.

## <sub>GetBonusDamage</sub>

`NPC.GetBonusDamage(npc):` <mark style="color:purple;">**`number`**</mark>

| Name    | Type                                                                                   | Description |
| ------- | -------------------------------------------------------------------------------------- | ----------- |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | target npc  |

Returns the bonus attack damage of the `CNPC`.

## <sub>GetTrueDamage</sub>

`NPC.GetTrueDamage(npc):` <mark style="color:purple;">**`number`**</mark>

| Name    | Type                                                                                   | Description |
| ------- | -------------------------------------------------------------------------------------- | ----------- |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | target npc  |

Returns the minumum attack damage + bonus damage of the `CNPC`.

## <sub>GetTrueMaximumDamage</sub>

`NPC.GetTrueMaximumDamage(npc):` <mark style="color:purple;">**`number`**</mark>

| Name    | Type                                                                                   | Description |
| ------- | -------------------------------------------------------------------------------------- | ----------- |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | target npc  |

Returns the maximum attack damage + bonus damage of the `CNPC`.

## <sub>GetItemByIndex</sub>

`NPC.GetItemByIndex(npc, index):` [<mark style="color:purple;">**`CItem`**</mark>](/api-v2.0/game-components/core/item.md) | <mark style="color:purple;">**`nil`**</mark>

| Name      | Type                                                                                   | Description |
| --------- | -------------------------------------------------------------------------------------- | ----------- |
| **npc**   | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | target npc  |
| **index** | <mark style="color:purple;">**`integer`**</mark>                                       | item index  |

Returns the `CItem` by index.

## <sub>GetAbilityByIndex</sub>

`NPC.GetAbilityByIndex(npc, index):` [<mark style="color:purple;">**`CAbility`**</mark>](/api-v2.0/game-components/core/ability.md) | <mark style="color:purple;">**`nil`**</mark>

| Name      | Type                                                                                   | Description   |
| --------- | -------------------------------------------------------------------------------------- | ------------- |
| **npc**   | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | target npc    |
| **index** | <mark style="color:purple;">**`integer`**</mark>                                       | ability index |

Returns the `CAbility` by index.

## <sub>GetAbilityByActivity</sub>

`NPC.GetAbilityByActivity(npc, activity):` [<mark style="color:purple;">**`CAbility`**</mark>](/api-v2.0/game-components/core/ability.md) | <mark style="color:purple;">**`nil`**</mark>

| Name         | Type                                                                                                                                                               | Description             |
| ------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ----------------------- |
| **npc**      | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md)                                                                             | npc to get ability from |
| **activity** | [<mark style="color:purple;">**`Enum.GameActivity`**</mark>](https://uczone.gitbook.io/api-v2.0/game-components/core/pages/VwVljl88Qnl7u9hhqRdw#enum.gameactivity) | game activity           |

Returns the `CAbility` by game activity.

## <sub>GetAbility</sub>

`NPC.GetAbility(npc, name):` [<mark style="color:purple;">**`CAbility`**</mark>](/api-v2.0/game-components/core/ability.md) | <mark style="color:purple;">**`nil`**</mark>

| Name     | Type                                                                                   | Description  |
| -------- | -------------------------------------------------------------------------------------- | ------------ |
| **npc**  | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | target npc   |
| **name** | <mark style="color:purple;">**`string`**</mark>                                        | ability name |

Returns the `CAbility` by name.

## <sub>HasAbility</sub>

`NPC.HasAbility(npc, name):` <mark style="color:purple;">**`boolean`**</mark>

| Name     | Type                                                                                   | Description  |
| -------- | -------------------------------------------------------------------------------------- | ------------ |
| **npc**  | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | target npc   |
| **name** | <mark style="color:purple;">**`string`**</mark>                                        | ability name |

Returns `true` if the `CNPC` has this ability.

## <sub>GetMana</sub>

`NPC.GetMana(npc):` <mark style="color:purple;">**`number`**</mark>

| Name    | Type                                                                                   | Description |
| ------- | -------------------------------------------------------------------------------------- | ----------- |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | target npc  |

Returns the current mana of the `CNPC`.

## <sub>GetMaxMana</sub>

`NPC.GetMaxMana(npc):` <mark style="color:purple;">**`number`**</mark>

| Name    | Type                                                                                   | Description |
| ------- | -------------------------------------------------------------------------------------- | ----------- |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | target npc  |

Returns the maximum mana of the `CNPC`.

## <sub>GetManaRegen</sub>

`NPC.GetManaRegen(npc):` <mark style="color:purple;">**`number`**</mark>

| Name    | Type                                                                                   | Description |
| ------- | -------------------------------------------------------------------------------------- | ----------- |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | target npc  |

Returns the mana regeneration rate of the `CNPC`.

## <sub>GetHealthRegen</sub>

`NPC.GetHealthRegen(npc):` <mark style="color:purple;">**`number`**</mark>

| Name    | Type                                                                                   | Description |
| ------- | -------------------------------------------------------------------------------------- | ----------- |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | target npc  |

Returns the health regeneration rate of the `CNPC`.

## <sub>CalculateHealthRegen</sub>

{% hint style="info" %}
Works for creeps but really slow.
{% endhint %}

`NPC.CalculateHealthRegen(npc):` <mark style="color:purple;">**`number`**</mark>

| Name    | Type                                                                                   | Description |
| ------- | -------------------------------------------------------------------------------------- | ----------- |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | target npc  |

Iterate over all modifiers and returns the health regeneration rate of the `CNPC`.

## <sub>GetCurrentLevel</sub>

`NPC.GetCurrentLevel(npc):` <mark style="color:purple;">**`number`**</mark>

| Name    | Type                                                                                   | Description |
| ------- | -------------------------------------------------------------------------------------- | ----------- |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | target npc  |

Returns the current level of the `CNPC`.

## <sub>GetDayTimeVisionRange</sub>

`NPC.GetDayTimeVisionRange(npc):` <mark style="color:purple;">**`integer`**</mark>

| Name    | Type                                                                                   | Description |
| ------- | -------------------------------------------------------------------------------------- | ----------- |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | target npc  |

Returns the day-time vision range of the `CNPC`.

## <sub>GetNightTimeVisionRange</sub>

`NPC.GetNightTimeVisionRange(npc):` <mark style="color:purple;">**`integer`**</mark>

| Name    | Type                                                                                   | Description |
| ------- | -------------------------------------------------------------------------------------- | ----------- |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | target npc  |

Returns the night-time vision range of the `CNPC`.

## <sub>GetUnitName</sub>

`NPC.GetUnitName(npc):` <mark style="color:purple;">**`string`**</mark>

| Name    | Type                                                                                   | Description |
| ------- | -------------------------------------------------------------------------------------- | ----------- |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | target npc  |

Returns the unit-name of the `CNPC`.

## <sub>GetHealthBarOffset</sub>

`NPC.GetHealthBarOffset(npc, [checkOverride]):` <mark style="color:purple;">**`integer`**</mark>

| Name                                                                | Type                                                                                   | Description                                            |
| ------------------------------------------------------------------- | -------------------------------------------------------------------------------------- | ------------------------------------------------------ |
| **npc**                                                             | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | target npc                                             |
| **checkOverride&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`boolean`**</mark>                                       | returns override offset if it exists `(default: true)` |

Returns the health bar offset of the `CNPC`.

## <sub>GetUnitNameIndex</sub>

{% hint style="info" %}
returns the legacy numeric ID, not the current UnitNames string-table index
{% endhint %}

`NPC.GetUnitNameIndex(npc):` <mark style="color:purple;">**`integer`**</mark>

| Name    | Type                                                                                   | Description |
| ------- | -------------------------------------------------------------------------------------- | ----------- |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | target npc  |

Returns the canonical unit-name index of the `CNPC`.

## <sub>GetAttachment</sub>

`NPC.GetAttachment(npc, name):` [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md)

| Name     | Type                                                                                   | Description                            |
| -------- | -------------------------------------------------------------------------------------- | -------------------------------------- |
| **npc**  | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | target npc                             |
| **name** | <mark style="color:purple;">**`string`**</mark>                                        | attachment name. e.g. "attach\_hitloc" |

Returns the attachment position of the `CNPC` by the name.

#### Example

```lua
-- attachments.txt
attach_hitloc
attach_eye_r
attach_eye_l
attach_mouth
attach_totem
attach_head
attach_tidebringer
attach_tidebringer_2
attach_sword
attach_attack1
attach_weapon
attach_eyes
attach_prop_l
attach_prop_r
attach_light
attach_staff
attach_mouthbase
attach_mouthend
attach_mom_l
attach_mom_r
attach_attack2
attach_fuse
attach_mane
attach_tail
attach_upper_jaw
attach_weapon_core_fx
attach_bow_top
attach_bow_bottom
attach_bow_mid
attach_armor
attach_chimmney
attach_eyeR
attach_eyeL
attach_spine4
attach_spine5
attach_spine6
attach_spine7
attach_spine8
attach_spine9
attach_armlet_1
attach_armlet_2
attach_armlet_3
attach_armlet_4
attach_armlet_5
attach_vanguard_guard_1
attach_vanguard_guard_2
attach_weapon_offhand
attach_vanguard_1
attach_vanguard_2
attach_attack3
attach_attack4
attach_banner
attach_fx
attach_portcullis
attach_gem
```

## <sub>GetAttachmentByIndex</sub>

`NPC.GetAttachmentByIndex(npc, index):` [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md)

| Name      | Type                                                                                   | Description      |
| --------- | -------------------------------------------------------------------------------------- | ---------------- |
| **npc**   | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | target npc       |
| **index** | <mark style="color:purple;">**`integer`**</mark>                                       | attachment index |

Returns the attachment position of the `CNPC` by the specified index.

## <sub>GetAttachmentIndexByName</sub>

`NPC.GetAttachmentIndexByName(npc, name):` <mark style="color:purple;">**`integer`**</mark>

| Name     | Type                                                                                   | Description                            |
| -------- | -------------------------------------------------------------------------------------- | -------------------------------------- |
| **npc**  | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | target npc                             |
| **name** | <mark style="color:purple;">**`string`**</mark>                                        | attachment name. e.g. "attach\_hitloc" |

Returns the attachment index of the `CNPC` by the name.

## <sub>EvaluateAttachmentEmulated</sub>

`NPC.EvaluateAttachmentEmulated(npc, name, activity, seq_variant, cycle):` [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md)

| Name             | Type                                                                                   | Description                                      |
| ---------------- | -------------------------------------------------------------------------------------- | ------------------------------------------------ |
| **npc**          | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | target npc                                       |
| **name**         | <mark style="color:purple;">**`string`**</mark>                                        | attachment name (e.g. "attach\_attack1")         |
| **activity**     | <mark style="color:purple;">**`number`**</mark>                                        | GameActivity int (e.g. 1503 = ACT\_DOTA\_ATTACK) |
| **seq\_variant** | <mark style="color:purple;">**`number`**</mark>                                        | sequence variant index (usually 0)               |
| **cycle**        | <mark style="color:purple;">**`number`**</mark>                                        | sequence cycle 0..1                              |

Returns the world-space position of the attachment `name` on the `CNPC`, evaluated for the\
given animation activity, sequence variant and cycle. The NPC's current animation is not changed.\
If no sequence matches the activity and variant, the position of the attachment in the current\
pose is returned.

## <sub>GetBountyXP</sub>

`NPC.GetBountyXP(npc):` <mark style="color:purple;">**`integer`**</mark>

| Name    | Type                                                                                   | Description |
| ------- | -------------------------------------------------------------------------------------- | ----------- |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | target npc  |

Returns the amount of experience points (XP) you can earn for killing the `CNPC`.

## <sub>GetGoldBountyMin</sub>

`NPC.GetGoldBountyMin(npc):` <mark style="color:purple;">**`integer`**</mark>

| Name    | Type                                                                                   | Description |
| ------- | -------------------------------------------------------------------------------------- | ----------- |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | target npc  |

Returns the minimum amount gold you can earn for killing the `CNPC`.

## <sub>GetGoldBountyMax</sub>

`NPC.GetGoldBountyMax(npc):` <mark style="color:purple;">**`integer`**</mark>

| Name    | Type                                                                                   | Description |
| ------- | -------------------------------------------------------------------------------------- | ----------- |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | target npc  |

Returns the maximum amount gold you can earn for killing the `CNPC`.

## <sub>MoveTo</sub>

`NPC.MoveTo(npc, position, [queue], [show], [callback], [executeFast], [identifier], [force_minimap]):` <mark style="color:purple;">**`nil`**</mark>

| Name                                                                 | Type                                                                                                           | Description                                                                             |
| -------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| **npc**                                                              | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md)                         | The target NPC.                                                                         |
| **position**                                                         | [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md) | The destination position.                                                               |
| **queue&#x20;**<mark style="color:orange;">**`[?]`**</mark>          | <mark style="color:purple;">**`boolean`**</mark>                                                               | Add the order to the Dota queue. `(default: false)`                                     |
| **show&#x20;**<mark style="color:orange;">**`[?]`**</mark>           | <mark style="color:purple;">**`boolean`**</mark>                                                               | Show the order position. `(default: false)`                                             |
| **callback&#x20;**<mark style="color:orange;">**`[?]`**</mark>       | <mark style="color:purple;">**`boolean`**</mark>                                                               | Push the order to the OnPrepareUnitOrders callback. `(default: false)`                  |
| **executeFast&#x20;**<mark style="color:orange;">**`[?]`**</mark>    | <mark style="color:purple;">**`boolean`**</mark>                                                               | Place the order at the top of the queue. `(default: false)`                             |
| **identifier&#x20;**<mark style="color:orange;">**`[?]`**</mark>     | <mark style="color:purple;">**`string`**</mark>                                                                | The identifier which will be passed to `OnPrepareUnitOrders` callback. `(default: nil)` |
| **force\_minimap&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`boolean`**</mark>                                                               | If true, the order will be forced by the minimap if possible. `(default: true)`         |

Initiates an order for the `CNPC` to move to a specified position.

## <sub>SetZDelta</sub>

`NPC.SetZDelta(npc, z):` <mark style="color:purple;">**`nil`**</mark>

| Name    | Type                                                                                   | Description     |
| ------- | -------------------------------------------------------------------------------------- | --------------- |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | The target NPC. |
| **z**   | <mark style="color:purple;">**`number`**</mark>                                        | Z pos           |

Sets the Z position of the `CNPC` model.

## <sub>HasScepter</sub>

`NPC.HasScepter(npc):` <mark style="color:purple;">**`boolean`**</mark>

| Name    | Type                                                                                   | Description     |
| ------- | -------------------------------------------------------------------------------------- | --------------- |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | The target NPC. |

Returns `true` if the `CNPC` has or consumed Aghanim Scepter.

## <sub>HasShard</sub>

`NPC.HasShard(npc):` <mark style="color:purple;">**`boolean`**</mark>

| Name    | Type                                                                                   | Description     |
| ------- | -------------------------------------------------------------------------------------- | --------------- |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | The target NPC. |

Returns `true` if the `CNPC` has or consumed Aghanim Shard.

## <sub>GetScepterUpgradeID</sub>

`NPC.GetScepterUpgradeID(npc):` <mark style="color:purple;">**`integer`**</mark>

| Name    | Type                                                                                   | Description     |
| ------- | -------------------------------------------------------------------------------------- | --------------- |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | The target NPC. |

Returns index of selected scepter upgrade.

## <sub>GetShardUpgradeID</sub>

`NPC.GetShardUpgradeID(npc):` <mark style="color:purple;">**`integer`**</mark>

| Name    | Type                                                                                   | Description     |
| ------- | -------------------------------------------------------------------------------------- | --------------- |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | The target NPC. |

Returns index of selected shard upgrade.

## <sub>SequenceDuration</sub>

`NPC.SequenceDuration(npc, sequence):` <mark style="color:purple;">**`number`**</mark>

| Name         | Type                                                                                   | Description         |
| ------------ | -------------------------------------------------------------------------------------- | ------------------- |
| **npc**      | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | The target NPC.     |
| **sequence** | <mark style="color:purple;">**`integer`**</mark>                                       | The sequence index. |

Returns sequence duration of the npc with the specified sequence index.

## <sub>GetSecondsPerAttack</sub>

`NPC.GetSecondsPerAttack(npc, bIgnoreTempAttackSpeed):` <mark style="color:purple;">**`number`**</mark>

| Name                       | Type                                                                                   | Description                    |
| -------------------------- | -------------------------------------------------------------------------------------- | ------------------------------ |
| **npc**                    | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | The target NPC.                |
| **bIgnoreTempAttackSpeed** | <mark style="color:purple;">**`boolean`**</mark>                                       | Ignore temporary attack speed. |

Returns the seconds per attack of the npc.

## <sub>GetSequence</sub>

`NPC.GetSequence(npc, sequenceVariant, activity):` <mark style="color:purple;">**`integer`**</mark>

| Name                | Type                                                                                   | Description                                                  |
| ------------------- | -------------------------------------------------------------------------------------- | ------------------------------------------------------------ |
| **npc**             | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | target npc                                                   |
| **sequenceVariant** | <mark style="color:purple;">**`integer`**</mark>                                       | 0 by default (most heroes)                                   |
| **activity**        | <mark style="color:purple;">**`integer`**</mark>                                       | GameActivity enum (e.g. Enum.GameActivity.ACT\_DOTA\_ATTACK) |

Returns the sequence (HSequence) the NPC plays for the given activity and sequence variant. The\
lookup uses the activity, not the NPC's current animation.

#### Example

```lua
local seq = NPC.GetSequence(npc, 0, Enum.GameActivity.ACT_DOTA_ATTACK)
local dur = NPC.SequenceDuration(npc, seq)
```

## <sub>GetBarriers</sub>

`NPC.GetBarriers(npc):` <mark style="color:purple;">**`{physical:{total:number, current:number}, magic:{total:number, current:number}, all:{total:number, current:number}}`**</mark> | <mark style="color:purple;">**`nil`**</mark>

| Name    | Type                                                                                   | Description     |
| ------- | -------------------------------------------------------------------------------------- | --------------- |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | The target NPC. |

Returns a table with information about the barriers of the `CNPC`, or `nil` if it has none.

## <sub>GetGlow</sub>

`NPC.GetGlow(npc):` <mark style="color:purple;">**`{m_bSuppressGlow:boolean, m_bFlashing:boolean, m_bGlowing:boolean, m_iGlowType:integer, r:integer, g:integer, b:integer}`**</mark>

| Name    | Type                                                                                   | Description     |
| ------- | -------------------------------------------------------------------------------------- | --------------- |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | The target NPC. |

Returns a table with information about the current glow effect of the `CNPC`.

## <sub>SetGlow</sub>

`NPC.SetGlow(npc, suppress_glow, flashing, glowing, glow_type, r, g, b):` <mark style="color:purple;">**`nil`**</mark>

| Name               | Type                                                                                   | Description     |
| ------------------ | -------------------------------------------------------------------------------------- | --------------- |
| **npc**            | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | The target NPC. |
| **suppress\_glow** | <mark style="color:purple;">**`boolean`**</mark>                                       | suppress\_glow  |
| **flashing**       | <mark style="color:purple;">**`boolean`**</mark>                                       | flashing        |
| **glowing**        | <mark style="color:purple;">**`boolean`**</mark>                                       | glowing         |
| **glow\_type**     | <mark style="color:purple;">**`integer`**</mark>                                       | glow type       |
| **r**              | <mark style="color:purple;">**`integer`**</mark>                                       | r factor        |
| **g**              | <mark style="color:purple;">**`integer`**</mark>                                       | g factor        |
| **b**              | <mark style="color:purple;">**`integer`**</mark>                                       | b factor        |

Sets the `CNPC` glow effect.

## <sub>SetColor</sub>

`NPC.SetColor(npc, r, g, b):` <mark style="color:purple;">**`nil`**</mark>

| Name    | Type                                                                                   | Description     |
| ------- | -------------------------------------------------------------------------------------- | --------------- |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | The target NPC. |
| **r**   | <mark style="color:purple;">**`integer`**</mark>                                       | r factor        |
| **g**   | <mark style="color:purple;">**`integer`**</mark>                                       | g factor        |
| **b**   | <mark style="color:purple;">**`integer`**</mark>                                       | b factor        |

Sets the `CNPC` model color.

## <sub>IsInRangeOfShop</sub>

`NPC.IsInRangeOfShop(npc, shop_type, [specific]):` <mark style="color:purple;">**`boolean`**</mark>

| Name                                                           | Type                                                                                                                                                       | Description                              |
| -------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------- |
| **npc**                                                        | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md)                                                                     | The target NPC.                          |
| **shop\_type**                                                 | [<mark style="color:purple;">**`Enum.ShopType`**</mark>](https://uczone.gitbook.io/api-v2.0/game-components/core/pages/VwVljl88Qnl7u9hhqRdw#enum.shoptype) | Shop type to check.                      |
| **specific&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`boolean`**</mark>                                                                                                           | No idea what is that. `(default: false)` |

Checks if the `CNPC` is in range of a shop.

## <sub>GetBaseSpellAmp</sub>

`NPC.GetBaseSpellAmp(npc):` <mark style="color:purple;">**`number`**</mark>

| Name    | Type                                                                                   | Description     |
| ------- | -------------------------------------------------------------------------------------- | --------------- |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | The target NPC. |

Returns the base spell amplification of the `CNPC`.

## <sub>GetModifierProperty</sub>

`NPC.GetModifierProperty(npc, property):` <mark style="color:purple;">**`number`**</mark>

| Name         | Type                                                                                                                                                                       | Description     |
| ------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------- |
| **npc**      | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md)                                                                                     | The target NPC. |
| **property** | [<mark style="color:purple;">**`Enum.ModifierFunction`**</mark>](https://uczone.gitbook.io/api-v2.0/game-components/core/pages/VwVljl88Qnl7u9hhqRdw#enum.modifierfunction) | Property enum.  |

Returns the property value for the `CNPC`.

## <sub>IsControllableByPlayer</sub>

`NPC.IsControllableByPlayer(npc, playerId):` <mark style="color:purple;">**`boolean`**</mark>

| Name         | Type                                                                                   | Description  |
| ------------ | -------------------------------------------------------------------------------------- | ------------ |
| **npc**      | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | npc to check |
| **playerId** | <mark style="color:purple;">**`integer`**</mark>                                       | player id    |

Returns `true` if npc is controllable by player.

## <sub>GetModifierPropertyHighest</sub>

{% hint style="info" %}
Fixes the issue when you have multiple Kaya items that actually don't stack.
{% endhint %}

\`NPC.GetModifierPropertyHighest(npc, property):\` <mark style="color:purple;">\*\*\`number\`\*\*</mark>

| Name         | Type                                                                                                                                                                       | Description     |
| ------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------- |
| **npc**      | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md)                                                                                     | The target NPC. |
| **property** | [<mark style="color:purple;">**`Enum.ModifierFunction`**</mark>](https://uczone.gitbook.io/api-v2.0/game-components/core/pages/VwVljl88Qnl7u9hhqRdw#enum.modifierfunction) | Property enum.  |

Returns the hieghest property value for the `CNPC`.
