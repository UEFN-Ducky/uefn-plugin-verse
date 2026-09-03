# SETUP: Base timer canvas + default builder. Swap SelectedCanvasType on the controller.
using { /Verse.org/Simulation }
using { /Fortnite.com/UI }
using { /UnrealEngine.com/Temporary/UI }
using { /UnrealEngine.com/Temporary/SpatialMath }
using { /Verse.org/Colors/NamedColors }

# <concrete> so the controller can use it as an @editable default; call BindLeaves with a
# fresh text_block per player before CreateCanvas (never share one widget across players).
timer_canvas <public> := class<concrete>:
    var TimeText : text_block = text_block{DefaultTextColor := White}

    BindLeaves<public>(Time : text_block) : void =
        set TimeText = Time

    CreateCanvas<public>() : canvas =
        canvas:
            Slots := array:
                canvas_slot:
                    Anchors := anchors:
                        Minimum := vector2{X := 0.4, Y := 0.0}
                        Maximum := vector2{X := 0.6, Y := 0.1}
                    Alignment := vector2{X := 0.5, Y := 0.0}
                    Widget := TimeText

default_timer_canvas_builder <public> := class<concrete>(timer_canvas) {}
