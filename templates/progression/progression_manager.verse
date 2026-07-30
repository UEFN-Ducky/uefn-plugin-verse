# SETUP: Requires Player Core. Registers as xp_awarder. Currency rewards use ?currency_provider.
using { /Verse.org/Simulation }
using { /Fortnite.com/Devices }
using { PlayerCore }

player_level <public> := class<final><persistable>:
    TotalLevelXP <public> : int = 0
    CurrentLevelIndex <public> : int = 0

progression_table <public> := class<final><persistable>:
    Version <public> : int = 0
    Level <public> : player_level = player_level{}

var ProgressionMap <public> : weak_map(player, progression_table) = map{}

player_level_threshold <public> := class<concrete>():
    @editable ThresholdXP <public> : int = 0
    @editable LevelName <public> : string = "Level 1"

MakeProgressionTable(Old : progression_table, NewLevel : player_level)<transacts> : progression_table =
    progression_table{Version := Old.Version, Level := NewLevel}

progression_manager <public> := class<unique>(xp_awarder):
    var LevelData <public> : []player_level_threshold = array{}
    var LastRecordedLevel <public> : int = 0
    var MyAgent <public> : ?agent = false

    SetConfig<public>(Levels : []player_level_threshold) : void =
        set LevelData = Levels

    EnsureRow(Agent : agent) : void =
        if:
            Player := player[Agent]
            Player.IsActive[]
        then:
            if (Existing := ProgressionMap[Player]):
            else:
                if (set ProgressionMap[Player] = progression_table{}):
                    {}

    GetTotalXP(Agent : agent) : int =
        if:
            Player := player[Agent]
            Player.IsActive[]
            Table := ProgressionMap[Player]
        then:
            return Table.Level.TotalLevelXP
        return 0

    GetCurrentLevelNumber<public>(XP : int) : int =
        if (LevelData.Length <= 0):
            return 0
        for (Index := 0..LevelData.Length - 2):
            if (XP >= LevelData[Index].ThresholdXP and XP < LevelData[Index + 1].ThresholdXP):
                return Index
        if (XP >= LevelData[LevelData.Length - 1].ThresholdXP):
            return LevelData.Length - 1
        return 0

    AddXP<override>(Agent : agent, Amount : int) : void =
        EnsureRow(Agent)
        if:
            Player := player[Agent]
            Player.IsActive[]
            OldTable := ProgressionMap[Player]
        then:
            NewXP := OldTable.Level.TotalLevelXP + Amount
            NewIndex := GetCurrentLevelNumber(NewXP)
            NewLevel := player_level{TotalLevelXP := NewXP, CurrentLevelIndex := NewIndex}
            if (set ProgressionMap[Player] = MakeProgressionTable(OldTable, NewLevel)):
                if (NewIndex > LastRecordedLevel):
                    set LastRecordedLevel = NewIndex

    ProgressPercent<public>(Agent : agent) : float =
        XP := GetTotalXP(Agent)
        Index := GetCurrentLevelNumber(XP)
        if (LevelData.Length <= 0):
            return 0.0
        if (Index >= LevelData.Length - 1):
            return 100.0
        if (Cur := LevelData[Index], Nxt := LevelData[Index + 1]):
            Span := (Nxt.ThresholdXP - Cur.ThresholdXP) * 1.0
            if (Span <= 0.0):
                return 0.0
            return ((XP - Cur.ThresholdXP) * 1.0) / Span * 100.0
        return 0.0

    LevelNameFor<public>(Agent : agent) : string =
        Index := GetCurrentLevelNumber(GetTotalXP(Agent))
        if (Row := LevelData[Index]):
            return Row.LevelName
        return "Level"
