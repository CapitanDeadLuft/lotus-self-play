> For the complete documentation index, see [llms.txt](https://uczone.gitbook.io/api-v2.0/llms.txt). Markdown versions of documentation pages are available by appending `.md` to page URLs; this page is available as [Markdown](https://uczone.gitbook.io/api-v2.0/cheats-types-and-callbacks/classes/menu.md).

# Menu

Table to work with Menu.

## <sub>Find</sub>

`Menu.Find(firstTabName, sectionName, secondTabName, thirdTabName, groupTabName, widgetName, attachmentName, widgetInGearName):` [<mark style="color:purple;">**`CMenuSwitch`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/widgets/cmenuswitch.md) | [<mark style="color:purple;">**`CMenuBind`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/widgets/cmenubind.md) | [<mark style="color:purple;">**`CMenuSliderFloat`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/widgets/cmenusliderfloat.md) | [<mark style="color:purple;">**`CMenuSliderInt`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/widgets/cmenusliderint.md) | [<mark style="color:purple;">**`CMenuColorPicker`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/widgets/cmenucolorpicker.md) | [<mark style="color:purple;">**`CMenuComboBox`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/widgets/cmenucombobox.md) | [<mark style="color:purple;">**`CMenuButton`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/widgets/cmenubutton.md) | [<mark style="color:purple;">**`CMenuMultiComboBox`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/widgets/cmenumulticombobox.md) | [<mark style="color:purple;">**`CMenuMultiSelect`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/widgets/cmenumultiselect.md) | [<mark style="color:purple;">**`CMenuInputBox`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/widgets/cmenuinputbox.md) | [<mark style="color:purple;">**`CMenuLabel`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/widgets/cmenulabel.md) | <mark style="color:purple;">**`nil`**</mark>

| Name                 | Type                                            | Description |
| -------------------- | ----------------------------------------------- | ----------- |
| **firstTabName**     | <mark style="color:purple;">**`string`**</mark> |             |
| **sectionName**      | <mark style="color:purple;">**`string`**</mark> |             |
| **secondTabName**    | <mark style="color:purple;">**`string`**</mark> |             |
| **thirdTabName**     | <mark style="color:purple;">**`string`**</mark> |             |
| **groupTabName**     | <mark style="color:purple;">**`string`**</mark> |             |
| **widgetName**       | <mark style="color:purple;">**`string`**</mark> |             |
| **attachmentName**   | <mark style="color:purple;">**`string`**</mark> |             |
| **widgetInGearName** | <mark style="color:purple;">**`string`**</mark> |             |

Returns menu item.

## <sub>Create</sub>

`Menu.Create(firstTabName, sectionName, secondTabName, thirdTabName, groupTabName):` [<mark style="color:purple;">**`CMenuGroup`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/menu/cmenugroup.md)

| Name              | Type                                            | Description |
| ----------------- | ----------------------------------------------- | ----------- |
| **firstTabName**  | <mark style="color:purple;">**`string`**</mark> |             |
| **sectionName**   | <mark style="color:purple;">**`string`**</mark> |             |
| **secondTabName** | <mark style="color:purple;">**`string`**</mark> |             |
| **thirdTabName**  | <mark style="color:purple;">**`string`**</mark> |             |
| **groupTabName**  | <mark style="color:purple;">**`string`**</mark> |             |

Creates tab/section/group. Returns menu item.

## <sub>Style</sub>

`Menu.Style(styleColor):` [<mark style="color:purple;">**`Color`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/color.md)

| Name           | Type                                            | Description |
| -------------- | ----------------------------------------------- | ----------- |
| **styleColor** | <mark style="color:purple;">**`string`**</mark> |             |

Creates tab/section/group. Returns color of specified style var or table of all style colors\
depends on param.

## <sub>Opened</sub>

`Menu.Opened():` <mark style="color:purple;">**`boolean`**</mark>

Returns current menu open state.

## <sub>VisualsIsEnabled</sub>

`Menu.VisualsIsEnabled():` <mark style="color:purple;">**`boolean`**</mark>

Returns current visuals enabled state.

## <sub>Alpha</sub>

`Menu.Alpha():` <mark style="color:purple;">**`number`**</mark>

Returns current menu alpha.

## <sub>Pos</sub>

`Menu.Pos():` [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md)

Returns current menu pos.

## <sub>Size</sub>

`Menu.Size():` [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md)

Returns current menu size.

## <sub>Scale</sub>

`Menu.Scale():` <mark style="color:purple;">**`integer`**</mark>

Returns current menu scale percentage.

## <sub>AnimDuration</sub>

`Menu.AnimDuration():` <mark style="color:purple;">**`number`**</mark>

Returns current menu animation duration.
