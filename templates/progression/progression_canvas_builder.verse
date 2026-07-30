# SETUP: Pure UI builder for XP bar + level name.
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/UI }
using { /UnrealEngine.com/Temporary/SpatialMath }
using { /Verse.org/Colors }
using { /Verse.org/Colors/NamedColors }

progression_canvas_builder <public> := class():
    var LevelName : text_block = text_block{}
    var LevelPercent : text_block = text_block{}
    var LevelProgressBar : color_block = color_block{DefaultColor := color{R := 1.0, G := 0.84, B := 0.0}}

    BindLeaves<public>(Name : text_block, Percent : text_block, Bar : color_block) : void =
        set LevelName = Name
        set LevelPercent = Percent
        set LevelProgressBar = Bar

    UpdateProgressBar<public>(Percent : float) : void =
        Clamped := if (Percent < 0.0) then 0.0 else if (Percent > 100.0) then 100.0 else Percent
        BarWidth := (Clamped / 100.0) * 300.0
        LevelProgressBar.SetDesiredSize(vector2{X := BarWidth, Y := 15.0})

    CreateCanvas<public>() : canvas =
        canvas:
            Slots := array:
                canvas_slot:
                    Anchors := anchors:
                        Minimum := vector2{X := 0.65, Y := 0.0}
                        Maximum := vector2{X := 1.0, Y := 0.12}
                    Offsets := margin{Top := 16.0, Left := 0.0, Right := 16.0, Bottom := 0.0}
                    Alignment := vector2{X := 1.0, Y := 0.0}
                    Widget := stack_box:
                        Orientation := orientation.Vertical
                        Slots := array:
                            stack_box_slot:
                                Widget := LevelName
                            stack_box_slot:
                                Widget := LevelProgressBar
                            stack_box_slot:
                                Widget := LevelPercent
