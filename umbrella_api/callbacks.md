> For the complete documentation index, see [llms.txt](https://uczone.gitbook.io/api-v2.0/llms.txt). Markdown versions of documentation pages are available by appending `.md` to page URLs; this page is available as [Markdown](https://uczone.gitbook.io/api-v2.0/cheats-types-and-callbacks/callbacks.md).

# Callbacks

Callbacks for lua Scripts should return a table with the following functions. If the table contains one of the functions below, it will be registered as a callback and will be called at the appropriate time.

## <sub>OnScriptsLoaded</sub>

`Callbacks.OnScriptsLoaded():` <mark style="color:purple;">**`nil`**</mark>

Called after all scripts are loaded.

## <sub>OnGameThreadInit</sub>

`Callbacks.OnGameThreadInit():` <mark style="color:purple;">**`nil`**</mark>

Called once on the game thread after all scripts are loaded, after OnScriptsLoaded.

## <sub>OnDraw</sub>

`Callbacks.OnDraw():` <mark style="color:purple;">**`nil`**</mark>

Called when the game is drawing. Works only in the game.\
Recommended to use for drawing only.

## <sub>OnFrame</sub>

`Callbacks.OnFrame():` <mark style="color:purple;">**`nil`**</mark>

The same as OnDraw, but called in the menu too.

## <sub>OnUpdate</sub>

`Callbacks.OnUpdate():` <mark style="color:purple;">**`nil`**</mark>

Called every game update. Works only in the game.\
Recommended to use for logic.

## <sub>OnPreHumanizer</sub>

`Callbacks.OnPreHumanizer():` <mark style="color:purple;">**`nil`**</mark>

TODO

## <sub>OnUpdateEx</sub>

`Callbacks.OnUpdateEx():` <mark style="color:purple;">**`nil`**</mark>

Called every game update. Same as OnUpdate but as well called in the menu.\
Recommended to use for logic.

## <sub>OnEntityCreate</sub>

`Callbacks.OnEntityCreate(entity):` <mark style="color:purple;">**`nil`**</mark>

| Name       | Type                                                                                         | Description                  |
| ---------- | -------------------------------------------------------------------------------------------- | ---------------------------- |
| **entity** | [<mark style="color:purple;">**`CEntity`**</mark>](/api-v2.0/game-components/core/entity.md) | The entity that was created. |

Called when a new entity is created.

## <sub>OnNpcSpawned</sub>

`Callbacks.OnNpcSpawned(npc):` <mark style="color:purple;">**`nil`**</mark>

| Name    | Type                                                                                   | Description                                                         |
| ------- | -------------------------------------------------------------------------------------- | ------------------------------------------------------------------- |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | The npc that was spawned. No respawn flag is supplied by this hook. |

Called on the client after an NPC finishes spawning, independently of the npc\_spawned game event.

## <sub>OnEntityDestroy</sub>

`Callbacks.OnEntityDestroy(entity):` <mark style="color:purple;">**`nil`**</mark>

| Name       | Type                                                                                         | Description                    |
| ---------- | -------------------------------------------------------------------------------------------- | ------------------------------ |
| **entity** | [<mark style="color:purple;">**`CEntity`**</mark>](/api-v2.0/game-components/core/entity.md) | The entity that was destroyed. |

Called when an entity is destroyed.

## <sub>OnModifierCreate</sub>

`Callbacks.OnModifierCreate(entity, modifier):` <mark style="color:purple;">**`nil`**</mark>

| Name         | Type                                                                                             | Description                       |
| ------------ | ------------------------------------------------------------------------------------------------ | --------------------------------- |
| **entity**   | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md)           | The entity that has the modifier. |
| **modifier** | [<mark style="color:purple;">**`CModifier`**</mark>](/api-v2.0/game-components/core/modifier.md) | The modifier that was created.    |

Called when a modifier is created.

## <sub>OnModifierDestroy</sub>

`Callbacks.OnModifierDestroy(entity, modifier):` <mark style="color:purple;">**`nil`**</mark>

| Name         | Type                                                                                             | Description                       |
| ------------ | ------------------------------------------------------------------------------------------------ | --------------------------------- |
| **entity**   | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md)           | The entity that has the modifier. |
| **modifier** | [<mark style="color:purple;">**`CModifier`**</mark>](/api-v2.0/game-components/core/modifier.md) | The modifier that was destroyed.  |

Called when a modifier is destroyed.

## <sub>OnModifierUpdate</sub>

`Callbacks.OnModifierUpdate(entity, modifier):` <mark style="color:purple;">**`nil`**</mark>

| Name         | Type                                                                                             | Description                       |
| ------------ | ------------------------------------------------------------------------------------------------ | --------------------------------- |
| **entity**   | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md)           | The entity that has the modifier. |
| **modifier** | [<mark style="color:purple;">**`CModifier`**</mark>](/api-v2.0/game-components/core/modifier.md) | The modifier that was updated.    |

Called when a modifier is updated/refreshed.

## <sub>OnEntityHurt</sub>

{% hint style="info" %}
This callback is called only in unsafe mode.
{% endhint %}

`Callbacks.OnEntityHurt(data):` <mark style="color:purple;">**`nil`**</mark>

| Name     | Type                                                                                                                                                                                                                                                       | Description               |
| -------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------- |
| **data** | <mark style="color:purple;">**`{source:CEntity`**</mark> \| <mark style="color:purple;">**`nil, target:CEntity`**</mark> \| <mark style="color:purple;">**`nil, ability:CAbility`**</mark> \| <mark style="color:purple;">**`nil, damage:number}`**</mark> | The data about the event. |

Called when an entity is hurt.

## <sub>OnEntityKilled</sub>

{% hint style="info" %}
This callback is called only in unsafe mode.
{% endhint %}

