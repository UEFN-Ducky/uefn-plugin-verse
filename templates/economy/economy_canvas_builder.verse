# SETUP: Pure UI builder. economy_manager owns the text_block leaves and passes them in.
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/UI }
using { /UnrealEngine.com/Temporary/SpatialMath }
using { /Verse.org/Colors }
using { /Verse.org/Colors/NamedColors }

economy_canvas_builder <public> := class():
    var AmountText : text_block = text_block{}
    var NameText : text_block = text_block{}

    BindLeaves<public>(Amount : text_block, Name : text_block) : void =
        set AmountText = Amount
        set NameText = Name

    CreateCanvas<public>() : canvas =
        canvas:
            Slots := array:
                canvas_slot:
                    Anchors := anchors:
                        Minimum := vector2{X := 0.0, Y := 0.0}
                        Maximum := vector2{X := 0.35, Y := 0.12}
                    Offsets := margin{Top := 16.0, Left := 16.0, Right := 0.0, Bottom := 0.0}
                    Alignment := vector2{X := 0.0, Y := 0.0}
                    Widget := stack_box:
                        Orientation := orientation.Vertical
                        Slots := array:
                            stack_box_slot:
                                Widget := NameText
                            stack_box_slot:
                                Widget := AmountText
