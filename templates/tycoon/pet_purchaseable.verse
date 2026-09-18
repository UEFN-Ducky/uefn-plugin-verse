# SETUP: Follow pet. One active pet per plot (ActivePetIndex). MoveTo owner.
using { /Verse.org/Simulation }
using { /Fortnite.com/Devices }
using { /Fortnite.com/Characters }
using { /UnrealEngine.com/Temporary/SpatialMath }

pet_purchaseable <public> := class<concrete>(purchaseable):
    @editable PetProp <public> : creative_prop = creative_prop{}
    @editable FollowSeconds <public> : float = 0.35

    Activate<override>()<suspends> : void =
        if (Plot := OwnerPlot?):
            set Plot.ActivePetIndex = ItemIndex
        ShowRevealProps()
        Gen := RunId
        loop:
            Sleep(FollowSeconds)
            if (RunId <> Gen):
                break
            if (IsOwned = false):
                break
            FollowOwner()

    FollowOwner<public>()<suspends> : void =
        if (Plot := OwnerPlot?):
            if (Plot.ActivePetIndex = ItemIndex):
                if (Agent := Plot.ClaimedBy?, Char := Agent.GetFortCharacter[]):
                    Target := Char.GetTransform()
                    PetProp.MoveTo(Target.Translation, Target.Rotation, FollowSeconds)