`Callbacks.OnEntityKilled(data):` <mark style="color:purple;">**`nil`**</mark>

| Name     | Type                                                                                                                                                                                                                                        | Description               |
| -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------- |
| **data** | <mark style="color:purple;">**`{source:CEntity`**</mark> \| <mark style="color:purple;">**`nil, target:CEntity`**</mark> \| <mark style="color:purple;">**`nil, ability:CAbility`**</mark> \| <mark style="color:purple;">**`nil}`**</mark> | The data about the event. |

Called when an entity is killed.

## <sub>OnFireEventClient</sub>

{% hint style="info" %}
This callback is called only in unsafe mode.
{% endhint %}

\`Callbacks.OnFireEventClient(data):\` <mark style="color:purple;">\*\*\`nil\`\*\*</mark>

| Name     | Type                                                                 | Description               |
| -------- | -------------------------------------------------------------------- | ------------------------- |
| **data** | <mark style="color:purple;">**`{name:string, event:CEvent}`**</mark> | The data about the event. |

Called when a game event is fired.

## <sub>OnUnitAnimation</sub>

`Callbacks.OnUnitAnimation(data):` <mark style="color:purple;">**`nil`**</mark>

| Name                          | Type                                                                                   | Description                         |
| ----------------------------- | -------------------------------------------------------------------------------------- | ----------------------------------- |
| **data**                      | <mark style="color:purple;">**`table`**</mark>                                         | The data about the event.           |
|  .**unit**                    | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | The unit that played the animation. |
|  .**sequenceVariant**         | <mark style="color:purple;">**`number`**</mark>                                        | The sequence variant.               |
|  .**playbackRate**            | <mark style="color:purple;">**`number`**</mark>                                        | The playback rate.                  |
|  .**castpoint**               | <mark style="color:purple;">**`number`**</mark>                                        | The castpoint.                      |
|  .**type**                    | <mark style="color:purple;">**`integer`**</mark>                                       | The type.                           |
|  .**activity**                | <mark style="color:purple;">**`integer`**</mark>                                       | The activity.                       |
|  .**sequence**                | <mark style="color:purple;">**`integer`**</mark>                                       | The sequence.                       |
|  .**sequenceName**            | <mark style="color:purple;">**`string`**</mark>                                        | The sequence name.                  |
|  .**lag\_compensation\_time** | <mark style="color:purple;">**`number`**</mark>                                        | The lag compensation time.          |

Called when a unit animation is played.

## <sub>OnUnitAnimationEnd</sub>

`Callbacks.OnUnitAnimationEnd(data):` <mark style="color:purple;">**`nil`**</mark>

| Name       | Type                                                                                   | Description                         |
| ---------- | -------------------------------------------------------------------------------------- | ----------------------------------- |
| **data**   | <mark style="color:purple;">**`table`**</mark>                                         | The data about the event.           |
|  .**unit** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | The unit that played the animation. |
|  .**snap** | <mark style="color:purple;">**`boolean`**</mark>                                       | The snap.                           |

Called when a unit animation ends.

## <sub>OnProjectile</sub>

`Callbacks.OnProjectile(data):` <mark style="color:purple;">**`nil`**</mark>

| Name                                                            | Type                                                                                                           | Description                                            |
| --------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------ |
| **data**                                                        | <mark style="color:purple;">**`table`**</mark>                                                                 | The data about the event.                              |
|  .**source&#x20;**<mark style="color:orange;">**`[?]`**</mark>  | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md)                         | The source entity. `(default: nil)`                    |
|  .**target&#x20;**<mark style="color:orange;">**`[?]`**</mark>  | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md)                         | The target entity. `(default: nil)`                    |
|  .**ability&#x20;**<mark style="color:orange;">**`[?]`**</mark> | [<mark style="color:purple;">**`CAbility`**</mark>](/api-v2.0/game-components/core/ability.md)                 | The ability linked to the projectile. `(default: nil)` |
|  .**moveSpeed**                                                 | <mark style="color:purple;">**`integer`**</mark>                                                               | The move speed.                                        |
|  .**sourceAttachment**                                          | <mark style="color:purple;">**`integer`**</mark>                                                               | The source attachment.                                 |
|  .**particleSystemHandle**                                      | <mark style="color:purple;">**`integer`**</mark>                                                               | The particle system handle.                            |
|  .**dodgeable**                                                 | <mark style="color:purple;">**`boolean`**</mark>                                                               | The dodgeable.                                         |
|  .**isAttack**                                                  | <mark style="color:purple;">**`boolean`**</mark>                                                               | The is attack.                                         |
|  .**expireTime**                                                | <mark style="color:purple;">**`number`**</mark>                                                                | The expire time.                                       |
|  .**maxImpactTime**                                             | <mark style="color:purple;">**`number`**</mark>                                                                | The max impact time.                                   |
|  .**launch\_tick**                                              | <mark style="color:purple;">**`integer`**</mark>                                                               | The tick the pojectile was launched.                   |
|  .**colorGemColor**                                             | <mark style="color:purple;">**`integer`**</mark>                                                               | The color gem color.                                   |
|  .**fullName**                                                  | <mark style="color:purple;">**`string`**</mark>                                                                | The full name of projectile.                           |
|  .**name**                                                      | <mark style="color:purple;">**`string`**</mark>                                                                | The short name of projectile.                          |
|  .**handle**                                                    | <mark style="color:purple;">**`integer`**</mark>                                                               | The handle of projectile.                              |
|  .**target\_loc**                                               | [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md) | The location of the target.                            |
|  .**original\_move\_speed**                                     | <mark style="color:purple;">**`integer`**</mark>                                                               | The original move speed.                               |

Called when new projectile is created.

## <sub>OnTargetProjectileDestroy</sub>

`Callbacks.OnTargetProjectileDestroy(data):` <mark style="color:purple;">**`nil`**</mark>

| Name                                                            | Type                                                                                                           | Description                                            |
| --------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------ |
| **data**                                                        | <mark style="color:purple;">**`table`**</mark>                                                                 | The data about the event.                              |
|  .**source&#x20;**<mark style="color:orange;">**`[?]`**</mark>  | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md)                         | The source entity. `(default: nil)`                    |
|  .**target&#x20;**<mark style="color:orange;">**`[?]`**</mark>  | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md)                         | The target entity. `(default: nil)`                    |
|  .**ability&#x20;**<mark style="color:orange;">**`[?]`**</mark> | [<mark style="color:purple;">**`CAbility`**</mark>](/api-v2.0/game-components/core/ability.md)                 | The ability linked to the projectile. `(default: nil)` |
|  .**moveSpeed**                                                 | <mark style="color:purple;">**`integer`**</mark>                                                               | The move speed.                                        |
|  .**dodgeable**                                                 | <mark style="color:purple;">**`boolean`**</mark>                                                               | The dodgeable.                                         |
|  .**isAttack**                                                  | <mark style="color:purple;">**`boolean`**</mark>                                                               | The is attack.                                         |
|  .**expireTime**                                                | <mark style="color:purple;">**`number`**</mark>                                                                | The expire time.                                       |
|  .**maxImpactTime**                                             | <mark style="color:purple;">**`number`**</mark>                                                                | The max impact time.                                   |
|  .**handle**                                                    | <mark style="color:purple;">**`integer`**</mark>                                                               | The handle of projectile.                              |
|  .**target\_loc**                                               | [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md) | The location of the target.                            |
|  .**location**                                                  | [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md) | The location of the projectile when it was destroyed.  |
|  .**original\_move\_speed**                                     | <mark style="color:purple;">**`integer`**</mark>                                                               | The original move speed.                               |

Called when a target projectile is destroyed.

## <sub>OnProjectileLoc</sub>

`Callbacks.OnProjectileLoc(data):` <mark style="color:purple;">**`nil`**</mark>

| Name                                                           | Type                                                                                                           | Description                         |
| -------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- | ----------------------------------- |
| **data**                                                       | <mark style="color:purple;">**`table`**</mark>                                                                 | The data about the event.           |
|  .**source&#x20;**<mark style="color:orange;">**`[?]`**</mark> | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md)                         | The source entity. `(default: nil)` |
|  .**target&#x20;**<mark style="color:orange;">**`[?]`**</mark> | [<mark style="color:purple;">**`CEntity`**</mark>](/api-v2.0/game-components/core/entity.md)                   | The target entity. `(default: nil)` |
|  .**sourceLoc**                                                | [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md) | The source location.                |
|  .**targetLoc**                                                | [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md) | The target location.                |
|  .**moveSpeed**                                                | <mark style="color:purple;">**`integer`**</mark>                                                               | The move speed.                     |
|  .**original\_move\_speed**                                    | <mark style="color:purple;">**`integer`**</mark>                                                               | The original move speed.            |
|  .**particleSystemHandle**                                     | <mark style="color:purple;">**`integer`**</mark>                                                               | The particle system handle.         |
|  .**dodgeable**                                                | <mark style="color:purple;">**`boolean`**</mark>                                                               | The dodgeable.                      |
|  .**isAttack**                                                 | <mark style="color:purple;">**`boolean`**</mark>                                                               | The is attack.                      |
|  .**expireTime**                                               | <mark style="color:purple;">**`number`**</mark>                                                                | The expire time.                    |
|  .**colorGemColor**                                            | <mark style="color:purple;">**`integer`**</mark>                                                               | The color gem color.                |
|  .**launchTick**                                               | <mark style="color:purple;">**`integer`**</mark>                                                               | The launch tick.                    |
|  .**handle**                                                   | <mark style="color:purple;">**`integer`**</mark>                                                               | The handle of projectile.           |
|  .**fullName**                                                 | <mark style="color:purple;">**`string`**</mark>                                                                | The full name of projectile.        |
|  .**name**                                                     | <mark style="color:purple;">**`string`**</mark>                                                                | The short name of projectile.       |

Called when new projectile loc is created.

## <sub>OnLinearProjectileCreate</sub>

`Callbacks.OnLinearProjectileCreate(data):` <mark style="color:purple;">**`nil`**</mark>

| Name                                                           | Type                                                                                                           | Description                         |
| -------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- | ----------------------------------- |
| **data**                                                       | <mark style="color:purple;">**`table`**</mark>                                                                 | The data about the event.           |
|  .**source&#x20;**<mark style="color:orange;">**`[?]`**</mark> | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md)                         | The source entity. `(default: nil)` |
|  .**origin**                                                   | [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md) | The origin.                         |
|  .**velocity**                                                 | [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md) | The velocity.                       |
|  .**particleIndex**                                            | <mark style="color:purple;">**`integer`**</mark>                                                               | The particle index.                 |
|  .**handle**                                                   | <mark style="color:purple;">**`integer`**</mark>                                                               | The handle of projectile.           |
|  .**acceleration**                                             | [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md) | The acceleration.                   |
|  .**maxSpeed**                                                 | <mark style="color:purple;">**`number`**</mark>                                                                | The max speed.                      |
|  .**fowRadius**                                                | <mark style="color:purple;">**`number`**</mark>                                                                | The fow radius.                     |
|  .**distance**                                                 | <mark style="color:purple;">**`number`**</mark>                                                                | The distance.                       |
|  .**colorGemColor**                                            | <mark style="color:purple;">**`integer`**</mark>                                                               | The color gem color.                |
|  .**fullName**                                                 | <mark style="color:purple;">**`string`**</mark>                                                                | The full name of projectile.        |
|  .**name**                                                     | <mark style="color:purple;">**`string`**</mark>                                                                | The short name of projectile.       |

Called when new linear projectile is created.

## <sub>OnLinearProjectileDestroy</sub>

`Callbacks.OnLinearProjectileDestroy(data):` <mark style="color:purple;">**`nil`**</mark>

| Name         | Type                                             | Description               |
| ------------ | ------------------------------------------------ | ------------------------- |
| **data**     | <mark style="color:purple;">**`table`**</mark>   | The data about the event. |
|  .**handle** | <mark style="color:purple;">**`integer`**</mark> | The handle of projectile. |

Called when linear projectile is destroyed.

## <sub>OnParticleCreate</sub>

`Callbacks.OnParticleCreate(data):` <mark style="color:purple;">**`nil`**</mark>

| Name                                                                       | Type                                                                                                                                                                                 | Description                                |
| -------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------ |
| **data**                                                                   | <mark style="color:purple;">**`table`**</mark>                                                                                                                                       | The data about the event.                  |
|  .**index**                                                                | <mark style="color:purple;">**`integer`**</mark>                                                                                                                                     | The index of particle.                     |
|  .**entity&#x20;**<mark style="color:orange;">**`[?]`**</mark>             | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md)                                                                                               | The entity. `(default: nil)`               |
|  .**entity\_id**                                                           | <mark style="color:purple;">**`integer`**</mark>                                                                                                                                     | The entity id.                             |
|  .**entityForModifiers&#x20;**<mark style="color:orange;">**`[?]`**</mark> | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md)                                                                                               | The entity for modifiers. `(default: nil)` |
|  .**entity\_for\_modifiers\_id**                                           | <mark style="color:purple;">**`integer`**</mark>                                                                                                                                     | The entity for modifiers id.               |
|  .**attachType**                                                           | [<mark style="color:purple;">**`Enum.ParticleAttachment`**</mark>](https://uczone.gitbook.io/api-v2.0/cheats-types-and-callbacks/pages/VwVljl88Qnl7u9hhqRdw#enum.particleattachment) | The attach type.                           |
|  .**fullName**                                                             | <mark style="color:purple;">**`string`**</mark>                                                                                                                                      | The full name of particle.                 |
|  .**name**                                                                 | <mark style="color:purple;">**`string`**</mark>                                                                                                                                      | The short name of particle.                |
|  .**hash**                                                                 | <mark style="color:purple;">**`integer`**</mark>                                                                                                                                     | The hash of particle.                      |
|  .**particleNameIndex**                                                    | <mark style="color:purple;">**`integer`**</mark>                                                                                                                                     | The particle name index.                   |

Called when new particle is created.

## <sub>OnParticleUpdate</sub>

`Callbacks.OnParticleUpdate(data):` <mark style="color:purple;">**`nil`**</mark>

| Name               | Type                                                                                                           | Description               |
| ------------------ | -------------------------------------------------------------------------------------------------------------- | ------------------------- |
| **data**           | <mark style="color:purple;">**`table`**</mark>                                                                 | The data about the event. |
|  .**index**        | <mark style="color:purple;">**`integer`**</mark>                                                               | The index of particle.    |
|  .**controlPoint** | <mark style="color:purple;">**`integer`**</mark>                                                               | The control point.        |
|  .**position**     | [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md) | The position.             |

Called when particle is updated.

## <sub>OnParticleUpdateFallback</sub>

`Callbacks.OnParticleUpdateFallback(data):` <mark style="color:purple;">**`nil`**</mark>

| Name               | Type                                                                                                           | Description               |
| ------------------ | -------------------------------------------------------------------------------------------------------------- | ------------------------- |
| **data**           | <mark style="color:purple;">**`table`**</mark>                                                                 | The data about the event. |
|  .**index**        | <mark style="color:purple;">**`integer`**</mark>                                                               | The index of particle.    |
|  .**controlPoint** | <mark style="color:purple;">**`integer`**</mark>                                                               | The control point.        |
|  .**position**     | [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md) | The position.             |

Called when particle is updated. Alternative version for some particles.

## <sub>OnParticleUpdateEntity</sub>

`Callbacks.OnParticleUpdateEntity(data):` <mark style="color:purple;">**`nil`**</mark>

| Name                                                                   | Type                                                                                                                                                                                 | Description                           |
| ---------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------- |
| **data**                                                               | <mark style="color:purple;">**`table`**</mark>                                                                                                                                       | The data about the event.             |
|  .**index**                                                            | <mark style="color:purple;">**`integer`**</mark>                                                                                                                                     | The index of particle.                |
|  .**controlPoint**                                                     | <mark style="color:purple;">**`integer`**</mark>                                                                                                                                     | The control point.                    |
|  .**entity&#x20;**<mark style="color:orange;">**`[?]`**</mark>         | [<mark style="color:purple;">**`CEntity`**</mark>](/api-v2.0/game-components/core/entity.md)                                                                                         | The entity. `(default: nil)`          |
|  .**entIdx**                                                           | <mark style="color:purple;">**`integer`**</mark>                                                                                                                                     | The entity id.                        |
|  .**attachType**                                                       | [<mark style="color:purple;">**`Enum.ParticleAttachment`**</mark>](https://uczone.gitbook.io/api-v2.0/cheats-types-and-callbacks/pages/VwVljl88Qnl7u9hhqRdw#enum.particleattachment) | The attach type.                      |
|  .**attachmentName&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`string`**</mark>                                                                                                                                      | The attachment name. `(default: nil)` |
|  .**position**                                                         | [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md)                                                                       | The position.                         |
|  .**includeWearables**                                                 | <mark style="color:purple;">**`boolean`**</mark>                                                                                                                                     | Include wearables.                    |

Called when particle is updated on entity.

## <sub>OnParticleDestroy</sub>

`Callbacks.OnParticleDestroy(data):` <mark style="color:purple;">**`nil`**</mark>

| Name                     | Type                                             | Description                      |
| ------------------------ | ------------------------------------------------ | -------------------------------- |
| **data**                 | <mark style="color:purple;">**`table`**</mark>   | The data about the event.        |
|  .**index**              | <mark style="color:purple;">**`integer`**</mark> | The index of destroyed particle. |
|  .**destroyImmediately** | <mark style="color:purple;">**`boolean`**</mark> | Destroy immediately.             |

Called when particle is destroyed.

## <sub>OnStartSound</sub>

`Callbacks.OnStartSound(data):` <mark style="color:purple;">**`nil`**</mark>

| Name                                                           | Type                                                                                                           | Description                           |
| -------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- | ------------------------------------- |
| **data**                                                       | <mark style="color:purple;">**`table`**</mark>                                                                 | The data about the event.             |
|  .**source&#x20;**<mark style="color:orange;">**`[?]`**</mark> | [<mark style="color:purple;">**`CEntity`**</mark>](/api-v2.0/game-components/core/entity.md)                   | The source of sound. `(default: nil)` |
|  .**hash**                                                     | <mark style="color:purple;">**`integer`**</mark>                                                               | The hash of sound.                    |
|  .**guid**                                                     | <mark style="color:purple;">**`integer`**</mark>                                                               | The guid of sound.                    |
|  .**seed**                                                     | <mark style="color:purple;">**`integer`**</mark>                                                               | The seed of sound.                    |
|  .**name**                                                     | <mark style="color:purple;">**`string`**</mark>                                                                | The name of sound.                    |
|  .**position**                                                 | [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md) | The position of sound.                |

Called when sound is started.

## <sub>OnSpeak</sub>

`Callbacks.OnSpeak(data):` <mark style="color:purple;">**`boolean`**</mark> | <mark style="color:purple;">**`string`**</mark> | <mark style="color:purple;">**`nil`**</mark>

| Name         | Type                                                                                                                                   | Description               |
| ------------ | -------------------------------------------------------------------------------------------------------------------------------------- | ------------------------- |
| **data**     | <mark style="color:purple;">**`table`**</mark>                                                                                         | The data about the event. |
|  .**source** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) \| <mark style="color:purple;">**`nil`**</mark> | The unit who speak.       |
|  .**name**   | <mark style="color:purple;">**`string`**</mark>                                                                                        | The name of the sound.    |

Called every time unit/announcer talk. Return false to prevent the sound from being played, or\
return a sound name to play that sound instead.

## <sub>OnChatEvent</sub>

`Callbacks.OnChatEvent(data):` <mark style="color:purple;">**`nil`**</mark>

| Name              | Type                                             | Description                    |
| ----------------- | ------------------------------------------------ | ------------------------------ |
| **data**          | <mark style="color:purple;">**`table`**</mark>   | The data about the event.      |
|  .**type**        | <mark style="color:purple;">**`integer`**</mark> | The type of chat event.        |
|  .**value**       | <mark style="color:purple;">**`integer`**</mark> | The value of chat event.       |
|  .**value2**      | <mark style="color:purple;">**`integer`**</mark> | The value2 of chat event.      |
|  .**value3**      | <mark style="color:purple;">**`integer`**</mark> | The value3 of chat event.      |
|  .**playerid\_1** | <mark style="color:purple;">**`integer`**</mark> | The playerid\_1 of chat event. |
|  .**playerid\_2** | <mark style="color:purple;">**`integer`**</mark> | The playerid\_2 of chat event. |
|  .**playerid\_3** | <mark style="color:purple;">**`integer`**</mark> | The playerid\_3 of chat event. |
|  .**playerid\_4** | <mark style="color:purple;">**`integer`**</mark> | The playerid\_4 of chat event. |
|  .**playerid\_5** | <mark style="color:purple;">**`integer`**</mark> | The playerid\_5 of chat event. |
|  .**playerid\_6** | <mark style="color:purple;">**`integer`**</mark> | The playerid\_6 of chat event. |

Called on chat event.

## <sub>OnOverHeadEvent</sub>

`Callbacks.OnOverHeadEvent(data):` <mark style="color:purple;">**`nil`**</mark>

| Name     | Type                                                                                                                                                                                                                                                                    | Description                    |
| -------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------ |
| **data** | <mark style="color:purple;">**`{player_source:CPlayer`**</mark> \| <mark style="color:purple;">**`nil, player_target:CPlayer`**</mark> \| <mark style="color:purple;">**`nil, target_npc:CNPC`**</mark> \| <mark style="color:purple;">**`nil, value:integer}`**</mark> | The table with the event info. |

Called on event above the hero's head.

## <sub>OnUnitAddGesture</sub>

`Callbacks.OnUnitAddGesture(data):` <mark style="color:purple;">**`nil`**</mark>

| Name                                                        | Type                                                                                   | Description                                           |
| ----------------------------------------------------------- | -------------------------------------------------------------------------------------- | ----------------------------------------------------- |
| **data**                                                    | <mark style="color:purple;">**`table`**</mark>                                         | The data about the event.                             |
|  .**npc&#x20;**<mark style="color:orange;">**`[?]`**</mark> | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | The unit that is added to a gesture. `(default: nil)` |
|  .**sequenceVariant**                                       | <mark style="color:purple;">**`integer`**</mark>                                       | The sequence variant.                                 |
|  .**playbackRate**                                          | <mark style="color:purple;">**`number`**</mark>                                        | The playback rate.                                    |
|  .**fadeIn**                                                | <mark style="color:purple;">**`number`**</mark>                                        | The fade in.                                          |
|  .**fadeOut**                                               | <mark style="color:purple;">**`number`**</mark>                                        | The fade out.                                         |
|  .**slot**                                                  | <mark style="color:purple;">**`integer`**</mark>                                       | The slot.                                             |
|  .**activity**                                              | <mark style="color:purple;">**`integer`**</mark>                                       | The activity.                                         |
|  .**sequenceName**                                          | <mark style="color:purple;">**`string`**</mark>                                        | The sequence name.                                    |

Called when a unit is added to a gesture.

## <sub>OnPrepareUnitOrders</sub>

`Callbacks.OnPrepareUnitOrders(data):` <mark style="color:purple;">**`boolean`**</mark>

| Name                                                            | Type                                                                                                                                                                               | Description                                                                 |
| --------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------- |
| **data**                                                        | <mark style="color:purple;">**`table`**</mark>                                                                                                                                     | The data about the event.                                                   |
|  .**player&#x20;**<mark style="color:orange;">**`[?]`**</mark>  | [<mark style="color:purple;">**`CPlayer`**</mark>](/api-v2.0/game-components/core/player.md)                                                                                       | The player that issued the order. `(default: nil)`                          |
|  .**order**                                                     | [<mark style="color:purple;">**`Enum.UnitOrder`**</mark>](https://uczone.gitbook.io/api-v2.0/cheats-types-and-callbacks/pages/VwVljl88Qnl7u9hhqRdw#enum.unitorder)                 | The order type.                                                             |
|  .**target&#x20;**<mark style="color:orange;">**`[?]`**</mark>  | [<mark style="color:purple;">**`CEntity`**</mark>](/api-v2.0/game-components/core/entity.md)                                                                                       | The target of the order. `(default: nil)`                                   |
|  .**position**                                                  | [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md)                                                                     | The position of the order.                                                  |
|  .**ability&#x20;**<mark style="color:orange;">**`[?]`**</mark> | [<mark style="color:purple;">**`CAbility`**</mark>](/api-v2.0/game-components/core/ability.md)                                                                                     | The ability of the order. `(default: nil)`                                  |
|  .**orderIssuer**                                               | [<mark style="color:purple;">**`Enum.PlayerOrderIssuer`**</mark>](https://uczone.gitbook.io/api-v2.0/cheats-types-and-callbacks/pages/VwVljl88Qnl7u9hhqRdw#enum.playerorderissuer) | The order issuer.                                                           |
|  .**npc&#x20;**<mark style="color:orange;">**`[?]`**</mark>     | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md)                                                                                             | The unit of the order. `(default: nil)`                                     |
|  .**queue**                                                     | <mark style="color:purple;">**`boolean`**</mark>                                                                                                                                   | If the order is queued.                                                     |
|  .**showEffects**                                               | <mark style="color:purple;">**`boolean`**</mark>                                                                                                                                   | The show effects of the order.                                              |
|  .**identifier**                                                | <mark style="color:purple;">**`string`**</mark>                                                                                                                                    | The identifier passed by the script that issued the order; empty when none. |

Called on every player order. Return false to prevent the order from being executed.

## <sub>OnAddUnitOrder</sub>

`Callbacks.OnAddUnitOrder(data):` <mark style="color:purple;">**`boolean`**</mark>

| Name                                                            | Type                                                                                                                                                                               | Description                                                                 |
| --------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------- |
| **data**                                                        | <mark style="color:purple;">**`table`**</mark>                                                                                                                                     | The data about the event.                                                   |
|  .**player&#x20;**<mark style="color:orange;">**`[?]`**</mark>  | [<mark style="color:purple;">**`CPlayer`**</mark>](/api-v2.0/game-components/core/player.md)                                                                                       | The player that issued the order. `(default: nil)`                          |
|  .**order**                                                     | [<mark style="color:purple;">**`Enum.UnitOrder`**</mark>](https://uczone.gitbook.io/api-v2.0/cheats-types-and-callbacks/pages/VwVljl88Qnl7u9hhqRdw#enum.unitorder)                 | The order type.                                                             |
|  .**target&#x20;**<mark style="color:orange;">**`[?]`**</mark>  | [<mark style="color:purple;">**`CEntity`**</mark>](/api-v2.0/game-components/core/entity.md)                                                                                       | The target of the order. `(default: nil)`                                   |
|  .**position**                                                  | [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md)                                                                     | The position of the order.                                                  |
|  .**ability&#x20;**<mark style="color:orange;">**`[?]`**</mark> | [<mark style="color:purple;">**`CAbility`**</mark>](/api-v2.0/game-components/core/ability.md)                                                                                     | The ability of the order. `(default: nil)`                                  |
|  .**orderIssuer**                                               | [<mark style="color:purple;">**`Enum.PlayerOrderIssuer`**</mark>](https://uczone.gitbook.io/api-v2.0/cheats-types-and-callbacks/pages/VwVljl88Qnl7u9hhqRdw#enum.playerorderissuer) | The order issuer.                                                           |
|  .**npc&#x20;**<mark style="color:orange;">**`[?]`**</mark>     | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md)                                                                                             | The unit of the order. `(default: nil)`                                     |
|  .**queue**                                                     | <mark style="color:purple;">**`boolean`**</mark>                                                                                                                                   | If the order is queued.                                                     |
|  .**showEffects**                                               | <mark style="color:purple;">**`boolean`**</mark>                                                                                                                                   | The show effects of the order.                                              |
|  .**identifier**                                                | <mark style="color:purple;">**`string`**</mark>                                                                                                                                    | The identifier passed by the script that issued the order; empty when none. |

Called when an order is added to a unit. Return false to prevent the order from being added.

## <sub>OnUnitOrderAdded</sub>

`Callbacks.OnUnitOrderAdded(data):` <mark style="color:purple;">**`nil`**</mark>

| Name                                                            | Type                                                                                                                                                                               | Description                                                                 |
| --------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------- |
| **data**                                                        | <mark style="color:purple;">**`table`**</mark>                                                                                                                                     | The data about the event.                                                   |
|  .**player&#x20;**<mark style="color:orange;">**`[?]`**</mark>  | [<mark style="color:purple;">**`CPlayer`**</mark>](/api-v2.0/game-components/core/player.md)                                                                                       | The player that issued the order. `(default: nil)`                          |
|  .**order**                                                     | [<mark style="color:purple;">**`Enum.UnitOrder`**</mark>](https://uczone.gitbook.io/api-v2.0/cheats-types-and-callbacks/pages/VwVljl88Qnl7u9hhqRdw#enum.unitorder)                 | The order type.                                                             |
|  .**target&#x20;**<mark style="color:orange;">**`[?]`**</mark>  | [<mark style="color:purple;">**`CEntity`**</mark>](/api-v2.0/game-components/core/entity.md)                                                                                       | The target of the order. `(default: nil)`                                   |
|  .**position**                                                  | [<mark style="color:purple;">**`Vector`**</mark>](/api-v2.0/cheats-types-and-callbacks/classes/math/vector.md)                                                                     | The position of the order.                                                  |
|  .**ability&#x20;**<mark style="color:orange;">**`[?]`**</mark> | [<mark style="color:purple;">**`CAbility`**</mark>](/api-v2.0/game-components/core/ability.md)                                                                                     | The ability of the order. `(default: nil)`                                  |
|  .**orderIssuer**                                               | [<mark style="color:purple;">**`Enum.PlayerOrderIssuer`**</mark>](https://uczone.gitbook.io/api-v2.0/cheats-types-and-callbacks/pages/VwVljl88Qnl7u9hhqRdw#enum.playerorderissuer) | The order issuer.                                                           |
|  .**npc&#x20;**<mark style="color:orange;">**`[?]`**</mark>     | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md)                                                                                             | The unit of the order. `(default: nil)`                                     |
|  .**queue**                                                     | <mark style="color:purple;">**`boolean`**</mark>                                                                                                                                   | If the order is queued.                                                     |
|  .**showEffects**                                               | <mark style="color:purple;">**`boolean`**</mark>                                                                                                                                   | The show effects of the order.                                              |
|  .**identifier**                                                | <mark style="color:purple;">**`string`**</mark>                                                                                                                                    | The identifier passed by the script that issued the order; empty when none. |

Called after an order has been added to a unit's order queue.

## <sub>OnGCMessage</sub>

`Callbacks.OnGCMessage(data):` <mark style="color:purple;">**`boolean`**</mark>

| Name                                                                         | Type                                              | Description                                                 |
| ---------------------------------------------------------------------------- | ------------------------------------------------- | ----------------------------------------------------------- |
| **data**                                                                     | <mark style="color:purple;">**`table`**</mark>    |                                                             |
|  .**msg\_type**                                                              | <mark style="color:purple;">**`number`**</mark>   | The message type.                                           |
|  .**size**                                                                   | <mark style="color:purple;">**`number`**</mark>   | The size of the message.                                    |
|  .**binary\_buffer\_send&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`userdata`**</mark> | The binary buffer of the send message. `(default: nil)`     |
|  .**binary\_buffer\_recv&#x20;**<mark style="color:orange;">**`[?]`**</mark> | <mark style="color:purple;">**`userdata`**</mark> | The binary buffer of the recieved message. `(default: nil)` |

Called when a game coordinator protobuff message is received. Return false to prevent the message\
from being sent (doesnt work with recieved messages). For more look at GC table description.

#### Example

```lua
-- ongc_message.lua
-- import protobuf and json libraries
local protobuf = require('protobuf');
local JSON = require('assets.JSON');

