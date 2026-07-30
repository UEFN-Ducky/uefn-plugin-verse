# SETUP: Place after Player Core. Registers playtime_provider. Flushes on leave.
using { /Verse.org/Simulation }
using { /Fortnite.com/Devices }
using { PlayerCore }

time_tracker_device := class(creative_device):
    @editable PlayerManager : player_manager = player_manager{}

    SharedTracker : player_time_tracker = player_time_tracker{}
    var PerPlayer <private> : [agent]player_time_tracker = map{}

    OnBegin<override>()<suspends> : void =
        PlayerManager.RegisterPlaytimeProvider(SharedTracker)
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
        Tracker := player_time_tracker{}
        set Tracker.MyAgent = option{Agent}
        Tracker.MarkSessionStart(Agent)
        SharedTracker.MarkSessionStart(Agent)
        if (set PerPlayer[Agent] = Tracker):
            {}

    OnPlayerLeft(GamePlayer : game_player) : void =
        Agent := GamePlayer.MyAgent
        if (Tracker := PerPlayer[Agent]):
            Tracker.EndSession(Agent)
        SharedTracker.EndSession(Agent)
        var Next : [agent]player_time_tracker = map{}
        for (Key -> Value : PerPlayer, Key <> Agent):
            set Next = ConcatenateMaps(Next, map{Key => Value})
        set PerPlayer = Next
