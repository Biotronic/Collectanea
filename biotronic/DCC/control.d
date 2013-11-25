module biotronic.DCC.control;

import biotronic.DCC.util.getlasterrorhandler;
import biotronic.DCC.util.windowenums;
import biotronic.DCC.util.color;
import biotronic.DCC.windowmessage;
import biotronic.DCC.util.util;
import biotronic.DCC.window;
import biotronic.DCC.util.event;
import biotronic.DCC.buttons;
import biotronic.DCC.containercontrol;
import biotronic.DCC.canvas;

import win32.windows;
import std.string : toStringz;

class Menu {}

template _(T...) {
	alias _ = T;
}

struct CreationParameters {
    WsExStyles exStyle = WsExStyles.AppWindow | WsExStyles.WindowEdge;
    WsStyles style = WsStyles.OverlappedWindow;
    string text;
    string className;
    Rect rect = Rect(CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT);
    Control parent = null;
    Menu menu;
}

class Control {
public:
	this() {
		left = top = CW_USEDEFAULT;
		width = height = 300;
		_backColor = Color(COLOR_BTNFACE+1);
	}

	final { @property {
	bool focused() const {
		return false;
	}

	inout(ContainerControl) parent() inout {
		return _parent;
	}

	HWND handle() {
		if (!_handleCreated) {
			createHandle();
		}
		return _hWnd;
	}

	HINSTANCE instance() const {
        return GetModuleHandle(null);
    }

	string text() const {
		return _text;
	}

	string text(string value) {
		if (_text != value) {
			_text = value;
			if (_handleCreated) {
				SetWindowText(handle, toStringz(_text));
			}
		}
		return value;
	}

	int left() const {
		return _rect.left;
	}

	int left(int value) {
		if (value != _rect.left) {
			_rect.left = value;
			setBounds();
		}
		return value;
	}

	int top() const {
		return _rect.top;
	}

	int top(int value) {
		if (value != _rect.top) {
			_rect.top = value;
			setBounds();
		}
		return value;
	}

	int width() const {
		return _rect.width;
	}

	int width(int value) {
		if (value != _rect.width) {
			_rect.width = value;
			setBounds();
		}
		return value;
	}

	int height() const {
		return _rect.height;
	}

	int height(int value) {
		if (value != _rect.height) {
			_rect.height = value;
			setBounds();
		}
		return value;
	}

	Rect clientRect() const {
		Rect rect;
		GetClientRect(_hWnd, cast(RECT*)&rect);
		return rect;
	}

	Rect clientRect(Rect value) {
		AdjustWindowRectEx(cast(RECT*)&value, windowStyle, cast(int)false, windowExStyle);
		_rect = value;
		MoveWindow(handle, value.left, value.top, value.width, value.height, true);
		return value;
	}

	bool topLevel() {
		return WsStyles.ChildWindow in windowStyle;
	}

	WsStyles windowStyle() {
		return WsStyles(GetWindowLong(handle, GWL_STYLE));
	}

	WsStyles windowStyle(WsStyles value) {
		SetWindowLong(handle, GWL_STYLE, value);
		return value;
	}

	WsExStyles windowExStyle() {
		return WsExStyles(GetWindowLong(handle, GWL_EXSTYLE));
	}

	WsExStyles windowExStyle(WsExStyles value) {
		SetWindowLong(handle, GWL_EXSTYLE, value);
		return value;
	}
	}} // final @property

	Event!() click;
	Event!() doubleClick;
	
	Event!() dragDrop;
	Event!() dragEnter;
	Event!() dragLeave;
	Event!() dragOver;

	Event!() mouseClick;
	Event!() mouseDoubleClick;
	Event!() mouseDown;
	Event!() mouseEnter;
	Event!() mouseHover;
	Event!() mouseLeave;
	Event!() mouseMove;
	Event!() mouseUp;
	Event!() mouseWheel;

	Event!() keyDown;
	Event!() keyPress;
	Event!() keyUp;

	Event!() leave;
	Event!() gotFocus;
	Event!() lostFocus;

	Event!() paint;
	Event!() paintBackground;

