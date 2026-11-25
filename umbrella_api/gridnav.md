> For the complete documentation index, see [llms.txt](https://uczone.gitbook.io/api-v2.0/llms.txt). Markdown versions of documentation pages are available by appending `.md` to page URLs; this page is available as [Markdown](https://uczone.gitbook.io/api-v2.0/game-components/game-engine/gridnav.md).

# GridNav

Table to work with in-game navigation API.

## <sub>CreateNpcMap</sub>

{% hint style="info" %}
You should always call \`GridNav.ReleaseNpcMap\` after you done with your build pathing
{% endhint %}

\`GridNav.CreateNpcMap(\[excluded\_npcs], \[includeTempTrees], \[customCollisionSizes]):\` \[<mark style="color:purple;">\*\*\`GridNavNpcMap\`\*\*</mark>]\(GridNavNpcMap.md)

| Name                                                                       | Type                                                                                                                                           | Description                                                                                                                                    |
| -------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| **excluded\_npcs&#x20;**<mark style="color:orange;">**`[?]`**</mark>       | [<mark style="color:purple;">**`CEntity[]`**</mark>](/api-v2.0/game-components/core/entity.md) \| <mark style="color:purple;">**`nil`**</mark> | table with npc to exclude from the map. for example you want to exclude local hero if you build path from local hero position `(default: nil)` |
| **includeTempTrees&#x20;**<mark style="color:orange;">**`[?]`**</mark>     | <mark style="color:purple;">**`boolean`**</mark>                                                                                               | `true` if you want include temp trees to the map e.g. furion's 1st spell, iron branch `(default: true)`                                        |
| **customCollisionSizes&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`table`**</mark> \| <mark style="color:purple;">**`nil`**</mark>                                                 | table where key is entity userdata and value is {left, top, right, bottom} offsets from entity position `(default: nil)`                       |

Creates a new `GridNavNpcMap`

## <sub>ReleaseNpcMap</sub>

`GridNav.ReleaseNpcMap(npc_map):` <mark style="color:purple;">**`nil`**</mark>

| Name         | Type                                                                                                                                           | Description               |
| ------------ | ---------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------- |
| **npc\_map** | [<mark style="color:purple;">**`GridNavNpcMap`**</mark>](https://github.com/Boyarinov/gitbook-doc-parser/tree/main/generated/GridNavNpcMap.md) | map to release to release |

Releases allocated memory for `GridNavNpcMap`

## <sub>IsTraversable</sub>

`GridNav.IsTraversable(pos, [flag], [flag_excluded]):` <mark style="color:purple;">**`boolean`**</mark>, <mark style="color:purple;">**`integer`**</mark>

| Name                                                                 | Type                                                                                                           | Description                                             |
| -------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------- |
| **pos**                                                              | [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md) | position to check                                       |
| **flag&#x20;**<mark style="color:orange;">**`[?]`**</mark>           | <mark style="color:purple;">**`number`**</mark>                                                                | required cell flag mask (must be set) `(default: 1)`    |
| **flag\_excluded&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`number`**</mark>                                                                | forbidden cell flag mask (must be clear) `(default: 2)` |

Returns `true` if the world position is traversable.\
\
Pass `flag_excluded` to replicate per-ability filter masks. Examples:\\

* `IsTraversable(pos, 0x1, 0x002)` - default (engine `BLOCKED` only)\\
* `IsTraversable(pos, 0x1, 0x102)` - Techies Land Mine semantics\
  (LOCATION 0x002 + BUILDING 0x100)\\
* `IsTraversable(pos, 0x1, 0x112)` - strictest variant used by many native\
  AOE landing checks (LOCATION + PORTAL + BUILDING)

## <sub>BuildPath</sub>

`GridNav.BuildPath(start, end_, [ignoreTrees], [npc_map]):` [<mark style="color:purple;">**`Vector[]`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md)

| Name                                                              | Type                                                                                                                                                                                           | Description                                                                                  |
| ----------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| **start**                                                         | [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md)                                                                                 | position to start                                                                            |
| **end\_**                                                         | [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md)                                                                                 | position to end                                                                              |
| **ignoreTrees&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`boolean`**</mark>                                                                                                                                               | `true` if you want to exclude static trees from the pathing `(default: false)`               |
| **npc\_map&#x20;**<mark style="color:orange;">**`[?]`**</mark>    | [<mark style="color:purple;">**`GridNavNpcMap`**</mark>](https://github.com/Boyarinov/gitbook-doc-parser/tree/main/generated/GridNavNpcMap.md) \| <mark style="color:purple;">**`nil`**</mark> | map with the npc's positions which works as additional mask for terrain map `(default: nil)` |

Build path from start to end. Returns an array with builded positions.

#### Example

```lua
-- build_path.lua
return {
    OnUpdate = function()
        local ignore_trees = false;
        local my_hero = Heroes.GetLocal();
        local start_pos = Entity.GetAbsOrigin(my_hero);
        local end_pos = Input.GetWorldCursorPos();

        -- create npc map with the temp trees but with no local hero in it
        local npc_map = GridNav.CreateNpcMap({Heroes.GetLocal()}, not ignore_trees);

        local path = GridNav.BuildPath(start_pos, end_pos, ignore_trees, npc_map);
        local prev_x, prev_y = nil, nil;
        for i, pos in pairs(path) do
            local x, y, visible = Renderer.WorldToScreen(pos);
            if (prev_x and visible) then
                Renderer.SetDrawColor(255, 255, 255, 255);
                Renderer.DrawLine(prev_x, prev_y, x, y);
            end
            prev_x, prev_y = x, y;
        end

        -- releasing allocated npc map after we done with build pathing
        GridNav.ReleaseNpcMap(npc_map)
    end
}

```

## <sub>IsTraversableFromTo</sub>

`GridNav.IsTraversableFromTo(start, end_, [ignoreTrees], [npc_map]):` <mark style="color:purple;">**`boolean`**</mark>

| Name                                                              | Type                                                                                                                                                                                           | Description                                                                                  |
| ----------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| **start**                                                         | [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md)                                                                                 | position to start                                                                            |
| **end\_**                                                         | [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md)                                                                                 | position to end                                                                              |
| **ignoreTrees&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`boolean`**</mark>                                                                                                                                               | `true` if you want to exclude static trees from the pathing `(default: false)`               |
| **npc\_map&#x20;**<mark style="color:orange;">**`[?]`**</mark>    | [<mark style="color:purple;">**`GridNavNpcMap`**</mark>](https://github.com/Boyarinov/gitbook-doc-parser/tree/main/generated/GridNavNpcMap.md) \| <mark style="color:purple;">**`nil`**</mark> | map with the npc's positions which works as additional mask for terrain map `(default: nil)` |

Lite version of GridNav.BuildPath function which just cheking if the path is exists.

## <sub>DebugRender</sub>

`GridNav.DebugRender([grid_range], [npc_map], [render_cell_flags]):` <mark style="color:purple;">**`nil`**</mark>

| Name                                                                      | Type                                                                                                                                                                                           | Description                                                                                                                                  |
| ------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| **grid\_range&#x20;**<mark style="color:orange;">**`[?]`**</mark>         | <mark style="color:purple;">**`integer`**</mark>                                                                                                                                               | grid radius in "cell units" from Vector(0,0,0) `(default: 50)`                                                                               |
| **npc\_map&#x20;**<mark style="color:orange;">**`[?]`**</mark>            | [<mark style="color:purple;">**`GridNavNpcMap`**</mark>](https://github.com/Boyarinov/gitbook-doc-parser/tree/main/generated/GridNavNpcMap.md) \| <mark style="color:purple;">**`nil`**</mark> | map with the npc's positions which works as additional mask for terrain map `(default: nil)`                                                 |
| **render\_cell\_flags&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`boolean`**</mark>                                                                                                                                               | render the flags value for each not approachable cell (don't think you ever want to see this numbers, so ignore this arg) `(default: false)` |

Debug render of current GridNav with GridNavNpcMap (if provided)
