# SETUP: Place after Player Core. Wire PlayerManager + CurrencyConfigs.
# OnBegin registers SharedManager as the Currency ?option slot on player_manager.
using { /Verse.org/Simulation }
using { /Fortnite.com/Devices }
using { /Fortnite.com/UI }
using { /UnrealEngine.com/Temporary/UI }
using { /Verse.org/Colors/NamedColors }
using { PlayerCore }

economy_manager_device := class(creative_device):
    Message<localizes>(String : string) : message = "{String}"

    @editable PlayerManager : player_manager = player_manager{}
    @editable CurrencyConfigs : []currency_config = array{}

    SharedManager : economy_manager = economy_manager{}
    var PerPlayer <private> : [agent]economy_manager = map{}
    var AgentCanvases <private> : [agent]canvas = map{}

    var AmountText : text_block = text_block{DefaultTextColor := NamedColors.White}
    var NameText : text_block = text_block{DefaultTextColor := NamedColors.White}
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
        Mgr := economy_manager{}
        Mgr.SetConfig(CurrencyConfigs)
        set Mgr.MyAgent = option{Agent}
        Mgr.EnsureRow(Agent)
        if (set PerPlayer[Agent] = Mgr):
            ShowHUD(Agent)

    OnPlayerLeft(GamePlayer : game_player) : void =
        Agent := GamePlayer.MyAgent
        RemoveHud(Agent)
        var Next : [agent]economy_manager = map{}
        for (Key -> Value : PerPlayer, Key <> Agent):
            set Next = ConcatenateMaps(Next, map{Key => Value})
        set PerPlayer = Next

    ShowHUD(Agent : agent) : void =
        CanvasBuilder.BindLeaves(AmountText, NameText)
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
        Amount := SharedManager.GetCurrency(Agent, 0)
        Name := SharedManager.GetCurrencyName(0)
        AmountText.SetText(Message(SharedManager.FormatAmount(Amount)))
        NameText.SetText(Message(Name))
