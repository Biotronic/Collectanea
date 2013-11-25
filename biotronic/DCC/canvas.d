module biotronic.DCC.canvas;

import biotronic.DCC.util.color;
import biotronic.DCC.util.util;
import win32.windows;

struct Brush {
public:
	@property
	HBRUSH handle() const {
		return _hBrush;
	}

	this(Color color) {
		_hBrush = CreateSolidBrush(color.value);
	}

	static Brush fromColorRef(int value) {
		Brush result;
		result._hBrush = cast(HBRUSH)(value + 1);
		return result;
	}
private:

	HBRUSH _hBrush;
}

class Canvas {
public:
	@property {
	HDC handle() const {
		return _hDC;
	}
	}

	void fillRectangle(Rect area, Brush brush) {
		FillRect(_hDC, cast(RECT*)&area, brush.handle);
	}

	static Canvas fromDC(HDC dc) {
		return new Canvas(dc);
	}
private:
	this(HDC dc) {
		_hDC = dc;
	}
	HDC _hDC;
}
