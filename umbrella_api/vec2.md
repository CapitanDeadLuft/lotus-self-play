> For the complete documentation index, see [llms.txt](https://uczone.gitbook.io/api-v2.0/llms.txt). Markdown versions of documentation pages are available by appending `.md` to page URLs; this page is available as [Markdown](https://uczone.gitbook.io/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md).

# Vec2

Vec2 metatable

### Fields

| Name  | Type                                            | Description |
| ----- | ----------------------------------------------- | ----------- |
| **x** | <mark style="color:purple;">**`number`**</mark> |             |
| **y** | <mark style="color:purple;">**`number`**</mark> |             |

## <sub>AddInPlace</sub>

`:AddInPlace(other):` [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md)

| Name      | Type                                                                                                                                                          | Description |
| --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------- |
| **other** | [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md) \| <mark style="color:purple;">**`number`**</mark> |             |

Adds other to this Vec2 in-place. Returns self for chaining.

## <sub>SubInPlace</sub>

`:SubInPlace(other):` [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md)

| Name      | Type                                                                                                                                                          | Description |
| --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------- |
| **other** | [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md) \| <mark style="color:purple;">**`number`**</mark> |             |

Subtracts other from this Vec2 in-place. Returns self for chaining.

## <sub>MulInPlace</sub>

`:MulInPlace(other):` [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md)

| Name      | Type                                                                                                                                                          | Description |
| --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------- |
| **other** | [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md) \| <mark style="color:purple;">**`number`**</mark> |             |

Multiplies this Vec2 by other in-place. Returns self for chaining.

## <sub>DivInPlace</sub>

`:DivInPlace(other):` [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md)

| Name      | Type                                                                                                                                                          | Description |
| --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------- |
| **other** | [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md) \| <mark style="color:purple;">**`number`**</mark> |             |

Divides this Vec2 by other in-place. Returns self for chaining.

## <sub>CopyFrom</sub>

`:CopyFrom(other):` [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md)

| Name      | Type                                                                                                       | Description |
| --------- | ---------------------------------------------------------------------------------------------------------- | ----------- |
| **other** | [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md) |             |

Copies values from another Vec2 without allocating. Returns self for chaining.

## <sub>Clone</sub>

`:Clone():` [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md)

Creates a new Vec2 with the same values as the original.

## <sub>Set</sub>

`:Set(x, y):` [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md)

| Name  | Type                                            | Description |
| ----- | ----------------------------------------------- | ----------- |
| **x** | <mark style="color:purple;">**`number`**</mark> |             |
| **y** | <mark style="color:purple;">**`number`**</mark> |             |

Sets x, y components. Returns self for chaining.

## <sub>IsZero</sub>

`:IsZero([tolerance]):` <mark style="color:purple;">**`boolean`**</mark>

| Name                                                            | Type                                            | Description       |
| --------------------------------------------------------------- | ----------------------------------------------- | ----------------- |
| **tolerance&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`number`**</mark> | `(default: 0.01)` |

Returns true if all components are near zero within tolerance.

## <sub>Vec2</sub>

`Vec2(x, y):` [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md)

| Name  | Type                                            | Description |
| ----- | ----------------------------------------------- | ----------- |
| **x** | <mark style="color:purple;">**`number`**</mark> |             |
| **y** | <mark style="color:purple;">**`number`**</mark> |             |

Create a new Vec2.

## <sub>Vec2</sub>

`Vec2():` [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md)

Create a new Vec2(0,0).

## <sub>\_\_tostring</sub>

`:__tostring():` <mark style="color:purple;">**`string`**</mark>

## <sub>\_\_add</sub>

{% hint style="info" %}
Overload for operator +
{% endhint %}

`:__add(other):` [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md)

| Name      | Type                                                                                                                                                          | Description |
| --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------- |
| **other** | [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md) \| <mark style="color:purple;">**`number`**</mark> |             |

## <sub>\_\_sub</sub>

{% hint style="info" %}
Overload for operator -
{% endhint %}

`:__sub(other):` [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md)

| Name      | Type                                                                                                                                                          | Description |
| --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------- |
| **other** | [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md) \| <mark style="color:purple;">**`number`**</mark> |             |

## <sub>\_\_div</sub>

{% hint style="info" %}
Overload for operator /
{% endhint %}

`:__div(other):` [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md)

| Name      | Type                                                                                                                                                          | Description |
| --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------- |
| **other** | [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md) \| <mark style="color:purple;">**`number`**</mark> |             |

## <sub>\_\_mul</sub>

{% hint style="info" %}
Overload for operator \*
{% endhint %}

`:__mul(other):` [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md)

| Name      | Type                                                                                                                                                          | Description |
| --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------- |
| **other** | [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md) \| <mark style="color:purple;">**`number`**</mark> |             |

## <sub>\_\_eq</sub>

{% hint style="info" %}
Overload for operator ==
{% endhint %}

\`:\_\_eq(other):\` <mark style="color:purple;">\*\*\`boolean\`\*\*</mark>

| Name      | Type                                                                                                       | Description |
| --------- | ---------------------------------------------------------------------------------------------------------- | ----------- |
| **other** | [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md) |             |

## <sub>Length</sub>

`:Length():` <mark style="color:purple;">**`number`**</mark>

Returns the length of the vector.

## <sub>Get</sub>

`:Get():` <mark style="color:purple;">**`number`**</mark>, <mark style="color:purple;">**`number`**</mark>

Returns x, y of this vector.

## <sub>GetX</sub>

`:GetX():` <mark style="color:purple;">**`number`**</mark>

Returns x of this vector. The same as Vec2.x.

## <sub>GetY</sub>

`:GetY():` <mark style="color:purple;">**`number`**</mark>

Returns y of this vector. The same as Vec2.y.

## <sub>SetX</sub>

`:SetX(value):` <mark style="color:purple;">**`nil`**</mark>

| Name      | Type                                            | Description |
| --------- | ----------------------------------------------- | ----------- |
| **value** | <mark style="color:purple;">**`number`**</mark> |             |

Sets x. The same as Vec2.x = value.

## <sub>SetY</sub>

`:SetY(value):` <mark style="color:purple;">**`nil`**</mark>

| Name      | Type                                            | Description |
| --------- | ----------------------------------------------- | ----------- |
| **value** | <mark style="color:purple;">**`number`**</mark> |             |

Sets y. The same as Vec2.y = value.
