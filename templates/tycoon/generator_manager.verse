# SETUP: Place after Player Core. Passive accrual loop + collect button.
# Pays via ?currency_provider. Offline bonus via ?playtime_provider when Time Tracker is present.
using { /Verse.org/Simulation }
using { /Fortnite.com/Devices }
using { PlayerCore }

generator_tier <public> := class<concrete>():
    @editable RatePerSecond <public> : float = 1.0
    @editable UpgradeCost <public> : float = 100.0
    @editable CurrencyIndex <public> : int = 0

generator_config <public> := class<concrete>():
    @editable CollectButton <public> : button_device = button_device{}
    @editable UpgradeButton <public> : button_device = button_device{}
    @editable Tiers <public> : []generator_tier = array{}

generator_collect_wrapper := class():
    Manager : generator_manager
    GenIndex : int
    OnPressed(Agent : agent) : void = Manager.Collect(Agent, GenIndex)

generator_upgrade_wrapper := class():
    Manager : generator_manager
    GenIndex : int
    OnPressed(Agent : agent) : void = Manager.Upgrade(Agent, GenIndex)

generator_manager := class(creative_device):
    Message<localizes>(String : string) : message = "{String}"

    @editable PlayerManager : player_manager = player_manager{}
    @editable Generators : []generator_config = array{}
    @editable SuccessHudMessage : hud_message_device = hud_message_device{}
    @editable ErrorHudMessage : hud_message_device = hud_message_device{}

    var Levels <private> : [agent][int]int = map{}
    var Accrued <private> : [agent][int]float = map{}
    var LastTick <private> : float = 0.0

    OnBegin<override>()<suspends> : void =
        for (GIndex -> Gen : Generators):
            CollectW := generator_collect_wrapper{Manager := Self, GenIndex := GIndex}
            UpgradeW := generator_upgrade_wrapper{Manager := Self, GenIndex := GIndex}
            Gen.CollectButton.InteractedWithEvent.Subscribe(CollectW.OnPressed)
            Gen.UpgradeButton.InteractedWithEvent.Subscribe(UpgradeW.OnPressed)
        set LastTick = GetSimulationElapsedTime()
        spawn{ GenerationLoop() }
        # Offline earnings once for already-joined players
        Agents := Self.GetPlayspace().GetPlayers()
        for (Agent : Agents):
            ApplyOfflineBonus(Agent)

    GenerationLoop<private>()<suspends> : void =
        loop:
            Sleep(0.25)
            Now := GetSimulationElapsedTime()
            Delta := Now - LastTick
            set LastTick = Now
            Agents := Self.GetPlayspace().GetPlayers()
            for (Agent : Agents):
                Accrue(Agent, Delta)

    Accrue(Agent : agent, Delta : float) : void =
        var AgentAcc : [int]float = map{}
        if (Existing := Accrued[Agent]):
            set AgentAcc = Existing
        for (GIndex -> Gen : Generators):
            Level := GetLevel(Agent, GIndex)
            if (Tier := Gen.Tiers[Level]):
                Prev := 0.0
                if (P := AgentAcc[GIndex]):
                    set Prev = P
                if (set AgentAcc[GIndex] = Prev + Tier.RatePerSecond * Delta):
                    {}
        if (set Accrued[Agent] = AgentAcc):
            {}

    ApplyOfflineBonus(Agent : agent) : void =
        if (Clock := PlayerManager.GetPlaytimeProvider()?):
            Offline := Clock.GetOfflineSeconds(Agent)
            if (Offline > 0.0):
                Accrue(Agent, Offline)

    Collect<public>(Agent : agent, GenIndex : int) : void =
        if (AgentAcc := Accrued[Agent], Amount := AgentAcc[GenIndex], Whole := Floor[Amount]):
            if (Whole > 0):
                if (Gen := Generators[GenIndex], Tier := Gen.Tiers[GetLevel(Agent, GenIndex)]):
                    if (Wallet := PlayerManager.GetCurrencyProvider()?):
                        Wallet.AddCurrency(Agent, Tier.CurrencyIndex, Whole * 1.0)
                        if (set AgentAcc[GenIndex] = Amount - (Whole * 1.0)):
                            if (set Accrued[Agent] = AgentAcc):
                                SuccessHudMessage.SetText(Message("Collected {Whole}"))
                                SuccessHudMessage.Show(Agent)
                    else:
                        ErrorHudMessage.SetText(Message("Economy not available"))
                        ErrorHudMessage.Show(Agent)

    Upgrade<public>(Agent : agent, GenIndex : int) : void =
        NextLevel := GetLevel(Agent, GenIndex) + 1
        if (Gen := Generators[GenIndex], Tier := Gen.Tiers[NextLevel]):
            if (Wallet := PlayerManager.GetCurrencyProvider()?):
                if (Wallet.GetCurrency(Agent, Tier.CurrencyIndex) >= Tier.UpgradeCost):
                    if (Wallet.RemoveCurrency[Agent, Tier.CurrencyIndex, Tier.UpgradeCost]):
                        SetLevel(Agent, GenIndex, NextLevel)
                        SuccessHudMessage.SetText(Message("Upgraded!"))
                        SuccessHudMessage.Show(Agent)
                    else:
                        ErrorHudMessage.SetText(Message("Upgrade failed"))
                        ErrorHudMessage.Show(Agent)
                else:
                    ErrorHudMessage.SetText(Message("Not enough currency"))
                    ErrorHudMessage.Show(Agent)
            else:
                ErrorHudMessage.SetText(Message("Economy not available"))
                ErrorHudMessage.Show(Agent)
        else:
            ErrorHudMessage.SetText(Message("Max tier"))
            ErrorHudMessage.Show(Agent)

    GetLevel(Agent : agent, GenIndex : int) : int =
        if (AgentLevels := Levels[Agent], L := AgentLevels[GenIndex]):
            return L
        return 0

    SetLevel(Agent : agent, GenIndex : int, Level : int) : void =
        var AgentLevels : [int]int = map{}
        if (Existing := Levels[Agent]):
            set AgentLevels = Existing
        if (set AgentLevels[GenIndex] = Level):
            if (set Levels[Agent] = AgentLevels):
                {}
