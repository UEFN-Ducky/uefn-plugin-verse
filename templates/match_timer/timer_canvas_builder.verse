# SETUP: Base timer canvas + default builder. Swap SelectedCanvasType on the controller.
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/UI }
using { /UnrealEngine.com/Temporary/SpatialMath }
using { /Verse.org/Colors/NamedColors }

timer_canvas <public> := class:
    var TimeText : text_block = text_block{DefaultTextColor := NamedColors.White}

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

default_timer_canvas_builder <public> := class(timer_canvas):
