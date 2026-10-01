---
description: "LLM NPCs / conversations (v42.30) — /UnrealEngine.com/Conversations persona_component: personality, voices, voice channel + conversation target, PromptToTalk, structured output with RegisterAction + @ai_description, one-shot Session.Prompt, captions, errors, rules; Epic's docs drift (no AppendToPersonality / RegisterPromptBinding / ResponseType)"
metadata:
  order: 15
  label: "Conversations / LLM NPCs (v42.30)"
  default_enabled: false
  load_condition: "NPCs that talk (LLM, AI-powered, persona, conversation, voiced character, quest giver that listens, haggling, negotiation, narrator, commentator), the Conversations template, Persona Modifier, structured output, @ai_description"
---

## Conversations — LLM-powered NPCs (v42.30)

An NPC with a **Persona Modifier** talks to players by voice: it remembers the
session, answers in character, and can drive gameplay through **structured
output**. The 42.30 **Conversations template** (Project Browser → Feature
Examples) is a used-car haggling game built on it. Publishable since 41.30 (Jul 30
2026); not experimental (no 2304 warnings).

Everything below is from the 42.30 `UnrealEngine.digest.verse` and compiled with
**0 errors, 0 warnings** in UEFN 42.30 (Tycoony, Oct 1 2026). The ready-made
version is the Verse template **`llm_npc`** (`verse_template_apply("llm_npc")` →
`Verse/LLMNPC/llm_npc_behavior.verse`).

### Docs drift (HARD)

Epic's template companion page ("LLM Game Mechanics with Verse") calls three
things the 42.30 digest does not have. Each is **E3506**:

| Do not write | Write |
| --- | --- |
| `PersonaComponent.AppendToPersonality("…")` | build the whole text, `if (Persona.SetPersonality[Msg]) {}` |
| `Session.RegisterPromptBinding(Def, F)` | `Session.RegisterAction(Def, Required, response_struct, F)` |
| `prompt_binding_definition{…, ResponseType := T}` | `prompt_binding_definition{Name := …, Description := …}` — the struct type is `RegisterAction`'s 3rd argument |
| `voice_channel(x){}` then `Channel.AddMember(…)` | `agent_group(x){}` holds members; `voice_channel(x){Name := …, Group := Group}` |

Ducky's Verse lint flags all of them.

### Editor setup

1. Content Browser → NPC Character Definition (Custom NPC Character Type).
2. Details → NPC Character Modifiers → **+** → **Persona Modifier (experimental label)**.
   Pick one of 36 Fortnite characters for a voice (17 IP characters, e.g. Jonesy,
   Peely, Fishstick, are locked to their persona) and fill **Character Facts**
   (Identity, Origin, Motivations, Dialogue, Gameplay — markdown) or the
   **Personality** / **Knowledge** fields.
3. Character Facts → **Edit in Prompt Editor**: test replies without a session
   (Conversation Mode, or Bulk Response Mode for many replies to one prompt).
4. NPC Character Behavior → **Verse Behavior** → your `npc_behavior` class
   (`Verse Explorer → Add new Verse file → NPC Behavior Basic`).
5. Drag the definition into the level (places an **NPC Spawner**). Players need
   **voice chat on**; they talk with the indicated key.

One persona per character definition. English only. Not on brand islands.

### API (`using { /UnrealEngine.com/Conversations }`)

`persona_component` (Scene Graph component on the NPC entity):

| Member | Use |
| --- | --- |
| `Personality:message` (read) / `SetPersonality(Msg)<transacts><decides>` | who it is — replaces the whole text |
| `Voice:voice_model` / `SetVoice(voice_model)<decides>` | e.g. `guild_voice{}`; `<epic_internal>` voices (jonesy, peely…) cannot be constructed |
| `var PromptInterruptionRule:persona_interruption_rule` | `IgnoreUntilFinished`, `InterruptOnPromptStart`, `InterruptOnResponseStart` |
| `GetAISession()<transacts>:ai_session` | history, prompts, structured output |
| `PromptToTalk[Instructions, Channel]` / `PromptToTalk[Instructions, Rule, Channel]` | make it speak (fails if busy or not in the channel) |
| `StartHearEvent` / `StopHearEvent : listenable(agent)` | player started / stopped talking to it |
| `StartSayEvent : listenable(tuple(?agent, cancelable))` | speech starting (cancel to stop it) |
| `CommitSayEvent : listenable(tuple(?agent, message))` | the final, moderated line — **captions** |
| `StopSayEvent : listenable(logic)` | done talking (`true` = interrupted) |
| `PromptFailureEvent : listenable(ai_error)` | a prompt failed |

`ai_session` (`<unique>`): `ClearHistory()`,
`Prompt(Msg, response_type)<suspends>:result(response_type, ai_error)` (one-shot,
no speech), `RegisterAction(Definition, Required:logic, output_type, Callback)<transacts>:cancelable`
(the model may emit `output_type` alongside any reply; `Required := true` makes it
emit every reply). History is shared by every persona in the same voice channel.

