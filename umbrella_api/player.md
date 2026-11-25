> For the complete documentation index, see [llms.txt](https://uczone.gitbook.io/api-v2.0/llms.txt). Markdown versions of documentation pages are available by appending `.md` to page URLs; this page is available as [Markdown](https://uczone.gitbook.io/api-v2.0/game-components/core/player.md).

# Player

Table to work with `CPlayer`. <mark style="color:purple;">**`CPlayer`**</mark> extends <mark style="color:purple;">**`CEntity`**</mark>

## <sub>PrepareUnitOrders</sub>

`Player.PrepareUnitOrders(player, type, target, pos, ability, issuer, issuer_npc, [queue], [show_effects], [callback], [execute_fast], [identifier], [force_minimap]):` <mark style="color:purple;">**`nil`**</mark>

| Name                                                                 | Type                                                                                                                                                                               | Description                                                                                       |
| -------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| **player**                                                           | [<mark style="color:purple;">**`CPlayer`**</mark>](/api-v2.0/game-components/core/player.md)                                                                                       | The player issuing the order.                                                                     |
| **type**                                                             | [<mark style="color:purple;">**`Enum.UnitOrder`**</mark>](https://uczone.gitbook.io/api-v2.0/game-components/core/pages/VwVljl88Qnl7u9hhqRdw#enum.unitorder)                       | The type of order to be issued.                                                                   |
| **target**                                                           | [<mark style="color:purple;">**`CEntity`**</mark>](/api-v2.0/game-components/core/entity.md) \| <mark style="color:purple;">**`nil`**</mark>                                       | The target entity, if applicable.                                                                 |
| **pos**                                                              | [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md)                                                                     | The positional coordinates for the order.                                                         |
| **ability**                                                          | [<mark style="color:purple;">**`CAbility`**</mark>](/api-v2.0/game-components/core/ability.md) \| <mark style="color:purple;">**`nil`**</mark>                                     | The ability for order.                                                                            |
| **issuer**                                                           | [<mark style="color:purple;">**`Enum.PlayerOrderIssuer`**</mark>](https://uczone.gitbook.io/api-v2.0/game-components/core/pages/VwVljl88Qnl7u9hhqRdw#enum.playerorderissuer)       | The issuer capture mode.                                                                          |
| **issuer\_npc**                                                      | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) \| [<mark style="color:purple;">**`CNPC[]`**</mark>](/api-v2.0/game-components/core/npc.md) | The specific NPC or group of NPC that will issue the order.                                       |
| **queue&#x20;**<mark style="color:orange;">**`[?]`**</mark>          | <mark style="color:purple;">**`boolean`**</mark>                                                                                                                                   | If true, the order will be added to the Dota cast queue. `(default: false)`                       |
| **show\_effects&#x20;**<mark style="color:orange;">**`[?]`**</mark>  | <mark style="color:purple;">**`boolean`**</mark>                                                                                                                                   | If true, visual effects will indicate the position of the order. `(default: false)`               |
| **callback&#x20;**<mark style="color:orange;">**`[?]`**</mark>       | <mark style="color:purple;">**`boolean`**</mark>                                                                                                                                   | If true, the order will be pushed to the `OnPrepareUnitOrders` callback. `(default: false)`       |
| **execute\_fast&#x20;**<mark style="color:orange;">**`[?]`**</mark>  | <mark style="color:purple;">**`boolean`**</mark>                                                                                                                                   | If true, the order will bypass internal safety delays for immediate execution. `(default: false)` |
| **identifier&#x20;**<mark style="color:orange;">**`[?]`**</mark>     | <mark style="color:purple;">**`string`**</mark>                                                                                                                                    | The identifier which will be passed to `OnPrepareUnitOrders` callback. `(default: nil)`           |
| **force\_minimap&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`boolean`**</mark>                                                                                                                                   | If true, the order will be forced by the minimap if possible. `(default: true)`                   |

Provides ability to execute such game actions as moving, attacking, or casting spells etc.

## <sub>HoldPosition</sub>

`Player.HoldPosition(player, issuer_npc, [queue], [push], [execute_fast], [identifier]):` <mark style="color:purple;">**`nil`**</mark>

| Name                                                                | Type                                                                                         | Description                                                                                       |
| ------------------------------------------------------------------- | -------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| **player**                                                          | [<mark style="color:purple;">**`CPlayer`**</mark>](/api-v2.0/game-components/core/player.md) | The player issuing the order.                                                                     |
| **issuer\_npc**                                                     | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md)       | The specific NPC that will issue the order.                                                       |
| **queue&#x20;**<mark style="color:orange;">**`[?]`**</mark>         | <mark style="color:purple;">**`boolean`**</mark>                                             | If true, the order will be added to the Dota cast queue. `(default: false)`                       |
| **push&#x20;**<mark style="color:orange;">**`[?]`**</mark>          | <mark style="color:purple;">**`boolean`**</mark>                                             | If true, the order will be pushed to the OnPrepareUnitOrders callback. `(default: false)`         |
| **execute\_fast&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`boolean`**</mark>                                             | If true, the order will bypass internal safety delays for immediate execution. `(default: false)` |
| **identifier&#x20;**<mark style="color:orange;">**`[?]`**</mark>    | <mark style="color:purple;">**`string`**</mark>                                              | The identifier which will be passed to `OnPrepareUnitOrders` callback. `(default: nil)`           |

Sends the hold position action.

## <sub>AttackTarget</sub>

`Player.AttackTarget(player, issuer_npc, target, [queue], [push], [execute_fast], [identifier], [force_minimap]):` <mark style="color:purple;">**`nil`**</mark>

| Name                                                                 | Type                                                                                         | Description                                                                                       |
| -------------------------------------------------------------------- | -------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| **player**                                                           | [<mark style="color:purple;">**`CPlayer`**</mark>](/api-v2.0/game-components/core/player.md) | The player issuing the order.                                                                     |
| **issuer\_npc**                                                      | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md)       | The specific NPC that will issue the order.                                                       |
| **target**                                                           | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md)       | The target NPC.                                                                                   |
| **queue&#x20;**<mark style="color:orange;">**`[?]`**</mark>          | <mark style="color:purple;">**`boolean`**</mark>                                             | If true, the order will be added to the Dota cast queue. `(default: false)`                       |
| **push&#x20;**<mark style="color:orange;">**`[?]`**</mark>           | <mark style="color:purple;">**`boolean`**</mark>                                             | If true, the order will be pushed to the OnPrepareUnitOrders callback. `(default: false)`         |
| **execute\_fast&#x20;**<mark style="color:orange;">**`[?]`**</mark>  | <mark style="color:purple;">**`boolean`**</mark>                                             | If true, the order will bypass internal safety delays for immediate execution. `(default: false)` |
| **identifier&#x20;**<mark style="color:orange;">**`[?]`**</mark>     | <mark style="color:purple;">**`string`**</mark>                                              | The identifier which will be passed to `OnPrepareUnitOrders` callback. `(default: nil)`           |
| **force\_minimap&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`boolean`**</mark>                                             | If true, the order will be forced by the minimap if possible. `(default: true)`                   |

