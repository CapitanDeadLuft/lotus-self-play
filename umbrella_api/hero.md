> For the complete documentation index, see [llms.txt](https://uczone.gitbook.io/api-v2.0/llms.txt). Markdown versions of documentation pages are available by appending `.md` to page URLs; this page is available as [Markdown](https://uczone.gitbook.io/api-v2.0/game-components/core/hero.md).

# Hero

Table to work with `CHero`.

<mark style="color:purple;">**`CHero`**</mark> extends <mark style="color:purple;">**`CNPC`**</mark>

## <sub>GetCurrentXP</sub>

`Hero.GetCurrentXP(hero):` <mark style="color:purple;">**`integer`**</mark>

| Name     | Type                                                                                     | Description |
| -------- | ---------------------------------------------------------------------------------------- | ----------- |
| **hero** | [<mark style="color:purple;">**`CHero`**</mark>](/api-v2.0/game-components/core/hero.md) |             |

Returns the hero's current XP.

## <sub>GetAbilityPoints</sub>

`Hero.GetAbilityPoints(hero):` <mark style="color:purple;">**`integer`**</mark>

| Name     | Type                                                                                     | Description |
| -------- | ---------------------------------------------------------------------------------------- | ----------- |
| **hero** | [<mark style="color:purple;">**`CHero`**</mark>](/api-v2.0/game-components/core/hero.md) |             |

Returns the hero's available ability points.

## <sub>GetRespawnTime</sub>

{% hint style="info" %}
Could be less than current game time if hero is already alive.
{% endhint %}

\`Hero.GetRespawnTime(hero):\` <mark style="color:purple;">\*\*\`number\`\*\*</mark>

| Name     | Type                                                                                     | Description |
| -------- | ---------------------------------------------------------------------------------------- | ----------- |
| **hero** | [<mark style="color:purple;">**`CHero`**</mark>](/api-v2.0/game-components/core/hero.md) |             |

Returns the game time when the hero will respawn.

## <sub>GetRespawnTimePenalty</sub>

`Hero.GetRespawnTimePenalty(hero):` <mark style="color:purple;">**`number`**</mark>

| Name     | Type                                                                                     | Description |
| -------- | ---------------------------------------------------------------------------------------- | ----------- |
| **hero** | [<mark style="color:purple;">**`CHero`**</mark>](/api-v2.0/game-components/core/hero.md) |             |

Returns the next respawn time penalty, e.g. buyback.

## <sub>GetPrimaryAttribute</sub>

`Hero.GetPrimaryAttribute(hero):` [<mark style="color:purple;">**`Enum.Attributes`**</mark>](https://uczone.gitbook.io/api-v2.0/game-components/core/pages/VwVljl88Qnl7u9hhqRdw#enum.attributes)

| Name     | Type                                                                                     | Description |
| -------- | ---------------------------------------------------------------------------------------- | ----------- |
| **hero** | [<mark style="color:purple;">**`CHero`**</mark>](/api-v2.0/game-components/core/hero.md) |             |

Returns the hero's primary attribute type.

## <sub>GetStrength</sub>

`Hero.GetStrength(hero):` <mark style="color:purple;">**`number`**</mark>

| Name     | Type                                                                                     | Description |
| -------- | ---------------------------------------------------------------------------------------- | ----------- |
| **hero** | [<mark style="color:purple;">**`CHero`**</mark>](/api-v2.0/game-components/core/hero.md) |             |

Returns `white` value of strength.

## <sub>GetAgility</sub>

`Hero.GetAgility(hero):` <mark style="color:purple;">**`number`**</mark>

| Name     | Type                                                                                     | Description |
| -------- | ---------------------------------------------------------------------------------------- | ----------- |
| **hero** | [<mark style="color:purple;">**`CHero`**</mark>](/api-v2.0/game-components/core/hero.md) |             |

Returns `white` value of agility.

## <sub>GetIntellect</sub>

`Hero.GetIntellect(hero):` <mark style="color:purple;">**`number`**</mark>

| Name     | Type                                                                                     | Description |
| -------- | ---------------------------------------------------------------------------------------- | ----------- |
| **hero** | [<mark style="color:purple;">**`CHero`**</mark>](/api-v2.0/game-components/core/hero.md) |             |

Returns `white` value of intellect.

## <sub>GetStrengthTotal</sub>

`Hero.GetStrengthTotal(hero):` <mark style="color:purple;">**`number`**</mark>

| Name     | Type                                                                                     | Description |
| -------- | ---------------------------------------------------------------------------------------- | ----------- |
| **hero** | [<mark style="color:purple;">**`CHero`**</mark>](/api-v2.0/game-components/core/hero.md) |             |

Returns total value of strength.

## <sub>GetAgilityTotal</sub>

`Hero.GetAgilityTotal(hero):` <mark style="color:purple;">**`number`**</mark>

| Name     | Type                                                                                     | Description |
| -------- | ---------------------------------------------------------------------------------------- | ----------- |
| **hero** | [<mark style="color:purple;">**`CHero`**</mark>](/api-v2.0/game-components/core/hero.md) |             |

Returns total value of agility.

## <sub>GetIntellectTotal</sub>

`Hero.GetIntellectTotal(hero):` <mark style="color:purple;">**`number`**</mark>

| Name     | Type                                                                                     | Description |
| -------- | ---------------------------------------------------------------------------------------- | ----------- |
| **hero** | [<mark style="color:purple;">**`CHero`**</mark>](/api-v2.0/game-components/core/hero.md) |             |

Returns total value of intellect.

## <sub>GetLastHurtTime</sub>

`Hero.GetLastHurtTime(hero):` <mark style="color:purple;">**`number`**</mark>

| Name     | Type                                                                                     | Description |
| -------- | ---------------------------------------------------------------------------------------- | ----------- |
| **hero** | [<mark style="color:purple;">**`CHero`**</mark>](/api-v2.0/game-components/core/hero.md) |             |

Returns the time when the hero was last hurt.

## <sub>GetHurtAmount</sub>

`Hero.GetHurtAmount(hero):` <mark style="color:purple;">**`number`**</mark>

| Name     | Type                                                                                     | Description |
| -------- | ---------------------------------------------------------------------------------------- | ----------- |
| **hero** | [<mark style="color:purple;">**`CHero`**</mark>](/api-v2.0/game-components/core/hero.md) |             |

Returns the amount of damage the hero last received.

## <sub>GetRecentDamage</sub>

`Hero.GetRecentDamage(hero):` <mark style="color:purple;">**`integer`**</mark>

| Name     | Type                                                                                     | Description |
| -------- | ---------------------------------------------------------------------------------------- | ----------- |
| **hero** | [<mark style="color:purple;">**`CHero`**</mark>](/api-v2.0/game-components/core/hero.md) |             |

Returns the damage taken by the hero in the last in \~1 second.

## <sub>GetPainFactor</sub>

`Hero.GetPainFactor(hero):` <mark style="color:purple;">**`number`**</mark>

| Name     | Type                                                                                     | Description |
| -------- | ---------------------------------------------------------------------------------------- | ----------- |
| **hero** | [<mark style="color:purple;">**`CHero`**</mark>](/api-v2.0/game-components/core/hero.md) |             |

Returns the pain factor of the hero. Not sure what it is.

## <sub>GetTargetPainFactor</sub>

`Hero.GetTargetPainFactor(hero):` <mark style="color:purple;">**`number`**</mark>

| Name     | Type                                                                                     | Description |
| -------- | ---------------------------------------------------------------------------------------- | ----------- |
| **hero** | [<mark style="color:purple;">**`CHero`**</mark>](/api-v2.0/game-components/core/hero.md) |             |

Returns the pain factor of the hero's target. Not sure what it is.

## <sub>GetLifeState</sub>

`Hero.GetLifeState(hero):` <mark style="color:purple;">**`boolean`**</mark>

| Name     | Type                                                                                     | Description |
| -------- | ---------------------------------------------------------------------------------------- | ----------- |
| **hero** | [<mark style="color:purple;">**`CHero`**</mark>](/api-v2.0/game-components/core/hero.md) |             |

Returns `true` if the hero is alive. Recommended to use `Entity.IsAlive` instead.

## <sub>GetPlayerID</sub>

`Hero.GetPlayerID(hero):` <mark style="color:purple;">**`integer`**</mark>

| Name     | Type                                                                                     | Description |
| -------- | ---------------------------------------------------------------------------------------- | ----------- |
| **hero** | [<mark style="color:purple;">**`CHero`**</mark>](/api-v2.0/game-components/core/hero.md) |             |

Returns the ID of the hero player.

## <sub>GetReplicatingOtherHeroModel</sub>

`Hero.GetReplicatingOtherHeroModel(hero):` [<mark style="color:purple;">**`CHero`**</mark>](/api-v2.0/game-components/core/hero.md) | <mark style="color:purple;">**`nil`**</mark>

| Name     | Type                                                                                     | Description |
| -------- | ---------------------------------------------------------------------------------------- | ----------- |
| **hero** | [<mark style="color:purple;">**`CHero`**</mark>](/api-v2.0/game-components/core/hero.md) |             |

If the hero is an illusion, Arc's copy, Meepo clone, etc. returns the original hero, otherwise returns nil.

## <sub>TalentIsLearned</sub>

`Hero.TalentIsLearned(hero, talent):` <mark style="color:purple;">**`boolean`**</mark>

| Name       | Type                                                                                                                                                             | Description |
| ---------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------- |
| **hero**   | [<mark style="color:purple;">**`CHero`**</mark>](/api-v2.0/game-components/core/hero.md)                                                                         |             |
| **talent** | [<mark style="color:purple;">**`Enum.TalentTypes`**</mark>](https://uczone.gitbook.io/api-v2.0/game-components/core/pages/VwVljl88Qnl7u9hhqRdw#enum.talenttypes) |             |

Returns `true` if talent is learned.

#### Example

```lua
TALENT_8 <=> TALENT_7
TALENT_6 <=> TALENT_5
TALENT_4 <=> TALENT_3
TALENT_2 <=> TALENT_1
```

## <sub>GetFacetAbilities</sub>

`Hero.GetFacetAbilities(hero):` [<mark style="color:purple;">**`CAbility[]`**</mark>](/api-v2.0/game-components/core/ability.md)

| Name     | Type                                                                                     | Description |
| -------- | ---------------------------------------------------------------------------------------- | ----------- |
| **hero** | [<mark style="color:purple;">**`CHero`**</mark>](/api-v2.0/game-components/core/hero.md) |             |

Returns facet ability array.

## <sub>GetFacetID</sub>

`Hero.GetFacetID(hero):` <mark style="color:purple;">**`integer`**</mark>

| Name     | Type                                                                                     | Description |
| -------- | ---------------------------------------------------------------------------------------- | ----------- |
| **hero** | [<mark style="color:purple;">**`CHero`**</mark>](/api-v2.0/game-components/core/hero.md) |             |

Returns facet id. Start from 1.

## <sub>GetLastMaphackPos</sub>

`Hero.GetLastMaphackPos(hero):` [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md) | <mark style="color:purple;">**`nil`**</mark>

| Name     | Type                                                                                     | Description |
| -------- | ---------------------------------------------------------------------------------------- | ----------- |
| **hero** | [<mark style="color:purple;">**`CHero`**</mark>](/api-v2.0/game-components/core/hero.md) |             |

Returns the last hero pos from maphack.

## <sub>GetLastVisibleTime</sub>

`Hero.GetLastVisibleTime(hero):` <mark style="color:purple;">**`number`**</mark> | <mark style="color:purple;">**`nil`**</mark>

| Name     | Type                                                                                     | Description |
| -------- | ---------------------------------------------------------------------------------------- | ----------- |
| **hero** | [<mark style="color:purple;">**`CHero`**</mark>](/api-v2.0/game-components/core/hero.md) |             |

Returns the last visible time from VBE.
