---
description: "Currency & economy — the wallet manager, currency config, buy-with-currency shops, granting items, HUD feedback, and scaled/suffixed currency values"
metadata:
  order: 23
  label: "Game systems — currency, wallet & shops"
  default_enabled: false
  load_condition: "Building currency/wallet, shops, purchases, item granting, or a scaled money display (K/M/B suffixes)"
---

## Currency, wallet & shops

Names below are generic — adapt them to your game. All device APIs
(`button_device`, `item_granter_device`, `hud_message_device`) come from the digest.

### The wallet manager

Wallet is a per-player manager in `game_player.Services.EconomyManager`.
Currencies persist as an array of a `<persistable>` entry inside the player's
table; a `economy_save_service` does the rebuild-and-store (see
`persistence`). Each currency is name + value + scale index:

```verse
currency_data := class<final><persistable>:
    CurrencyName <public> : string = ""
    Value <public> : float = 0.0
    ScaleIndex <public> : int = 0        # 0 = ones, 1 = K, 2 = M … (display scaling)
```

Designers configure available currencies with a `<concrete>` config class exposed
on the wallet device:

```verse
currency_config <public> := class<concrete>():
    @editable CurrencyName : string = "Coins"
    @editable Disabled : logic = false
    @editable ScaleSuffixes : []string = array{}   # "", "K", "M", "B"
```

### Add / remove / read

All mutations go through the wallet system's public API (which calls the
persistence manager). Adding accumulates into the matching entry or appends a new
one; removing subtracts and drops entries that hit zero:

```verse
MyPlayer.Services.EconomyManager.RemoveCurrency(CurrencyName, Price)
Current := MyPlayer.Services.EconomyManager.GetCurrency(CurrencyName)
```

The manager rebuilds the currency array functionally (accumulate into a
`var []currency_data` with `+=`, then store) — the standard immutable-update
pattern.

### A purchase device (buy with currency)

The shop pattern: subscribe buttons → look up the buyer's wallet → check funds →
remove currency + grant item → HUD feedback + analytics:

```verse
buy_with_currency := class(creative_device):
    @editable MyPlayerManager : player_manager = player_manager{}
    @editable Buttons : []button_device = array{}
    @editable ItemGranter : item_granter_device = item_granter_device{}
    @editable var Price : int = 100
    @editable var CurrencyIndex : int = 0
    Message<localizes>(String : string) : message = "{String}"

    OnBegin<override>()<suspends> : void =
        for (Button : Buttons):
            Button.InteractedWithEvent.Subscribe(BuyWithCurrency)

    BuyWithCurrency(Agent : agent) : void =
        AllPlayers := MyPlayerManager.GetAllGamePlayers()
        if (MyPlayer := AllPlayers[Agent], Cfg := MyPlayer.Services.EconomyManager.CurrencyData[CurrencyIndex]):
            Name := Cfg.CurrencyName
            if (MyPlayer.Services.EconomyManager.GetCurrency(Name) >= Price):
                MyPlayer.Services.EconomyManager.RemoveCurrency(Name, Price)
                ItemGranter.GrantItem(Agent)
                SuccessHudMessage.SetText(Message("Purchase Successful!"))
                SuccessHudMessage.Show(Agent)
            else:
                ErrorHudMessage.SetText(Message("Not enough {Name}!"))
                ErrorHudMessage.Show(Agent)
```

Key devices from the digest: `button_device` (`InteractedWithEvent`),
`item_granter_device` (`GrantItem(Agent)`), `hud_message_device`
(`SetText`/`Show`), `conditional_button_device`. Search the digest for exact
member names.

### Rewarding currency from gameplay

Grant currency the same way you spend it — from an elimination/objective handler:

```verse
if (CPlayer := Manager.GetGamePlayer(Agent)?):
    CPlayer.Services.EconomyManager.AddCurrency("Coins", 25)
```

### Scaled display (K / M / B)

For idle/tycoon-scale numbers the wallet stores `Value : float` + `ScaleIndex` and
formats with a suffix table (a base-amount converter, an index calculator, and a
`Log10` helper). Keep the raw scaled value for math and only format for the HUD
`text_block`. Update the wallet UI after every change (`UpdateWalletUI()`).

### Gotchas

- Look the buyer up by `agent` in `GetAllGamePlayers()` — don't assume the
  handler's agent is a `game_player`; guard with `if`.
- Check `Disabled?` on the currency config before charging.
- Always give HUD feedback on both success and failure — silent purchases feel
  broken.
- Grant items with `item_granter_device` from the digest, not by inventing an API.
