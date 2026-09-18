# SETUP: Part of Player Core. Shared weak_map row created on join via game_player.Init.
# Other packs keep their own weak_maps; this table is the backbone Version row.
# PlotRebirths / PlotUnlocks / PlotLevels are defaulted nests for the tycoon pack (no 5th map).
using { /Verse.org/Simulation }
using { /Fortnite.com/Devices }

var PlayerStatsMap <public> : weak_map(player, game_player_table) = map{}

game_player_table <public> := class<final><persistable>:
    Version <public> : int = 0
    PlotRebirths <public> : int = 0
    PlotUnlocks <public> : []int = array{}
    PlotLevels <public> : [int]int = map{}

PackPlotUnlock<public>(TypeIndex : int, ItemIndex : int)<transacts> : int =
    TypeIndex * 1000 + ItemIndex

UnpackPlotType<public>(Packed : int)<transacts> : int =
    if (TypeIndex := Floor[(Packed * 1.0) / 1000.0]):
        return TypeIndex
    return 0

UnpackPlotItem<public>(Packed : int)<transacts> : int =
    Packed - UnpackPlotType(Packed) * 1000

MakeGamePlayerTable<public>(Old : game_player_table, NewRebirths : int, NewUnlocks : []int, NewLevels : [int]int)<transacts> : game_player_table =
    game_player_table{Version := Old.Version, PlotRebirths := NewRebirths, PlotUnlocks := NewUnlocks, PlotLevels := NewLevels}

GetPlotRebirths<public>(Agent : agent)<transacts> : int =
    if:
        Player := player[Agent]
        Player.IsActive[]
        Table := PlayerStatsMap[Player]
    then:
        return Table.PlotRebirths
    return 0

GetPlotUnlocks<public>(Agent : agent)<transacts> : []int =
    if:
        Player := player[Agent]
        Player.IsActive[]
        Table := PlayerStatsMap[Player]
    then:
        return Table.PlotUnlocks
    return array{}

HasPlotUnlock<public>(Agent : agent, Packed : int)<transacts> : logic =
    for (Key : GetPlotUnlocks(Agent)):
        if (Key = Packed):
            return true
    return false

GetPlotLevel<public>(Agent : agent, Packed : int)<transacts> : int =
    if:
        Player := player[Agent]
        Player.IsActive[]
        Table := PlayerStatsMap[Player]
        Level := Table.PlotLevels[Packed]
    then:
        return Level
    return 0

AddPlotUnlock<public>(Agent : agent, Packed : int) : void =
    if:
        Player := player[Agent]
        Player.IsActive[]
        Old := PlayerStatsMap[Player]
    then:
        if (not HasPlotUnlock(Agent, Packed)?):
            if (set PlayerStatsMap[Player] = MakeGamePlayerTable(Old, Old.PlotRebirths, Old.PlotUnlocks + array{Packed}, Old.PlotLevels)) {}

SetPlotLevel<public>(Agent : agent, Packed : int, Level : int) : void =
    if:
        Player := player[Agent]
        Player.IsActive[]
        Old := PlayerStatsMap[Player]
    then:
        var NextLevels : [int]int = Old.PlotLevels
        if (set NextLevels[Packed] = Level):
            if (set PlayerStatsMap[Player] = MakeGamePlayerTable(Old, Old.PlotRebirths, Old.PlotUnlocks, NextLevels)) {}

AddPlotRebirth<public>(Agent : agent) : void =
    if:
        Player := player[Agent]
        Player.IsActive[]
        Old := PlayerStatsMap[Player]
    then:
        EmptyLevels : [int]int = map{}
        if (set PlayerStatsMap[Player] = MakeGamePlayerTable(Old, Old.PlotRebirths + 1, array{}, EmptyLevels)) {}

save_service <public> := class():
    InitializePlayer(Agent : ?agent) : void =
        if:
            RealAgent := Agent?
            Player := player[RealAgent]
            Player.IsActive[]
        then:
            if (ExistingStats := PlayerStatsMap[Player]):
                # rejoin — keep persisted row
            else:
                if (set PlayerStatsMap[Player] = game_player_table{}):
                    # new player
