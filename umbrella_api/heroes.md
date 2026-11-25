> For the complete documentation index, see [llms.txt](https://uczone.gitbook.io/api-v2.0/llms.txt). Markdown versions of documentation pages are available by appending `.md` to page URLs; this page is available as [Markdown](https://uczone.gitbook.io/api-v2.0/game-components/lists/heroes.md).

# Heroes

Table to work with hero list.

## <sub>Count</sub>

`Heroes.Count():` <mark style="color:purple;">**`integer`**</mark>

Return size of hero list.

## <sub>Get</sub>

`Heroes.Get(index):` [<mark style="color:purple;">**`CHero`**</mark>](/api-v2.0/game-components/core/hero.md) | <mark style="color:purple;">**`nil`**</mark>

| Name      | Type                                             | Description                  |
| --------- | ------------------------------------------------ | ---------------------------- |
| **index** | <mark style="color:purple;">**`integer`**</mark> | Index of hero in cheat list. |

Return hero by index in cheat list. Not the same as in-game index.

## <sub>GetAll</sub>

`Heroes.GetAll():` [<mark style="color:purple;">**`CHero[]`**</mark>](/api-v2.0/game-components/core/hero.md)

Return all heroes in cheat list.

## <sub>Contains</sub>

`Heroes.Contains(hero):` <mark style="color:purple;">**`boolean`**</mark>

| Name     | Type                                                                                     | Description    |
| -------- | ---------------------------------------------------------------------------------------- | -------------- |
| **hero** | [<mark style="color:purple;">**`CHero`**</mark>](/api-v2.0/game-components/core/hero.md) | Hero to check. |

Check hero in cheat list.

## <sub>InRadius</sub>

`Heroes.InRadius(pos, radius, teamNum, teamType, [omitIllusions], [omitDormant]):` [<mark style="color:purple;">**`CHero[]`**</mark>](/api-v2.0/game-components/core/hero.md)

| Name                                                                | Type                                                                                                                                                        | Description                                                             |
| ------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| **pos**                                                             | [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md)                                              | Position to check.                                                      |
| **radius**                                                          | <mark style="color:purple;">**`number`**</mark>                                                                                                             | Radius to check.                                                        |
| **teamNum**                                                         | [<mark style="color:purple;">**`Enum.TeamNum`**</mark>](https://uczone.gitbook.io/api-v2.0/game-components/lists/pages/VwVljl88Qnl7u9hhqRdw#enum.teamnum)   | Team number to check.                                                   |
| **teamType**                                                        | [<mark style="color:purple;">**`Enum.TeamType`**</mark>](https://uczone.gitbook.io/api-v2.0/game-components/lists/pages/VwVljl88Qnl7u9hhqRdw#enum.teamtype) | Team type to filter by. Relative to teamNum param.                      |
| **omitIllusions&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`boolean`**</mark>                                                                                                            | `true` if you want to get table without illusions `(default: false)`    |
| **omitDormant&#x20;**<mark style="color:orange;">**`[?]`**</mark>   | <mark style="color:purple;">**`boolean`**</mark>                                                                                                            | `true` if you want to get table without dormant units `(default: true)` |

Return all heroes in radius.

## <sub>GetLocal</sub>

`Heroes.GetLocal():` [<mark style="color:purple;">**`CHero`**</mark>](/api-v2.0/game-components/core/hero.md) | <mark style="color:purple;">**`nil`**</mark>

Return local hero.
