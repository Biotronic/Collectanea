module biotronic.DCC.foo;

import std.stdio : writeln;

import biotronic.DCC.window,
	biotronic.DCC.button,
	biotronic.DCC.application;

//import derelict.opengl3.gl3;

//pragma(lib, "derelictgl3_32");
//pragma(lib, "derelictutil_32");

class MyWindow : Window {
	this() {
		_controls.add(new Button);
	}
}

int main() {
	return Application.run(new MyWindow());
}