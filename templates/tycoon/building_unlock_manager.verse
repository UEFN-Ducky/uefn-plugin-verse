# SETUP: Place after Player Core. Pay-to-unlock tiers via ?currency_provider.
# Wire BuildingConfigs (props + costs). Without Economy pack, unlock no-ops.
using { /Verse.org/Simulation }
using { /Fortnite.com/Devices }
using { /UnrealEngine.com/Temporary/SpatialMath }
using { PlayerCore }

building_tier_config <public> := class<concrete>():
    @editable Cost <public> : float = 100.0
    @editable CurrencyIndex <public> : int = 0
    @editable LevelProp <public> : creative_prop = creative_prop{}

building_config <public> := class<concrete>():
    @editable Button <public> : button_device = button_device{}
    @editable Tiers <public> : []building_tier_config = array{}
    @editable UndergroundOffset <public> : float = -5000.0

building_button_wrapper := class():
    Manager : building_unlock_manager
    BuildingIndex : int
    OnPressed(Agent : agent) : void =
        Manager.OnUnlockPressed(Agent, BuildingIndex)

building_unlock_manager := class(creative_device):
    Message<localizes>(String : string) : message = "{String}"

    @editable PlayerManager : player_manager = player_manager{}
    @editable Buildings : []building_config = array{}
    @editable SuccessHudMessage : hud_message_device = hud_message_device{}
    @editable ErrorHudMessage : hud_message_device = hud_message_device{}

    var PlayerLevels <private> : [agent][int]int = map{}
    var AnchorTransforms <private> : [int]transform = map{}

    OnBegin<override>()<suspends> : void =
        for (BIndex -> Building : Buildings):
            if (First := Building.Tiers[0]):
                if (set AnchorTransforms[BIndex] = First.LevelProp.GetTransform()):
                    {}
            ParkInactiveTiers(BIndex, -1)
            Wrapper := building_button_wrapper{Manager := Self, BuildingIndex := BIndex}
            Building.Button.InteractedWithEvent.Subscribe(Wrapper.OnPressed)

    OnUnlockPressed<public>(Agent : agent, BuildingIndex : int) : void =
        Current := GetLevel(Agent, BuildingIndex)
        NextLevel := Current + 1
        if (Building := Buildings[BuildingIndex], Tier := Building.Tiers[NextLevel]):
            if (Wallet := PlayerManager.GetCurrencyProvider()?):
                if (Wallet.GetCurrency(Agent, Tier.CurrencyIndex) >= Tier.Cost):
                    if (Wallet.RemoveCurrency[Agent, Tier.CurrencyIndex, Tier.Cost]):
                        SetLevel(Agent, BuildingIndex, NextLevel)
                        ApplyReveal(BuildingIndex, NextLevel)
                        SuccessHudMessage.SetText(Message("Unlocked!"))
                        SuccessHudMessage.Show(Agent)
                    else:
                        ErrorHudMessage.SetText(Message("Purchase failed"))
                        ErrorHudMessage.Show(Agent)
                else:
                    ErrorHudMessage.SetText(Message("Not enough currency"))
                    ErrorHudMessage.Show(Agent)
            else:
                ErrorHudMessage.SetText(Message("Economy not available"))
                ErrorHudMessage.Show(Agent)
        else:
            ErrorHudMessage.SetText(Message("Max tier reached"))
            ErrorHudMessage.Show(Agent)

    GetLevel(Agent : agent, BuildingIndex : int) : int =
        if (Levels := PlayerLevels[Agent], L := Levels[BuildingIndex]):
            return L
        return -1

    SetLevel(Agent : agent, BuildingIndex : int, Level : int) : void =
        var Levels : [int]int = map{}
        if (Existing := PlayerLevels[Agent]):
            set Levels = Existing
        if (set Levels[BuildingIndex] = Level):
            if (set PlayerLevels[Agent] = Levels):
                {}

    ApplyReveal(BuildingIndex : int, ActiveTier : int) : void =
        ParkInactiveTiers(BuildingIndex, ActiveTier)

    ParkInactiveTiers(BuildingIndex : int, ActiveTier : int) : void =
        if (Building := Buildings[BuildingIndex], Anchor := AnchorTransforms[BuildingIndex]):
            for (TIndex -> Tier : Building.Tiers):
                if (TIndex = ActiveTier):
                    if (Tier.LevelProp.TeleportTo[Anchor.Translation, Anchor.Rotation]):
                        {}
                else:
                    Underground := vector3{
                        X := Anchor.Translation.X,
                        Y := Anchor.Translation.Y,
                        Z := Anchor.Translation.Z + Building.UndergroundOffset
                    }
                    if (Tier.LevelProp.TeleportTo[Underground, Anchor.Rotation]):
                        {}
