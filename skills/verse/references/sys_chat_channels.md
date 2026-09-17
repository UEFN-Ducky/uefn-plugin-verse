---
description: "Channel API (v42.20) — custom voice chat via /Verse.org/Chat: voice_channel, AddChatChannel on the simulation entity, mute/cut comms, IsMemberSpeaking + Begin/EndBroadcastEvent"
metadata:
  order: 14
  label: "Chat channels / voice (v42.20)"
  default_enabled: false
  load_condition: "Voice chat channels, squad comms, muting a team, cutting comms, detecting who is speaking, or custom Game Voice Chat / Game Text Chat"
---

## Chat channels — Channel API (v42.20)

Custom **voice** groups so players hear only who you put in the channel, and so
you can mute, cut comms, or react when someone talks. Everything below is
verified against the 42.20 `Verse.digest.verse` `/Verse.org/Chat` module.

**HARD:** use this API. Never invent `IsSpeaking`, `text_channel` (commented in
the digest, **no** `text_channel :=` class), a custom “radio” device, or a
HUD-only mute. Island Settings `VoiceChat` / `TextChatScope` is the *session
default* — per-group control is `voice_channel`.

```verse
using { /Verse.org/Chat }           # voice_channel, AddChatChannel, has_voice_member_info
using { /Verse.org/AgentGroup }     # agent_group
using { /Verse.org/Simulation }
using { /Fortnite.com/Devices }     # GetSimulationEntity on creative_device
```

`@available` floors: channel types **4000**; speaking events **4220**
(`IsMemberSpeaking`, `BeginBroadcastEvent`, `EndBroadcastEvent`,
`CanBroadcastChangeEvent`). Uploads older than 42.20 will not compile the
speaking APIs.

### Digest map

| Symbol | Kind | Notes |
|--------|------|-------|
| `chat_channel` | abstract `<internal>` | Do not construct. `Name : message`, `Group : agent_group_interface`, `Enable` / `Disable` / `IsEnabled` |
| `has_voice_member_info` | interface | `var CanBroadcast : logic` — false = hear-only (still in overlay) |
| `voice_channel(member_info)` | `class<final>(chat_channel)` | Concrete channel. Cap **80** members of `Group` |
| `IsMemberSpeaking(Agent)` | `<decides><reads>` | Fails if not a member or not talking. **Not** `IsSpeaking` |
| `BeginBroadcastEvent()` | `listenable(agent)` | Started talking |
| `EndBroadcastEvent()` | `listenable(agent)` | Stopped talking |
| `CanBroadcastChangeEvent()` | `listenable(tuple(agent, logic))` | Mute flag flipped while they hold a slot |
| `AddChatChannel` | on **simulation entity** | `Sim.AddChatChannel(Channel) : result(void, add_channel_error)` |
| `RemoveChatChannel` | same | deregister |
| `GetVoiceChannels()` | on sim entity | `[]voice_channel(has_voice_member_info)` |

AddChatChannel docs also name a **100**-cap text path, but this digest has no
`text_channel` type — do not invent one. Re-search if a later digest adds it.

Get the sim entity from a placed `creative_device`: `GetSimulationEntity[]`
(`<transacts><decides>`).

### Member info + group + channel

`has_voice_member_info` is an **interface** — you supply a concrete class, then
an `agent_group` of that type, then the matching `voice_channel`:

```verse
voice_member <public> := class(has_voice_member_info):
    var CanBroadcast<override> : logic = true

ChannelName<localizes>(S : string) : message = "{S}"

# OnBegin of a creative_device:
if (Sim := GetSimulationEntity[]):
    Group := agent_group(voice_member){}
    Chan := voice_channel(voice_member){ Name := ChannelName("Squad"), Group := Group }
    Sim.AddChatChannel(Chan)
    Chan.BeginBroadcastEvent().Subscribe(OnStartedTalking)
    Chan.EndBroadcastEvent().Subscribe(OnStoppedTalking)
```

Membership is the **group**, not a channel-side AddPlayer:

```verse
JoinSquad(Agent : agent, Group : agent_group(voice_member)) : void =
    Group.AddMember(Agent, voice_member{ CanBroadcast := true })

Mute(Agent : agent, Group : agent_group(voice_member)) : void =
    if (Info := Group.GetMemberMap()[Agent]):
        set Info.CanBroadcast = false

# Cut the whole channel (squad split, round end, dramatic silence):
CutComms(Chan : voice_channel(voice_member)) : void =
    Chan.Disable()

# Guard hears talking:
OnStartedTalking(Agent : agent) : void =
    Print("speaking")
```

`IsMemberSpeaking` is `<decides>`:

```verse
if (Chan.IsMemberSpeaking[Agent]):
    AlertGuard()
```

Parental controls / user settings can still block voice even when
`CanBroadcast` is true. Agents beyond the 80 cap are **not** in chat.

### Do not

| Invent | Use |
|--------|-----|
| `IsSpeaking` / `OnSpeak` | `IsMemberSpeaking` / `BeginBroadcastEvent` |
| `text_channel` class | digest has none — voice only until a type appears |
| Custom radio / HUD mute as the comms system | `voice_channel` Enable/Disable + `CanBroadcast` |
| `AddChatChannel` on the player/agent | `GetSimulationEntity[]` then `AddChatChannel` |
