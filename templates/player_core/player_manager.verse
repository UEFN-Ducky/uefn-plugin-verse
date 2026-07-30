# SETUP: Place ONE player_manager in the level. Wire AllPlayerSpawners (one pad per MaxPlayers).
# Connection slots (?option): Economy / Progression / Playtime register themselves from their packs.
# Consumers: if (Wallet := PlayerManager.GetCurrencyProvider()?): …
using { /Verse.org/Simulation }
using { /Fortnite.com/Devices }
using { /Fortnite.com/Game }
using { /Fortnite.com/Characters }
using { /Verse.org/Random }

# --- Cross-pack connection interfaces (stubs; packs override via subclass / register concrete) ---
currency_provider <public> := class:
    AddCurrency<public>(Agent : agent, CurrencyIndex : int, Amount : float) : void = {}
    RemoveCurrency<public>(Agent : agent, CurrencyIndex : int, Amount : float)<decides> : void = false
    GetCurrency<public>(Agent : agent, CurrencyIndex : int) : float = 0.0
    GetCurrencyName<public>(CurrencyIndex : int) : string = ""

xp_awarder <public> := class:
    AddXP<public>(Agent : agent, Amount : int) : void = {}

playtime_provider <public> := class:
    GetOfflineSeconds<public>(Agent : agent) : float = 0.0
    MarkSessionStart<public>(Agent : agent) : void = {}

# --- Event bus types ---
player_connected_to_game <public> := type{_(GamePlayer : game_player):void}
player_removed_from_game <public> := type{_(GamePlayer : game_player):void}
elimination_event <public> := type{_(EliminatedPlayer : agent, EliminatingPlayer : ?agent):void}

player_manager <public> := class(creative_device):
    @editable AllPlayerSpawners <private> : []player_spawner_device = array{}

    var AllPlayers <private> : [agent]game_player = map{}
    var PlayerConnectedToGame <private> : []player_connected_to_game = array{}
    var PlayerRemovedFromGame <private> : []player_removed_from_game = array{}
    var EliminationEvents <private> : []elimination_event = array{}

    # Optional cross-pack slots — filled by feature pack devices on OnBegin
    var Currency <private> : ?currency_provider = false
    var Progression <private> : ?xp_awarder = false
    var Playtime <private> : ?playtime_provider = false

    OnBegin<override>()<suspends> : void =
        GetPlayspace().PlayerAddedEvent().Subscribe(OnPlayerAdded)
        GetPlayspace().PlayerRemovedEvent().Subscribe(OnPlayerRemoved)
        for (Index -> Spawner : AllPlayerSpawners):
            Spawner.SpawnedEvent.Subscribe(OnPlayerAdded)
        spawn{ AddAllPlayersAfterDelay() }

    RegisterCurrencyProvider<public>(Provider : currency_provider) : void =
        set Currency = option{Provider}

    RegisterXPAwarder<public>(Awarder : xp_awarder) : void =
        set Progression = option{Awarder}

    RegisterPlaytimeProvider<public>(Provider : playtime_provider) : void =
        set Playtime = option{Provider}

    GetCurrencyProvider<public>()<transacts> : ?currency_provider = Currency
    GetXPAwarder<public>()<transacts> : ?xp_awarder = Progression
    GetPlaytimeProvider<public>()<transacts> : ?playtime_provider = Playtime

    AddAllPlayersAfterDelay<private>()<suspends> : void =
        Sleep(2.0)
        Agents := Self.GetPlayspace().GetPlayers()
        for (Agent : Agents):
            OnPlayerAdded(Agent)

    OnPlayerAdded<public>(NewAgent : agent) : void =
        spawn{ OnPlayerAddedLoop(NewAgent) }

    OnPlayerAddedLoop<private>(NewAgent : agent)<suspends> : void =
        if (PlayerExists := AllPlayers[NewAgent]):
            # already registered
        else:
            NewGamePlayer : game_player = game_player{MyAgent := NewAgent}
            if (set AllPlayers[NewAgent] = NewGamePlayer):
                NewGamePlayer.Init(NewAgent)
                for (ConnectEvent : PlayerConnectedToGame):
                    ConnectEvent(NewGamePlayer)
                if (FortChar := NewAgent.GetFortCharacter[]):
                    if (FortChar.IsActive[]):
                        FortChar.EliminatedEvent().Subscribe(OnEliminated)

    OnPlayerRemoved<private>(OutAgent : agent) : void =
        if (Leaving := AllPlayers[OutAgent]):
            for (RemoveEvent : PlayerRemovedFromGame):
                RemoveEvent(Leaving)
            var TempAllPlayers : [agent]game_player = map{}
            for (Key -> Value : AllPlayers, Key <> OutAgent):
                set TempAllPlayers = ConcatenateMaps(TempAllPlayers, map{Key => Value})
            set AllPlayers = TempAllPlayers

    OnEliminated<private>(Result : elimination_result) : void =
        Eliminator := Result.EliminatingCharacter
        Eliminated := Result.EliminatedCharacter
        var TemplEliminator : ?agent = false
        if (FortCharacter := Eliminator?, EliminatorAgent := FortCharacter.GetAgent[]):
            set TemplEliminator = option{EliminatorAgent}
            if (FortCharacter2 := Eliminated, EliminatedAgent := FortCharacter2.GetAgent[]):
                if (not EliminatorAgent = EliminatedAgent):
                    for (Event : EliminationEvents):
                        Event(EliminatedAgent, option{EliminatorAgent})
                    return
        if (FortCharacter := Eliminated, EliminatedAgent := FortCharacter.GetAgent[]):
            if (not TemplEliminator?):
                for (Event : EliminationEvents):
                    Event(EliminatedAgent, false)

    SubscribePlayerConnected<public>(ConnectEvent : player_connected_to_game) : void =
        set PlayerConnectedToGame += array{ConnectEvent}

    SubscribePlayerRemoved<public>(RemoveEvent : player_removed_from_game) : void =
        set PlayerRemovedFromGame += array{RemoveEvent}

    SubscribeElimination<public>(Event : elimination_event) : void =
        set EliminationEvents += array{Event}

    GetAllGamePlayers<public>()<transacts> : [agent]game_player = AllPlayers

    GetGamePlayer<public>(Agent : agent)<transacts> : ?game_player =
        if (MyPlayer := AllPlayers[Agent]):
            return option{MyPlayer}
        else:
            return false

    GetRandomPlayerSpawner<public>() : ?player_spawner_device =
        if (AllPlayerSpawners.Length > 0):
            if (RandomSpawner := AllPlayerSpawners[GetRandomInt(0, AllPlayerSpawners.Length - 1)]):
                return option{RandomSpawner}
        return false
