# SETUP: Place after Player Core. Wire Levels ladder. Subscribes elimination → XP.
# Optional: awards currency via PlayerManager.GetCurrencyProvider()? when Economy pack is present.
using { /Verse.org/Simulation }
using { /Fortnite.com/Devices }
using { /Fortnite.com/UI }
using { /UnrealEngine.com/Temporary/UI }
using { /UnrealEngine.com/Temporary/SpatialMath }
using { /Verse.org/Colors }
using { /Verse.org/Colors/NamedColors }
using { PlayerCore }

# Per-player HUD leaves. A widget can only live in one canvas, so never share widgets across players.
progression_hud_leaves := class:
    LevelName : text_block
    LevelPercent : text_block
    LevelProgressBar : color_block

progression_manager_device := class(creative_device):
    Message<localizes>(String : string) : message = "{String}"

    @editable PlayerManager : player_manager = player_manager{}
    @editable Levels : []player_level_threshold = array{}
    @editable XPPerElimination : int = 25
    @editable CurrencyRewardIndex : int = 0
    @editable CurrencyRewardAmount : float = 10.0

    SharedAwarder : progression_manager = progression_manager{}
    var AgentCanvases <private> : [agent]canvas = map{}
    var AgentLeaves <private> : [agent]progression_hud_leaves = map{}
    CanvasBuilder : progression_canvas_builder = progression_canvas_builder{}

    OnBegin<override>()<suspends> : void =
        SharedAwarder.SetConfig(Levels)
        PlayerManager.RegisterXPAwarder(SharedAwarder)
        PlayerManager.SubscribePlayerConnected(OnPlayerJoined)
        PlayerManager.SubscribePlayerRemoved(OnPlayerLeft)
        PlayerManager.SubscribeElimination(OnElimination)
        InitializeAllAlreadyJoined()

    InitializeAllAlreadyJoined() : void =
        Agents := Self.GetPlayspace().GetPlayers()
        for (Agent : Agents):
            if (GP := PlayerManager.GetGamePlayer(Agent)?):
                OnPlayerJoined(GP)

    OnPlayerJoined(GamePlayer : game_player) : void =
        Agent := GamePlayer.MyAgent
        SharedAwarder.EnsureRow(Agent)
        ShowHUD(Agent)

    OnPlayerLeft(GamePlayer : game_player) : void =
        RemoveHud(GamePlayer.MyAgent)

    OnElimination(EliminatedPlayer : agent, EliminatingPlayer : ?agent) : void =
        if (Killer := EliminatingPlayer?):
            SharedAwarder.AddXP(Killer, XPPerElimination)
            # Optional economy hook — no-ops if Economy pack not applied
            if (Wallet := PlayerManager.GetCurrencyProvider()?):
                Wallet.AddCurrency(Killer, CurrencyRewardIndex, CurrencyRewardAmount)
            RefreshHUD(Killer)

    ShowHUD(Agent : agent) : void =
        if (AgentCanvases[Agent]):
            RemoveHud(Agent)
        Leaves := progression_hud_leaves{
            LevelName := text_block{DefaultTextColor := White},
            LevelPercent := text_block{DefaultTextColor := White},
            LevelProgressBar := color_block{DefaultColor := color{R := 1.0, G := 0.84, B := 0.0}}
        }
        CanvasBuilder.BindLeaves(Leaves.LevelName, Leaves.LevelPercent, Leaves.LevelProgressBar)
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
        var NextLeaves : [agent]progression_hud_leaves = map{}
        for (Key -> Value : AgentLeaves, Key <> Agent):
            if (set NextLeaves[Key] = Value) {}
        set AgentLeaves = NextLeaves

    RefreshHUD<public>(Agent : agent) : void =
        if (Leaves := AgentLeaves[Agent]):
            Pct := SharedAwarder.ProgressPercent(Agent)
            CanvasBuilder.BindLeaves(Leaves.LevelName, Leaves.LevelPercent, Leaves.LevelProgressBar)
            CanvasBuilder.UpdateProgressBar(Pct)
            Leaves.LevelName.SetText(Message(SharedAwarder.LevelNameFor(Agent)))
            Leaves.LevelPercent.SetText(Message("{Pct}%"))
