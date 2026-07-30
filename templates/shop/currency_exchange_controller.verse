# SETUP: Bidirectional currency swap via ?currency_provider. Needs Economy pack for both indices.
using { /Verse.org/Simulation }
using { /Fortnite.com/Devices }
using { PlayerCore }

currency_exchange_controller := class(creative_device):
    Message<localizes>(String : string) : message = "{String}"

    @editable PlayerManager : player_manager = player_manager{}
    @editable Buttons : []button_device = array{}
    @editable SuccessHudMessage : hud_message_device = hud_message_device{}
    @editable ErrorHudMessage : hud_message_device = hud_message_device{}
    @editable var FromCurrencyIndex : int = 0
    @editable var ToCurrencyIndex : int = 1
    @editable var FromAmount : float = 100.0
    @editable var ToAmount : float = 10.0

    OnBegin<override>()<suspends> : void =
        for (Button : Buttons):
            Button.InteractedWithEvent.Subscribe(Exchange)

    Exchange(Agent : agent) : void =
        if (Wallet := PlayerManager.GetCurrencyProvider()?):
            FromName := Wallet.GetCurrencyName(FromCurrencyIndex)
            ToName := Wallet.GetCurrencyName(ToCurrencyIndex)
            if (Wallet.GetCurrency(Agent, FromCurrencyIndex) >= FromAmount):
                if (Wallet.RemoveCurrency[Agent, FromCurrencyIndex, FromAmount]):
                    Wallet.AddCurrency(Agent, ToCurrencyIndex, ToAmount)
                    SuccessHudMessage.SetText(Message("Exchanged {FromAmount} {FromName} → {ToAmount} {ToName}"))
                    SuccessHudMessage.Show(Agent)
                else:
                    ErrorHudMessage.SetText(Message("Exchange failed"))
                    ErrorHudMessage.Show(Agent)
            else:
                ErrorHudMessage.SetText(Message("Not enough {FromName}"))
                ErrorHudMessage.Show(Agent)
        else:
            ErrorHudMessage.SetText(Message("Economy not available"))
            ErrorHudMessage.Show(Agent)
