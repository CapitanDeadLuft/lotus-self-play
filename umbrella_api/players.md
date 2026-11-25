> For the complete documentation index, see [llms.txt](https://uczone.gitbook.io/api-v2.0/llms.txt). Markdown versions of documentation pages are available by appending `.md` to page URLs; this page is available as [Markdown](https://uczone.gitbook.io/api-v2.0/game-components/lists/players.md).

# Players

Table to work with player list.

## <sub>Count</sub>

`Players.Count():` <mark style="color:purple;">**`integer`**</mark>

Return size of player list.

## <sub>Get</sub>

`Players.Get(index):` [<mark style="color:purple;">**`CPlayer`**</mark>](/api-v2.0/game-components/core/player.md) | <mark style="color:purple;">**`nil`**</mark>

| Name      | Type                                             | Description                    |
| --------- | ------------------------------------------------ | ------------------------------ |
| **index** | <mark style="color:purple;">**`integer`**</mark> | Index of player in cheat list. |

Return player by index in cheat list. Not the same as in-game index.

## <sub>GetAll</sub>

`Players.GetAll():` [<mark style="color:purple;">**`CPlayer[]`**</mark>](/api-v2.0/game-components/core/player.md)

Return all players in cheat list.

## <sub>Contains</sub>

`Players.Contains(player):` <mark style="color:purple;">**`boolean`**</mark>

| Name       | Type                                                                                         | Description      |
| ---------- | -------------------------------------------------------------------------------------------- | ---------------- |
| **player** | [<mark style="color:purple;">**`CPlayer`**</mark>](/api-v2.0/game-components/core/player.md) | Player to check. |

Check player in cheat list.

## <sub>GetLocal</sub>

`Players.GetLocal():` [<mark style="color:purple;">**`CPlayer`**</mark>](/api-v2.0/game-components/core/player.md) | <mark style="color:purple;">**`nil`**</mark>

Return local player.
