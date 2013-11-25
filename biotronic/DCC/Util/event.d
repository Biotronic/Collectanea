module biotronic.DCC.util.event;

struct Event(T...) {
	alias EventHandlerDg = void delegate(ref T);
	alias EventHandlerFn = void function(ref T);

	private EventHandlerDg[] dgHandlers;
	private EventHandlerFn[] fnHandlers;

	@disable this(this);
    
    void opCall(ref T args) const {
        foreach (handler; dgHandlers) {
            handler(args);
        }
        foreach (handler; fnHandlers) {
            handler(args);
        }
    }

	ref Event opOpAssign(string op : "+")(EventHandlerDg handler) {
		dgHandlers ~= handler;
		return this;
	}

	ref Event opOpAssign(string op : "+")(EventHandlerFn handler) {
		fnHandlers ~= handler;
		return this;
	}

	ref Event opOpAssign(string op : "-")(EventHandlerDg handler) {
		import std.algorithm : remove, SwapStrategy;
		dgHandlers = remove!(a=>a==handler, SwapStrategy.unstable)(dgHandlers);
		return this;
	}

	ref Event opOpAssign(string op : "-")(EventHandlerFn handler) {
		import std.algorithm : remove, SwapStrategy;
		fnHandlers = remove!(a=>a==handler, SwapStrategy.unstable)(fnHandlers);
		return this;
	}
}