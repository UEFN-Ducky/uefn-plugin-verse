# SETUP: Part of Player Core. Shared weak_map row created on join via game_player.Init.
# Other packs keep their own weak_maps; this table is the backbone Version row.
using { /Verse.org/Simulation }
using { /Fortnite.com/Devices }

var PlayerStatsMap <public> : weak_map(player, game_player_table) = map{}

game_player_table <public> := class<final><persistable>:
    Version <public> : int = 0

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
