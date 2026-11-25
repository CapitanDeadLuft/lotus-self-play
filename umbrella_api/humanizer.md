> For the complete documentation index, see [llms.txt](https://uczone.gitbook.io/api-v2.0/llms.txt). Markdown versions of documentation pages are available by appending `.md` to page URLs; this page is available as [Markdown](https://uczone.gitbook.io/api-v2.0/game-components/configuration-and-utilities/humanizer.md).

# Humanizer

Table to work with humanizer.

## <sub>IsInServerCameraBounds</sub>

`Humanizer.IsInServerCameraBounds(pos):` <mark style="color:purple;">**`boolean`**</mark>

| Name    | Type                                                                                                           | Description       |
| ------- | -------------------------------------------------------------------------------------------------------------- | ----------------- |
| **pos** | [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md) | position to check |

Returns `true` if the world position is in server camera bounds.

## <sub>GetServerCameraPos</sub>

`Humanizer.GetServerCameraPos():` [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md)

Returns server camera position.

## <sub>GetClientCameraPos</sub>

`Humanizer.GetClientCameraPos():` [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md)

Returns client camera position.

## <sub>GetServerCursorPos</sub>

`Humanizer.GetServerCursorPos():` [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md)

Returns the server cursor position.

## <sub>GetOrderQueue</sub>

`Humanizer.GetOrderQueue():` <mark style="color:purple;">**`{player: CPlayer, orderType: Enum.UnitOrder, targetIndex: integer, position: Vector, abilityIndex: integer, orderIssuer: Enum.PlayerOrderIssuer, unit: CNPC`**</mark> | <mark style="color:purple;">**`nil, orderQueueBehavior: integer, showEffects: boolean, triggerCallBack: boolean, isByMiniMap: boolean, addTime: number }[]`**</mark> | <mark style="color:purple;">**`nil`**</mark>

Returns the current humanizer order queue, or nil when no order is queued.

## <sub>IsSafeTarget</sub>

`Humanizer.IsSafeTarget(entity):` <mark style="color:purple;">**`boolean`**</mark>

| Name       | Type                                                                                         | Description |
| ---------- | -------------------------------------------------------------------------------------------- | ----------- |
| **entity** | [<mark style="color:purple;">**`CEntity`**</mark>](/api-v2.0/game-components/core/entity.md) |             |

Returns information about the current humanizer order queue.

## <sub>IsSafeToCastOrder</sub>

`Humanizer.IsSafeToCastOrder():` <mark style="color:purple;">**`boolean`**</mark>

Checks whether casting the next order will trigger the spam filter.

## <sub>OrdersCanBeCastedThisTick</sub>

`Humanizer.OrdersCanBeCastedThisTick():` <mark style="color:purple;">**`integer`**</mark>

Returns the number of orders that can be casted during the current tick without triggering the spam filter.

## <sub>ForceUserOrderByMinimap</sub>

`Humanizer.ForceUserOrderByMinimap():` <mark style="color:purple;">**`nil`**</mark>

Forces current user order by minimap. Must be called in OnPrepareUnitOrder