Sends the attack target position.

## <sub>GetPlayerID</sub>

`Player.GetPlayerID(player):` <mark style="color:purple;">**`integer`**</mark>

| Name       | Type                                                                                         | Description        |
| ---------- | -------------------------------------------------------------------------------------------- | ------------------ |
| **player** | [<mark style="color:purple;">**`CPlayer`**</mark>](/api-v2.0/game-components/core/player.md) | The target player. |

Returns the player ID within the current game session.\
If the player ID is not valid, it will return -1.

## <sub>GetPlayerSlot</sub>

`Player.GetPlayerSlot(player):` <mark style="color:purple;">**`integer`**</mark>

| Name       | Type                                                                                         | Description        |
| ---------- | -------------------------------------------------------------------------------------------- | ------------------ |
| **player** | [<mark style="color:purple;">**`CPlayer`**</mark>](/api-v2.0/game-components/core/player.md) | The target player. |

Returns the player slot number within the current game session.

## <sub>GetPlayerTeamSlot</sub>

`Player.GetPlayerTeamSlot(player):` <mark style="color:purple;">**`integer`**</mark>

| Name       | Type                                                                                         | Description        |
| ---------- | -------------------------------------------------------------------------------------------- | ------------------ |
| **player** | [<mark style="color:purple;">**`CPlayer`**</mark>](/api-v2.0/game-components/core/player.md) | The target player. |

