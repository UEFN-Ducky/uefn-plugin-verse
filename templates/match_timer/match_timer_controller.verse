# SETUP: Place in level. Optional PlayerManager for per-player HUD; works as match-wide timer alone.
using { /Verse.org/Simulation }
using { /Fortnite.com/Devices }
using { /Fortnite.com/UI }
using { /UnrealEngine.com/Temporary/UI }
using { /Verse.org/Colors/NamedColors }
using { PlayerCore }

timer_finished <public> := type{_(FinalTime : float):void}

match_timer_controller := class(creative_device):
    Message<localizes>(String : string) : message = "{String}"

    @editable PlayerManager : player_manager = player_manager{}
    @editable DurationSeconds : float = 60.0
    @editable CountDown : logic = true
    @editable AutoStart : logic = true
    @editable SelectedCanvasType : timer_canvas = default_timer_canvas_builder{}

    var Running <private> : logic = false
    var Elapsed <private> : float = 0.0
    var FinishedSubs <private> : []timer_finished = array{}
    var AgentCanvases <private> : [agent]canvas = map{}
    var TimeText : text_block = text_block{DefaultTextColor := NamedColors.White}

    OnBegin<override>()<suspends> : void =
        PlayerManager.SubscribePlayerConnected(OnPlayerJoined)
        InitializeAllAlreadyJoined()
        if (AutoStart?):
            StartTimer()

    InitializeAllAlreadyJoined() : void =
        Agents := Self.GetPlayspace().GetPlayers()
        for (Agent : Agents):
            if (GP := PlayerManager.GetGamePlayer(Agent)?):
                OnPlayerJoined(GP)

    OnPlayerJoined(GamePlayer : game_player) : void =
        ShowHUD(GamePlayer.MyAgent)

    SubscribeFinished<public>(Cb : timer_finished) : void =
        set FinishedSubs += array{Cb}

    StartTimer<public>() : void =
        if (Running?):
        else:
            set Running = true
            set Elapsed = 0.0
            spawn{ TimerLoop() }

    StopTimer<public>() : void =
        set Running = false

    TimerLoop<private>()<suspends> : void =
        var Last : float = GetSimulationElapsedTime()
        loop:
            if (not Running?):
                break
            Sleep(0.1)
            Now := GetSimulationElapsedTime()
            set Elapsed += Now - Last
            set Last = Now
            RefreshAll()
            if (CountDown?):
                Remaining := DurationSeconds - Elapsed
                if (Remaining <= 0.0):
                    set Running = false
                    for (Cb : FinishedSubs):
                        Cb(DurationSeconds)
                    break
            else:
                if (Elapsed >= DurationSeconds):
                    set Running = false
                    for (Cb : FinishedSubs):
                        Cb(Elapsed)
                    break

    DisplaySeconds()<transacts> : float =
        if (CountDown?):
            Remaining := DurationSeconds - Elapsed
            if (Remaining < 0.0) then 0.0 else Remaining
        else:
            Elapsed

    FormatTime(Seconds : float) : string =
        var Total : int = 0
        if (F := Floor[Seconds]):
            set Total = F
        Mins := Total / 60
        Secs := Total - Mins * 60
        MinStr := if (Mins < 10) then "0{Mins}" else "{Mins}"
        SecStr := if (Secs < 10) then "0{Secs}" else "{Secs}"
        "{MinStr}:{SecStr}"

    ShowHUD(Agent : agent) : void =
        SelectedCanvasType.BindLeaves(TimeText)
        Canvas := SelectedCanvasType.CreateCanvas()
        if (AgentCanvases[Agent]):
            RemoveHud(Agent)
        if (PUI := GetPlayerUI[player[Agent]]):
            PUI.AddWidget(Canvas)
            if (set AgentCanvases[Agent] = Canvas):
                TimeText.SetText(Message(FormatTime(DisplaySeconds())))

    RemoveHud(Agent : agent) : void =
        if (Canvas := AgentCanvases[Agent], PUI := GetPlayerUI[player[Agent]]):
            PUI.RemoveWidget(Canvas)
        var Next : [agent]canvas = map{}
        for (Key -> Value : AgentCanvases, Key <> Agent):
            set Next = ConcatenateMaps(Next, map{Key => Value})
        set AgentCanvases = Next

    RefreshAll() : void =
        Text := FormatTime(DisplaySeconds())
        TimeText.SetText(Message(Text))
