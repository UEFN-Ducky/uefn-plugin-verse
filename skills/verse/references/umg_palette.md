---
description: "UEFN UMG palette — classes ListWidgetClasses actually returns, slot type, bindable events, and classes AddWidget rejects"
metadata:
  order: 66
  label: "UMG palette"
  default_enabled: false
  load_condition: "Choosing a UMG widget class, or AddWidget rejected a class name"
---

## UMG palette

Call `list_widget_classes` before any class name. `get_widget_class_info` returns the class description. The lists below are what a live UEFN editor returned. A later build can add classes; the tool result wins.

### Panels

| class | Use |
|-------|-----|
| `CanvasPanel` | Root. Canvas slot: anchors, offsets, alignment, `z_order` |
| `Overlay` | Stacked layers. Overlay slot: padding, alignment |
| `GridPanel` | Fixed grid. Slot: row, column, row_span, column_span |
| `UniformGridPanel` | Equal cells |
| `StackBox` | Vertical or horizontal stack (shop rows) |
| `WrapBox` | Wrapping row |
| `ScrollBox` | Scroll. Slot is padding. There is no Verse scroll-offset API |
| `SizeBox` | Fixed desired size |
| `ScaleBox` | Scale to fit |
| `NamedSlot` | One hole a child User Widget or Verse fills |
| `WidgetSwitcher` | One visible child |
| `UIFrameworkCustomButtonWidget` | Custom Button. Alias `CustomButton` |

### Content

| class | Use |
|-------|-----|
| `Image` | Brush. `properties.brush_material` or `brush_texture` |
| `CommonActionWidget` | Input glyph |
| `ActionWidget` | Input action |
| `DeveloperLayoutButtonProxy` | Editor layout proxy |

Project User Widgets also appear (`BP_TestWidget_C`). Nest those by class name from `list_widget_classes`.

### AddWidget rejects these

Do not pass them. The tool raises before the editor call:

- Text: `Text`, `TextBlock`, `CommonTextBlock`, `RichTextBlock`, `UIFrameworkTextBlock`, `VerseFortniteUIFrameworkTextBlock`. Put the label on a Custom Button or a nested User Widget.
- Preset buttons: `LoudButton`, `QuietButton`, `RegularButton`, and `VerseFortniteUIFrameworkButton_Loud` / `_Quiet` / `_Regular`. The palette button is `CustomButton`.

`Button`, `ProgressBar`, and `Slider` were absent from `ListWidgetClasses`. A float Verse field drives a progress-style value when the class is missing (`umg_recipes` recipe 2).

### Custom Button events

`list_bindable_properties` on `UIFrameworkCustomButtonWidget` includes `OnClicked`, `OnPressed`, `OnReleased`, `OnHovered`, `OnUnhovered`, `OnButtonClicked`, `OnButtonHighlight`, `OnButtonUnhighlight`, plus `IsFocusable`, `RenderOpacity`, `RenderTransform`, `ColorAndOpacity`, `Visibility`. In 42.30 only `OnButtonClicked` / `OnButtonHighlight` / `OnButtonUnhighlight` compile as event-binding sources; the others fail with "The property path … is invalid".

Bind with `bind_widget_event`. Highlight uses `OnButtonHighlight` / `OnButtonUnhighlight`.