`prompt_binding_definition := struct{Name:message, Description:message}` — what the
model sees when deciding to emit the output.

Player side: `Player.SetConversationTarget(Persona, Channel)` (the persona must be
in that channel), `Player.GetConversationTarget[]`, `Player.ClearConversationTarget()`.

Errors (`ai_error` is `<castable>`, `.Message:message`): `ai_timeout_error`,
`ai_throttled_error`, `ai_moderated_error`, `ai_character_limit_error` — test with
`if (ai_throttled_error[Error])`.

Read a `result`: `if (Value := Reply.GetSuccess[])` / `if (Error := Reply.GetError[])`.

### Structured output

A struct whose fields the model fills; `@ai_description("…")` on each field says how.
Field types: numbers, `logic`, `message`, enums, agents, and structs/arrays of those.

```verse
llm_npc_deal<public> := struct:
    @ai_description("True when you and the player agreed on a price you are both happy with.")
    Accepted:logic = false
    @ai_description("The agreed price in gold.")
    Price:int = 0
```

### The working behavior (compile-verified; the `llm_npc` template adds Prompt, captions and failures)

```verse
using { /Fortnite.com/AI }
using { /Fortnite.com/Playspaces }
using { /UnrealEngine.com/Conversations }
using { /UnrealEngine.com/Temporary/Diagnostics }
using { /Verse.org/AgentGroup }
using { /Verse.org/Chat }
using { /Verse.org/SceneGraph }
using { /Verse.org/Simulation }

shop_member<public> := class(has_voice_member_info){}

shop_deal<public> := struct:
    @ai_description("True when you and the player agreed on a price you are both happy with.")
    Accepted:logic = false
    @ai_description("The agreed price in gold.")
    Price:int = 0

ShopText<localizes>(Text:string):message = "{Text}"

shop_npc<public> := class(npc_behavior):
    var Cancels:[]cancelable = array{}

    OnBegin<override>()<suspends>:void =
        if:
            Entity := GetEntity[]
            NPCAgent := GetAgent[]
            Persona := Entity.GetComponent[persona_component]
            Sim := Entity.GetSimulationEntity[]
        then:
            Group := agent_group(shop_member){}
            Channel := voice_channel(shop_member){Name := ShopText("Shop"), Group := Group}
            Sim.AddChatChannel(Channel)
            Group.AddMember(NPCAgent, shop_member{CanBroadcast := true})
            if (Playspace := Entity.GetPlayspaceForEntity[]):
                for (Player : Playspace.GetPlayers()):
                    Group.AddMember(Player, shop_member{CanBroadcast := true})
                    Player.SetConversationTarget(Persona, Channel)
            # <localizes> is no_rollback: build the message BEFORE the [ ] call (else E3512).
            Personality := ShopText("You are a grumpy car buyer with 500 gold.")
            if (Persona.SetPersonality[Personality]) {}
            Session := Persona.GetAISession()
            DealDef := prompt_binding_definition:
                Name := ShopText("FinalOffer")
                Description := ShopText("Signals when you and the player agreed on a price.")
            set Cancels += array{Session.RegisterAction(DealDef, false, shop_deal, OnDeal)}
            set Cancels += array{Persona.CommitSayEvent.Subscribe(OnSaid)}
            Greeting := ShopText("Greet the player who just walked in.")
            if (Persona.PromptToTalk[Greeting, Channel]) {}

    # Award Deal.Price, despawn, open a gate…
    OnDeal(Deal:shop_deal):void =
        if (Deal.Accepted?):
            Print("Deal at {Deal.Price} gold")

    # Said is the final, moderated line: show it as a caption.
    OnSaid(Speaker:?agent, Said:message):void =
        Print("NPC finished a line")

    OnEnd<override>():void =
        for (Cancel : Cancels):
            Cancel.Cancel()
```

Gameplay patterns from the template: pick a random buyer type and budget at spawn
(`GetRandomInt`) and set the personality from it; a second output (`Kicked:logic`
"Return true if you have been told to leave") ends the deal; apply the results in
`StopSayEvent` so the score changes after the NPC finishes the line; captions =
two Verse fields on a UMG widget (`CloseCaption:message`, `CCVisible:logic`,
`umg_verse_fields`) set from `CommitSayEvent` / cleared on `StopSayEvent`.

### Rules (Fortnite Developer Rules 1.22)

No persona that gives medical or mental-health guidance, no romantic or intimate
companion, no attempt to get around the safety systems — breaking them can ban
the account. Players can report replies (Report → Conversational AI). Rate limits
may apply; handle `ai_throttled_error`.

Related: `sys_npc_ai` (NPC behaviors), `sys_chat_channels` (voice channels),
`umg_verse_fields` (captions), scenegraph `components`.
