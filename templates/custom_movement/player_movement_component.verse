# SETUP (Experimental — `Move` + Scene Graph camera classes block publishing):
# 1. Rig prefab: root entity (transform_component) → child `Mesh` (mesh_component)
#    → child `CameraPivot` (transform_component) → child `Camera` (perspective_camera_component).
# 2. Add player_movement_component to the ROOT entity of that prefab.
# 3. Place custom_movement_controller, wire RigPrefabRoot to the placed rig.
# Speed / accel / friction / gravity / jump are all @editable — fully custom locomotion,
# not Fortnite character movement.
using { /Fortnite.com/Devices }
using { /Fortnite.com/Characters }
using { /Fortnite.com/Playspaces }
using { /Fortnite.com/Input }
using { /Fortnite.com/Input/Character }
using { /Verse.org/Input }
using { /Verse.org/SceneGraph }
using { /Verse.org/SpatialMath }
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/Diagnostics }

# --- per-entity movement integrator -----------------------------------------
# NOTE: TickEvents.PrePhysics.Subscribe is epic_internal on FN 42.10 (execution_listenable
# is class<epic_internal>) — creator code cannot subscribe. The per-frame hook available to
# us is OnSimulate + loop with Sleep(0.0) (one frame) and our own delta clock.
player_movement_component<public> := class<final_super>(component):

    @editable
    var MaxSpeed : float = 600.0

    @editable
    var Acceleration : float = 3000.0

    @editable
    var Friction : float = 2000.0

    @editable
    var Gravity : float = -1800.0

    @editable
    var JumpImpulse : float = 700.0

    @editable
    var GroundHeight : float = 0.0

    # Desired planar direction (-1..1 per axis), written by the controller from Move input.
    var DesiredMove : vector3 = vector3{}
    var Velocity : vector3 = vector3{}
    var JumpQueued : logic = false

    SetDesiredMove<public>(Dir : vector3)<transacts> : void =
        set DesiredMove = Dir

    QueueJump<public>()<transacts> : void =
        set JumpQueued = true

    OnSimulate<override>()<suspends> : void =
        var Last : float = GetSimulationElapsedTime()
        loop:
            Sleep(0.0)                                  # one frame
            if (not IsSimulating[]):
                break
            Now := GetSimulationElapsedTime()
            Step(Now - Last)
            set Last = Now

    Step(DeltaTime : float) : void =
        T := Entity.GetGlobalTransform()
        Pos := T.Translation

        # comparisons are <decides> — they must sit in a failure context
        var OnGround : logic = false
        if (Pos.Up <= GroundHeight + 1.0):
            set OnGround = true

        WantForward := DesiredMove.Forward * MaxSpeed
        WantLeft := DesiredMove.Left * MaxSpeed
        NewForward := Approach(Velocity.Forward, WantForward, DeltaTime)
        NewLeft := Approach(Velocity.Left, WantLeft, DeltaTime)

        var NewUp : float = Velocity.Up + Gravity * DeltaTime
        if (OnGround?):
            if (JumpQueued?):
                set NewUp = JumpImpulse
                set JumpQueued = false
            else if (NewUp < 0.0):
                set NewUp = 0.0

        set Velocity = vector3{Forward := NewForward, Left := NewLeft, Up := NewUp}

        NextPos := vector3:
            Forward := Pos.Forward + NewForward * DeltaTime
            Left := Pos.Left + NewLeft * DeltaTime
            Up := Max(GroundHeight, Pos.Up + NewUp * DeltaTime)
        Entity.SetGlobalTransform(transform{Translation := NextPos, Rotation := T.Rotation, Scale := T.Scale})

    # Move Current toward Target: Acceleration when driving, Friction when releasing.
    Approach(Current : float, Target : float, DeltaTime : float)<transacts> : float =
        var Rate : float = Acceleration
        if (Target = 0.0):
            set Rate = Friction
        MaxDelta := Rate * DeltaTime          # local must not shadow the method `Step` (E3588)
        Delta := Target - Current
        var Out : float = Target
        if (Delta > MaxDelta):
            set Out = Current + MaxDelta
        else if (Delta < -MaxDelta):
            set Out = Current - MaxDelta
        Out
