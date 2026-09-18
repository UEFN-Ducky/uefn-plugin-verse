# SETUP: Idle generator on a plot. Collect/upgrade buttons. Offline via playtime_provider.
using { /Verse.org/Simulation }
using { /Fortnite.com/Devices }
using { PlayerCore }

generator_tier <public> := class<concrete>:
    @editable RatePerSecond <public> : float = 1.0
    @editable UpgradeCost <public> : float = 100.0
    @editable CurrencyIndex <public> : int = 0

generator_button_wrapper := class:
    Item : generator_purchaseable
    IsUpgrade : logic = false
    OnAgent(Agent : agent) : void =
        if (IsUpgrade = true):
            Item.TryUpgrade(Agent)
        else:
            Item.TryCollect(Agent)

generator_purchaseable <public> := class<concrete>(purchaseable):
    @editable CollectButton <public> : button_device = button_device{}
    @editable UpgradeButton <public> : button_device = button_device{}
    @editable Tiers <public> : []generator_tier = array{}
    var Accrued <public> : float = 0.0
    var CollectHook <public> : ?generator_button_wrapper = false
    var UpgradeHook <public> : ?generator_button_wrapper = false
    var AppliedOffline <public> : logic = false

    Initialize<override>(Plot : plot_manager, NewType : int, NewIndex : int) : void =
        (super:)Initialize(Plot, NewType, NewIndex)
        CollectW := generator_button_wrapper{Item := Self, IsUpgrade := false}
        UpgradeW := generator_button_wrapper{Item := Self, IsUpgrade := true}
        set CollectHook = option{CollectW}
        set UpgradeHook = option{UpgradeW}
        CollectButton.InteractedWithEvent.Subscribe(CollectW.OnAgent)
        UpgradeButton.InteractedWithEvent.Subscribe(UpgradeW.OnAgent)

    Activate<override>()<suspends> : void =
        if (AppliedOffline = false):
            ApplyOffline()
            set AppliedOffline = true
        Last := GetSimulationElapsedTime()
        Gen := RunId
        loop:
            Sleep(0.25)
            if (RunId <> Gen):
                break
            if (IsOwned = false):
                break
            Now := GetSimulationElapsedTime()
            Accrue(Now - Last)
            set Last = Now

    ApplyOffline<public>() : void =
        if (Plot := OwnerPlot?):
            if (Clock := Plot.PlayerManager.GetPlaytimeProvider()?):
                if (Agent := Plot.ClaimedBy?):
                    Offline := Clock.GetOfflineSeconds(Agent)
                    if (Offline > 0.0):
                        Accrue(Offline)

    CurrentRate<public>()<transacts> : float =
        if (Plot := OwnerPlot?, Agent := Plot.ClaimedBy?):
            Level := GetPlotLevel(Agent, PackedKey())
            if (Tier := Tiers[Level]):
                return Tier.RatePerSecond
        if (Tier := Tiers[0]):
            return Tier.RatePerSecond
        return 0.0

    Accrue<public>(Delta : float) : void =
        set Accrued = Accrued + CurrentRate() * Delta

    TryCollect<public>(Agent : agent) : void =
        if (Plot := OwnerPlot?):
            if (Plot.IsClaimedBy(Agent) = false):
                ErrorHud.SetText(Message("Not your plot"))
                ErrorHud.Show(Agent)
            else if (IsOwned = false):
                ErrorHud.SetText(Message("Locked"))
                ErrorHud.Show(Agent)
            else if (Whole := Floor[Accrued]):
                if (Whole > 0):
                    Plot.GrantToAgent(Agent, GrantCurrencyIndex, Whole * 1.0)
                    set Accrued = Accrued - (Whole * 1.0)
                    SuccessHud.SetText(Message("Collected {Whole}"))
                    SuccessHud.Show(Agent)

    TryUpgrade<public>(Agent : agent) : void =
        if (Plot := OwnerPlot?):
            if (Plot.IsClaimedBy(Agent) = false):
                ErrorHud.SetText(Message("Not your plot"))
                ErrorHud.Show(Agent)
            else if (IsOwned = false):
                ErrorHud.SetText(Message("Locked"))
                ErrorHud.Show(Agent)
            else:
                Level := GetPlotLevel(Agent, PackedKey())
                NextLevel := Level + 1
                if (Tier := Tiers[NextLevel]):
                    if (Wallet := Plot.PlayerManager.GetCurrencyProvider()?):
                        if (Wallet.GetCurrency(Agent, Tier.CurrencyIndex) >= Tier.UpgradeCost):
                            if (Wallet.RemoveCurrency[Agent, Tier.CurrencyIndex, Tier.UpgradeCost]):
                                SetPlotLevel(Agent, PackedKey(), NextLevel)
                                SuccessHud.SetText(Message("Upgraded"))
                                SuccessHud.Show(Agent)
                            else:
                                ErrorHud.SetText(Message("Upgrade failed"))
                                ErrorHud.Show(Agent)
                        else:
                            ErrorHud.SetText(Message("Not enough currency"))
                            ErrorHud.Show(Agent)
                    else:
                        ErrorHud.SetText(Message("Economy not available"))
                        ErrorHud.Show(Agent)
                else:
                    ErrorHud.SetText(Message("Max tier"))
                    ErrorHud.Show(Agent)

    OnRebirth<override>() : void =
        (super:)OnRebirth()
        set Accrued = 0.0
        set AppliedOffline = false