-- do the stats request
local request = protobuf.encodeFromJSON('CMsgDOTAMatchmakingStatsRequest', JSON:encode({}));
GC.SendMessage( request.binary, 7197, request.size );

return {
    OnGCMessage = function(msg)
        if (msg.msg_type ~= 7198) then
            return true;
        end

        -- decode the response and print it
        local response = protobuf.decodeToJSON('CMsgDOTAMatchmakingStatsResponse', msg.binary_buffer_recv, msg.size);
        Log.Write(response);

        return true;
    end
}
```

## <sub>OnSendNetMessage</sub>

`Callbacks.OnSendNetMessage(data):` <mark style="color:purple;">**`boolean`**</mark>

| Name              | Type                                                   | Description                                                         |
| ----------------- | ------------------------------------------------------ | ------------------------------------------------------------------- |
| **data**          | <mark style="color:purple;">**`table`**</mark>         | The data about the event.                                           |
|  .**message\_id** | <mark style="color:purple;">**`integer`**</mark>       | The message id.                                                     |
|  .**msg\_object** | <mark style="color:purple;">**`lightuserdata`**</mark> | The protobuf message object, borrowed for the duration of the call. |

Called when a net message is sent. Return false to prevent the message from being sent. See\
example

#### Example

```lua
-- onsend_netmsg.lua
-- anti-mute script for dota 2
-- redirects all chat messages to console command 'say' or 'say_team'

