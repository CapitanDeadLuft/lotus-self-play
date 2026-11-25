> For the complete documentation index, see [llms.txt](https://uczone.gitbook.io/api-v2.0/llms.txt). Markdown versions of documentation pages are available by appending `.md` to page URLs; this page is available as [Markdown](https://uczone.gitbook.io/api-v2.0/game-components/rendering-and-visuals/renderv2.md).

# Render

Table to work with render v2.

## <sub>FilledRect</sub>

`Render.FilledRect(start, end_, color, [rounding], [flags]):` <mark style="color:purple;">**`nil`**</mark>

| Name                                                           | Type                                                                                                                                                                          | Description                                                    |
| -------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------- |
| **start**                                                      | [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md)                                                                    | The starting point of the rectangle.                           |
| **end\_**                                                      | [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md)                                                                    | The ending point of the rectangle.                             |
| **color**                                                      | [<mark style="color:purple;">**`Color`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/color.md)                                                                       | The color of the rectangle.                                    |
| **rounding&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`number`**</mark>                                                                                                                               | The rounding radius of the rectangle corners. `(default: 0.0)` |
| **flags&#x20;**<mark style="color:orange;">**`[?]`**</mark>    | [<mark style="color:purple;">**`Enum.DrawFlags`**</mark>](https://uczone.gitbook.io/api-v2.0/game-components/rendering-and-visuals/pages/VwVljl88Qnl7u9hhqRdw#enum.drawflags) | Custom flags for drawing. `(default: Enum.DrawFlags.None)`     |

Draws a filled rectangle.

## <sub>Rect</sub>

`Render.Rect(start, end_, color, [rounding], [flags], [thickness]):` <mark style="color:purple;">**`nil`**</mark>

| Name                                                            | Type                                                                                                                                                                          | Description                                                    |
| --------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------- |
| **start**                                                       | [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md)                                                                    | The starting point of the rectangle.                           |
| **end\_**                                                       | [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md)                                                                    | The ending point of the rectangle.                             |
| **color**                                                       | [<mark style="color:purple;">**`Color`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/color.md)                                                                       | The color of the rectangle's border.                           |
| **rounding&#x20;**<mark style="color:orange;">**`[?]`**</mark>  | <mark style="color:purple;">**`number`**</mark>                                                                                                                               | The rounding radius of the rectangle corners. `(default: 0.0)` |
| **flags&#x20;**<mark style="color:orange;">**`[?]`**</mark>     | [<mark style="color:purple;">**`Enum.DrawFlags`**</mark>](https://uczone.gitbook.io/api-v2.0/game-components/rendering-and-visuals/pages/VwVljl88Qnl7u9hhqRdw#enum.drawflags) | Custom flags for drawing. `(default: Enum.DrawFlags.None)`     |
| **thickness&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`number`**</mark>                                                                                                                               | The thickness of the rectangle's border. `(default: 1.0)`      |

Draws an unfilled rectangle.

## <sub>RoundedProgressRect</sub>

`Render.RoundedProgressRect(start, end_, color, percent, rounding, [thickness]):` <mark style="color:purple;">**`nil`**</mark>

| Name                                                            | Type                                                                                                       | Description                                               |
| --------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- | --------------------------------------------------------- |
| **start**                                                       | [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md) | The starting point of the rectangle.                      |
| **end\_**                                                       | [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md) | The ending point of the rectangle.                        |
| **color**                                                       | [<mark style="color:purple;">**`Color`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/color.md)    | The color of the rectangle.                               |
| **percent**                                                     | <mark style="color:purple;">**`number`**</mark>                                                            | The percentage of the rectangle to fill \[0..1].          |
| **rounding**                                                    | <mark style="color:purple;">**`number`**</mark>                                                            | The rounding radius of the rectangle corners.             |
| **thickness&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`number`**</mark>                                                            | The thickness of the rectangle's border. `(default: 1.0)` |

Draw a progress rectangle.

## <sub>DonutChart</sub>

`Render.DonutChart(center, radius, thickness, segments, [options]):` <mark style="color:purple;">**`nil`**</mark>

| Name                                                          | Type                                                                                                                                                                                                                                                                                                             | Description                                                  |
| ------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------ |
| **center**                                                    | [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md)                                                                                                                                                                                                       | The center position of the chart.                            |
| **radius**                                                    | <mark style="color:purple;">**`number`**</mark>                                                                                                                                                                                                                                                                  | The outer radius of the chart.                               |
| **thickness**                                                 | <mark style="color:purple;">**`number`**</mark>                                                                                                                                                                                                                                                                  | The thickness of the donut ring.                             |
| **segments**                                                  | <mark style="color:purple;">**`{value: number, color: Color, icon: number`**</mark> \| <mark style="color:purple;">**`nil, icon_color: Color`**</mark> \| <mark style="color:purple;">**`nil, font_icon: {font: number, size: number, text: string}`**</mark> \| <mark style="color:purple;">**`nil}[]`**</mark> | List of data segments.                                       |
| **options&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`{separator_color:Color`**</mark> \| <mark style="color:purple;">**`nil, separator_thickness:number`**</mark> \| <mark style="color:purple;">**`nil}`**</mark> \| <mark style="color:purple;">**`nil`**</mark>                                                                     | Optional settings for the chart appearance. `(default: nil)` |

Draw a donut chart.

## <sub>Line</sub>

`Render.Line(start, end_, color, [thickness]):` <mark style="color:purple;">**`nil`**</mark>

| Name                                                            | Type                                                                                                       | Description                                 |
| --------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- | ------------------------------------------- |
| **start**                                                       | [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md) | The starting point of the line.             |
| **end\_**                                                       | [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md) | The ending point of the line.               |
| **color**                                                       | [<mark style="color:purple;">**`Color`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/color.md)    | The color of the line.                      |
| **thickness&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`number`**</mark>                                                            | The thickness of the line. `(default: 1.0)` |

Draws a line between two points.

## <sub>PolyLine</sub>

`Render.PolyLine(points, color, [thickness]):` <mark style="color:purple;">**`nil`**</mark>

| Name                                                            | Type                                                                                                         | Description                                     |
| --------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ | ----------------------------------------------- |
| **points**                                                      | [<mark style="color:purple;">**`Vec2[]`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md) | A table of Vec2 points to connect with lines.   |
| **color**                                                       | [<mark style="color:purple;">**`Color`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/color.md)      | The color of the polyline.                      |
| **thickness&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`number`**</mark>                                                              | The thickness of the polyline. `(default: 1.0)` |

Draws a series of connected lines (polyline).

## <sub>Circle</sub>

`Render.Circle(pos, radius, color, [thickness], [startDeg], [percentage], [rounded], [segments]):` <mark style="color:purple;">**`nil`**</mark>

| Name                                                             | Type                                                                                                       | Description                                                                                                          |
| ---------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| **pos**                                                          | [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md) | The center position of the circle.                                                                                   |
| **radius**                                                       | <mark style="color:purple;">**`number`**</mark>                                                            | The radius of the circle.                                                                                            |
| **color**                                                        | [<mark style="color:purple;">**`Color`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/color.md)    | The color of the circle.                                                                                             |
| **thickness&#x20;**<mark style="color:orange;">**`[?]`**</mark>  | <mark style="color:purple;">**`number`**</mark>                                                            | The thickness of the circle's outline. `(default: 1.0)`                                                              |
| **startDeg&#x20;**<mark style="color:orange;">**`[?]`**</mark>   | <mark style="color:purple;">**`number`**</mark>                                                            | The starting degree for drawing the circle. 0 is right side, 90 is bottom, 180 is left, 270 is top. `(default: 0.0)` |
| **percentage&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`number`**</mark>                                                            | The percentage of the circle to draw, in the range \[0.0-1.0]. `(default: 1.0)`                                      |
| **rounded&#x20;**<mark style="color:orange;">**`[?]`**</mark>    | <mark style="color:purple;">**`boolean`**</mark>                                                           | Whether the circle is rounded. `(default: false)`                                                                    |
| **segments&#x20;**<mark style="color:orange;">**`[?]`**</mark>   | <mark style="color:purple;">**`integer`**</mark>                                                           | The number of segments used for drawing the circle. `(default: 32)`                                                  |

Draws a circle.

## <sub>FilledCircle</sub>

`Render.FilledCircle(pos, radius, color, [startDeg], [percentage], [segments]):` <mark style="color:purple;">**`nil`**</mark>

| Name                                                             | Type                                                                                                       | Description                                                                                                          |
| ---------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| **pos**                                                          | [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md) | The center position of the circle.                                                                                   |
| **radius**                                                       | <mark style="color:purple;">**`number`**</mark>                                                            | The radius of the circle.                                                                                            |
| **color**                                                        | [<mark style="color:purple;">**`Color`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/color.md)    | The color of the circle.                                                                                             |
| **startDeg&#x20;**<mark style="color:orange;">**`[?]`**</mark>   | <mark style="color:purple;">**`number`**</mark>                                                            | The starting degree for drawing the circle. 0 is right side, 90 is bottom, 180 is left, 270 is top. `(default: 0.0)` |
| **percentage&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`number`**</mark>                                                            | The percentage of the circle to draw, in the range \[0.0-1.0]. `(default: 1.0)`                                      |
| **segments&#x20;**<mark style="color:orange;">**`[?]`**</mark>   | <mark style="color:purple;">**`integer`**</mark>                                                           | The number of segments used for drawing the circle. `(default: 32)`                                                  |

Draws a filled circle.

## <sub>CircleGradient</sub>

`Render.CircleGradient(pos, radius, colorOuter, colorInner, [startDeg], [percentage]):` <mark style="color:purple;">**`nil`**</mark>

| Name                                                             | Type                                                                                                       | Description                                                                                                          |
| ---------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| **pos**                                                          | [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md) | The center position of the circle.                                                                                   |
| **radius**                                                       | <mark style="color:purple;">**`number`**</mark>                                                            | The radius of the circle.                                                                                            |
| **colorOuter**                                                   | [<mark style="color:purple;">**`Color`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/color.md)    | The outer color of the gradient.                                                                                     |
| **colorInner**                                                   | [<mark style="color:purple;">**`Color`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/color.md)    | The inner color of the gradient.                                                                                     |
| **startDeg&#x20;**<mark style="color:orange;">**`[?]`**</mark>   | <mark style="color:purple;">**`number`**</mark>                                                            | The starting degree for drawing the circle. 0 is right side, 90 is bottom, 180 is left, 270 is top. `(default: 0.0)` |
| **percentage&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`number`**</mark>                                                            | The percentage of the circle to draw, in the range \[0.0-1.0]. `(default: 1.0)`                                      |

Draws a circle with a gradient.

## <sub>Triangle</sub>

`Render.Triangle(points, color, [thickness]):` <mark style="color:purple;">**`nil`**</mark>

| Name                                                            | Type                                                                                                         | Description                                                         |
| --------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------- |
| **points**                                                      | [<mark style="color:purple;">**`Vec2[]`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md) | A table of three Vec2 points defining the vertices of the triangle. |
| **color**                                                       | [<mark style="color:purple;">**`Color`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/color.md)      | The color of the triangle's outline.                                |
| **thickness&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`number`**</mark>                                                              | The thickness of the triangle's outline. `(default: 1.0)`           |

Draws a triangle outline.

## <sub>FilledTriangle</sub>

`Render.FilledTriangle(points, color):` <mark style="color:purple;">**`nil`**</mark>

| Name       | Type                                                                                                         | Description                                                         |
| ---------- | ------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------- |
| **points** | [<mark style="color:purple;">**`Vec2[]`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md) | A table of three Vec2 points defining the vertices of the triangle. |
| **color**  | [<mark style="color:purple;">**`Color`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/color.md)      | The color of the triangle.                                          |

Draws a filled triangle.

## <sub>TexturedPoly</sub>

`Render.TexturedPoly(points, textureHandle, color, [grayscale]):` <mark style="color:purple;">**`nil`**</mark>

| Name                                                            | Type                                                                                                             | Description                                                                                                                            |
| --------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| **points**                                                      | [<mark style="color:purple;">**`Vertex[]`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vertex.md) | A table of Vertex points defining the vertices of the polygon. Each Vertex contains a position (Vec2) and a texture coordinate (Vec2). |
| **textureHandle**                                               | <mark style="color:purple;">**`integer`**</mark>                                                                 | The handle to the texture to be applied to the polygon.                                                                                |
| **color**                                                       | [<mark style="color:purple;">**`Color`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/color.md)          | The color to apply over the texture. This can be used to tint the texture.                                                             |
| **grayscale&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`number`**</mark>                                                                  | The grayscale of the image. `(default: 0.0)`                                                                                           |

Draws a textured polygon.

## <sub>LoadFont</sub>

`Render.LoadFont(fontName, [fontFlag], [weight]):` <mark style="color:purple;">**`integer`**</mark>

| Name                                                           | Type                                                                                                                                                                                                                                | Description                                                                               |
| -------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| **fontName**                                                   | <mark style="color:purple;">**`string`**</mark>                                                                                                                                                                                     | The name of the font to load.                                                             |
| **fontFlag&#x20;**<mark style="color:orange;">**`[?]`**</mark> | [<mark style="color:purple;">**`Enum.FontCreate`**</mark>](https://uczone.gitbook.io/api-v2.0/game-components/rendering-and-visuals/pages/VwVljl88Qnl7u9hhqRdw#enum.fontcreate) \| <mark style="color:purple;">**`integer`**</mark> | Flags for font creation, such as antialiasing. `(default: Enum.FontCreate.FONTFLAG_NONE)` |
| **weight&#x20;**<mark style="color:orange;">**`[?]`**</mark>   | <mark style="color:purple;">**`integer`**</mark>                                                                                                                                                                                    | The weight (thickness) of the font. Typically, 0 means default weight. `(default: 400)`   |

Loads a font and returns its handle. Returns handle to the loaded font.

## <sub>Text</sub>

`Render.Text(font, fontSize, text, pos, color):` <mark style="color:purple;">**`nil`**</mark>

| Name         | Type                                                                                                       | Description                                       |
| ------------ | ---------------------------------------------------------------------------------------------------------- | ------------------------------------------------- |
| **font**     | <mark style="color:purple;">**`integer`**</mark>                                                           | The handle to the font used for drawing the text. |
| **fontSize** | <mark style="color:purple;">**`number`**</mark>                                                            | The size of the font.                             |
| **text**     | <mark style="color:purple;">**`string`**</mark>                                                            | The text to be drawn.                             |
| **pos**      | [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md) | The position where the text will be drawn.        |
| **color**    | [<mark style="color:purple;">**`Color`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/color.md)    | The color of the text.                            |

Draws text at a specified position.

## <sub>WorldToScreen</sub>

`Render.WorldToScreen(pos):` [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md), <mark style="color:purple;">**`boolean`**</mark>

| Name    | Type                                                                                                           | Description                            |
| ------- | -------------------------------------------------------------------------------------------------------------- | -------------------------------------- |
| **pos** | [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md) | The 3D world position to be converted. |

Converts a 3D world position to a 2D screen position. Returns A Vec2 representing the 2D screen position and a boolean indicating visibility on the screen.

#### Example

```lua
-- Example: Convert the center of the map (0,0,0) to screen coordinates.
local worldPos = Vector(0.0, 0.0, 0.0)
local screenPos, isVisible = Render.WorldToScreen(worldPos)
if isVisible then
    Log.Write("Screen Position: " .. screenPos.x .. ", " .. screenPos.y)
else
    Log.Write("Position is not visible on the screen")
end
```

## <sub>ScreenSize</sub>

`Render.ScreenSize():` [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md)

Retrieves the current screen size, returning it as a Vec2 where x is the width and y is the height of the screen.

## <sub>TextSize</sub>

`Render.TextSize(font, fontSize, text):` [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md)

| Name         | Type                                             | Description                                         |
| ------------ | ------------------------------------------------ | --------------------------------------------------- |
| **font**     | <mark style="color:purple;">**`integer`**</mark> | The handle to the font used for measuring the text. |
| **fontSize** | <mark style="color:purple;">**`number`**</mark>  | The size of the font.                               |
| **text**     | <mark style="color:purple;">**`string`**</mark>  | The text to measure.                                |

Calculates the size of the given text using the specified font, returning the size as a Vec2 where x is the width and y is the height of the text.

## <sub>LoadImage</sub>

`Render.LoadImage(path):` <mark style="color:purple;">**`integer`**</mark>

| Name     | Type                                            | Description        |
| -------- | ----------------------------------------------- | ------------------ |
| **path** | <mark style="color:purple;">**`string`**</mark> | Path to the image. |

Loads an image and returns its handle.

## <sub>LoadSvg</sub>

`Render.LoadSvg(path, size):` <mark style="color:purple;">**`integer`**</mark>

| Name     | Type                                                                                                       | Description             |
| -------- | ---------------------------------------------------------------------------------------------------------- | ----------------------- |
| **path** | <mark style="color:purple;">**`string`**</mark>                                                            | Path to the image.      |
| **size** | [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md) | Size of image to scale. |

Loads svg image and returns its handle.

## <sub>LoadSvgString</sub>

`Render.LoadSvgString(svg, size, cacheId):` <mark style="color:purple;">**`integer`**</mark>

| Name        | Type                                                                                                       | Description                                                  |
| ----------- | ---------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------ |
| **svg**     | <mark style="color:purple;">**`string`**</mark>                                                            | Svg text itself.                                             |
| **size**    | [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md) | Size of image to scale.                                      |
| **cacheId** | <mark style="color:purple;">**`string`**</mark>                                                            | Texture of image creates only once for every unique cache id |

Loads svg image from string and returns its handle.

## <sub>Image</sub>

`Render.Image(imageHandle, pos, size, color, [rounding], [flags], [uvMin], [uvMax], [grayscale]):` <mark style="color:purple;">**`nil`**</mark>

| Name                                                            | Type                                                                                                                                                                          | Description                                                             |
| --------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| **imageHandle**                                                 | <mark style="color:purple;">**`integer`**</mark>                                                                                                                              | The handle to the image.                                                |
| **pos**                                                         | [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md)                                                                    | The position to draw the image.                                         |
| **size**                                                        | [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md)                                                                    | The size of the image.                                                  |
| **color**                                                       | [<mark style="color:purple;">**`Color`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/color.md)                                                                       | The color to tint the image.                                            |
| **rounding&#x20;**<mark style="color:orange;">**`[?]`**</mark>  | <mark style="color:purple;">**`number`**</mark>                                                                                                                               | The rounding radius of the image corners. `(default: 0.0)`              |
| **flags&#x20;**<mark style="color:orange;">**`[?]`**</mark>     | [<mark style="color:purple;">**`Enum.DrawFlags`**</mark>](https://uczone.gitbook.io/api-v2.0/game-components/rendering-and-visuals/pages/VwVljl88Qnl7u9hhqRdw#enum.drawflags) | Custom flags for drawing. `(default: Enum.DrawFlags.None)`              |
| **uvMin&#x20;**<mark style="color:orange;">**`[?]`**</mark>     | [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md)                                                                    | The minimum UV coordinates for texture mapping. `(default: {0.0, 0.0})` |
| **uvMax&#x20;**<mark style="color:orange;">**`[?]`**</mark>     | [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md)                                                                    | The maximum UV coordinates for texture mapping. `(default: {1.0, 1.0})` |
| **grayscale&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`number`**</mark>                                                                                                                               | The grayscale of the image. `(default: 0.0)`                            |

Draws an image at a specified position and size.

## <sub>ImageCentered</sub>

`Render.ImageCentered(imageHandle, pos, size, color, [rounding], [flags], [uvMin], [uvMax], [grayscale]):` <mark style="color:purple;">**`nil`**</mark>

| Name                                                            | Type                                                                                                                                                                          | Description                                                             |
| --------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| **imageHandle**                                                 | <mark style="color:purple;">**`integer`**</mark>                                                                                                                              | The handle to the image.                                                |
| **pos**                                                         | [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md)                                                                    | The center position to draw the image.                                  |
| **size**                                                        | [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md)                                                                    | The size of the image.                                                  |
| **color**                                                       | [<mark style="color:purple;">**`Color`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/color.md)                                                                       | The color to tint the image.                                            |
| **rounding&#x20;**<mark style="color:orange;">**`[?]`**</mark>  | <mark style="color:purple;">**`number`**</mark>                                                                                                                               | The rounding radius of the image corners. `(default: 0.0)`              |
| **flags&#x20;**<mark style="color:orange;">**`[?]`**</mark>     | [<mark style="color:purple;">**`Enum.DrawFlags`**</mark>](https://uczone.gitbook.io/api-v2.0/game-components/rendering-and-visuals/pages/VwVljl88Qnl7u9hhqRdw#enum.drawflags) | Custom flags for drawing. `(default: Enum.DrawFlags.None)`              |
| **uvMin&#x20;**<mark style="color:orange;">**`[?]`**</mark>     | [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md)                                                                    | The minimum UV coordinates for texture mapping. `(default: {0.0, 0.0})` |
| **uvMax&#x20;**<mark style="color:orange;">**`[?]`**</mark>     | [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md)                                                                    | The maximum UV coordinates for texture mapping. `(default: {1.0, 1.0})` |
| **grayscale&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`number`**</mark>                                                                                                                               | The grayscale of the image. `(default: 0.0)`                            |

Draws an image centered at a specified position and size.

## <sub>ImageSize</sub>

`Render.ImageSize(imageHandle):` [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md)

| Name            | Type                                             | Description              |
| --------------- | ------------------------------------------------ | ------------------------ |
| **imageHandle** | <mark style="color:purple;">**`integer`**</mark> | The handle to the image. |

Retrieves the size of an image. Returns the size of the image as a Vec2.

## <sub>OutlineGradient</sub>

`Render.OutlineGradient(start, end_, topLeft, topRight, bottomLeft, bottomRight, [rounding], [flags], [thickness]):` <mark style="color:purple;">**`nil`**</mark>

| Name                                                            | Type                                                                                                                                                                          | Description                                                    |
| --------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------- |
| **start**                                                       | [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md)                                                                    | The starting point of the gradient rectangle.                  |
| **end\_**                                                       | [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md)                                                                    | The ending point of the gradient rectangle.                    |
| **topLeft**                                                     | [<mark style="color:purple;">**`Color`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/color.md)                                                                       | The color of the top-left corner.                              |
| **topRight**                                                    | [<mark style="color:purple;">**`Color`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/color.md)                                                                       | The color of the top-right corner.                             |
| **bottomLeft**                                                  | [<mark style="color:purple;">**`Color`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/color.md)                                                                       | The color of the bottom-left corner.                           |
| **bottomRight**                                                 | [<mark style="color:purple;">**`Color`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/color.md)                                                                       | The color of the bottom-right corner.                          |
| **rounding&#x20;**<mark style="color:orange;">**`[?]`**</mark>  | <mark style="color:purple;">**`number`**</mark>                                                                                                                               | The rounding radius of the rectangle corners. `(default: 0.0)` |
| **flags&#x20;**<mark style="color:orange;">**`[?]`**</mark>     | [<mark style="color:purple;">**`Enum.DrawFlags`**</mark>](https://uczone.gitbook.io/api-v2.0/game-components/rendering-and-visuals/pages/VwVljl88Qnl7u9hhqRdw#enum.drawflags) | Custom flags for drawing. `(default: Enum.DrawFlags.None)`     |
| **thickness&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`number`**</mark>                                                                                                                               | The thickness of the outline. `(default: 1.0)`                 |

Draws a outlined gradient rectangle.

## <sub>Gradient</sub>

`Render.Gradient(start, end_, topLeft, topRight, bottomLeft, bottomRight, [rounding], [flags]):` <mark style="color:purple;">**`nil`**</mark>

| Name                                                           | Type                                                                                                                                                                          | Description                                                    |
| -------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------- |
| **start**                                                      | [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md)                                                                    | The starting point of the gradient rectangle.                  |
| **end\_**                                                      | [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md)                                                                    | The ending point of the gradient rectangle.                    |
| **topLeft**                                                    | [<mark style="color:purple;">**`Color`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/color.md)                                                                       | The color of the top-left corner.                              |
| **topRight**                                                   | [<mark style="color:purple;">**`Color`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/color.md)                                                                       | The color of the top-right corner.                             |
| **bottomLeft**                                                 | [<mark style="color:purple;">**`Color`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/color.md)                                                                       | The color of the bottom-left corner.                           |
| **bottomRight**                                                | [<mark style="color:purple;">**`Color`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/color.md)                                                                       | The color of the bottom-right corner.                          |
| **rounding&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`number`**</mark>                                                                                                                               | The rounding radius of the rectangle corners. `(default: 0.0)` |
| **flags&#x20;**<mark style="color:orange;">**`[?]`**</mark>    | [<mark style="color:purple;">**`Enum.DrawFlags`**</mark>](https://uczone.gitbook.io/api-v2.0/game-components/rendering-and-visuals/pages/VwVljl88Qnl7u9hhqRdw#enum.drawflags) | Custom flags for drawing. `(default: Enum.DrawFlags.None)`     |

Draws a filled gradient rectangle.

## <sub>Shadow</sub>

`Render.Shadow(start, end_, color, thickness, [obj_rounding], [flags], [offset]):` <mark style="color:purple;">**`nil`**</mark>

| Name                                                                | Type                                                                                                                                                                          | Description                                                                                  |
| ------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| **start**                                                           | [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md)                                                                    | The starting point of the shadow rectangle.                                                  |
| **end\_**                                                           | [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md)                                                                    | The ending point of the shadow rectangle.                                                    |
| **color**                                                           | [<mark style="color:purple;">**`Color`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/color.md)                                                                       | The color of the shadow.                                                                     |
| **thickness**                                                       | <mark style="color:purple;">**`number`**</mark>                                                                                                                               | The thickness of the shadow.                                                                 |
| **obj\_rounding&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`number`**</mark>                                                                                                                               | The rounding radius of the shadow rectangle corners. `(default: 0.0)`                        |
| **flags&#x20;**<mark style="color:orange;">**`[?]`**</mark>         | [<mark style="color:purple;">**`Enum.DrawFlags`**</mark>](https://uczone.gitbook.io/api-v2.0/game-components/rendering-and-visuals/pages/VwVljl88Qnl7u9hhqRdw#enum.drawflags) | Custom flags for drawing the shadow. `(default: Enum.DrawFlags.ShadowCutOutShapeBackground)` |
| **offset&#x20;**<mark style="color:orange;">**`[?]`**</mark>        | [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md)                                                                    | The offset of the shadow from the original rectangle. `(default: {0.0, 0.0})`                |

Draws a shadow effect within a specified rectangular area.

## <sub>ShadowCircle</sub>

`Render.ShadowCircle(center, radius, color, thickness, [num_segments], [flags], [offset]):` <mark style="color:purple;">**`nil`**</mark>

| Name                                                                | Type                                                                                                                                                                          | Description                                                                                  |
| ------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| **center**                                                          | [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md)                                                                    | The center point of the circle.                                                              |
| **radius**                                                          | <mark style="color:purple;">**`number`**</mark>                                                                                                                               | The radius of the circle.                                                                    |
| **color**                                                           | [<mark style="color:purple;">**`Color`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/color.md)                                                                       | The color of the shadow.                                                                     |
| **thickness**                                                       | <mark style="color:purple;">**`number`**</mark>                                                                                                                               | The thickness of the shadow.                                                                 |
| **num\_segments&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`integer`**</mark>                                                                                                                              | The number of segments for drawing the circle. `(default: 12)`                               |
| **flags&#x20;**<mark style="color:orange;">**`[?]`**</mark>         | [<mark style="color:purple;">**`Enum.DrawFlags`**</mark>](https://uczone.gitbook.io/api-v2.0/game-components/rendering-and-visuals/pages/VwVljl88Qnl7u9hhqRdw#enum.drawflags) | Custom flags for drawing the shadow. `(default: Enum.DrawFlags.ShadowCutOutShapeBackground)` |
| **offset&#x20;**<mark style="color:orange;">**`[?]`**</mark>        | [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md)                                                                    | The offset of the shadow from the circle. `(default: {0.0, 0.0})`                            |

Draws a circle shadow effect.

## <sub>ShadowConvexPoly</sub>

`Render.ShadowConvexPoly(points, color, thickness, [flags], [offset]):` <mark style="color:purple;">**`nil`**</mark>

| Name                                                         | Type                                                                                                                                                                          | Description                                                                                  |
| ------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| **points**                                                   | [<mark style="color:purple;">**`Vec2[]`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md)                                                                  | Table of Vec2 points defining the convex polygon. Should be more than 2 points.              |
| **color**                                                    | [<mark style="color:purple;">**`Color`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/color.md)                                                                       | The color of the shadow.                                                                     |
| **thickness**                                                | <mark style="color:purple;">**`number`**</mark>                                                                                                                               | The thickness of the shadow.                                                                 |
| **flags&#x20;**<mark style="color:orange;">**`[?]`**</mark>  | [<mark style="color:purple;">**`Enum.DrawFlags`**</mark>](https://uczone.gitbook.io/api-v2.0/game-components/rendering-and-visuals/pages/VwVljl88Qnl7u9hhqRdw#enum.drawflags) | Custom flags for drawing the shadow. `(default: Enum.DrawFlags.ShadowCutOutShapeBackground)` |
| **offset&#x20;**<mark style="color:orange;">**`[?]`**</mark> | [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md)                                                                    | The offset of the shadow from the polygon. `(default: {0.0, 0.0})`                           |

Draws a shadow convex polygon effect.

## <sub>ShadowNGon</sub>

`Render.ShadowNGon(center, radius, color, thickness, num_segments, [flags], [offset]):` <mark style="color:purple;">**`nil`**</mark>

| Name                                                         | Type                                                                                                                                                                          | Description                                                                                  |
| ------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| **center**                                                   | [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md)                                                                    | The center point of the n-gon.                                                               |
| **radius**                                                   | <mark style="color:purple;">**`number`**</mark>                                                                                                                               | The radius of the n-gon.                                                                     |
| **color**                                                    | [<mark style="color:purple;">**`Color`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/color.md)                                                                       | The color of the shadow.                                                                     |
| **thickness**                                                | <mark style="color:purple;">**`number`**</mark>                                                                                                                               | The thickness of the shadow.                                                                 |
| **num\_segments**                                            | <mark style="color:purple;">**`integer`**</mark>                                                                                                                              | The number of segments (sides) of the n-gon.                                                 |
| **flags&#x20;**<mark style="color:orange;">**`[?]`**</mark>  | [<mark style="color:purple;">**`Enum.DrawFlags`**</mark>](https://uczone.gitbook.io/api-v2.0/game-components/rendering-and-visuals/pages/VwVljl88Qnl7u9hhqRdw#enum.drawflags) | Custom flags for drawing the shadow. `(default: Enum.DrawFlags.ShadowCutOutShapeBackground)` |
| **offset&#x20;**<mark style="color:orange;">**`[?]`**</mark> | [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md)                                                                    | The offset of the shadow from the n-gon. `(default: {0.0, 0.0})`                             |

Draws a shadow n-gon (polygon with n sides) effect.

## <sub>Blur</sub>

`Render.Blur(start, end_, [strength], [alpha], [rounding], [flags]):` <mark style="color:purple;">**`nil`**</mark>

| Name                                                           | Type                                                                                                                                                                          | Description                                                         |
| -------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------- |
| **start**                                                      | [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md)                                                                    | The starting point of the blur rectangle.                           |
| **end\_**                                                      | [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md)                                                                    | The ending point of the blur rectangle.                             |
| **strength&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`number`**</mark>                                                                                                                               | The strength of the blur effect. `(default: 1.0)`                   |
| **alpha&#x20;**<mark style="color:orange;">**`[?]`**</mark>    | <mark style="color:purple;">**`number`**</mark>                                                                                                                               | The alpha value of the blur effect. `(default: 1.0)`                |
| **rounding&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`number`**</mark>                                                                                                                               | The rounding radius of the blur rectangle corners. `(default: 0.0)` |
| **flags&#x20;**<mark style="color:orange;">**`[?]`**</mark>    | [<mark style="color:purple;">**`Enum.DrawFlags`**</mark>](https://uczone.gitbook.io/api-v2.0/game-components/rendering-and-visuals/pages/VwVljl88Qnl7u9hhqRdw#enum.drawflags) | Custom flags for the blur effect. `(default: Enum.DrawFlags.None)`  |

Applies a blur effect within a specified rectangular area.

## <sub>PushClip</sub>

`Render.PushClip(start, end_, [intersect]):` <mark style="color:purple;">**`nil`**</mark>

| Name                                                            | Type                                                                                                       | Description                                                                                      |
| --------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| **start**                                                       | [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md) | The starting point of the clipping rectangle.                                                    |
| **end\_**                                                       | [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md) | The ending point of the clipping rectangle.                                                      |
| **intersect&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`boolean`**</mark>                                                           | If true, the new clipping area is intersected with the current clipping area. `(default: false)` |

Begins a new clipping region. Only the rendering within the specified rectangular area will be displayed.

## <sub>PopClip</sub>

`Render.PopClip():` <mark style="color:purple;">**`nil`**</mark>

Ends the most recently begun clipping region, restoring the previous clipping region.

## <sub>StartRotation</sub>

`Render.StartRotation(angle):` <mark style="color:purple;">**`nil`**</mark>

| Name      | Type                                            | Description         |
| --------- | ----------------------------------------------- | ------------------- |
| **angle** | <mark style="color:purple;">**`number`**</mark> | The rotation angle. |

Begins a new rotation.

## <sub>StopRotation</sub>

`Render.StopRotation():` <mark style="color:purple;">**`nil`**</mark>

End the rotation.

## <sub>SetGlobalAlpha</sub>

{% hint style="info" %}
Do not forget to reset the global alpha value after your rendering.
{% endhint %}

\`Render.SetGlobalAlpha(alpha):\` <mark style="color:purple;">\*\*\`nil\`\*\*</mark>

| Name      | Type                                            | Description                    |
| --------- | ----------------------------------------------- | ------------------------------ |
| **alpha** | <mark style="color:purple;">**`number`**</mark> | The alpha value to set \[0..1] |

Set the global alpha value for rendering.

## <sub>ResetGlobalAlpha</sub>

`Render.ResetGlobalAlpha():` <mark style="color:purple;">**`nil`**</mark>

Reset the global alpha value for rendering to 1.0.

## <sub>CenteredNotification</sub>

`Render.CenteredNotification(text, duration):` <mark style="color:purple;">**`nil`**</mark>

| Name         | Type                                            | Description                   |
| ------------ | ----------------------------------------------- | ----------------------------- |
| **text**     | <mark style="color:purple;">**`string`**</mark> | Text to draw.                 |
| **duration** | <mark style="color:purple;">**`number`**</mark> | Duration of the notification. |

Draws a centered notification.

## <sub>Logo</sub>

`Render.Logo(center, radius, [angle], [primary_color], [secondary_color]):` <mark style="color:purple;">**`nil`**</mark>

| Name                                                                   | Type                                                                                                       | Description                        |
| ---------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- | ---------------------------------- |
| **center**                                                             | [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md) |                                    |
| **radius**                                                             | <mark style="color:purple;">**`number`**</mark>                                                            |                                    |
| **angle&#x20;**<mark style="color:orange;">**`[?]`**</mark>            | <mark style="color:purple;">**`number`**</mark>                                                            | rotation angle `(default: -45)`    |
| **primary\_color&#x20;**<mark style="color:orange;">**`[?]`**</mark>   | [<mark style="color:purple;">**`Color`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/color.md)    | `(default: Menu.Style("primary"))` |
| **secondary\_color&#x20;**<mark style="color:orange;">**`[?]`**</mark> | [<mark style="color:purple;">**`Color`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/color.md)    | `(default: {227, 227, 227, 255})`  |

Draws umbrella logo

## <sub>FindOrCreateRT</sub>

`Render.FindOrCreateRT(name, [w], [h]):` <mark style="color:purple;">**`userdata`**</mark>

| Name                                                    | Type                                            | Description                                                 |
| ------------------------------------------------------- | ----------------------------------------------- | ----------------------------------------------------------- |
| **name**                                                | <mark style="color:purple;">**`string`**</mark> | The unique name of the render target.                       |
| **w&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`number`**</mark> | The width of the render target. Optional. `(default: nil)`  |
| **h&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`number`**</mark> | The height of the render target. Optional. `(default: nil)` |

Creates a new render target or retrieves an existing one by name.\
If width or height are not provided, the render target will be full screen size.

## <sub>MarkDirtyRT</sub>

`Render.MarkDirtyRT(handle):` <mark style="color:purple;">**`nil`**</mark>

| Name       | Type                                              | Description                      |
| ---------- | ------------------------------------------------- | -------------------------------- |
| **handle** | <mark style="color:purple;">**`userdata`**</mark> | The handle of the render target. |

Marks a render target as dirty, causing the next Render.RenderRT call to re-bake it.\
Safe across frame drops: the dirty state is only cleared once the bake is actually processed.

## <sub>RenderRT</sub>

`Render.RenderRT(callback, handle, pos, color, [scale], [uvSizeMin], [uvSizeMax]):` <mark style="color:purple;">**`boolean`**</mark>

| Name                                                            | Type                                                                                                       | Description                                                                |
| --------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------- |
| **callback**                                                    | <mark style="color:purple;">**`fun():boolean?`**</mark>                                                    | The function containing rendering commands to bake into the render target. |
| **handle**                                                      | <mark style="color:purple;">**`userdata`**</mark>                                                          | The handle of the render target (from Render.FindOrCreateRT).              |
| **pos**                                                         | [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md) | The screen position where the render target texture will be drawn.         |
| **color**                                                       | [<mark style="color:purple;">**`Color`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/color.md)    | The color tint to apply when drawing the render target texture.            |
| **scale&#x20;**<mark style="color:orange;">**`[?]`**</mark>     | <mark style="color:purple;">**`number`**</mark>                                                            | The scale factor for the render target. `(default: 1.0)`                   |
| **uvSizeMin&#x20;**<mark style="color:orange;">**`[?]`**</mark> | [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md) | The minimum UV offset for texture mapping. `(default: {0.0, 0.0})`         |
| **uvSizeMax&#x20;**<mark style="color:orange;">**`[?]`**</mark> | [<mark style="color:purple;">**`Vec2`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vec2.md) | The maximum UV offset for texture mapping. `(default: {0.0, 0.0})`         |

Renders a cached render target texture at the given position.\
If the render target is dirty (see Render.MarkDirtyRT), the callback is invoked once\
inside a push/pop RT context to re-bake the texture content, then the baked texture\
is drawn at `pos`. If the render target is clean, only the cached texture is drawn.\
\
The callback receives no arguments and may return a boolean: returning `true` signals\
that the content is still updating (e.g. animation in progress).

#### Example

```lua
-- render_target.lua
local rt_w, rt_h = 256, 80
local rt_handle = Render.FindOrCreateRT("example_rt", rt_w, rt_h)

local font = Render.LoadFont("MuseoSansEx", Enum.FontCreate.FONTFLAG_ANTIALIAS | Enum.FontCreate.FONTFLAG_DROPSHADOW, 500)

local white  = Color(255, 255, 255, 255)
local bg     = Color(20, 20, 20, 220)
local accent = Color(80, 200, 120, 255)
local dim    = Color(160, 160, 160, 200)
local rt_pos = Vec2(100, 100)

-- Animation state
local anim_start = 0
local anim_duration = 0.6 -- seconds
local is_animating = false
local click_count = 0

-- Draw callback is invoked ONLY when the RT is dirty.
-- Returning true  tells the caller "content is still changing" (animation in progress).
-- Returning false tells the caller "content is now static" (bake is final).
-- The engine itself does NOT use this value — it is passed through as RenderRT's return.
local function draw_rt_content()
    local t = is_animating
        and math.min((os.clock() - anim_start) / anim_duration, 1.0)
        or 0

    Render.FilledRect(Vec2(0, 0), Vec2(rt_w, rt_h), bg)
    Render.FilledRect(Vec2(0, rt_h - 8), Vec2(t * rt_w, rt_h), accent)
    Render.Text(font, 14, "Clicks: " .. click_count, Vec2(10, 10), white)

    if t >= 1.0 then
        is_animating = false
    end

    return is_animating
end

return {
    OnDraw = function()
        -- Click inside the RT rect -> start a new animation
        if Input.IsKeyDownOnce(Enum.ButtonCode.KEY_MOUSE1)
            and Input.IsCursorInRect(rt_pos.x, rt_pos.y, rt_w, rt_h) then
            click_count = click_count + 1
            anim_start = os.clock()
            is_animating = true
            Render.MarkDirtyRT(rt_handle)
        end

        -- RenderRT returns true when it baked AND the callback returned true.
        -- That means the animation is still playing, so mark dirty again
        -- to force another bake next frame.
        -- Tint alpha and Render.SetGlobalAlpha multiply the cached texture's opacity.
        -- Use white RGB for an untinted fade; no MarkDirtyRT is needed for opacity changes.
        local still_updating = Render.RenderRT(draw_rt_content, rt_handle, rt_pos, white)
        if still_updating then
            Render.MarkDirtyRT(rt_handle)
        end

        -- Print current state below the RT rect
        local state = still_updating and "Redrawing (animation)" or "Cached (using RT)"
        Render.Text(font, 12, state, Vec2(rt_pos.x, rt_pos.y + rt_h + 4), dim)
    end
}

```

## <sub>ResizeRT</sub>

`Render.ResizeRT(handle, [w], [h]):` <mark style="color:purple;">**`nil`**</mark>

| Name                                                    | Type                                              | Description                                                                  |
| ------------------------------------------------------- | ------------------------------------------------- | ---------------------------------------------------------------------------- |
| **handle**                                              | <mark style="color:purple;">**`userdata`**</mark> | The handle of the render target to resize.                                   |
| **w&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`number`**</mark>   | The new width. Used as the square size when `h` is omitted. `(default: nil)` |
| **h&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`number`**</mark>   | The new height. Not used when Vec2 is provided. `(default: nil)`             |

Resizes an existing render target.\
If width and height are not provided, it changes the render target to be full screen size.\
Accepts (handle, w, h), (handle, vec2), or (handle) for full screen.