Returns the team slot number assigned to the player within their respective team.

## <sub>GetName</sub>

`Player.GetName(player):` <mark style="color:purple;">**`string`**</mark>, <mark style="color:purple;">**`string`**</mark> | <mark style="color:purple;">**`nil`**</mark>

| Name       | Type                                                                                         | Description        |
| ---------- | -------------------------------------------------------------------------------------------- | ------------------ |
| **player** | [<mark style="color:purple;">**`CPlayer`**</mark>](/api-v2.0/game-components/core/player.md) | The target player. |

Returns the player nickname and his proname

## <sub>GetProName</sub>

`Player.GetProName(steamId):` <mark style="color:purple;">**`string`**</mark>

| Name        | Type                                             | Description |
| ----------- | ------------------------------------------------ | ----------- |
| **steamId** | <mark style="color:purple;">**`integer`**</mark> |             |

Returns cached player's proname. Works only in game callbacks

## <sub>GetPlayerData</sub>

`Player.GetPlayerData(player, [output]):` <mark style="color:purple;">**`{valid:boolean, fullyJoined:boolean, fakeClient:boolean, connectionState:integer, steamid:integer, PlusSubscriber:boolean, MVPLastGame:boolean, PlayerName:string, ProName:string}`**</mark>

| Name                                                         | Type                                                                                         | Description                                                                         |
| ------------------------------------------------------------ | -------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| **player**                                                   | [<mark style="color:purple;">**`CPlayer`**</mark>](/api-v2.0/game-components/core/player.md) | The target player.                                                                  |
| **output&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`table`**</mark>                                               | Optional reusable table to populate instead of creating a new one. `(default: nil)` |

Returns the player data table.

## <sub>GetTeamData</sub>

`Player.GetTeamData(player):` <mark style="color:purple;">**`{selected_hero_id:integer, kills:integer, assists:integer, deaths:integer, streak:integer, respawnTime:integer, selected_hero_variant:integer, lane_selection_flags:integer, last_buyback_time:number}`**</mark>

| Name       | Type                                                                                         | Description        |
| ---------- | -------------------------------------------------------------------------------------------- | ------------------ |
| **player** | [<mark style="color:purple;">**`CPlayer`**</mark>](/api-v2.0/game-components/core/player.md) | The target player. |

Returns the player team data table.\
Team data is only available for players on the local team.

## <sub>GetNeutralStashItems</sub>

`Player.GetNeutralStashItems(player):` [<mark style="color:purple;">**`CItem[]`**</mark>](/api-v2.0/game-components/core/item.md)

| Name       | Type                                                                                         | Description        |
| ---------- | -------------------------------------------------------------------------------------------- | ------------------ |
| **player** | [<mark style="color:purple;">**`CPlayer`**</mark>](/api-v2.0/game-components/core/player.md) | The target player. |

Returns table with `CItem`s available in the neutral stash.

## <sub>GetTeamPlayer</sub>

`Player.GetTeamPlayer(player, [output]):` <mark style="color:purple;">**`{reliable_gold:integer, unreliable_gold:integer, starting_position:integer, totalearned_gold:integer, totalearned_xp:integer, shared_gold:integer, hero_kill_gold:integer, creep_kill_gold:integer, neutral_kill_gold:integer, courier_gold:integer, bounty_gold:integer, roshan_gold:integer, building_gold:integer, other_gold:integer, comeback_gold:integer, experimental_gold:integer, experimental2_gold:integer, creepdeny_gold:integer, tp_scrolls_purchased:integer, custom_stats:number, income_gold:integer, ward_kill_gold:integer, ability_gold:integer, networth:integer, deny_count:integer, lasthit_count:integer, lasthit_streak:integer, lasthit_multikill:integer, nearby_creep_death_count:integer, claimed_deny_count:integer, claimed_miss_count:integer, miss_count:integer, possible_hero_selection:integer, buyback_cooldown_time:number, buyback_gold_limit_time:number, buyback_cost_time:number, custom_buyback_cooldown:number, stuns:number, healing:number, tower_Kills:integer, roshan_kills:integer, camera_target:CEntity`**</mark> | <mark style="color:purple;">**`nil, override_selection_entity:CEntity`**</mark> | <mark style="color:purple;">**`nil, observer_wards_placed:integer, sentry_wards_placed:integer, creeps_stacked:integer, camps_stacked:integer, rune_pickups:integer, gold_spent_on_support:integer, hero_damage:number, wards_purchased:integer, wards_destroyed:integer, commands_issued:integer, gold_spent_on_consumables:integer, gold_spent_on_items:integer, gold_spent_on_buybacks:integer, gold_lost_to_death:integer, is_new_player:boolean, is_guide_player:boolean, acquired_madstone:integer, current_madstone:integer, possible_hero_facet_selection:integer}`**</mark>

