# LLM NPC conversation (UEFN 42.30, compile-verified).
#
# Put this behavior on an NPC Character Definition that has a Persona Modifier
# (NPC Character Behavior → Verse Behavior → llm_npc_behavior), drag the definition
# into the level (it places an NPC Spawner), and turn voice chat on to talk to it.
#
# What it shows:
#   * a voice channel with the NPC and the players in it, and each player's conversation target
#   * the personality set from Verse (SetPersonality — there is no AppendToPersonality)
#   * structured output: the model fills `llm_npc_deal` when you agree on a price
#     (RegisterAction — there is no RegisterPromptBinding / ResponseType)
#   * a one-shot structured question with Session.Prompt (no speech)
#   * captions from CommitSayEvent / StopSayEvent, failures from PromptFailureEvent
using { /Fortnite.com/AI }
using { /Fortnite.com/Playspaces }
using { /UnrealEngine.com/Conversations }
using { /UnrealEngine.com/Temporary/Diagnostics }
using { /Verse.org/AgentGroup }
using { /Verse.org/Chat }
using { /Verse.org/SceneGraph }
using { /Verse.org/Simulation }

llm_npc_log<public> := class(log_channel){}

# A voice channel needs a concrete member-info class.
llm_npc_member<public> := class(has_voice_member_info){}

llm_npc_mood<public> := enum:
    Happy
    Annoyed

# Structured output: the model fills these fields; @ai_description tells it how.
# Allowed field types: numbers, logic, message, enums, agents, structs/arrays of those.
llm_npc_deal<public> := struct:
    @ai_description("True when you and the player agreed on a price you are both happy with.")
    Accepted:logic = false
    @ai_description("The agreed price in gold.")
    Price:int = 0

llm_npc_read<public> := struct:
    @ai_description("How you feel about the player right now.")
    Mood:llm_npc_mood = llm_npc_mood.Happy
    @ai_description("How many times the player has spoken to you.")
    Count:int = 0

LlmNpcText<localizes>(Text:string):message = "{Text}"

llm_npc_behavior<public> := class(npc_behavior):
    Logger:log = log{Channel := llm_npc_log}
    var MaybeChannel:?voice_channel(llm_npc_member) = false
    var Cancels:[]cancelable = array{}

    OnBegin<override>()<suspends>:void =
        if:
            Entity := GetEntity[]
            NPCAgent := GetAgent[]
            Persona := Entity.GetComponent[persona_component]
            Sim := Entity.GetSimulationEntity[]
        then:
            # 1. A voice channel with the NPC and the players in it.
            Group := agent_group(llm_npc_member){}
            Channel := voice_channel(llm_npc_member){Name := LlmNpcText("Shop"), Group := Group}
            set MaybeChannel = option{Channel}
            Sim.AddChatChannel(Channel)
            Group.AddMember(NPCAgent, llm_npc_member{CanBroadcast := true})
            if (Playspace := Entity.GetPlayspaceForEntity[]):
                for (Player : Playspace.GetPlayers()):
                    Group.AddMember(Player, llm_npc_member{CanBroadcast := true})
                    Player.SetConversationTarget(Persona, Channel)
            # 2. Who the NPC is. <localizes> calls are no_rollback: build messages BEFORE a [ ] call (else E3512).
            Personality := LlmNpcText("You are a grumpy car buyer with a budget of 500 gold. Keep replies under 20 words.")
            if (Persona.SetPersonality[Personality]) {}
            if (Persona.SetVoice[guild_voice{}]) {}
            set Persona.PromptInterruptionRule = persona_interruption_rule.InterruptOnPromptStart
            # 3. Structured output the model may emit alongside any reply.
            Session := Persona.GetAISession()
            DealDef := prompt_binding_definition:
                Name := LlmNpcText("FinalOffer")
                Description := LlmNpcText("Signals when you and the player agreed on a price.")
            set Cancels += array{Session.RegisterAction(DealDef, false, llm_npc_deal, OnDeal)}
            # 4. Captions and failures.
            set Cancels += array{Persona.CommitSayEvent.Subscribe(OnSaid)}
            set Cancels += array{Persona.StopSayEvent.Subscribe(OnStopped)}
            set Cancels += array{Persona.PromptFailureEvent.Subscribe(OnFailed)}
            # 5. Make the NPC speak first.
            Greeting := LlmNpcText("Greet the player who just walked in.")
            if (Persona.PromptToTalk[Greeting, Channel]) {}
            # 6. A one-shot structured question (no speech).
            Reply := Session.Prompt(LlmNpcText("Rate the player so far."), llm_npc_read)
            if (Read := Reply.GetSuccess[]):
                Logger.Print("Player spoke {Read.Count} times")
            else if (Error := Reply.GetError[], ai_throttled_error[Error]):
                Logger.Print("Throttled; try later")

    OnDeal(Deal:llm_npc_deal):void =
        if (Deal.Accepted?):
            Logger.Print("Deal at {Deal.Price} gold")

    # Show `Said` as a caption here (it is the final, moderated line).
    OnSaid(Speaker:?agent, Said:message):void =
        Logger.Print("NPC finished a line")

    OnStopped(Interrupted:logic):void =
        if (Interrupted?) then Logger.Print("NPC was interrupted")

    OnFailed(Error:ai_error):void =
        if (ai_moderated_error[Error]) then Logger.Print("Moderated reply replaced")
        else Logger.Print("Prompt failed")

    OnEnd<override>():void =
        for (Cancel : Cancels):
            Cancel.Cancel()
        if (Entity := GetEntity[], Playspace := Entity.GetPlayspaceForEntity[]):
            for (Player : Playspace.GetPlayers()):
                Player.ClearConversationTarget()
