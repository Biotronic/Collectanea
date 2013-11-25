module biotronic.DCC.util.util;

import std.algorithm;
import win32.windows : RECT;

struct Point {
public:
	this(int x, int y) {
		_x = x;
		_y = y;
	}
@property {
	int x() const {
		return _x;
	}
	int x(int value) {
		return _x = value;
	}
	
	int y() const {
		return _y;
	}
	int y(int value) {
		return _y = value;
	}
	}
private:
	int _x, _y;
}

struct Rect {
	this(Point topLeft, Point topRight) {
		_top = topLeft.y;
		_left = topLeft.x;
		_right = bottomRight.x;
		_bottom = bottomRight.y;
	}
	this(int left, int right, int top, int bottom) {
		_top = top;
		_left = left;
		_right = right;
		_bottom = bottom;
	}

	alias asRECT this;
@property {
	RECT asRECT() const {
		return RECT(_left, _right, _top, _bottom);
	}

	int left() const {
		return _left;
	}
	int left(int value) {
		return _left = value;
	}
	
	int right() const {
		return _right;
	}
	int right(int value) {
		return _right = value;
	}
	
	int top() const {
		return _top;
	}
	int top(int value) {
		return _top = value;
	}
	
	int bottom() const {
		return _bottom;
	}
	int bottom(int value) {
		return _bottom = value;
	}
	
	int width() const {
		return right - left;
	}
	int width(int value) {
		right = left + value;
		return value;
	}
	
	uint height() const {
		return bottom - top;
	}
	uint height(int value) {
		bottom = top + value;
		return value;
	}
	
	Point topLeft() const {
		return Point(top, left);
	}
	Point topLeft(Point value) {
		left = value.x;
		top = value.y;
		return value;
	}
	
	Point bottomRight() const {
		return Point(bottom, right);
	}
	Point bottomRight(Point value) {
		right = value.x;
		bottom = value.y;
		return value;
	}
	}
	
	bool contains(Point p) const {
		return p.x >= _left && p.x < _right &&
			p.y >= _top && p.y < _bottom;
	}
	
	bool intersects(Rect r) const {
		return _left < r._right && _right > r._left &&
			_top < r._bottom && _bottom > r._top;
	}
	
	Rect intersection(Rect r) const {
		return Rect(
			min(_left, r._left),
			max(_right, r._right),
			min(_top, r._top),
			max(_bottom, r._bottom),
		);
	}
private:
	int _left, _right, _top, _bottom;
	
	invariant() {
		//assert(_right >= _left);
		//assert(_bottom >= _top);
	}
}