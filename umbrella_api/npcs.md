> For the complete documentation index, see [llms.txt](https://uczone.gitbook.io/api-v2.0/llms.txt). Markdown versions of documentation pages are available by appending `.md` to page URLs; this page is available as [Markdown](https://uczone.gitbook.io/api-v2.0/game-components/lists/npcs.md).

# NPCs

Table to work with NPC list.

## <sub>Count</sub>

`NPCs.Count():` <mark style="color:purple;">**`integer`**</mark>

Return size of NPC list.

## <sub>Get</sub>

`NPCs.Get(index):` [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | <mark style="color:purple;">**`nil`**</mark>

| Name      | Type                                             | Description                 |
| --------- | ------------------------------------------------ | --------------------------- |
| **index** | <mark style="color:purple;">**`integer`**</mark> | Index of NPC in cheat list. |

Return NPC by index in cheat list. Not the same as in-game index.

## <sub>GetAll</sub>

`NPCs.GetAll([filter]):` [<mark style="color:purple;">**`CNPC[]`**</mark>](/api-v2.0/game-components/core/npc.md)

| Name                                                         | Type                                                                                                                                                                                                                                     | Description      |
| ------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------- |
| **filter&#x20;**<mark style="color:orange;">**`[?]`**</mark> | [<mark style="color:purple;">**`Enum.UnitTypeFlags`**</mark>](https://uczone.gitbook.io/api-v2.0/game-components/lists/pages/VwVljl88Qnl7u9hhqRdw#enum.unittypeflags) \| <mark style="color:purple;">**`fun(npc: CNPC):boolean`**</mark> | `(default: nil)` |

Return all NPCs in cheat list. Can be filtered by unit type or custom function.\
Unit type filter is a much faster than custom function and can be or'ed to filter multiple types.

#### Example

```lua
-- filter function to get all structures except towers
for _, v in pairs(NPCs.GetAll(function (npc)
     return NPC.IsStructure(npc) and not NPC.IsTower(npc);
end)) do
     print(NPC.GetUnitName(v))
end

-- get all towers and heroes (x5 times faster than filter function)
for _, v in pairs(NPCs.GetAll(Enum.UnitTypeFlags.TYPE_TOWER | Enum.UnitTypeFlags.TYPE_HERO)) do
		print(NPC.GetUnitName(v))
end
```

## <sub>GetInScreen</sub>

`NPCs.GetInScreen([filter], [skipDormant]):` <mark style="color:purple;">**`{entity:CNPC, position:Vec2}[]`**</mark>

| Name                                                              | Type                                                                                                                                                                                                                  | Description                                                             |
| ----------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| **filter&#x20;**<mark style="color:orange;">**`[?]`**</mark>      | [<mark style="color:purple;">**`Enum.UnitTypeFlags`**</mark>](https://uczone.gitbook.io/api-v2.0/game-components/lists/pages/VwVljl88Qnl7u9hhqRdw#enum.unittypeflags) \| <mark style="color:purple;">**`nil`**</mark> | `(default: nil)`                                                        |
| **skipDormant&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`boolean`**</mark>                                                                                                                                                                      | `true` if you want to get table without dormant units `(default: true)` |

Return all NPCs in cheat list that visible on your screen. Can be filtered by unit type argument.

## <sub>InRadius</sub>

`NPCs.InRadius(pos, radius, teamNum, teamType, [omitIllusions], [omitDormant]):` [<mark style="color:purple;">**`CNPC[]`**</mark>](/api-v2.0/game-components/core/npc.md)

| Name                                                                | Type                                                                                                                                                        | Description                                                             |
| ------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| **pos**                                                             | [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md)                                              | Position to check.                                                      |
| **radius**                                                          | <mark style="color:purple;">**`number`**</mark>                                                                                                             | Radius to check.                                                        |
| **teamNum**                                                         | [<mark style="color:purple;">**`Enum.TeamNum`**</mark>](https://uczone.gitbook.io/api-v2.0/game-components/lists/pages/VwVljl88Qnl7u9hhqRdw#enum.teamnum)   | Team number to check.                                                   |
| **teamType**                                                        | [<mark style="color:purple;">**`Enum.TeamType`**</mark>](https://uczone.gitbook.io/api-v2.0/game-components/lists/pages/VwVljl88Qnl7u9hhqRdw#enum.teamtype) | Team type to filter by. Relative to teamNum param.                      |
| **omitIllusions&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`boolean`**</mark>                                                                                                            | `true` if you want to get table without illusions `(default: false)`    |
| **omitDormant&#x20;**<mark style="color:orange;">**`[?]`**</mark>   | <mark style="color:purple;">**`boolean`**</mark>                                                                                                            | `true` if you want to get table without dormant units `(default: true)` |

Return all NPCs in radius.

## <sub>Contains</sub>

`NPCs.Contains(npc):` <mark style="color:purple;">**`boolean`**</mark>

| Name    | Type                                                                                   | Description   |
| ------- | -------------------------------------------------------------------------------------- | ------------- |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | NPC to check. |

Check NPC in cheat list.
