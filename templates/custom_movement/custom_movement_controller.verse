# SETUP: pairs with player_movement_component in this pack.
# 1. Rig prefab: root entity (transform_component) -> child Mesh (mesh_component)
#    -> child CameraPivot (transform_component) -> child Camera (perspective_camera_component).
# 2. Add player_movement_component to the ROOT entity of that prefab.
# 3. Place this device, wire RigPrefabRoot to the placed rig.
# EXPERIMENTAL: `Move` input + Scene Graph camera classes + fort_* camera modifiers
# all block publishing (Script warning 2304).
using { /Fortnite.com/Devices }
using { /Fortnite.com/Characters }
using { /Fortnite.com/Playspaces }
using { /Fortnite.com/Input }
using { /Fortnite.com/Input/Character }
using { /Fortnite.com/SceneGraphCameras }
using { /Verse.org/Input }
using { /Verse.org/SceneGraph }
using { /Verse.org/SpatialMath }
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/Diagnostics }

# --- device: hooks input, parks the stock character, rigs the orbit camera ---
custom_movement_controller := class(creative_device):

    @editable
    RigPrefabRoot : entity = entity{}

    @editable
    HideStockCharacter : logic = true

    # Orbit camera tuning -- all live on fort_orbit_camera_modifier (centimeters).
    @editable
    CameraDistanceCentimeters : float = 450.0

    @editable
    CameraHeightCentimeters : float = 120.0

    @editable
    CameraCollision : logic = true

    var Movers : [player]player_movement_component = map{}
    var Subs : [player][]cancelable = map{}

    OnBegin<override>()<suspends> : void =
        Playspace := GetPlayspace()
        for (P : Playspace.GetPlayers()):
            Attach(P)
        Playspace.PlayerAddedEvent().Subscribe(Attach)
        Playspace.PlayerRemovedEvent().Subscribe(Detach)

    Attach(P : player) : void =
        # 1. custom locomotion component on the rig
        if (Mover := (for (M : RigPrefabRoot.FindDescendantComponents(player_movement_component)) do M)[0]):
            if (set Movers[P] = Mover) {}
        # 2. orbit-follow the rig, then make that camera this player's view
        if (Cam := (for (C : RigPrefabRoot.FindDescendantComponents(perspective_camera_component)) do C)[0]):
            RigOrbitCamera(Cam)
            if:
                Director := (for (D : P.FindDescendantComponents(camera_director_component)) do D)[0]
                # AddCamera IS <decides> -> square brackets. Highest priority wins.
                CamHandle := Director.AddCamera[Cam, 100]
            then:
                Print("custom orbit camera active")
        # 3. park the stock character so it cannot fight our motion
        if (HideStockCharacter?, FC := P.GetFortCharacter[]):
            FC.PutInStasis(stasis_args{})
            FC.Hide()
        # 4. Move + Jump input (TraversalMapping)
        if (PlayerInput := GetPlayerInput[P]):
            PlayerInput.AddInputMapping(TraversalMapping)
            MoveSub := PlayerInput.GetInputEvents(Move).TriggerActivationEvent.Subscribe(OnMove)
            MoveEnd := PlayerInput.GetInputEvents(Move).EndDetectEvent.Subscribe(OnMoveEnd)
            JumpSub := PlayerInput.GetInputEvents(Jump).TriggerActivationEvent.Subscribe(OnJump)
            if (set Subs[P] = array{MoveSub, MoveEnd, JumpSub}) {}

    # Scene Graph orbit camera: a fort_orbit_camera_modifier on the rig camera's
    # modifier stack. TargetEntity is not a `var` -> set at construction.
    RigOrbitCamera(Cam : camera_component) : void =
        Orbit := fort_orbit_camera_modifier:
            TargetEntity := RigPrefabRoot
        set Orbit.CameraDistanceCentimeters = CameraDistanceCentimeters
        set Orbit.CameraHeightCentimeters = CameraHeightCentimeters
        set Orbit.EnableCollision = CameraCollision
        # AddModifier has NO <decides> -> parentheses (brackets give error 3511).
        OrbitHandle := Cam.CameraModifiers.AddModifier(Orbit, VisualModifierPosition)
        # Keep OrbitHandle if you need to pop the modifier later: OrbitHandle.Cancel()

    Detach(P : player) : void =
        if (List := Subs[P]):
            for (S : List):
                S.Cancel()
        var NextSubs : [player][]cancelable = map{}
        for (K -> V : Subs, K <> P):
            if (set NextSubs[K] = V) {}
        set Subs = NextSubs
        var NextMovers : [player]player_movement_component = map{}
        for (K -> V : Movers, K <> P):
            if (set NextMovers[K] = V) {}
        set Movers = NextMovers

    # Move payload: (player, vector3) -- Forward/Left are the stick/WASD axes, -1..1
    OnMove(Arg : tuple(player, vector3)) : void =
        if (Mover := Movers[Arg(0)]):
            Mover.SetDesiredMove(Arg(1))

    # EndDetectEvent carries (player, float) -- elapsed seconds, NO position.
    OnMoveEnd(Arg : tuple(player, float)) : void =
        if (Mover := Movers[Arg(0)]):
            Mover.SetDesiredMove(vector3{})

    OnJump(Arg : tuple(player, logic)) : void =
        if (Mover := Movers[Arg(0)]):
            Mover.QueueJump()
