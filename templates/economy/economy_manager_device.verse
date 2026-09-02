# SETUP: Place after Player Core. Wire PlayerManager + CurrencyConfigs.
# OnBegin registers SharedManager as the Currency ?option slot on player_manager.
using { /Verse.org/Simulation }
using { /Fortnite.com/Devices }
using { /Fortnite.com/UI }
using { /UnrealEngine.com/Temporary/UI }
using { /Verse.org/Colors/NamedColors }
using { PlayerCore }

# Per-player HUD leaves. A widget can only live in one canvas, so never share text_blocks across players.
economy_hud_leaves := class:
    AmountText : text_block
    NameText : text_block

economy_manager_device := class(creative_device):
    Message<localizes>(String : string) : message = "{String}"

    @editable PlayerManager : player_manager = player_manager{}
    @editable CurrencyConfigs : []currency_config = array{}

    SharedManager : economy_manager = economy_manager{}
    var AgentCanvases <private> : [agent]canvas = map{}
    var AgentLeaves <private> : [agent]economy_hud_leaves = map{}
    CanvasBuilder : economy_canvas_builder = economy_canvas_builder{}

    OnBegin<override>()<suspends> : void =
        SharedManager.SetConfig(CurrencyConfigs)
        PlayerManager.RegisterCurrencyProvider(SharedManager)
        PlayerManager.SubscribePlayerConnected(OnPlayerJoined)
        PlayerManager.SubscribePlayerRemoved(OnPlayerLeft)
        InitializeAllAlreadyJoined()

    InitializeAllAlreadyJoined() : void =
        Agents := Self.GetPlayspace().GetPlayers()
        for (Agent : Agents):
            if (GP := PlayerManager.GetGamePlayer(Agent)?):
                OnPlayerJoined(GP)

    OnPlayerJoined(GamePlayer : game_player) : void =
        Agent := GamePlayer.MyAgent
        SharedManager.EnsureRow(Agent)
        ShowHUD(Agent)

    OnPlayerLeft(GamePlayer : game_player) : void =
        RemoveHud(GamePlayer.MyAgent)

    ShowHUD(Agent : agent) : void =
        if (AgentCanvases[Agent]):
            RemoveHud(Agent)
        Leaves := economy_hud_leaves{
            AmountText := text_block{DefaultTextColor := White},
            NameText := text_block{DefaultTextColor := White}
        }
        CanvasBuilder.BindLeaves(Leaves.AmountText, Leaves.NameText)
        Canvas := CanvasBuilder.CreateCanvas()
        if (PUI := GetPlayerUI[player[Agent]]):
            PUI.AddWidget(Canvas)
            if (set AgentCanvases[Agent] = Canvas, set AgentLeaves[Agent] = Leaves):
                RefreshHUD(Agent)

    RemoveHud(Agent : agent) : void =
        if (Canvas := AgentCanvases[Agent], PUI := GetPlayerUI[player[Agent]]):
            PUI.RemoveWidget(Canvas)
        var NextCanvases : [agent]canvas = map{}
        for (Key -> Value : AgentCanvases, Key <> Agent):
            if (set NextCanvases[Key] = Value) {}
        set AgentCanvases = NextCanvases
        var NextLeaves : [agent]economy_hud_leaves = map{}
        for (Key -> Value : AgentLeaves, Key <> Agent):
            if (set NextLeaves[Key] = Value) {}
        set AgentLeaves = NextLeaves

    RefreshHUD<public>(Agent : agent) : void =
        if (Leaves := AgentLeaves[Agent]):
            Amount := SharedManager.GetCurrency(Agent, 0)
            Name := SharedManager.GetCurrencyName(0)
            Leaves.AmountText.SetText(Message(SharedManager.FormatAmount(Amount)))
            Leaves.NameText.SetText(Message(Name))
