using { /Fortnite.com/AI }
using { /Fortnite.com/Characters }
using { /Fortnite.com/Playspaces }
using { /UnrealEngine.com/Temporary/SpatialMath }
using { /Verse.org/Random }
using { /Verse.org/Simulation }
using { /Verse.org/Verse }

# Shared helpers + session registries. Duplicate react clips into THIS folder
# (AS_CatReact_Attack_01/02/03, AS_CatReact_Die, AS_CatReact_Dead, AS_DogReact_Attack)
# BEFORE the first Verse compile so they resolve as same-module animation_sequence.

var ActiveCatAgents : weak_map(session, []agent) = map{}
var ActiveDogAgents : weak_map(session, []agent) = map{}
var CatDownedAgents : weak_map(session, []agent) = map{}
var CatDownedUntilTimes : weak_map(session, []float) = map{}

CatXYLength<public>(V : vector3) : float =
    Distance(vector3{X := 0.0, Y := 0.0, Z := 0.0}, vector3{X := V.X, Y := V.Y, Z := 0.0})

CatNormalizeXY<public>(V : vector3) : vector3 =
    Len := CatXYLength(V)
    if (Len > 1.0):
        vector3{X := V.X / Len, Y := V.Y / Len, Z := 0.0}
    else:
        vector3{X := 1.0, Y := 0.0, Z := 0.0}

CatRandomPointAround<public>(Origin : vector3, MinRadius : float, MaxRadius : float) : vector3 =
    Angle := GetRandomFloat(0.0, 6.28318)
    Radius := GetRandomFloat(MinRadius, MaxRadius)
    vector3{
        X := Origin.X + Cos(Angle) * Radius
        Y := Origin.Y + Sin(Angle) * Radius
        Z := Origin.Z
    }

CatFleePointFrom<public>(SelfPos : vector3, ThreatPos : vector3, FleeDistance : float) : vector3 =
    Away := CatNormalizeXY(SelfPos - ThreatPos)
    vector3{
        X := SelfPos.X + Away.X * FleeDistance
        Y := SelfPos.Y + Away.Y * FleeDistance
        Z := SelfPos.Z
    }

CatGetActiveAgents<public>() : []agent =
    if (Active := ActiveCatAgents[GetSession()]):
        Active
    else:
        array{}

DogGetActiveAgents<public>() : []agent =
    if (Active := ActiveDogAgents[GetSession()]):
        Active
    else:
        array{}

GetDownedAgents() : []agent =
    if (Active := CatDownedAgents[GetSession()]):
        Active
    else:
        array{}

GetDownedUntilTimes() : []float =
    if (Active := CatDownedUntilTimes[GetSession()]):
        Active
    else:
        array{}

MarkCatDowned<public>(Agent : agent, UntilTime : float) : void =
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
    if (set CatDownedAgents[Session] = NextAgents) {}
    if (set CatDownedUntilTimes[Session] = NextUntils) {}

ClearCatDowned<public>(Agent : agent) : void =
    Session := GetSession()
    Agents := GetDownedAgents()
    Untils := GetDownedUntilTimes()
    var NextAgents : []agent = array{}
    var NextUntils : []float = array{}
    for (Idx := 0..Agents.Length - 1):
        if (A := Agents[Idx], U := Untils[Idx], A <> Agent):
            set NextAgents += array{A}
            set NextUntils += array{U}
    if (set CatDownedAgents[Session] = NextAgents) {}
    if (set CatDownedUntilTimes[Session] = NextUntils) {}

# Pure list check — callers fetch lists in a void/no_rollback-ok context first.
IsCatDownedInLists<public>(Agent : agent, Now : float, Agents : []agent, Untils : []float)<transacts> : logic =
    var Found : logic = false
    for (Idx := 0..Agents.Length - 1):
        if (A := Agents[Idx], U := Untils[Idx], A = Agent, Now < U):
            set Found = true
    Found

IsCatDownedAt<public>(Agent : agent, Now : float) : logic =
    IsCatDownedInLists(Agent, Now, GetDownedAgents(), GetDownedUntilTimes())

RegisterCatAgent<public>(Agent : agent) : void =
    Session := GetSession()
    Current := CatGetActiveAgents()
    var Next : []agent = array{Agent}
    for (Existing : Current, Existing <> Agent):
        set Next += array{Existing}
    if (set ActiveCatAgents[Session] = Next) {}

