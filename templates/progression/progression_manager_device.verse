# SETUP: Place after Player Core. Wire Levels ladder. Subscribes elimination → XP.
# Optional: awards currency via PlayerManager.GetCurrencyProvider()? when Economy pack is present.
using { /Verse.org/Simulation }
using { /Fortnite.com/Devices }
using { /Fortnite.com/UI }
using { /UnrealEngine.com/Temporary/UI }
using { /Verse.org/Colors/NamedColors }
using { PlayerCore }

progression_manager_device := class(creative_device):
    Message<localizes>(String : string) : message = "{String}"

    @editable PlayerManager : player_manager = player_manager{}
    @editable Levels : []player_level_threshold = array{}
    @editable XPPerElimination : int = 25
    @editable CurrencyRewardIndex : int = 0
    @editable CurrencyRewardAmount : float = 10.0

    SharedAwarder : progression_manager = progression_manager{}
    var PerPlayer <private> : [agent]progression_manager = map{}
    var AgentCanvases <private> : [agent]canvas = map{}

    var LevelName : text_block = text_block{DefaultTextColor := NamedColors.White}
    var LevelPercent : text_block = text_block{DefaultTextColor := NamedColors.White}
    var LevelProgressBar : color_block = color_block{DefaultColor := color{R := 1.0, G := 0.84, B := 0.0}}
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
        Mgr := progression_manager{}
        Mgr.SetConfig(Levels)
        set Mgr.MyAgent = option{Agent}
        Mgr.EnsureRow(Agent)
        if (set PerPlayer[Agent] = Mgr):
            ShowHUD(Agent)

    OnPlayerLeft(GamePlayer : game_player) : void =
        Agent := GamePlayer.MyAgent
        RemoveHud(Agent)
        var Next : [agent]progression_manager = map{}
        for (Key -> Value : PerPlayer, Key <> Agent):
            set Next = ConcatenateMaps(Next, map{Key => Value})
        set PerPlayer = Next

    OnElimination(EliminatedPlayer : agent, EliminatingPlayer : ?agent) : void =
        if (Killer := EliminatingPlayer?):
            SharedAwarder.AddXP(Killer, XPPerElimination)
            # Optional economy hook — no-ops if Economy pack not applied
            if (Wallet := PlayerManager.GetCurrencyProvider()?):
                Wallet.AddCurrency(Killer, CurrencyRewardIndex, CurrencyRewardAmount)
            RefreshHUD(Killer)

    ShowHUD(Agent : agent) : void =
        CanvasBuilder.BindLeaves(LevelName, LevelPercent, LevelProgressBar)
        Canvas := CanvasBuilder.CreateCanvas()
        if (AgentCanvases[Agent]):
            RemoveHud(Agent)
        if (PUI := GetPlayerUI[player[Agent]]):
            PUI.AddWidget(Canvas)
            if (set AgentCanvases[Agent] = Canvas):
                RefreshHUD(Agent)

    RemoveHud(Agent : agent) : void =
        if (Canvas := AgentCanvases[Agent], PUI := GetPlayerUI[player[Agent]]):
            PUI.RemoveWidget(Canvas)
        var Next : [agent]canvas = map{}
        for (Key -> Value : AgentCanvases, Key <> Agent):
            set Next = ConcatenateMaps(Next, map{Key => Value})
        set AgentCanvases = Next

    RefreshHUD(Agent : agent) : void =
        Pct := SharedAwarder.ProgressPercent(Agent)
        CanvasBuilder.UpdateProgressBar(Pct)
        LevelName.SetText(Message(SharedAwarder.LevelNameFor(Agent)))
        LevelPercent.SetText(Message("{Pct}%"))
