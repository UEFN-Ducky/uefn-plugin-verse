# SETUP: Requires Player Core. economy_manager_device registers this as currency_provider.
# Own weak_map — does not edit PlayerCore files.
using { /Verse.org/Simulation }
using { /Fortnite.com/Devices }
using { /UnrealEngine.com/Temporary/UI }
using { PlayerCore }

currency_data <public> := class<final><persistable>:
    CurrencyName <public> : string = ""
    Value <public> : float = 0.0
    ScaleIndex <public> : int = 0

economy_table <public> := class<final><persistable>:
    Version <public> : int = 0
    Currencies <public> : []currency_data = array{}

var EconomyMap <public> : weak_map(player, economy_table) = map{}

currency_config <public> := class<concrete>():
    @editable Disabled <public> : logic = false
    @editable CurrencyName <public> : string = "Coins"
    @editable ScaleSuffixes <public> : []string = array{"", "K", "M", "B"}
    @editable ItemGranter <public> : item_granter_device = item_granter_device{}
    @editable ConditionalButton <public> : conditional_button_device = conditional_button_device{}

MakeEconomyTable(Old : economy_table, NewCurrencies : []currency_data)<transacts> : economy_table =
    economy_table{Version := Old.Version, Currencies := NewCurrencies}

economy_manager <public> := class<unique>(currency_provider):
    var CurrencyConfigs <public> : []currency_config = array{}
    var MyAgent <public> : ?agent = false

    SetConfig<public>(Configs : []currency_config) : void =
        set CurrencyConfigs = Configs

    EnsureRow(Agent : agent) : void =
        if:
            Player := player[Agent]
            Player.IsActive[]
        then:
            if (Existing := EconomyMap[Player]):
            else:
                if (set EconomyMap[Player] = economy_table{}):
                    {}

    AddCurrency<override>(Agent : agent, CurrencyIndex : int, Amount : float) : void =
        EnsureRow(Agent)
        if:
            Player := player[Agent]
            Player.IsActive[]
            OldTable := EconomyMap[Player]
            Cfg := CurrencyConfigs[CurrencyIndex]
            not Cfg.Disabled?
        then:
            Name := Cfg.CurrencyName
            var Updated : []currency_data = array{}
            var Found : logic = false
            for (Entry : OldTable.Currencies):
                if (Entry.CurrencyName = Name):
                    set Found = true
                    set Updated += array{currency_data{
                        CurrencyName := Name,
                        Value := Entry.Value + Amount,
                        ScaleIndex := Entry.ScaleIndex
                    }}
                else:
                    set Updated += array{Entry}
            if (Found = false):
                set Updated += array{currency_data{CurrencyName := Name, Value := Amount, ScaleIndex := 0}}
            if (set EconomyMap[Player] = MakeEconomyTable(OldTable, Updated)):
                {}

    RemoveCurrency<override>(Agent : agent, CurrencyIndex : int, Amount : float)<decides> : void =
        EnsureRow(Agent)
        if:
            Player := player[Agent]
            Player.IsActive[]
            OldTable := EconomyMap[Player]
            Cfg := CurrencyConfigs[CurrencyIndex]
            not Cfg.Disabled?
            Current := GetCurrency(Agent, CurrencyIndex)
            Current >= Amount
        then:
            Name := Cfg.CurrencyName
            var Updated : []currency_data = array{}
            for (Entry : OldTable.Currencies):
                if (Entry.CurrencyName = Name):
                    set Updated += array{currency_data{
                        CurrencyName := Name,
                        Value := Entry.Value - Amount,
                        ScaleIndex := Entry.ScaleIndex
                    }}
                else:
                    set Updated += array{Entry}
            if (set EconomyMap[Player] = MakeEconomyTable(OldTable, Updated)):
                {}
        else:
            false

    GetCurrency<override>(Agent : agent, CurrencyIndex : int) : float =
        if:
            Player := player[Agent]
            Player.IsActive[]
            Table := EconomyMap[Player]
            Cfg := CurrencyConfigs[CurrencyIndex]
        then:
            Name := Cfg.CurrencyName
            for (Entry : Table.Currencies):
                if (Entry.CurrencyName = Name):
                    return Entry.Value
            return 0.0
        return 0.0

    GetCurrencyName<override>(CurrencyIndex : int) : string =
        if (Cfg := CurrencyConfigs[CurrencyIndex]):
            return Cfg.CurrencyName
        return ""

    FormatAmount<public>(Amount : float) : string =
        if (Amount >= 1000000000.0):
            return "{Amount / 1000000000.0}B"
        else if (Amount >= 1000000.0):
            return "{Amount / 1000000.0}M"
        else if (Amount >= 1000.0):
            return "{Amount / 1000.0}K"
        else:
            return "{Amount}"