UnregisterCatAgent<public>(Agent : agent) : void =
    Session := GetSession()
    Current := CatGetActiveAgents()
    var Next : []agent = array{}
    for (Existing : Current, Existing <> Agent):
        set Next += array{Existing}
    if (set ActiveCatAgents[Session] = Next) {}
    ClearCatDowned(Agent)

RegisterDogAgent<public>(Agent : agent) : void =
    Session := GetSession()
    Current := DogGetActiveAgents()
    var Next : []agent = array{Agent}
    for (Existing : Current, Existing <> Agent):
        set Next += array{Existing}
    if (set ActiveDogAgents[Session] = Next) {}

UnregisterDogAgent<public>(Agent : agent) : void =
    Session := GetSession()
    Current := DogGetActiveAgents()
    var Next : []agent = array{}
    for (Existing : Current, Existing <> Agent):
        set Next += array{Existing}
    if (set ActiveDogAgents[Session] = Next) {}

CatFindNearestPlayer<public>(Behavior : npc_behavior, FortChar : fort_character, DetectionRange : float) : ?fort_character =
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

CatFindNearestPeer<public>(SelfAgent : agent, FortChar : fort_character, DetectionRange : float) : ?fort_character =
    var Best : ?fort_character = false
    var BestDist : float = DetectionRange
    SelfPos := FortChar.GetTransform().Translation
    Peers := CatGetActiveAgents()
    for (OtherAgent : Peers):
        if (OtherAgent <> SelfAgent, OtherChar := OtherAgent.GetFortCharacter[]):
            if:
                OtherChar.IsActive[]
                D := Distance(SelfPos, OtherChar.GetTransform().Translation)
                D < BestDist
            then:
                set Best = option{OtherChar}
                set BestDist = D
    Best

CatFindNearestDog<public>(FortChar : fort_character, DetectionRange : float) : ?fort_character =
    var Best : ?fort_character = false
    var BestDist : float = DetectionRange
    SelfPos := FortChar.GetTransform().Translation
    DogList := DogGetActiveAgents()
    for (DogAgent : DogList):
        if (DogChar := DogAgent.GetFortCharacter[]):
            DogPos := DogChar.GetTransform().Translation
            D := Distance(SelfPos, DogPos)
            if (DogChar.IsActive[], D < BestDist):
                set Best = option{DogChar}
                set BestDist = D
    Best

DogFindNearestCat<public>(SelfAgent : agent, FortChar : fort_character, DetectionRange : float, Now : float) : ?fort_character =
    var Best : ?fort_character = false
    var BestDist : float = DetectionRange
    SelfPos := FortChar.GetTransform().Translation
    CatList := CatGetActiveAgents()
    DownedAgents := GetDownedAgents()
    DownedUntils := GetDownedUntilTimes()
    for (CatAgent : CatList):
        if (CatAgent <> SelfAgent):
            Downed := IsCatDownedInLists(CatAgent, Now, DownedAgents, DownedUntils)
            if (Downed = false, CatChar := CatAgent.GetFortCharacter[]):
                CatPos := CatChar.GetTransform().Translation
                D := Distance(SelfPos, CatPos)
                if (CatChar.IsActive[], D < BestDist):
                    set Best = option{CatChar}
                    set BestDist = D
    Best

DogFindNearestCatExcluding<public>(SelfAgent : agent, FortChar : fort_character, DetectionRange : float, Exclude : fort_character, Now : float) : ?fort_character =
    var Best : ?fort_character = false
    var BestDist : float = DetectionRange
    SelfPos := FortChar.GetTransform().Translation
    CatList := CatGetActiveAgents()
    DownedAgents := GetDownedAgents()
    DownedUntils := GetDownedUntilTimes()
    for (CatAgent : CatList):
        if (CatAgent <> SelfAgent):
            Downed := IsCatDownedInLists(CatAgent, Now, DownedAgents, DownedUntils)
            if (Downed = false, CatChar := CatAgent.GetFortCharacter[], CatChar <> Exclude):
                CatPos := CatChar.GetTransform().Translation
                D := Distance(SelfPos, CatPos)
                if (CatChar.IsActive[], D < BestDist):
                    set Best = option{CatChar}
                    set BestDist = D
    Best
