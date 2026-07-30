# SETUP: Single-file helper. Place under Content/Verse (or any module folder).
# Provides Subscribe* wrappers that pass ExtraData into listenable callbacks.
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/UI }
using { /Fortnite.com/Devices }

(Listenable : listenable(agent)).SubscribeAgent(OutputFunc : tuple(agent, t)->void, ExtraData : t where t:type) : cancelable =
    Wrapper := wrapper_agent(t){ExtraData := ExtraData, OutputFunc := OutputFunc}
    Listenable.Subscribe(Wrapper.InputFunc)

wrapper_agent(t : type) := class():
    ExtraData : t
    OutputFunc : tuple(agent, t) -> void
    InputFunc(Agent : agent):void = OutputFunc(Agent, ExtraData)

(Listenable : listenable(?agent)).SubscribeOptionAgent(OutputFunc : tuple(?agent, t)->void, ExtraData : t where t:type) : cancelable =
    Wrapper := wrapper_option_agent(t){ExtraData := ExtraData, OutputFunc := OutputFunc}
    Listenable.Subscribe(Wrapper.InputFunc)

wrapper_option_agent(t : type) := class():
    ExtraData : t
    OutputFunc : tuple(?agent, t) -> void
    InputFunc(OptionAgent : ?agent):void = OutputFunc(OptionAgent, ExtraData)

(Listenable : listenable(tuple())).SubscribeEmpty(OutputFunc : t -> void, ExtraData : t where t:type) : cancelable =
    Wrapper := wrapper_empty(t){ExtraData := ExtraData, OutputFunc := OutputFunc}
    Listenable.Subscribe(Wrapper.InputFunc)

wrapper_empty(t : type) := class():
    ExtraData : t
    OutputFunc : t -> void
    InputFunc():void = OutputFunc(ExtraData)

(Listenable : listenable(widget_message)).SubscribeWidgetMessage(OutputFunc : tuple(widget_message, t)->void, ExtraData : t where t:type) : cancelable =
    Wrapper := wrapper_widget_message(t){ExtraData := ExtraData, OutputFunc := OutputFunc}
    Listenable.Subscribe(Wrapper.InputFunc)

wrapper_widget_message(t : type) := class():
    ExtraData : t
    OutputFunc : tuple(widget_message, t) -> void
    InputFunc(Message : widget_message):void = OutputFunc(Message, ExtraData)

(Listenable : listenable(agent)).SubscribeButton(OutputFunc : tuple(agent, t) -> void, ExtraData : t where t:type) : cancelable =
    Wrapper := wrapper_button_agent(t){ExtraData := ExtraData, OutputFunc := OutputFunc}
    Listenable.Subscribe(Wrapper.InputFunc)

wrapper_button_agent(t : type) := class():
    ExtraData : t
    OutputFunc : tuple(agent, t) -> void
    InputFunc(Agent : agent): void =
        OutputFunc(Agent, ExtraData)
