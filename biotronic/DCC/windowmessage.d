module biotronic.DCC.windowmessage;

import win32.windows;

struct WindowMessage {
    UINT msg;
    WPARAM wParam;
    LPARAM lParam;
	UINT result;

	this(T = WPARAM, U = LPARAM)(UINT msg, T wParam = T.init, U lParam = U.init) if (isAcceptableParameterType!T && isAcceptableParameterType!U) {
		this.msg = msg;
		this.wParam = cast(WPARAM)wParam;
		this.lParam = cast(LPARAM)lParam;
		this.result = 0;
	}

	private template isAcceptableParameterType(T) {
		enum isAcceptableParameterType = 
			is(T : const(int)) ||
			is(T : const(uint)) ||
			is(T : const(bool)) ||
			is(T : const(void*));
	}
}