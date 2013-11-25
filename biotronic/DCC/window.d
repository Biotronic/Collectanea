module biotronic.DCC.window;

import biotronic.DCC.application;
import biotronic.DCC.util.getlasterrorhandler;
import biotronic.DCC.util.util;
import biotronic.DCC.util.event;
import biotronic.DCC.canvas;
import biotronic.DCC.control;
import biotronic.DCC.containercontrol;
import biotronic.DCC.windowmessage;
import biotronic.DCC.util.windowenums;

import win32.windows;
pragma(lib, "dmd_win32_x32");
pragma(lib, "gdi32");

import std.algorithm : remove;
import std.exception : enforce, assumeUnique;
import std.string : toStringz;

class Window : ContainerControl {
public:
	this() {
		Application.existingWindows ~= this;
	}
	
	~this() {
	}

	final void show() {
		ShowWindow(handle, SW_SHOW);
		UpdateWindow(handle);
	}

	final void hide() {
		ShowWindow(handle, SW_HIDE);
		UpdateWindow(handle);
	}
protected:
	override CreationParameters getCreationParameters() {
		auto result = super.getCreationParameters();
		result.exStyle |= WsExStyles.AppWindow | WsExStyles.WindowEdge;
		return result;
	}

	override void wmDestroy(ref WindowMessage msg) {
		Application.existingWindows = Application.existingWindows.remove!(a => a is this);
	}
    
    override void onPaint(Canvas canvas) {
		string greeting = "Hello world!";

        TextOut(canvas.handle, 5, 5, greeting.ptr, greeting.length);
    }
	
	override void wndProc(ref WindowMessage msg) {
		switch (msg.msg) {
			case WM_PAINT:
				wmPaint(msg);
				break;
			default:
				super.wndProc(msg);
		}
	}
private:
	
	enum WINDOW_CLASS_INSTANCE = "WINDOW_CLASS_INSTANCE";
}