	void onClick() {
		click();
	}
	void onDoubleClick() {
		doubleClick();
	}
	void onDragDrop() {
		dragDrop();
	}
	void onDragEnter() {
		dragEnter();
	}
	void onDragLeave() {
		dragLeave();
	}
	void onDragOver() {
		dragOver();
	}
	void onMouseClick() {
		mouseClick();
	}
	void onMouseDoubleClick() {
		mouseDoubleClick();
	}
	void onMouseDown() {
		mouseDown();
	}
	void onMouseEnter() {
		mouseEnter();
	}
	void onMouseHover() {
		mouseHover();
	}
	void onMouseLeave() {
		mouseLeave();
	}
	void onMouseMove() {
		mouseMove();
	}
	void onMouseUp() {
		mouseUp();
	}
	void onMouseWheel() {
		mouseWheel();
	}
	void onKeyDown() {
		keyDown();
	}
	void onKeyPress() {
		keyPress();
	}
	void onKeyUp() {
		keyUp();
	}
	void onLeave() {
		leave();
	}
	void onGotFocus() {
		gotFocus();
	}
	void onLostFocus() {
		lostFocus();
	}
	void onPaint(Canvas canvas) {
		paint();
	}
	void onPaintBackground(Canvas canvas) {
		canvas.fillRectangle(clientRect, Brush(_backColor));
		paintBackground();
	}

	final {
	void postMessage(WindowMessage msg) {
		glSafe!(.PostMessage)(handle, msg.msg, msg.wParam, msg.lParam);
	}

	void sendMessage(WindowMessage msg) {
		glSafe!(.SendMessage)(handle, msg.msg, msg.wParam, msg.lParam);
	}

	void sendToBack() {
		if (parent) {
			parent._controls.moveChild(this, -1);
		} else {
			if (!topLevel) {
				SetWindowPos(handle, HWND_BOTTOM, 0,0,0,0, SWP_NOMOVE | SWP_NOSIZE);
			}
		}
	}
	void bringToFront() {
		if (parent) {
			parent._controls.moveChild(this, 0);
		} else {
			if (!topLevel) {
				SetWindowPos(handle, HWND_TOP, 0,0,0,0, SWP_NOMOVE | SWP_NOSIZE);
			}
		}
	}
	} // final
protected:
    void wndProc(ref WindowMessage msg) {
        switch (msg.msg) {
			case  WM_MOUSEHOVER:
				wmMouseHover(msg);
				break;
			case  WM_MOUSELEAVE:
				wmMouseLeave(msg);
				break;
			case  WM_MOUSEMOVE:
				wmMouseMove(msg);
				break;

			case  WM_LBUTTONDOWN:
				wmMouseDown(msg, MouseButton.left, 1);
				break;
			case  WM_RBUTTONDOWN:
				wmMouseDown(msg, MouseButton.right, 1);
				break;
			case  WM_MBUTTONDOWN:
				wmMouseDown(msg, MouseButton.middle, 1);
				break;

			case  WM_LBUTTONUP:
				wmMouseUp(msg, MouseButton.left, 1);
				break;
			case  WM_RBUTTONUP:
				wmMouseUp(msg, MouseButton.right, 1);
				break;
			case  WM_MBUTTONUP:
				wmMouseUp(msg, MouseButton.middle, 1);
				break;

			case  WM_LBUTTONDBLCLK:
				wmMouseDown(msg, MouseButton.left, 2);
				break;
			case  WM_RBUTTONDBLCLK:
				wmMouseDown(msg, MouseButton.right, 2);
				break;
			case  WM_MBUTTONDBLCLK:
				wmMouseDown(msg, MouseButton.middle, 2);
				break;

			case WM_DESTROY:
			case WM_NCDESTROY:
				wmDestroy(msg);
				break;

			case WM_PAINT:
				wmPaint(msg);
				break;
            default:
                DefWndProc(msg);
        }
    }
    
    CreationParameters getCreationParameters() {
        CreationParameters result;
        result.className = this.classinfo.name;
		result.text = text;
		result.parent = parent;
        return result;
    }

	void wmDestroy(ref WindowMessage msg) {
	}

	void wmMouseHover(ref WindowMessage msg) {
		onMouseHover();
		DefWndProc(msg);
	}

	void wmMouseLeave(ref WindowMessage msg) {
		onMouseLeave();
		DefWndProc(msg);
	}

	void wmMouseMove(ref WindowMessage msg) {
		onMouseMove();
		DefWndProc(msg);
	}

