# SETUP: verse_template_apply("npc_core") → Verse/NPCCore/.
# Session registries for prey/hunter awareness. Fetch lists in void, then pass into <transacts>.
# After duplicate_asset, add Play(AS_…) in the behavior files — this pack compiles with no clips.
using { /Fortnite.com/AI }
using { /Fortnite.com/Characters }
using { /Fortnite.com/Playspaces }
using { /UnrealEngine.com/Temporary/SpatialMath }
using { /Verse.org/Random }
using { /Verse.org/Simulation }
using { /Verse.org/Verse }

var ActivePreyAgents : weak_map(session, []agent) = map{}
var ActiveHunterAgents : weak_map(session, []agent) = map{}
var DownedAgents : weak_map(session, []agent) = map{}
var DownedUntilTimes : weak_map(session, []float) = map{}

NPCXYLength<public>(V : vector3) : float =
    Distance(vector3{X := 0.0, Y := 0.0, Z := 0.0}, vector3{X := V.X, Y := V.Y, Z := 0.0})

NPCNormalizeXY<public>(V : vector3) : vector3 =
    Len := NPCXYLength(V)
    if (Len > 1.0):
        vector3{X := V.X / Len, Y := V.Y / Len, Z := 0.0}
    else:
        vector3{X := 1.0, Y := 0.0, Z := 0.0}

NPCRandomPointAround<public>(Origin : vector3, MinRadius : float, MaxRadius : float) : vector3 =
    Angle := GetRandomFloat(0.0, 6.28318)
    Radius := GetRandomFloat(MinRadius, MaxRadius)
    vector3{
        X := Origin.X + Cos(Angle) * Radius
        Y := Origin.Y + Sin(Angle) * Radius
        Z := Origin.Z
    }

NPCFleePointFrom<public>(SelfPos : vector3, ThreatPos : vector3, FleeDistance : float) : vector3 =
    Away := NPCNormalizeXY(SelfPos - ThreatPos)
    vector3{
        X := SelfPos.X + Away.X * FleeDistance
        Y := SelfPos.Y + Away.Y * FleeDistance
        Z := SelfPos.Z
    }

GetPreyAgents<public>()<transacts> : []agent =
    if (Active := ActivePreyAgents[GetSession()]):
        Active
    else:
        array{}

GetHunterAgents<public>()<transacts> : []agent =
    if (Active := ActiveHunterAgents[GetSession()]):
        Active
    else:
        array{}

GetDownedAgents<public>()<transacts> : []agent =
    if (Active := DownedAgents[GetSession()]):
        Active
    else:
        array{}

GetDownedUntilTimes<public>()<transacts> : []float =
    if (Active := DownedUntilTimes[GetSession()]):
        Active
    else:
        array{}

MarkPreyDowned<public>(Agent : agent, UntilTime : float) : void =
    Session := GetSession()
    Agents := GetDownedAgents()
    Untils := GetDownedUntilTimes()
    var NextAgents : []agent = array{}
    var NextUntils : []float = array{}
    var Replaced : logic = false
    for (Idx := 0..Agents.Length - 1):
        if (A := Agents[Idx], U := Untils[Idx]):
            if (A = Agent):
                set NextAgents += array{Agent}
                set NextUntils += array{UntilTime}
                set Replaced = true
            else:
                set NextAgents += array{A}
                set NextUntils += array{U}
    if (Replaced = false):
        set NextAgents += array{Agent}
        set NextUntils += array{UntilTime}
    if (set DownedAgents[Session] = NextAgents) {}
    if (set DownedUntilTimes[Session] = NextUntils) {}

ClearPreyDowned<public>(Agent : agent) : void =
    Session := GetSession()
    Agents := GetDownedAgents()
    Untils := GetDownedUntilTimes()
    var NextAgents : []agent = array{}
    var NextUntils : []float = array{}
    for (Idx := 0..Agents.Length - 1):
        if (A := Agents[Idx], U := Untils[Idx], A <> Agent):
            set NextAgents += array{A}
            set NextUntils += array{U}
    if (set DownedAgents[Session] = NextAgents) {}
    if (set DownedUntilTimes[Session] = NextUntils) {}

IsDownedInLists<public>(Agent : agent, Now : float, Agents : []agent, Untils : []float)<transacts> : logic =
    var Found : logic = false
    for (Idx := 0..Agents.Length - 1):
        if (A := Agents[Idx], U := Untils[Idx], A = Agent, Now < U):
            set Found = true
    Found

IsPreyDownedAt<public>(Agent : agent, Now : float)<transacts> : logic =
    IsDownedInLists(Agent, Now, GetDownedAgents(), GetDownedUntilTimes())