| Name                                                         | Type                                                                                         | Description                                                                         |
| ------------------------------------------------------------ | -------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| **player**                                                   | [<mark style="color:purple;">**`CPlayer`**</mark>](/api-v2.0/game-components/core/player.md) | The target player.                                                                  |
| **output&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`table`**</mark>                                               | Optional reusable table to populate instead of creating a new one. `(default: nil)` |

Returns **Team Player Data** table

## <sub>GetPlayerNeutralInfo</sub>

`Player.GetPlayerNeutralInfo(player):` <mark style="color:purple;">**`nil`**</mark> | <mark style="color:purple;">**`{acquired_madstone:integer, current_madstone:integer, trinket_choices:integer[], enhancement_choices:integer[], selected_trinkets:integer[], selected_enhancements:integer[], times_crafted:integer[]}`**</mark>

| Name       | Type                                                                                         | Description        |
| ---------- | -------------------------------------------------------------------------------------------- | ------------------ |
| **player** | [<mark style="color:purple;">**`CPlayer`**</mark>](/api-v2.0/game-components/core/player.md) | The target player. |

Returns info about player's neutral items

## <sub>IsMuted</sub>

`Player.IsMuted(player):` <mark style="color:purple;">**`boolean`**</mark>

| Name       | Type                                                                                         | Description        |
| ---------- | -------------------------------------------------------------------------------------------- | ------------------ |
| **player** | [<mark style="color:purple;">**`CPlayer`**</mark>](/api-v2.0/game-components/core/player.md) | The target player. |

Returns the player mute status.

## <sub>GetSelectedUnits</sub>

`Player.GetSelectedUnits(player):` [<mark style="color:purple;">**`CNPC[]`**</mark>](/api-v2.0/game-components/core/npc.md)

| Name       | Type                                                                                         | Description        |
| ---------- | -------------------------------------------------------------------------------------------- | ------------------ |
| **player** | [<mark style="color:purple;">**`CPlayer`**</mark>](/api-v2.0/game-components/core/player.md) | The target player. |

Returns table of selected units by player.

## <sub>AddSelectedUnit</sub>

`Player.AddSelectedUnit(player, NPC):` <mark style="color:purple;">**`nil`**</mark>

| Name       | Type                                                                                         | Description        |
| ---------- | -------------------------------------------------------------------------------------------- | ------------------ |
| **player** | [<mark style="color:purple;">**`CPlayer`**</mark>](/api-v2.0/game-components/core/player.md) | The target player. |
| **NPC**    | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md)       | To select.         |

Adds unit to player selection.

## <sub>ClearSelectedUnits</sub>

`Player.ClearSelectedUnits(player):` <mark style="color:purple;">**`nil`**</mark>

| Name       | Type                                                                                         | Description        |
| ---------- | -------------------------------------------------------------------------------------------- | ------------------ |
| **player** | [<mark style="color:purple;">**`CPlayer`**</mark>](/api-v2.0/game-components/core/player.md) | The target player. |

Clears player selection.

## <sub>GetQuickBuyInfo</sub>