-- import protobuf and json libraries
local protobuf = require('protobuf');
local JSON = require('assets.JSON');
return {
    OnSendNetMessage = function(msg)
        if msg.message_id ~= 394 then
            return true;
        end

        -- decode protobuf message to json
        local json_message = JSON:decode(protobuf.decodeToJSONfromObject(msg.msg_object));
        if not json_message then
            return true;
        end

        -- message CDOTAClientMsg_ChatMessage {
        --     optional uint32 channel_type = 1;
        --     optional string message_text = 2;
        -- }

        local text_message = json_message.message_text;
        -- skip commands starting with '-'
        if text_message:find("-") == 1 then
            return true;
        end
    
        -- 11 - all chat 
        if (json_message.channel_type == 11) then
            Engine.ExecuteCommand('say "'..text_message..'"');
            return false;
        -- 12 - team chat
        elseif (json_message.channel_type == 12) then
            Engine.ExecuteCommand('say_team "'..text_message..'"');
            return false;
        end
    end
}
```

## <sub>OnPostReceivedNetMessage</sub>

`Callbacks.OnPostReceivedNetMessage(data):` <mark style="color:purple;">**`nil`**</mark>

| Name              | Type                                                   | Description                                                         |
| ----------------- | ------------------------------------------------------ | ------------------------------------------------------------------- |
| **data**          | <mark style="color:purple;">**`table`**</mark>         | The data about the event.                                           |
|  .**message\_id** | <mark style="color:purple;">**`integer`**</mark>       | The message id.                                                     |
|  .**msg\_object** | <mark style="color:purple;">**`lightuserdata`**</mark> | The protobuf message object, borrowed for the duration of the call. |

Called when a net message is received. The message has already been processed; the handler\
result is ignored.

#### Example

```lua
-- onrecv_netmsg.lua
local protobuf = require('protobuf')
local JSON = require('assets.JSON')
return {
    OnPostReceivedNetMessage = function(msg)
        if msg.message_id == 612 then -- DOTA_UM_ChatMessage https://github.com/SteamDatabase/GameTracking-Dota2/blob/932a8b002f651262ffda6562b758d8ca97c98297/Protobufs/dota_usermessages.proto#L152
            local json = protobuf.decodeToJSONfromObject(msg.msg_object);
            Log.Write(json)
            local lua_table = JSON:decode(json)
            -- ...
        end
    end
}

