# SETUP: Assign this class on hunter NPCDefs via set_npc_definition_behavior.
# After a catch, hunt someone else — never the prey you just downed.
using { /Fortnite.com/AI }
using { /Fortnite.com/AI/movement_types }
using { /Fortnite.com/Animation/PlayAnimation }
using { /Fortnite.com/Characters }
using { /UnrealEngine.com/Temporary/SpatialMath }
using { /Verse.org/Random }
using { /Verse.org/Simulation }

hunter_ai_state := enum:
    Hunting
    Attacking
    GivingUp

hunter_npc_behavior<public> := class(npc_behavior):
    @editable HuntRange : float = 2500.0
    @editable CatchRadius : float = 160.0
    @editable ChaseSecondsMin : float = 6.0
    @editable ChaseSecondsMax : float = 10.0
    @editable GiveUpSeconds : float = 2.5
    @editable PreyDownedSeconds : float = 10.0
    @editable AttackHoldSeconds : float = 1.2
    @editable SprintSpeedMultiplier : float = 1.65
    @editable SenseInterval : float = 0.2

    var CurrentState : hunter_ai_state = hunter_ai_state.Hunting
    var Prey : ?fort_character = false
    var ChaseUntilTime : float = 0.0
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
            RegisterHunterAgent(Agent)
            race:
                SenseLoop(Agent, Char)
                BehaviorLoop(Char, Nav, Focus, Anim)
                WaitUntilInactive(Char)
            UnregisterHunterAgent(Agent)
            Nav.StopNavigation()

    OnEnd<override>() : void =
        if (Agent := SelfAgent?):
            UnregisterHunterAgent(Agent)

    WaitUntilInactive(Char : fort_character)<suspends> : void =
        loop:
            Sleep(0.25)
            if (not Char.IsActive[]):
                break

    SenseLoop(Agent : agent, Char : fort_character)<suspends> : void =
        loop:
            Sleep(SenseInterval)
            if (not Char.IsActive[]):
                break
            UpdateDesiredState(Agent, Char)

    UpdateDesiredState(Agent : agent, Char : fort_character) : void =
        Now := GetSimulationElapsedTime()
        Agents := GetDownedAgents()
        Untils := GetDownedUntilTimes()
        if (CurrentState = hunter_ai_state.GivingUp or CurrentState = hunter_ai_state.Attacking):
            return
        if (Target := Prey?):
            if (Target.IsActive[]):
                if (PreyAgent := Target.GetAgent[]):
                    if (IsDownedInLists(PreyAgent, Now, Agents, Untils) = true):
                        set CurrentState = hunter_ai_state.GivingUp
                        return
                Dist := Distance(Char.GetTransform().Translation, Target.GetTransform().Translation)
                if (Dist <= CatchRadius):
                    set CurrentState = hunter_ai_state.Attacking
                    return
                if (Now >= ChaseUntilTime):
                    set CurrentState = hunter_ai_state.GivingUp
                    return
                return
            else:
                set Prey = false
        if (Found := FindNearestPrey(Agent, Char, HuntRange, Now)?):
            set Prey = option{Found}
            set ChaseUntilTime = Now + GetRandomFloat(ChaseSecondsMin, ChaseSecondsMax)
            set CurrentState = hunter_ai_state.Hunting
        else:
            set Prey = false

    BehaviorLoop(Char : fort_character, Nav : navigatable, Focus : focus_interface, Anim : play_animation_controller)<suspends> : void =
        loop:
            if (not Char.IsActive[]):
                break
            case (CurrentState):
                hunter_ai_state.Hunting => HuntOnce(Char, Nav, Focus)
                hunter_ai_state.Attacking => AttackOnce(Char, Nav, Focus, Anim)
                hunter_ai_state.GivingUp => GiveUpOnce(Char, Nav)

    HuntOnce(Char : fort_character, Nav : navigatable, Focus : focus_interface)<suspends> : void =
        if (Target := Prey?, Target.IsActive[]):
            Nav.SetMovementSpeedMultiplier(SprintSpeedMultiplier)
            if (TargetAgent := Target.GetAgent[]):
                race:
                    Nav.NavigateTo(MakeNavigationTarget(TargetAgent), ?MovementType := Running, ?ReachRadius := CatchRadius)
                    Focus.MaintainFocus(TargetAgent)
                    WaitWhileState(hunter_ai_state.Hunting)
            else:
                TargetPos := Target.GetTransform().Translation
                race:
                    Nav.NavigateTo(MakeNavigationTarget(TargetPos), ?MovementType := Running, ?ReachRadius := CatchRadius)
                    Focus.MaintainFocus(TargetPos)
                    WaitWhileState(hunter_ai_state.Hunting)
            Nav.SetMovementSpeedMultiplier(1.0)
        else:
            Dest := NPCRandomPointAround(Char.GetTransform().Translation, 400.0, 700.0)
            race:
                Nav.NavigateTo(MakeNavigationTarget(Dest), ?MovementType := Walking, ?ReachRadius := 100.0)
                Sleep(2.5)
                WaitWhileState(hunter_ai_state.Hunting)

    AttackOnce(Char : fort_character, Nav : navigatable, Focus : focus_interface, Anim : play_animation_controller)<suspends> : void =
        Nav.StopNavigation()
        Nav.SetMovementSpeedMultiplier(1.0)
        Now := GetSimulationElapsedTime()
        if (Target := Prey?, TargetAgent := Target.GetAgent[]):
            MarkPreyDowned(TargetAgent, Now + PreyDownedSeconds)
            race:
                Focus.MaintainFocus(TargetAgent)
                Sleep(AttackHoldSeconds)
        else:
            Sleep(AttackHoldSeconds)
        set CurrentState = hunter_ai_state.GivingUp

    GiveUpOnce(Char : fort_character, Nav : navigatable)<suspends> : void =
        Nav.StopNavigation()
        OldPrey := Prey
        set Prey = false
        Sleep(GiveUpSeconds)
        Now := GetSimulationElapsedTime()
        if (Agent := SelfAgent?):
            if (Old := OldPrey?):
                if (Other := FindNearestPreyExcluding(Agent, Char, HuntRange, Old, Now)?):
                    set Prey = option{Other}
            else if (Any := FindNearestPrey(Agent, Char, HuntRange, Now)?):
                set Prey = option{Any}
            if (P := Prey?):
                set ChaseUntilTime = Now + GetRandomFloat(ChaseSecondsMin, ChaseSecondsMax)
        set CurrentState = hunter_ai_state.Hunting

    WaitWhileState(Wanted : hunter_ai_state)<suspends> : void =
        loop:
            Sleep(0.15)
            if (CurrentState <> Wanted):
                break