`Player.GetQuickBuyInfo(player):` <mark style="color:purple;">**`{mark_for_buy: boolean, buyback_protection: boolean, items: {ability_id: integer, top_level_item: integer, top_level_item_ability_id: integer, purchasable_state: integer, purchasable_accum_state: integer, marked_for_buy: boolean, parity: integer, sticky: boolean, purchase_in_flight: boolean, newly_actionable: boolean}[]}`**</mark> | <mark style="color:purple;">**`nil`**</mark>

| Name       | Type                                                                                         | Description        |
| ---------- | -------------------------------------------------------------------------------------------- | ------------------ |
| **player** | [<mark style="color:purple;">**`CPlayer`**</mark>](/api-v2.0/game-components/core/player.md) | The target player. |

Returns the player's quick-buy state: the mark-for-buy and buyback-protection flags and the\
quick-buy item slots. Returns nil when the player has no hero or no team data.

## <sub>GetCourierControllerInfo</sub>

`Player.GetCourierControllerInfo(player):` <mark style="color:purple;">**`{state:integer, shop:integer}`**</mark> | <mark style="color:purple;">**`nil`**</mark>

| Name       | Type                                                                                         | Description        |
| ---------- | -------------------------------------------------------------------------------------------- | ------------------ |
| **player** | [<mark style="color:purple;">**`CPlayer`**</mark>](/api-v2.0/game-components/core/player.md) | The target player. |

Returns the player's courier controller state, or nil when it is unavailable.

## <sub>GetTotalGold</sub>

`Player.GetTotalGold(player):` <mark style="color:purple;">**`integer`**</mark>

| Name       | Type                                                                                         | Description        |
| ---------- | -------------------------------------------------------------------------------------------- | ------------------ |
| **player** | [<mark style="color:purple;">**`CPlayer`**</mark>](/api-v2.0/game-components/core/player.md) | The target player. |

Returns total gold of player.

## <sub>GetAssignedHero</sub>

`Player.GetAssignedHero(player):` [<mark style="color:purple;">**`CHero`**</mark>](/api-v2.0/game-components/core/hero.md) | <mark style="color:purple;">**`nil`**</mark>

| Name       | Type                                                                                         | Description        |
| ---------- | -------------------------------------------------------------------------------------------- | ------------------ |
| **player** | [<mark style="color:purple;">**`CPlayer`**</mark>](/api-v2.0/game-components/core/player.md) | The target player. |

Returns player's assigned hero.

## <sub>GetQueryUnit</sub>

`Player.GetQueryUnit(player):` [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | <mark style="color:purple;">**`nil`**</mark>

| Name       | Type                                                                                         | Description        |
| ---------- | -------------------------------------------------------------------------------------------- | ------------------ |
| **player** | [<mark style="color:purple;">**`CPlayer`**</mark>](/api-v2.0/game-components/core/player.md) | The target player. |

Returns the unit currently queried by the player.

## <sub>SetQueryUnit</sub>

`Player.SetQueryUnit(unit):` <mark style="color:purple;">**`boolean`**</mark>

| Name     | Type                                                                                   | Description          |
| -------- | -------------------------------------------------------------------------------------- | -------------------- |
| **unit** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | The entity to query. |

Sets the local player's HUD query entity without changing the selection group.

## <sub>GetClickBehaviors</sub>

`Player.GetClickBehaviors():` [<mark style="color:purple;">**`Enum.CLICK_BEHAVIORS`**</mark>](https://uczone.gitbook.io/api-v2.0/game-components/core/pages/VwVljl88Qnl7u9hhqRdw#enum.click_behaviors)

Returns the local player's current click mode, like GameUI.GetClickBehaviors.\
Returns DOTA\_CLICK\_BEHAVIOR\_NONE when there is no local player.

## <sub>GetActiveAbility</sub>

`Player.GetActiveAbility(player):` [<mark style="color:purple;">**`CAbility`**</mark>](/api-v2.0/game-components/core/ability.md) | <mark style="color:purple;">**`nil`**</mark>

| Name       | Type                                                                                         | Description        |
| ---------- | -------------------------------------------------------------------------------------------- | ------------------ |
| **player** | [<mark style="color:purple;">**`CPlayer`**</mark>](/api-v2.0/game-components/core/player.md) | The target player. |

Returns player's active ability.
