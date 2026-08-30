using { /Fortnite.com/AI }
using { /Fortnite.com/AI/movement_types }
using { /Fortnite.com/Animation/PlayAnimation }
using { /Fortnite.com/Characters }
using { /UnrealEngine.com/Temporary/SpatialMath }
using { /Verse.org/Random }
using { /Verse.org/Simulation }

# Autonomous cat. Clips are same-module assets in this folder — never @editable Details.

cat_ai_state := enum:
    Exploring
    Following
    Fleeing
    Greeting
    PlayingDead

cat_npc_behavior<public> := class(npc_behavior):

    @editable ExploreMinRadius : float = 500.0
    @editable ExploreMaxRadius : float = 600.0
    @editable ExploreReachRadius : float = 80.0
    @editable SniffChanceOneIn : int = 4
    @editable SniffMinSeconds : float = 1.5
    @editable SniffMaxSeconds : float = 2.5

    @editable PlayerDetectRange : float = 400.0
    @editable DogDetectRange : float = 900.0
    @editable FollowMinSeconds : float = 4.0
    @editable FollowMaxSeconds : float = 6.0
    @editable FollowReachRadius : float = 120.0
    @editable PlayerReactChanceOneIn : int = 3
    @editable PlayerReactMinSeconds : float = 1.0
    @editable PlayerReactMaxSeconds : float = 1.6
    @editable PlayerReactCooldownSeconds : float = 4.0
    @editable FleeDistance : float = 800.0
    @editable FleeReachRadius : float = 100.0
    @editable FleeSpeedMultiplier : float = 1.75
    @editable SprintSpeedMultiplier : float = 1.55
    @editable DieHoldSeconds : float = 1.4
    @editable DeadLieSeconds : float = 2.5
    @editable AfterCatchIgnoreDogSeconds : float = 5.0

    @editable PeerGreetRange : float = 300.0
    @editable GreetMinSeconds : float = 1.4
    @editable GreetMaxSeconds : float = 2.0
    @editable GreetCooldownSeconds : float = 12.0
    @editable SenseInterval : float = 0.2

    var CurrentState : cat_ai_state = cat_ai_state.Exploring
    var StateLocked : logic = false
    var FollowTarget : ?fort_character = false
    var GreetingPartner : ?fort_character = false
    var FollowUntilTime : float = 0.0
    var LastGreetingTime : float = -999.0
    var LastPlayerReactTime : float = -999.0
    var IgnoreDogsUntil : float = -999.0
    var PlayDeadClaimed : logic = false
    var SelfAgent : ?agent = false

    OnBegin<override>()<suspends> : void =
        if:
            Agent := GetAgent[]
            Char := Agent.GetFortCharacter[]
            Nav := Char.GetNavigatable[]
            Focus := Char.GetFocusInterface[]
            Anim := Char.GetPlayAnimationController[]
        then:
            set SelfAgent = option{Agent}
            RegisterCatAgent(Agent)
            race:
                SenseLoop(Agent, Char)
                BehaviorLoop(Char, Nav, Focus, Anim)
                WaitUntilInactive(Char)
            UnregisterCatAgent(Agent)
            Nav.StopNavigation()

    OnEnd<override>() : void =
        if (Agent := SelfAgent?):
            UnregisterCatAgent(Agent)

    WaitUntilInactive(Char : fort_character)<suspends> : void =
        loop:
            Sleep(0.25)
            if (not Char.IsActive[]):
                break

    ReactPool() : []animation_sequence =
        array{AS_CatReact_Attack_01, AS_CatReact_Attack_02, AS_CatReact_Attack_03}

    PlayOneShot(Anim : play_animation_controller, Clip : animation_sequence, HoldSeconds : float)<suspends> : void =
        Inst := Anim.Play(Clip, ?PlayCount := 1.0, ?BlendInTime := 0.1, ?BlendOutTime := 0.15)
        race:
            Inst.Await()
            Sleep(HoldSeconds)
        Inst.Stop()

    PlayRandomReact(Anim : play_animation_controller, HoldSeconds : float)<suspends> : void =
        Pool := ReactPool()
        Count := Pool.Length
        if (Count > 0):
            Idx := GetRandomInt(0, Count - 1)
            if (Clip := Pool[Idx]):
                PlayOneShot(Anim, Clip, HoldSeconds)
            else:
                Sleep(HoldSeconds)
        else:
            Sleep(HoldSeconds)

    SenseLoop(Agent : agent, Char : fort_character)<suspends> : void =
        loop:
            Sleep(SenseInterval)
            if (not Char.IsActive[]):
                break
            Now := GetSimulationElapsedTime()
            Downed := IsCatDownedAt(Agent, Now)
            if (Downed = false):
                set PlayDeadClaimed = false

            if (CurrentState = cat_ai_state.PlayingDead):
            else if (Downed = true, PlayDeadClaimed = false):
                set PlayDeadClaimed = true
                set StateLocked = false
                set CurrentState = cat_ai_state.PlayingDead
            else if (StateLocked = false):
                UpdateDesiredState(Agent, Char)

    UpdateDesiredState(Agent : agent, Char : fort_character) : void =
        Now := GetSimulationElapsedTime()

        Downed := IsCatDownedAt(Agent, Now)
        if (Downed = true, PlayDeadClaimed = false):
            set PlayDeadClaimed = true
            set GreetingPartner = false
            set CurrentState = cat_ai_state.PlayingDead
            return

        if (CurrentState = cat_ai_state.PlayingDead):
            return

        if (Downed = true):
            if (CurrentState <> cat_ai_state.Exploring):
                set CurrentState = cat_ai_state.Exploring
            return

        if (Now < IgnoreDogsUntil):
            if (CurrentState = cat_ai_state.Fleeing):
                set CurrentState = cat_ai_state.Exploring
        else:
            if (CurrentState <> cat_ai_state.Fleeing):
                MaybeDog := CatFindNearestDog(Char, DogDetectRange)
                if (Dog := MaybeDog?):
                    set FollowTarget = option{Dog}
                    set GreetingPartner = false
                    set CurrentState = cat_ai_state.Fleeing
                    return

        if (CurrentState <> cat_ai_state.Following, CurrentState <> cat_ai_state.Fleeing):
            MaybePeer := CatFindNearestPeer(Agent, Char, PeerGreetRange)
            if (Peer := MaybePeer?):
                if (Now - LastGreetingTime >= GreetCooldownSeconds):
                    set GreetingPartner = option{Peer}
                    set CurrentState = cat_ai_state.Greeting
                    return

        if (CurrentState = cat_ai_state.Following):
            if (Target := FollowTarget?):
                if (Target.IsActive[]):
                    Dist := Distance(Char.GetTransform().Translation, Target.GetTransform().Translation)
                    if (Dist > PlayerDetectRange * 1.5):
                        ClearFollow()
                        set CurrentState = cat_ai_state.Exploring
                        return
                    if (Now >= FollowUntilTime):
                        set CurrentState = cat_ai_state.Fleeing
                        return
                    return
                else:
                    ClearFollow()
                    set CurrentState = cat_ai_state.Exploring
                    return

        MaybePlayer := CatFindNearestPlayer(Self, Char, PlayerDetectRange)
        if (Player := MaybePlayer?):
            set FollowTarget = option{Player}
            Duration := GetRandomFloat(FollowMinSeconds, FollowMaxSeconds)
            set FollowUntilTime = Now + Duration
            set CurrentState = cat_ai_state.Following
            return

        if (CurrentState <> cat_ai_state.Fleeing):
            set CurrentState = cat_ai_state.Exploring

    ClearFollow() : void =
        set FollowTarget = false
        set FollowUntilTime = 0.0

    BehaviorLoop(Char : fort_character, Nav : navigatable, Focus : focus_interface, Anim : play_animation_controller)<suspends> : void =
        loop:
            if (not Char.IsActive[]):
                break
            case (CurrentState):
                cat_ai_state.Exploring => ExploreOnce(Char, Nav, Focus, Anim)
                cat_ai_state.Following => FollowOnce(Char, Nav, Focus, Anim)
                cat_ai_state.Fleeing => FleeOnce(Char, Nav, Focus, Anim)
                cat_ai_state.Greeting => GreetOnce(Char, Nav, Focus, Anim)
                cat_ai_state.PlayingDead => PlayDeadOnce(Char, Nav, Anim)

    ExploreOnce(Char : fort_character, Nav : navigatable, Focus : focus_interface, Anim : play_animation_controller)<suspends> : void =
        SelfPos := Char.GetTransform().Translation
        Dest := CatRandomPointAround(SelfPos, ExploreMinRadius, ExploreMaxRadius)
        Nav.SetMovementSpeedMultiplier(1.0)
        race:
            block:
                Nav.NavigateTo(MakeNavigationTarget(Dest), ?MovementType := Walking, ?ReachRadius := ExploreReachRadius)
                MaybeSniff(Char, Nav)
            WaitWhileState(cat_ai_state.Exploring)

    MaybeSniff(Char : fort_character, Nav : navigatable)<suspends> : void =
        Roll := GetRandomInt(1, SniffChanceOneIn)
        if (Roll = 1):
            Nav.StopNavigation()
            Sleep(GetRandomFloat(SniffMinSeconds, SniffMaxSeconds))

    FollowOnce(Char : fort_character, Nav : navigatable, Focus : focus_interface, Anim : play_animation_controller)<suspends> : void =
        if (Target := FollowTarget?):
            if (Target.IsActive[]):
                TargetPos := Target.GetTransform().Translation
                Dist := Distance(Char.GetTransform().Translation, TargetPos)
                if (Dist <= FollowReachRadius * 1.35):
                    Nav.StopNavigation()
                    Nav.SetMovementSpeedMultiplier(1.0)
                    Now := GetSimulationElapsedTime()
                    ReactSeconds := GetRandomFloat(PlayerReactMinSeconds, PlayerReactMaxSeconds)
                    Roll := GetRandomInt(1, PlayerReactChanceOneIn)
                    if (TargetAgent := Target.GetAgent[]):
                        race:
                            Focus.MaintainFocus(TargetAgent)
                            block:
                                if (Roll = 1, Now - LastPlayerReactTime >= PlayerReactCooldownSeconds):
                                    set LastPlayerReactTime = Now
                                    PlayRandomReact(Anim, ReactSeconds)
                                else:
                                    Sleep(ReactSeconds)
                    else:
                        race:
                            Focus.MaintainFocus(TargetPos)
                            block:
                                if (Roll = 1, Now - LastPlayerReactTime >= PlayerReactCooldownSeconds):
                                    set LastPlayerReactTime = Now
                                    PlayRandomReact(Anim, ReactSeconds)
                                else:
                                    Sleep(ReactSeconds)
                else:
                    Nav.SetMovementSpeedMultiplier(SprintSpeedMultiplier)
                    if (TargetAgent := Target.GetAgent[]):
                        race:
                            Nav.NavigateTo(MakeNavigationTarget(TargetAgent), ?MovementType := Running, ?ReachRadius := FollowReachRadius)
                            Focus.MaintainFocus(TargetAgent)
                            WaitWhileState(cat_ai_state.Following)
                    else:
                        race:
                            Nav.NavigateTo(MakeNavigationTarget(TargetPos), ?MovementType := Running, ?ReachRadius := FollowReachRadius)
                            Focus.MaintainFocus(TargetPos)
                            WaitWhileState(cat_ai_state.Following)
                    Nav.SetMovementSpeedMultiplier(1.0)
            else:
                ClearFollow()
                set CurrentState = cat_ai_state.Exploring
                Sleep(0.1)
        else:
            ClearFollow()
            set CurrentState = cat_ai_state.Exploring
            Sleep(0.1)

    FleeOnce(Char : fort_character, Nav : navigatable, Focus : focus_interface, Anim : play_animation_controller)<suspends> : void =
        set StateLocked = true
        Nav.StopNavigation()
        SelfPos := Char.GetTransform().Translation
        var ThreatPos : vector3 = SelfPos
        if (Target := FollowTarget?):
            set ThreatPos = Target.GetTransform().Translation
        else:
            MaybeDog := CatFindNearestDog(Char, DogDetectRange * 2.0)
            if (Dog := MaybeDog?):
                set ThreatPos = Dog.GetTransform().Translation
            else:
                MaybeThreat := CatFindNearestPlayer(Self, Char, PlayerDetectRange * 2.0)
                if (Player := MaybeThreat?):
                    set ThreatPos = Player.GetTransform().Translation
        FleeDest := CatFleePointFrom(SelfPos, ThreatPos, FleeDistance)

        # No jump — jump spam looked like the catch bug.
        Nav.SetMovementSpeedMultiplier(FleeSpeedMultiplier)
        race:
            Nav.NavigateTo(MakeNavigationTarget(FleeDest), ?MovementType := Running, ?ReachRadius := FleeReachRadius)
            Focus.MaintainFocus(ThreatPos)
            WaitWhileState(cat_ai_state.Fleeing)
            Sleep(3.5)
        Nav.SetMovementSpeedMultiplier(1.0)
        ClearFollow()
        if (CurrentState = cat_ai_state.Fleeing):
            set CurrentState = cat_ai_state.Exploring
        set StateLocked = false

    PlayDeadOnce(Char : fort_character, Nav : navigatable, Anim : play_animation_controller)<suspends> : void =
        set StateLocked = true
        Nav.StopNavigation()
        Nav.SetMovementSpeedMultiplier(1.0)
        ClearFollow()
        set GreetingPartner = false
        PlayOneShot(Anim, AS_CatReact_Die, DieHoldSeconds)
        PlayOneShot(Anim, AS_CatReact_Dead, DeadLieSeconds)
        set IgnoreDogsUntil = GetSimulationElapsedTime() + AfterCatchIgnoreDogSeconds
        set CurrentState = cat_ai_state.Exploring
        set StateLocked = false

    GreetOnce(Char : fort_character, Nav : navigatable, Focus : focus_interface, Anim : play_animation_controller)<suspends> : void =
        set StateLocked = true
        Nav.StopNavigation()
        Nav.SetMovementSpeedMultiplier(1.0)
        set LastGreetingTime = GetSimulationElapsedTime()
        GreetSeconds := GetRandomFloat(GreetMinSeconds, GreetMaxSeconds)
        if (Partner := GreetingPartner?):
            if (Partner.IsActive[]):
                if (PartnerAgent := Partner.GetAgent[]):
                    race:
                        Focus.MaintainFocus(PartnerAgent)
                        PlayRandomReact(Anim, GreetSeconds)
                else:
                    PartnerPos := Partner.GetTransform().Translation
                    race:
                        Focus.MaintainFocus(PartnerPos)
                        PlayRandomReact(Anim, GreetSeconds)
            else:
                Sleep(0.2)
        else:
            Sleep(0.2)
        set GreetingPartner = false
        set CurrentState = cat_ai_state.Exploring
        set StateLocked = false

    WaitWhileState(Wanted : cat_ai_state)<suspends> : void =
        loop:
            Sleep(0.15)
            if (CurrentState <> Wanted):
                break
