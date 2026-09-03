# SETUP: Place this device. Wire PreySpawners / HunterSpawners with wire_verse_device_array
# after compile. Give hunters ~1500–2000 units of runway from the prey cluster.
using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }

npc_spawn_controller := class(creative_device):
    @editable PreySpawners : []npc_spawner_device = array{}
    @editable HunterSpawners : []npc_spawner_device = array{}
    @editable AutoSpawnOnBegin : logic = true
    @editable SpawnCountPerSpawner : int = 1
    @editable DelayAfterStart : float = 1.0

    OnBegin<override>()<suspends> : void =
        if (AutoSpawnOnBegin = true):
            Sleep(DelayAfterStart)
            SpawnAll()

    SpawnAll()<suspends> : void =
        Players := GetPlayspace().GetPlayers()
        if (Players.Length = 0):
            Sleep(1.0)
            SpawnAll()
        else:
            for (Spawner : PreySpawners):
                TrySpawn(Spawner)
            for (Spawner : HunterSpawners):
                TrySpawn(Spawner)

    TrySpawn(Spawner : npc_spawner_device)<suspends> : void =
        var Index : int = 0
        loop:
            if (Index >= SpawnCountPerSpawner):
                break
            Spawner.Enable()
            Spawner.Reset()
            Spawner.Spawn()
            set Index += 1
            Sleep(0.15)
