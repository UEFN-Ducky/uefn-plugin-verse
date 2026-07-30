# SETUP: Requires Player Core. Registers as playtime_provider for offline earnings.
using { /Verse.org/Simulation }
using { /Fortnite.com/Devices }
using { /UnrealEngine.com/Temporary/Diagnostics }
using { PlayerCore }

player_time_data <public> := class<final><persistable>:
    FirstLoginEpoch <public> : float = 0.0
    LastLogoutEpoch <public> : float = 0.0
    TotalPlaySeconds <public> : float = 0.0

time_tracker_table <public> := class<final><persistable>:
    Version <public> : int = 0
    TimeData <public> : player_time_data = player_time_data{}

var TimeTrackerMap <public> : weak_map(player, time_tracker_table) = map{}

MakeTimeTable(Old : time_tracker_table, NewData : player_time_data)<transacts> : time_tracker_table =
    time_tracker_table{Version := Old.Version, TimeData := NewData}

player_time_tracker <public> := class<unique>(playtime_provider):
    var SessionStartSim <public> : float = 0.0
    var MyAgent <public> : ?agent = false

    EnsureRow(Agent : agent) : void =
        if:
            Player := player[Agent]
            Player.IsActive[]
        then:
            if (Existing := TimeTrackerMap[Player]):
            else:
                if (set TimeTrackerMap[Player] = time_tracker_table{}):
                    {}

    MarkSessionStart<override>(Agent : agent) : void =
        EnsureRow(Agent)
        set SessionStartSim = GetSimulationElapsedTime()
        if:
            Player := player[Agent]
            Player.IsActive[]
            OldTable := TimeTrackerMap[Player]
        then:
            Now := GetSecondsSinceEpoch()
            First := if (OldTable.TimeData.FirstLoginEpoch <= 0.0) then Now else OldTable.TimeData.FirstLoginEpoch
            NewData := player_time_data{
                FirstLoginEpoch := First,
                LastLogoutEpoch := OldTable.TimeData.LastLogoutEpoch,
                TotalPlaySeconds := OldTable.TimeData.TotalPlaySeconds
            }
            if (set TimeTrackerMap[Player] = MakeTimeTable(OldTable, NewData)):
                {}

    EndSession<public>(Agent : agent) : void =
        if:
            Player := player[Agent]
            Player.IsActive[]
            OldTable := TimeTrackerMap[Player]
        then:
            NowSim := GetSimulationElapsedTime()
            Delta := NowSim - SessionStartSim
            if (Delta < 0.0):
                set Delta = 0.0
            NewData := player_time_data{
                FirstLoginEpoch := OldTable.TimeData.FirstLoginEpoch,
                LastLogoutEpoch := GetSecondsSinceEpoch(),
                TotalPlaySeconds := OldTable.TimeData.TotalPlaySeconds + Delta
            }
            if (set TimeTrackerMap[Player] = MakeTimeTable(OldTable, NewData)):
                {}

    GetOfflineSeconds<override>(Agent : agent) : float =
        if:
            Player := player[Agent]
            Player.IsActive[]
            Table := TimeTrackerMap[Player]
            Table.TimeData.LastLogoutEpoch > 0.0
        then:
            Delta := GetSecondsSinceEpoch() - Table.TimeData.LastLogoutEpoch
            if (Delta > 0.0):
                return Delta
            return 0.0
        return 0.0