RegisterPreyAgent<public>(Agent : agent) : void =
    Session := GetSession()
    Current := GetPreyAgents()
    var Next : []agent = array{Agent}
    for (Existing : Current, Existing <> Agent):
        set Next += array{Existing}
    if (set ActivePreyAgents[Session] = Next) {}

UnregisterPreyAgent<public>(Agent : agent) : void =
    Session := GetSession()
    Current := GetPreyAgents()
    var Next : []agent = array{}
    for (Existing : Current, Existing <> Agent):
        set Next += array{Existing}
    if (set ActivePreyAgents[Session] = Next) {}
    ClearPreyDowned(Agent)

RegisterHunterAgent<public>(Agent : agent) : void =
    Session := GetSession()
    Current := GetHunterAgents()
    var Next : []agent = array{Agent}
    for (Existing : Current, Existing <> Agent):
        set Next += array{Existing}
    if (set ActiveHunterAgents[Session] = Next) {}

UnregisterHunterAgent<public>(Agent : agent) : void =
    Session := GetSession()
    Current := GetHunterAgents()
    var Next : []agent = array{}
    for (Existing : Current, Existing <> Agent):
        set Next += array{Existing}
    if (set ActiveHunterAgents[Session] = Next) {}

FindNearestPlayer<public>(Behavior : npc_behavior, FortChar : fort_character, DetectionRange : float)<transacts> : ?fort_character =
    var Best : ?fort_character = false
    var BestDist : float = DetectionRange
    if (Ent := Behavior.GetEntity[], PS := Ent.GetPlayspaceForEntity[]):
        SelfPos := FortChar.GetTransform().Translation
        for (Player : PS.GetPlayers(), PlayerChar := Player.GetFortCharacter[]):
            if:
                PlayerChar.IsActive[]
                not PlayerChar = FortChar
                D := Distance(SelfPos, PlayerChar.GetTransform().Translation)
                D < BestDist
            then:
                set Best = option{PlayerChar}
                set BestDist = D
    Best

FindNearestPreyPeer<public>(SelfAgent : agent, FortChar : fort_character, DetectionRange : float)<transacts> : ?fort_character =
    var Best : ?fort_character = false
    var BestDist : float = DetectionRange
    SelfPos := FortChar.GetTransform().Translation
    for (OtherAgent : GetPreyAgents()):
        if (OtherAgent <> SelfAgent, OtherChar := OtherAgent.GetFortCharacter[]):
            if:
                OtherChar.IsActive[]
                D := Distance(SelfPos, OtherChar.GetTransform().Translation)
                D < BestDist
            then:
                set Best = option{OtherChar}
                set BestDist = D
    Best

FindNearestHunter<public>(FortChar : fort_character, DetectionRange : float)<transacts> : ?fort_character =
    var Best : ?fort_character = false
    var BestDist : float = DetectionRange
    SelfPos := FortChar.GetTransform().Translation
    for (HunterAgent : GetHunterAgents()):
        if (HunterChar := HunterAgent.GetFortCharacter[]):
            D := Distance(SelfPos, HunterChar.GetTransform().Translation)
            if (HunterChar.IsActive[], D < BestDist):
                set Best = option{HunterChar}
                set BestDist = D
    Best

FindNearestPrey<public>(SelfAgent : agent, FortChar : fort_character, DetectionRange : float, Now : float)<transacts> : ?fort_character =
    var Best : ?fort_character = false
    var BestDist : float = DetectionRange
    SelfPos := FortChar.GetTransform().Translation
    Agents := GetDownedAgents()
    Untils := GetDownedUntilTimes()
    for (PreyAgent : GetPreyAgents()):
        if (PreyAgent <> SelfAgent):
            if (IsDownedInLists(PreyAgent, Now, Agents, Untils) = false, PreyChar := PreyAgent.GetFortCharacter[]):
                D := Distance(SelfPos, PreyChar.GetTransform().Translation)
                if (PreyChar.IsActive[], D < BestDist):
                    set Best = option{PreyChar}
                    set BestDist = D
    Best

FindNearestPreyExcluding<public>(SelfAgent : agent, FortChar : fort_character, DetectionRange : float, Exclude : fort_character, Now : float)<transacts> : ?fort_character =
    var Best : ?fort_character = false
    var BestDist : float = DetectionRange
    SelfPos := FortChar.GetTransform().Translation
    Agents := GetDownedAgents()
    Untils := GetDownedUntilTimes()
    for (PreyAgent : GetPreyAgents()):
        if (PreyAgent <> SelfAgent):
            if (IsDownedInLists(PreyAgent, Now, Agents, Untils) = false, PreyChar := PreyAgent.GetFortCharacter[], PreyChar <> Exclude):
                D := Distance(SelfPos, PreyChar.GetTransform().Translation)
                if (PreyChar.IsActive[], D < BestDist):
                    set Best = option{PreyChar}
                    set BestDist = D
    Best
