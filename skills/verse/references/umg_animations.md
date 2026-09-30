---
description: "UMG Widget Animations — create, bind, opacity color and transform keys, highlight and loop playback"
metadata:
  order: 70
  label: "UMG widget animations"
  default_enabled: false
  load_condition: "Authoring a UMG Widget Animation, highlight, loop, or color keyframes"
---

## Widget Animations

These are `UWidgetAnimation` tracks, not `play_animation_device`. Verse cannot call `PlayAnimation` by name. Playback is a View Binding (`umg_view_bindings`) or a Verse `logic` / float field the binding watches. Preview in the UMG editor (42.20). Do not Launch Session to check a button animation.

### Tools

1. `create_widget_animation(widget_path, animation_name, length_seconds)`
2. `add_animation_keys(...)` binds the widget, adds the track, and keys it.
3. `list_widget_animations` / `get_widget_blueprint_info` → `animations[].tracks[].key_count`

`track_type`:

| track_type | Track | Channel |
|------------|-------|---------|
| `Opacity` | `RenderOpacity` | one float channel |
| `Color` | `ColorAndOpacity` | `R` `G` `B` `A` |
| `Transform` | `RenderTransform` | `TranslationX` `TranslationY` `ScaleX` `ScaleY` `ShearX` `ShearY` `Angle` |

Keys are `{time, value}` in seconds. Two keys minimum (start pose, end pose). A hover wobble uses three keys (1 → 1.06 → 1). Material-parameter channels on the brush are not a MovieScene track here. Drive `ColorFill` / `ColorShadow` / `ColorStroke` with a Verse float or color field and a conversion (`umg_ui_materials`).

### Custom Button graph

| Widget event | Binding |
|--------------|---------|
| `OnButtonHighlight` | Play `Anim_Highlight` forward, and play `Anim_Loop` looped (template uses 999 loops, speed 1.0) |
| `OnButtonUnhighlight` | Reverse `Anim_Highlight`, stop `Anim_Loop` |
| `OnClicked` | Signal close (`umg_verse_field_events`) |

`bind_widget_event` writes the event → Verse field link. Queue Play / Queue Stop pins (forward, reverse, loop count, speed) are View Binding pins. When that destination is not a field path, keep the animation keys in the asset and trigger them by the field the binding already watches (`TriggerIntro` bool). Auto Play only for motion that starts on construct.

`Anim_Highlight` opacity 0.45 → 1 over 0.35s and `Anim_Loop` scale 1 → 1.06 → 1 over 0.8s is the verified shape (`umg_recipes` recipe 3).