```

## <sub>OnGameEnd</sub>

`Callbacks.OnGameEnd():` <mark style="color:purple;">**`nil`**</mark>

Called on game end.\
Recommended to use for zeroing.

## <sub>OnKeyEvent</sub>

`Callbacks.OnKeyEvent(data):` <mark style="color:purple;">**`boolean`**</mark>

| Name        | Type                                                                                                                                                                 | Description               |
| ----------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------- |
| **data**    | <mark style="color:purple;">**`table`**</mark>                                                                                                                       | The data about the event. |
|  .**key**   | [<mark style="color:purple;">**`Enum.ButtonCode`**</mark>](https://uczone.gitbook.io/api-v2.0/cheats-types-and-callbacks/pages/VwVljl88Qnl7u9hhqRdw#enum.buttoncode) | The key code.             |
|  .**event** | [<mark style="color:purple;">**`Enum.EKeyEvent`**</mark>](https://uczone.gitbook.io/api-v2.0/cheats-types-and-callbacks/pages/VwVljl88Qnl7u9hhqRdw#enum.ekeyevent)   | Key event.                |

Called on key and mouse input. Return false to prevent the event from being processed.

## <sub>OnTextInput</sub>

`Callbacks.OnTextInput(data):` <mark style="color:purple;">**`nil`**</mark>

| Name      | Type                                             | Description                                |
| --------- | ------------------------------------------------ | ------------------------------------------ |
| **data**  | <mark style="color:purple;">**`table`**</mark>   | The data about the event.                  |
|  .**key** | <mark style="color:purple;">**`integer`**</mark> | The character code of the typed character. |

Called on text input.

## <sub>OnUnitInventoryUpdated</sub>

`Callbacks.OnUnitInventoryUpdated(data):` <mark style="color:purple;">**`nil`**</mark>

| Name     | Type                                                                                   | Description               |
| -------- | -------------------------------------------------------------------------------------- | ------------------------- |
| **data** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | The data about the event. |

Called on unit inventory updated.

## <sub>OnSetDormant</sub>

`Callbacks.OnSetDormant(npc, type):` <mark style="color:purple;">**`nil`**</mark>

| Name     | Type                                                                                                                                                                     | Description         |
| -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------- |
| **npc**  | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md)                                                                                   | The target npc.     |
| **type** | [<mark style="color:purple;">**`Enum.DormancyType`**</mark>](https://uczone.gitbook.io/api-v2.0/cheats-types-and-callbacks/pages/VwVljl88Qnl7u9hhqRdw#enum.dormancytype) | The type of change. |

Called on NPC dormancy state changed.

## <sub>OnGameRulesStateChange</sub>

`Callbacks.OnGameRulesStateChange(data):` <mark style="color:purple;">**`nil`**</mark>

| Name     | Type                                        | Description                         |
| -------- | ------------------------------------------- | ----------------------------------- |
| **data** | <mark style="color:purple;">**`{}`**</mark> | The table with new game state info. |

Called on gamestate change.

## <sub>OnNpcDying</sub>

`Callbacks.OnNpcDying(npc):` <mark style="color:purple;">**`nil`**</mark>

| Name    | Type                                                                                   | Description     |
| ------- | -------------------------------------------------------------------------------------- | --------------- |
| **npc** | [<mark style="color:purple;">**`CNPC`**</mark>](/api-v2.0/game-components/core/npc.md) | The target npc. |

Called on NPC dying.

## <sub>OnPreReload</sub>

`Callbacks.OnPreReload():` <mark style="color:purple;">**`nil`**</mark>

Called before scripts are reloaded.

## <sub>OnThemeUpdate</sub>

`Callbacks.OnThemeUpdate():` <mark style="color:purple;">**`nil`**</mark>

Called when the UI theme colors are changed.\
This includes animated theme transitions (called every frame during animation)\
and manual per-color edits via the theme color picker.
