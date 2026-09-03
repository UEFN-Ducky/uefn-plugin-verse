# SETUP: Place after Player Core. Buys via PlayerManager.GetCurrencyProvider()? + item_granter.
# Standalone without Economy: purchase button no-ops (lookup fails).
using { /Verse.org/Simulation }
using { /Fortnite.com/Devices }
using { PlayerCore }

shop_controller := class(creative_device):
    Message<localizes>(String : string) : message = "{String}"

    @editable PlayerManager : player_manager = player_manager{}
    @editable Buttons : []button_device = array{}
    @editable ItemGranter : item_granter_device = item_granter_device{}
    @editable SuccessHudMessage : hud_message_device = hud_message_device{}
    @editable ErrorHudMessage : hud_message_device = hud_message_device{}
    @editable var CurrencyIndex : int = 0
    @editable var Price : float = 100.0

    OnBegin<override>()<suspends> : void =
        for (Button : Buttons):
            Button.InteractedWithEvent.Subscribe(BuyWithCurrency)

    BuyWithCurrency(Agent : agent) : void =
        if (Wallet := PlayerManager.GetCurrencyProvider()?):
            Name := Wallet.GetCurrencyName(CurrencyIndex)
            Current := Wallet.GetCurrency(Agent, CurrencyIndex)
            if (Current >= Price):
                if (Wallet.RemoveCurrency[Agent, CurrencyIndex, Price]):
                    ItemGranter.GrantItem(Agent)
                    SuccessHudMessage.SetText(Message("Purchase Successful!"))
                    SuccessHudMessage.Show(Agent)
                else:
                    ErrorHudMessage.SetText(Message("Could not charge {Name}"))
                    ErrorHudMessage.Show(Agent)
            else:
                ErrorHudMessage.SetText(Message("Not enough {Name}!"))
                ErrorHudMessage.Show(Agent)
        else:
            ErrorHudMessage.SetText(Message("Economy not available"))
            ErrorHudMessage.Show(Agent)
