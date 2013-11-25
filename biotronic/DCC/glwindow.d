module biotronic.DCC.glwindow;

import biotronic.DCC.window;
import biotronic.DCC.getlasterrorhandler;

import derelict.opengl3.gl3;
import derelict.opengl3.wglext;
import derelict.opengl3.wgl;
import win32.windows : HGLRC, PIXELFORMATDESCRIPTOR, SetPixelFormat, PFD_DOUBLEBUFFER, PFD_SUPPORT_OPENGL, PFD_DRAW_TO_WINDOW, PFD_TYPE_RGBA, ChoosePixelFormat, CreateCompatibleDC;

pragma(lib, "derelictgl3");
pragma(lib, "derelictutil");

static this() {
	DerelictGL3.load();
}

class GlWindow : Window {
public:
	this(ubyte colorBits = 32, ubyte depthBits = 32)
	out {
		assert(hRC);
	} body {
		if (DerelictGL3.loadedVersion < GLVersion.GL33) {
			auto tmpRC = glSafe!wglCreateContext(DC);
			glSafe!wglMakeCurrent(DC, tmpRC);
			auto glVersion = DerelictGL3.reload();
			wglMakeCurrent(DC, null);
			wglDeleteContext(tmpRC);

			if (glVersion < GLVersion.GL33) {
				throw new Exception("Argargarg!");
			}
		}


		PIXELFORMATDESCRIPTOR pfd;
		pfd.nSize = PIXELFORMATDESCRIPTOR.sizeof;
		pfd.dwFlags = PFD_DOUBLEBUFFER | PFD_SUPPORT_OPENGL | PFD_DRAW_TO_WINDOW;
		pfd.iPixelType = PFD_TYPE_RGBA;
		pfd.cColorBits = colorBits;
		pfd.cDepthBits = depthBits;
		
		glSafe!SetPixelFormat(DC, glSafe!ChoosePixelFormat(DC, &pfd), &pfd);
        
		
		if (&wglCreateContextAttribsARB) {
            immutable pt = [
				WGL_CONTEXT_MAJOR_VERSION_ARB, 3,
				WGL_CONTEXT_MINOR_VERSION_ARB, 2,
				WGL_CONTEXT_FLAGS_ARB, WGL_CONTEXT_FORWARD_COMPATIBLE_BIT_ARB,
				0
				];
			hRC = wglCreateContextAttribsARB(DC, null, pt.ptr);
		} else {
			hRC = glSafe!wglCreateContext(DC);
		}
		glSafe!wglMakeCurrent(DC, hRC);
	}

	~this() {
		wglMakeCurrent(DC, null);
		wglDeleteContext(hRC);
	}
private:
	HGLRC hRC;
}