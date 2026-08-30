using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }

# Force-spawn all wired Character Spawners once a player exists.
# Wire CatSpawner1..6 and DogSpawner1 with wire_verse_device_ref — never Details.

cat_spawn_controller := class(creative_device):

    @editable CatSpawner1 : npc_spawner_device = npc_spawner_device{}
    @editable CatSpawner2 : npc_spawner_device = npc_spawner_device{}
    @editable CatSpawner3 : npc_spawner_device = npc_spawner_device{}
    @editable CatSpawner4 : npc_spawner_device = npc_spawner_device{}
    @editable CatSpawner5 : npc_spawner_device = npc_spawner_device{}
    @editable CatSpawner6 : npc_spawner_device = npc_spawner_device{}
    @editable DogSpawner1 : npc_spawner_device = npc_spawner_device{}

    @editable StartTrigger : ?trigger_device = false
    @editable StartMutatorZone : ?mutator_zone_device = false

    @editable AutoSpawnOnBegin : logic = true
    @editable SpawnCountPerSpawner : int = 1
    @editable DelayAfterStart : float = 1.0

    OnBegin<override>()<suspends> : void =
        if (Trigger := StartTrigger?):
            Trigger.TriggeredEvent.Subscribe(OnTriggered)
        if (Zone := StartMutatorZone?):
            Zone.AgentEntersEvent.Subscribe(OnAgentEnteredZone)

        if (AutoSpawnOnBegin = true):
            Sleep(DelayAfterStart)
            SpawnAll()

    OnTriggered(MaybeAgent : ?agent) : void =
        spawn{ SpawnAll() }

    OnAgentEnteredZone(Agent : agent) : void =
        spawn{ SpawnAll() }

    SpawnAll()<suspends> : void =
        Players := GetPlayspace().GetPlayers()
        if (Players.Length = 0):
            Sleep(1.0)
            SpawnAll()
        else:
            TrySpawn(CatSpawner1)
            TrySpawn(CatSpawner2)
            TrySpawn(CatSpawner3)
            TrySpawn(CatSpawner4)
            TrySpawn(CatSpawner5)
            TrySpawn(CatSpawner6)
            TrySpawn(DogSpawner1)

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
