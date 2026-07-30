# SETUP: Canvas builder starter. Pair with a manager device that owns the text_block leaves
# and calls CreateCanvas() from ShowHUD (see sys_hud_template).
using { /Fortnite.com/Devices }
using { /Fortnite.com/UI }
using { /UnrealEngine.com/Temporary/UI }
using { /Verse.org/Colors/NamedColors }
using { /Verse.org/Simulation }

hud_canvas_example := class(creative_device):

    StringToMessage<localizes>(InString : string) : message = "{InString}"

    OnBegin<override>()<suspends>:void =
        Print("hud_canvas_example OnBegin")

    MakeHUDCanvas() : canvas =
        canvas:
            Slots := array:
                canvas_slot:
                    Widget := text_block:
                        DefaultText := StringToMessage("Hello UI")
                        DefaultTextColor := NamedColors.White