	void wmMouseDown(ref WindowMessage msg, MouseButton button, int num) {
		onMouseDown();
		DefWndProc(msg);
	}

	void wmMouseUp(ref WindowMessage msg, MouseButton button, int num) {
		onMouseUp();
		DefWndProc(msg);
	}

	void wmPaint(ref WindowMessage msg) {
		PAINTSTRUCT ps;
		auto dc = BeginPaint(handle, &ps);
		scope(exit) {
			EndPaint(handle, &ps);
		}
		auto tmpCanvas = Canvas.fromDC(dc);
		onPaintBackground(tmpCanvas);
		onPaint(tmpCanvas);
	}
private:
	void setBounds() {
		if (_handleCreated) {
			SetWindowPos(handle, null, _rect.left, _rect.top, _rect.width, _rect.height, SWP_NOACTIVATE | SWP_NOZORDER);
		}
	}

	void DefWndProc(ref WindowMessage msg) {
        msg.result = DefWindowProc(handle, msg.msg, msg.wParam, msg.lParam);
	}

	void recreateHandle() {
		if (!_handleCreated) {
			return;
		}
		auto oldParent = GetParent(_hWnd);
		destroyHandle();
		createHandle();

		if (oldParent) {
			SetParent(_hWnd, oldParent);
		}
	}

	void destroyHandle() {
		if (_hWnd) {
			if (!DestroyWindow(_hWnd)) {
				PostMessage(_hWnd, WM_CLOSE, 0, 0);
			}
			_hWnd = null;
		}
	}

	void createHandle()
	in {
		assert(!_creatingHandle);
		assert(!_handleCreated);
	} out {
		assert(_handleCreated);
		assert(_hWnd);
	} body {
		_creatingHandle = true;
		scope(exit) {
			_creatingHandle = false;
		}
		scope(success) {
			_handleCreated = true;
		}

        auto params = getCreationParameters();
		WNDCLASSEX windowClass;

		windowClass.style = CS_HREDRAW | CS_VREDRAW | CS_OWNDC;
		windowClass.lpfnWndProc = &staticWndProc;
		windowClass.cbClsExtra = 0;
		windowClass.cbWndExtra = 0;
		windowClass.hInstance = instance;
		windowClass.hIcon = LoadIcon(null, IDI_WINLOGO);
		windowClass.hIconSm = LoadIcon(null, IDI_WINLOGO);
		windowClass.hCursor = LoadCursor(null, IDC_ARROW);
		windowClass.hbrBackground = Brush.fromColorRef(COLOR_BTNFACE).handle;
		windowClass.lpszMenuName = null;
		windowClass.lpszClassName = toStringz(params.className);
		
		glSafe!RegisterClassEx(&windowClass);
		
		auto hParent = params.parent ? params.parent.handle : null;
		auto text = params.text ? params.text : this.classinfo.name;

		_hWnd = glSafe!CreateWindowEx(params.exStyle, toStringz(params.className), toStringz(text), params.style,
									  left, top, width, height, hParent, null, instance, null);
		glSafe!SetProp(_hWnd, toStringz(WINDOW_CLASS_INSTANCE), cast(void*)this);
	}
	
	bool             _handleCreated = false;
	bool             _creatingHandle = false;
	ContainerControl _parent = null;
	HWND             _hWnd = null;
	Rect             _rect;
	string           _text;
	Color            _backColor;

	enum WINDOW_CLASS_INSTANCE = "WINDOW_CLASS_INSTANCE";
	
	static extern(Windows)
	HRESULT staticWndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam) {
		auto wnd = cast(Control)GetProp(hWnd, WINDOW_CLASS_INSTANCE);
		if (wnd) {
			auto message = WindowMessage(msg, wParam, lParam);
			wnd.wndProc(message);
			return message.result;
		} else {
            return DefWindowProc(hWnd, msg, wParam, lParam);
        }
	}
package:
	void changeParent(ContainerControl value) {
		_parent = value;
	}

	void setParentHandle(HANDLE value) {
		if (!_handleCreated) {
			return;
		}

		HANDLE oldParent = GetParent(handle);
		if (oldParent != value || (!oldParent && !topLevel)) {
			recreateHandle();
			if (topLevel) {
				return;
			}
			if (value) {
				SetParent(handle, value);
			}
		} else if (!value && !parent && topLevel) {
			SetParent(handle, null);
		}
	}
}