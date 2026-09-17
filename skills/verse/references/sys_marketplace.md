---
description: "In-island entitlements / V-Bucks offers (v42.20) — using { /UnrealEngine.com/Marketplace }; not island Coins"
metadata:
  order: 15
  label: "Marketplace / entitlements (v42.20)"
  default_enabled: false
  load_condition: "Selling entitlements, BuyOffer / GrantEntitlement, V-Bucks prices, paid offers, or migrating off /Fortnite.com/Marketplace"
---

## Marketplace — entitlements, not island Coins (v42.20)

**HARD:** new code uses `using { /UnrealEngine.com/Marketplace }`.
`/Fortnite.com/Marketplace` still aliases the same types but every digest
symbol there is `@deprecated` — do not import it.

This is **Epic entitlements / V-Bucks offers**. Island Coins, wallets, and
shops stay `economy` / `GetCurrencyProvider`. Never mix the two.

```verse
using { /UnrealEngine.com/Marketplace }
```

### Digest map (UnrealEngine.digest.verse)

| Symbol | Role |
|--------|------|
| `MakePriceVBucks(Amount:float)<converges>:price_vbucks` | V-Bucks price |
| `GetPriceVBucks(P:price_vbucks):float` | reverse |
| `offer` / `entitlement_offer` / `bundle_offer` | purchasable offers |
| `entitlement` | owned grant type |
| `offer_interactable_component` | world interact → buy |
| `BuyOffer(Player, Offer)<suspends>:logic` | Epic purchase UI; true if bought |
| `GrantEntitlement(Player, entitlement_type, ?Count)<suspends>:logic` | grant without the buy UI |
| `GetPurchasedEntitlements(Player, entitlement_type)<suspends>` | `[]tuple(type, int)` — do not call with bare `entitlement` (suspends forever) |
| `ConsumeEntitlement(...)` | consumables only |
| `GetEntitlementsChangedEvent(Player, entitlement_type)` | session quantity changes |
| `ShowOffersDialog(Player, Offers, ?Title)` | Epic storefront |
| `RestrictPaidRandomItems[Player]` / `RestrictDirectPromptsToPurchase[Player]` | `<decides>` platform/age gates |

Copy remaining member names from `get_verse_api` — do not invent Fortnite-path wrappers.

### Not this module

| Need | Use |
|------|-----|
| Island Coins / wallets / shops | `economy`, `GetCurrencyProvider` |
| XP / levels | `progression`, `GetXPAwarder` |
| Voice / mute | `sys_chat_channels` (`/Verse.org/Chat`) |
