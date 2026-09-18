# SETUP: Place ONE tycoon_controller. Wire Plots + PlayerManager.
# ClaimMode: Manual (plot ClaimButton), Fill (first free plot on join), Teleport (Fill + move).
using { /Verse.org/Simulation }
using { /Fortnite.com/Devices }
using { PlayerCore }

plot_claim_mode <public> := enum:
    Manual
    Fill
    Teleport

tycoon_controller <public> := class(creative_device):
    Message<localizes>(String : string) : message = "{String}"

    @editable PlayerManager <public> : player_manager = player_manager{}
    @editable Plots <public> : []plot_manager = array{}
    @editable ClaimMode <public> : plot_claim_mode = plot_claim_mode.Manual
    @editable StatusHud <public> : hud_message_device = hud_message_device{}

    OnBegin<override>()<suspends> : void =
        PlayerManager.SubscribePlayerConnected(OnPlayerJoined)
        PlayerManager.SubscribePlayerRemoved(OnPlayerLeft)
        InitializeAlreadyJoined()

    InitializeAlreadyJoined<public>() : void =
        Agents := Self.GetPlayspace().GetPlayers()
        for (Agent : Agents):
            if (GP := PlayerManager.GetGamePlayer(Agent)?):
                OnPlayerJoined(GP)

    OnPlayerJoined<public>(GamePlayer : game_player) : void =
        if (ClaimMode <> plot_claim_mode.Manual):
            AssignPlot(GamePlayer.MyAgent)

    OnPlayerLeft<public>(GamePlayer : game_player) : void =
        Agent := GamePlayer.MyAgent
        for (Plot : Plots):
            if (Plot.IsClaimedBy(Agent) = true):
                Plot.Unclaim()

    AssignPlot<public>(Agent : agent) : void =
        for (Plot : Plots):
            if (Plot.IsClaimed() = false):
                Plot.Claim(Agent)
                if (ClaimMode = plot_claim_mode.Teleport):
                    Plot.TeleportOwner(Agent)
                StatusHud.SetText(Message("Plot assigned"))
                StatusHud.Show(Agent)
                return
        StatusHud.SetText(Message("No free plots"))
        StatusHud.Show(Agent)
