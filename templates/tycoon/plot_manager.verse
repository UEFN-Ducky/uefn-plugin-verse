# SETUP: Place one plot_manager per pad. Wire PlayerManager + purchaseable arrays.
# Apply player_core → economy → progression → time_tracker → tycoon first.
using { /Verse.org/Simulation }
using { /Fortnite.com/Devices }
using { PlayerCore }

plot_manager <public> := class(creative_device, rebirthable):
    Message<localizes>(String : string) : message = "{String}"

    @editable PlayerManager <public> : player_manager = player_manager{}
    @editable ClaimButton <public> : button_device = button_device{}
    @editable ClaimTeleporter <public> : teleporter_device = teleporter_device{}
    @editable SuccessHud <public> : hud_message_device = hud_message_device{}
    @editable ErrorHud <public> : hud_message_device = hud_message_device{}
    @editable RebirthButton <public> : button_device = button_device{}
    @editable RebirthCost <public> : float = 1000.0
    @editable RebirthCurrencyIndex <public> : int = 0
    @editable RebirthCostMultiplier <public> : float = 2.0
    @editable GrantMultiplier <public> : float = 1.15
    @editable Props <public> : []prop_purchaseable = array{}
    @editable Generators <public> : []generator_purchaseable = array{}
    @editable Droppers <public> : []dropper_purchaseable = array{}
    @editable Conveyors <public> : []conveyor_purchaseable = array{}
    @editable Upgraders <public> : []upgrader_purchaseable = array{}
    @editable NPCs <public> : []npc_purchaseable = array{}
    @editable Pets <public> : []pet_purchaseable = array{}
    @editable Dancefloors <public> : []dancefloor_purchaseable = array{}
    @editable Hitables <public> : []hitable_purchaseable = array{}
    @editable Shootables <public> : []shootable_purchaseable = array{}
    @editable Collectables <public> : []plot_collectable = array{}
    @editable Gifts <public> : []timed_gift = array{}
    @editable Wheels <public> : []money_wheel = array{}

    var ClaimedBy <public> : ?agent = false
    var BeltMultiplier <public> : float = 1.0
    var ActivePetIndex <public> : int = -1

    OnBegin<override>()<suspends> : void =
        ClaimButton.InteractedWithEvent.Subscribe(OnClaimPressed)
        RebirthButton.InteractedWithEvent.Subscribe(OnRebirthPressed)
        InitializeAll()

    InitializeAll<public>() : void =
        set BeltMultiplier = 1.0
        set ActivePetIndex = -1
        for (I -> Item : Props):
            Item.Initialize(Self, 0, I)
        for (I -> Item : Generators):
            Item.Initialize(Self, 1, I)
        for (I -> Item : Droppers):
            Item.Initialize(Self, 2, I)
        for (I -> Item : Conveyors):
            Item.Initialize(Self, 3, I)
        for (I -> Item : Upgraders):
            Item.Initialize(Self, 4, I)
        for (I -> Item : NPCs):
            Item.Initialize(Self, 5, I)
        for (I -> Item : Pets):
            Item.Initialize(Self, 6, I)
        for (I -> Item : Dancefloors):
            Item.Initialize(Self, 7, I)
        for (I -> Item : Hitables):
            Item.Initialize(Self, 8, I)
        for (I -> Item : Shootables):
            Item.Initialize(Self, 9, I)
        for (I -> Item : Collectables):
            Item.Initialize(Self, I)
        for (I -> Item : Gifts):
            Item.Initialize(Self, I)
        for (I -> Item : Wheels):
            Item.Initialize(Self, I)

    IsClaimed<public>()<transacts> : logic =
        if (ClaimedBy?):
            return true
        return false

    IsClaimedBy<public>(Agent : agent)<transacts> : logic =
        if (Owner := ClaimedBy?, Owner = Agent):
            return true
        return false

    FindPurchaseable<public>(TypeIndex : int, ItemIndex : int)<transacts> : ?purchaseable =
        if (TypeIndex = 0, Item := Props[ItemIndex]):
            return option{Item}
        if (TypeIndex = 1, Item := Generators[ItemIndex]):
            return option{Item}
        if (TypeIndex = 2, Item := Droppers[ItemIndex]):
            return option{Item}
        if (TypeIndex = 3, Item := Conveyors[ItemIndex]):
            return option{Item}
        if (TypeIndex = 4, Item := Upgraders[ItemIndex]):
            return option{Item}
        if (TypeIndex = 5, Item := NPCs[ItemIndex]):
            return option{Item}
        if (TypeIndex = 6, Item := Pets[ItemIndex]):
            return option{Item}
        if (TypeIndex = 7, Item := Dancefloors[ItemIndex]):
            return option{Item}
        if (TypeIndex = 8, Item := Hitables[ItemIndex]):
            return option{Item}
        if (TypeIndex = 9, Item := Shootables[ItemIndex]):
            return option{Item}
        return false

    FindConveyor<public>(ConveyorIndex : int)<transacts> : ?conveyor_purchaseable =
        if (Belt := Conveyors[ConveyorIndex]):
            return option{Belt}
        return false

    OnClaimPressed<public>(Agent : agent) : void =
        Claim(Agent)

    Claim<public>(Agent : agent) : void =
        if (IsClaimed() = true):
            ErrorHud.SetText(Message("Plot already claimed"))
            ErrorHud.Show(Agent)
        else:
            set ClaimedBy = option{Agent}
            SuccessHud.SetText(Message("Plot claimed"))
            SuccessHud.Show(Agent)
            ApplySavedUnlocks(Agent)
            ShowRuntime(Agent)

    TeleportOwner<public>(Agent : agent) : void =
        ClaimTeleporter.Teleport(Agent)

    Unclaim<public>() : void =
        set ClaimedBy = false
        set BeltMultiplier = 1.0
        set ActivePetIndex = -1
        RebirthList()

    ApplySavedUnlocks<public>(Agent : agent) : void =
        for (Packed : GetPlotUnlocks(Agent)):
            TypeIndex := UnpackPlotType(Packed)
            ItemIndex := UnpackPlotItem(Packed)
            if (Item := FindPurchaseable(TypeIndex, ItemIndex)?):
                Item.ApplyLoadedUnlock(Agent)

    ShowRuntime<public>(Agent : agent) : void =
        for (Item : Collectables):
            Item.ShowFor(Agent)
        for (Item : Gifts):
            Item.StartFor(Agent)
        for (Item : Wheels):
            Item.EnableFor(Agent)

    GrantToOwner<public>(CurrencyIndex : int, Amount : float) : void =
        if (Agent := ClaimedBy?):
            GrantToAgent(Agent, CurrencyIndex, Amount)

    GrantToAgent<public>(Agent : agent, CurrencyIndex : int, Amount : float) : void =
        if (Wallet := PlayerManager.GetCurrencyProvider()?):
            Rebirths := GetPlotRebirths(Agent)
            Scaled := ScaleByRebirths(Amount, Rebirths)
            Wallet.AddCurrency(Agent, CurrencyIndex, Scaled * BeltMultiplier)

    ScaleByRebirths<public>(Amount : float, Rebirths : int) : float =
        var Scale : float = 1.0
        var I : int = 0
        loop:
            if (I >= Rebirths):
                break
            set Scale = Scale * GrantMultiplier
            set I = I + 1
        Amount * Scale

    CostForRebirth<public>(Rebirths : int) : float =
        var Cost : float = RebirthCost
        var I : int = 0
        loop:
            if (I >= Rebirths):
                break
            set Cost = Cost * RebirthCostMultiplier
            set I = I + 1
        Cost

    OnRebirthPressed<public>(Agent : agent) : void =
        if (IsClaimedBy(Agent) = false):
            ErrorHud.SetText(Message("Not your plot"))
            ErrorHud.Show(Agent)
        else:
            TryRebirth(Agent)

    TryRebirth<public>(Agent : agent) : void =
        Rebirths := GetPlotRebirths(Agent)
        Cost := CostForRebirth(Rebirths)
        if (Wallet := PlayerManager.GetCurrencyProvider()?):
            if (Wallet.GetCurrency(Agent, RebirthCurrencyIndex) >= Cost):
                if (Wallet.RemoveCurrency[Agent, RebirthCurrencyIndex, Cost]):
                    DrainWallet(Agent, Wallet)
                    AddPlotRebirth(Agent)
                    OnRebirth()
                    SuccessHud.SetText(Message("Rebirth complete"))
                    SuccessHud.Show(Agent)
                else:
                    ErrorHud.SetText(Message("Rebirth failed"))
                    ErrorHud.Show(Agent)
            else:
                ErrorHud.SetText(Message("Not enough currency"))
                ErrorHud.Show(Agent)
        else:
            ErrorHud.SetText(Message("Economy not available"))
            ErrorHud.Show(Agent)

    DrainWallet<public>(Agent : agent, Wallet : currency_provider) : void =
        var Index : int = 0
        loop:
            if (Index > 7):
                break
            Amt := Wallet.GetCurrency(Agent, Index)
            if (Amt > 0.0):
                if (Wallet.RemoveCurrency[Agent, Index, Amt]) {}
            set Index = Index + 1

    OnRebirth<override>() : void =
        set BeltMultiplier = 1.0
        set ActivePetIndex = -1
        RebirthList()
        if (Agent := ClaimedBy?):
            ShowRuntime(Agent)

    RebirthList<public>() : void =
        for (Item : Props):
            Item.OnRebirth()
        for (Item : Generators):
            Item.OnRebirth()
        for (Item : Droppers):
            Item.OnRebirth()
        for (Item : Conveyors):
            Item.OnRebirth()
        for (Item : Upgraders):
            Item.OnRebirth()
        for (Item : NPCs):
            Item.OnRebirth()
        for (Item : Pets):
            Item.OnRebirth()
        for (Item : Dancefloors):
            Item.OnRebirth()
        for (Item : Hitables):
            Item.OnRebirth()
        for (Item : Shootables):
            Item.OnRebirth()
        for (Item : Collectables):
            Item.OnRebirth()
        for (Item : Gifts):
            Item.OnRebirth()
        for (Item : Wheels):
            Item.OnRebirth()
