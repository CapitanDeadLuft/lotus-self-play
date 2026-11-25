> For the complete documentation index, see [llms.txt](https://uczone.gitbook.io/api-v2.0/llms.txt). Markdown versions of documentation pages are available by appending `.md` to page URLs; this page is available as [Markdown](https://uczone.gitbook.io/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md).

# Vector

Vector metatable

### Fields

| Name  | Type                                            | Description |
| ----- | ----------------------------------------------- | ----------- |
| **x** | <mark style="color:purple;">**`number`**</mark> |             |
| **y** | <mark style="color:purple;">**`number`**</mark> |             |
| **z** | <mark style="color:purple;">**`number`**</mark> |             |

## <sub>AddInPlace</sub>

`:AddInPlace(other):` [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md)

| Name      | Type                                                                                                                                                              | Description |
| --------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------- |
| **other** | [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md) \| <mark style="color:purple;">**`number`**</mark> |             |

Adds other to this vector in-place. Returns self for chaining.

## <sub>SubInPlace</sub>

`:SubInPlace(other):` [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md)

| Name      | Type                                                                                                                                                              | Description |
| --------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------- |
| **other** | [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md) \| <mark style="color:purple;">**`number`**</mark> |             |

Subtracts other from this vector in-place. Returns self for chaining.

## <sub>MulInPlace</sub>

`:MulInPlace(other):` [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md)

| Name      | Type                                                                                                                                                              | Description |
| --------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------- |
| **other** | [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md) \| <mark style="color:purple;">**`number`**</mark> |             |

Multiplies this vector by other in-place. Returns self for chaining.

## <sub>DivInPlace</sub>

`:DivInPlace(other):` [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md)

| Name      | Type                                                                                                                                                              | Description |
| --------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------- |
| **other** | [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md) \| <mark style="color:purple;">**`number`**</mark> |             |

Divides this vector by other in-place. Returns self for chaining.

## <sub>Set</sub>

`:Set(x, y, z):` [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md)

| Name  | Type                                            | Description |
| ----- | ----------------------------------------------- | ----------- |
| **x** | <mark style="color:purple;">**`number`**</mark> |             |
| **y** | <mark style="color:purple;">**`number`**</mark> |             |
| **z** | <mark style="color:purple;">**`number`**</mark> |             |

Sets x, y, z components. Returns self for chaining.

## <sub>SetGroundZ</sub>

`:SetGroundZ():` [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md)

Sets .z = World.GetGroundZ(.x, .y). Returns self for chaining.

## <sub>LerpInPlace</sub>

`:LerpInPlace(b, t):` [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md)

| Name  | Type                                                                                                           | Description |
| ----- | -------------------------------------------------------------------------------------------------------------- | ----------- |
| **b** | [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md) |             |
| **t** | <mark style="color:purple;">**`number`**</mark>                                                                |             |

Linearly interpolates this vector towards other in-place. Returns self for chaining.

## <sub>CopyFrom</sub>

`:CopyFrom(other):` [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md)

| Name      | Type                                                                                                           | Description |
| --------- | -------------------------------------------------------------------------------------------------------------- | ----------- |
| **other** | [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md) |             |

Copies values from another vector without allocating. Returns self for chaining.

## <sub>Clone</sub>

`:Clone():` [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md)

Creates a new vector with the same values as the original.

## <sub>DirectionTo</sub>

`:DirectionTo(other, [dist]):` [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md)

| Name                                                       | Type                                                                                                           | Description                            |
| ---------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- | -------------------------------------- |
| **other**                                                  | [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md) |                                        |
| **dist&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`number`**</mark>                                                                | optional scale factor `(default: 1.0)` |

Returns a normalized direction vector from this point to other, optionally scaled by distance.\
Equivalent to `(other - self):Normalized():Scaled(dist)` but with a single allocation.

## <sub>AngleBetween2D</sub>

`:AngleBetween2D(middle, point3):` <mark style="color:purple;">**`number`**</mark>

| Name       | Type                                                                                                           | Description                                         |
| ---------- | -------------------------------------------------------------------------------------------------------------- | --------------------------------------------------- |
| **middle** | [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md) | the vertex point (this is point1, middle is point2) |
| **point3** | [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md) |                                                     |

Returns the angle in radians between two 2D vectors formed by three points.\
Equivalent to the angle at point2 in the triangle point1-point2-point3, ignoring Z.

## <sub>ClosestToPoint</sub>

`:ClosestToPoint(entities):` [<mark style="color:purple;">**`CEntity`**</mark>](/api-v2.0/game-components/core/entity.md) | <mark style="color:purple;">**`nil`**</mark>, <mark style="color:purple;">**`number`**</mark>

| Name         | Type                                                                                           | Description |
| ------------ | ---------------------------------------------------------------------------------------------- | ----------- |
| **entities** | [<mark style="color:purple;">**`CEntity[]`**</mark>](/api-v2.0/game-components/core/entity.md) |             |

Finds the closest entity to this position from a table of entities.\
Returns the entity and the distance. Uses Distance2D.

## <sub>DistanceSqr2D</sub>

`:DistanceSqr2D(other):` <mark style="color:purple;">**`number`**</mark>

| Name      | Type                                                                                                           | Description |
| --------- | -------------------------------------------------------------------------------------------------------------- | ----------- |
| **other** | [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md) |             |

Returns the squared 2D distance to another vector. Cheaper than Distance2D (no sqrt).\
Use for distance comparisons: `a:DistanceSqr2D(b) < range * range`.

## <sub>IsInRange2D</sub>

`:IsInRange2D(other, range):` <mark style="color:purple;">**`boolean`**</mark>

| Name      | Type                                                                                                           | Description |
| --------- | -------------------------------------------------------------------------------------------------------------- | ----------- |
| **other** | [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md) |             |
| **range** | <mark style="color:purple;">**`number`**</mark>                                                                |             |

Returns true if this position is within range of another position (2D, no sqrt).

## <sub>Extend2D</sub>

`:Extend2D(target, distance):` [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md)

| Name         | Type                                                                                                           | Description |
| ------------ | -------------------------------------------------------------------------------------------------------------- | ----------- |
| **target**   | [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md) |             |
| **distance** | <mark style="color:purple;">**`number`**</mark>                                                                |             |

Extends this position towards target by distance (2D, ignores Z). Single allocation.\
Equivalent to `self + (target - self):Normalized() * distance` without intermediate vectors.

## <sub>Perpendicular2D</sub>

`:Perpendicular2D():` [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md)

Returns a 2D perpendicular vector (-y, x, z). Zero allocation if called in-place.

## <sub>Negate</sub>

`:Negate():` [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md)

Negates this vector in-place (-x, -y, -z). Returns self for chaining.

## <sub>IsZero</sub>

`:IsZero([tolerance]):` <mark style="color:purple;">**`boolean`**</mark>

| Name                                                            | Type                                            | Description       |
| --------------------------------------------------------------- | ----------------------------------------------- | ----------------- |
| **tolerance&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`number`**</mark> | `(default: 0.01)` |

Returns true if all components are near zero within tolerance.

## <sub>Extrapolate</sub>

`:Extrapolate(direction, scalar):` [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md)

| Name          | Type                                                                                                           | Description |
| ------------- | -------------------------------------------------------------------------------------------------------------- | ----------- |
| **direction** | [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md) |             |
| **scalar**    | <mark style="color:purple;">**`number`**</mark>                                                                |             |

Returns `self + direction * scalar`. Single allocation.\
Useful for position extrapolation: `start:Extrapolate(velocity, dt * speed)`.

## <sub>Vector</sub>

`Vector([x], [y], [z]):` [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md)

| Name                                                    | Type                                            | Description      |
| ------------------------------------------------------- | ----------------------------------------------- | ---------------- |
| **x&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`number`**</mark> | `(default: 0.0)` |
| **y&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`number`**</mark> | `(default: 0.0)` |
| **z&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`number`**</mark> | `(default: 0.0)` |

Create a new Vector.

## <sub>\_\_tostring</sub>

`:__tostring():` <mark style="color:purple;">**`string`**</mark>

## <sub>\_\_add</sub>

{% hint style="info" %}
Overload for operator +
{% endhint %}

`:__add(other):` [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md)

| Name      | Type                                                                                                                                                                                                                                                                            | Description |
| --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------- |
| **other** | [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md) \| [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md) \| <mark style="color:purple;">**`number`**</mark> |             |

## <sub>\_\_sub</sub>

{% hint style="info" %}
Overload for operator -
{% endhint %}

`:__sub(other):` [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md)

| Name      | Type                                                                                                                                                                                                                                                                            | Description |
| --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------- |
| **other** | [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md) \| [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md) \| <mark style="color:purple;">**`number`**</mark> |             |

## <sub>\_\_div</sub>

{% hint style="info" %}
Overload for operator /
{% endhint %}

`:__div(other):` [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md)

| Name      | Type                                                                                                                                                                                                                                                                            | Description |
| --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------- |
| **other** | [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md) \| [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md) \| <mark style="color:purple;">**`number`**</mark> |             |

## <sub>\_\_mul</sub>

{% hint style="info" %}
Overload for operator \*
{% endhint %}

`:__mul(other):` [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md)

| Name      | Type                                                                                                                                                                                                                                                                            | Description |
| --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------- |
| **other** | [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md) \| [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md) \| <mark style="color:purple;">**`number`**</mark> |             |

## <sub>\_\_eq</sub>

{% hint style="info" %}
Overload for operator ==
{% endhint %}

\`:\_\_eq(other):\` <mark style="color:purple;">\*\*\`boolean\`\*\*</mark>

| Name      | Type                                                                                                           | Description |
| --------- | -------------------------------------------------------------------------------------------------------------- | ----------- |
| **other** | [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md) |             |

## <sub>Distance</sub>

`:Distance(other):` <mark style="color:purple;">**`number`**</mark>

| Name      | Type                                                                                                           | Description |
| --------- | -------------------------------------------------------------------------------------------------------------- | ----------- |
| **other** | [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md) |             |

Computes the distance from this vector to other.

## <sub>Distance2D</sub>

`:Distance2D(other):` <mark style="color:purple;">**`number`**</mark>

| Name      | Type                                                                                                           | Description |
| --------- | -------------------------------------------------------------------------------------------------------------- | ----------- |
| **other** | [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md) |             |

Computes the distance from this vector to other ignoring Z axis.

## <sub>Normalized</sub>

`:Normalized():` [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md)

Returns this vector with a length of 1.\
When normalized, a vector keeps the same direction but its length is 1.0.\
Note that the current vector is unchanged and a new normalized vector is returned. If you want to normalize the current vector, use `Vector:Normalize` function.

## <sub>Normalize</sub>

`:Normalize():` <mark style="color:purple;">**`nil`**</mark>

Makes this vector have a length of 1.\
When normalized, a vector keeps the same direction but its length is 1.0.\
Note that this function will change the current vector. If you want to keep the current vector unchanged, use `Vector:Normalized` function.

## <sub>Dot</sub>

`:Dot(vector):` <mark style="color:purple;">**`number`**</mark>

| Name       | Type                                                                                                           | Description |
| ---------- | -------------------------------------------------------------------------------------------------------------- | ----------- |
| **vector** | [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md) |             |

Dot Product of two vectors.\
The dot product is a float value equal to the magnitudes of the two vectors multiplied together and then multiplied by the cosine of the angle between them.\
For normalized vectors Dot returns 1 if they point in exactly the same direction, -1 if they point in completely opposite directions and zero if the vectors are perpendicular.\
\
[More](https://medium.com/@r.w.overdijk/unity-vector3-dot-what-11feb258052e)

## <sub>Dot2D</sub>

`:Dot2D(vector):` <mark style="color:purple;">**`number`**</mark>

| Name       | Type                                                                                                           | Description |
| ---------- | -------------------------------------------------------------------------------------------------------------- | ----------- |
| **vector** | [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md) |             |

Dot Product of two vectors ignoring Z axis.

## <sub>Scaled</sub>

`:Scaled(scale):` [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md)

| Name      | Type                                            | Description |
| --------- | ----------------------------------------------- | ----------- |
| **scale** | <mark style="color:purple;">**`number`**</mark> |             |

Returns this vector multiplied by the given number. The same as `Vector * number`.

## <sub>Scale</sub>

`:Scale(scale):` <mark style="color:purple;">**`nil`**</mark>

| Name      | Type                                            | Description |
| --------- | ----------------------------------------------- | ----------- |
| **scale** | <mark style="color:purple;">**`number`**</mark> |             |

Multiplies this vector by the given number. The same as `Vector = Vector * number`.

## <sub>Length</sub>

`:Length():` <mark style="color:purple;">**`number`**</mark>

Returns the length of this vector.\
The length of the vector is `math.sqrt(x*x+y*y+z*z)`.\
If you only need to compare length of some vectors, you can compare squared magnitudes of them using LengthSqr (computing squared length is faster).

## <sub>LengthSqr</sub>

`:LengthSqr():` <mark style="color:purple;">**`number`**</mark>

Returns the squared length of this vector.\
This method is faster than Length because it avoids computing a square root. Use this method if you need to compare vectors.

## <sub>Length2D</sub>

`:Length2D():` <mark style="color:purple;">**`number`**</mark>

Returns the length of this vector ignoring Z axis.

## <sub>Length2DSqr</sub>

`:Length2DSqr():` <mark style="color:purple;">**`number`**</mark>

Returns the squared length of this vector ignoring Z axis.\
This method is faster than Length2D because it avoids computing a square root. Use this method if you need to compare vectors.

## <sub>Rotated</sub>

`:Rotated(angle):` [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md)

| Name      | Type                                                                                                                                                            | Description |
| --------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------- |
| **angle** | <mark style="color:purple;">**`number`**</mark> \| [<mark style="color:purple;">**`Angle`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/angle.md) |             |

Returns the new vector rotated counterclockwise by the given angle in the XY-plane, leaving the Z-axis unaffected.

## <sub>Rotate</sub>

`:Rotate(angle):` <mark style="color:purple;">**`nil`**</mark>

| Name      | Type                                                                                                                                                            | Description |
| --------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------- |
| **angle** | <mark style="color:purple;">**`number`**</mark> \| [<mark style="color:purple;">**`Angle`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/angle.md) |             |

Rotates this vector counterclockwise by the given angle in the XY-plane, leaving the Z-axis unaffected.

## <sub>Lerp</sub>

`:Lerp(b, t):` [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md)

| Name  | Type                                                                                                           | Description                                |
| ----- | -------------------------------------------------------------------------------------------------------------- | ------------------------------------------ |
| **b** | [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md) | end value, returned when t = 1             |
| **t** | <mark style="color:purple;">**`number`**</mark>                                                                | value used to interpolate between a and b. |

Returns linearly interpolated vector between two vectors.\
The value returned equals **a + (b - a) \* t** (which can also be written **a \* (1-t) + b\*t**).\
When `t = 0`, **a:Lerp(b, t)** returns `a`.\
When `t = 1`, **a:Lerp(b, t)** returns `b`.\
When `t = 0.5`, **a:Lerp(b, t)** returns the point midway between `a` and `b`.

## <sub>Cross</sub>

`:Cross(vector):` [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md)

| Name       | Type                                                                                                           | Description |
| ---------- | -------------------------------------------------------------------------------------------------------------- | ----------- |
| **vector** | [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md) |             |

Returns cross product of two vectors.\
\
[More](https://docs.unity3d.com/ScriptReference/Vector3.Cross.html)\
[Visualization](https://www.youtube.com/watch?v=kz92vvioeng)

## <sub>MoveForward</sub>

`:MoveForward(angle, distance):` [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md)

| Name         | Type                                                                                                         | Description      |
| ------------ | ------------------------------------------------------------------------------------------------------------ | ---------------- |
| **angle**    | [<mark style="color:purple;">**`Angle`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/angle.md) |                  |
| **distance** | <mark style="color:purple;">**`number`**</mark>                                                              | distance to move |

Moves vector forward by a specified distance in the direction defined by a given Angle.

#### Example

```lua
-- entity position moved forward by 300
local pos = Entity.GetAbsOrigin(entity):MoveForward(Entity.GetRotation(entity), 300);
```

## <sub>ToAngle</sub>

`:ToAngle():` [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md)

Converts Vector to Angle. See\
<https://github.com/ValveSoftware/source-sdk-2013/blob/0565403b153dfcde602f6f58d8f4d13483696a13/src/mathlib/mathlib\\_base.cpp#L535>

## <sub>ToScreen</sub>

`:ToScreen():` [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md), <mark style="color:purple;">**`boolean`**</mark>

Converts Vector to screen coordinate

## <sub>IsVisible</sub>

`:IsVisible():` <mark style="color:purple;">**`boolean`**</mark>

Returns `true` if position visible on screen.\
To get screen position use :ToScreen method

## <sub>Get</sub>

`:Get():` <mark style="color:purple;">**`number`**</mark>, <mark style="color:purple;">**`number`**</mark>, <mark style="color:purple;">**`number`**</mark>

Returns x, y and z of this vector.

## <sub>GetX</sub>

`:GetX():` <mark style="color:purple;">**`number`**</mark>

Returns x of this vector. The same as Vector.x.

## <sub>GetY</sub>

`:GetY():` <mark style="color:purple;">**`number`**</mark>

Returns y of this vector. The same as Vector.y.

## <sub>GetZ</sub>

`:GetZ():` <mark style="color:purple;">**`number`**</mark>

Returns z of this vector. The same as Vector.z.

## <sub>SetX</sub>

`:SetX(value):` <mark style="color:purple;">**`nil`**</mark>

| Name      | Type                                            | Description |
| --------- | ----------------------------------------------- | ----------- |
| **value** | <mark style="color:purple;">**`number`**</mark> |             |

Sets x. The same as Vector.x = value.

## <sub>SetY</sub>

`:SetY(value):` <mark style="color:purple;">**`nil`**</mark>

| Name      | Type                                            | Description |
| --------- | ----------------------------------------------- | ----------- |
| **value** | <mark style="color:purple;">**`number`**</mark> |             |

Sets y. The same as Vector.y = value.

## <sub>SetZ</sub>

`:SetZ(value):` <mark style="color:purple;">**`nil`**</mark>

| Name      | Type                                            | Description |
| --------- | ----------------------------------------------- | ----------- |
| **value** | <mark style="color:purple;">**`number`**</mark> |             |

Sets z. The same as Vector.z = value.
