module biotronic.DCC.application;

import biotronic.DCC.window,
    biotronic.DCC.util.event;

import win32.windows;
pragma(lib, "dmd_win32_x32");

final class TerminateEventArgs {
    public bool doTerminate = true;
}

class Application {
static:
public:
    Event!() idle;
    Event!() terminate;
    Event!(TerminateEventArgs) noWindows;

	void onIdle() {
		idle();
	}

	void onTerminate() {
		terminate();
	}

	void onNoWindows(TerminateEventArgs args) {
		noWindows(args);
	}

	void kill() {
        onTerminate();
		running = false;
	}

	int run(Window window = null) {
		running = true;
		MSG msg;

		if (window) {
			window.show();
		}
		
		while (running) {
			if (PeekMessage(&msg, null, 0, 0, PM_REMOVE)) {
				if (msg.message == WM_QUIT) {
					kill();
				} else {
					TranslateMessage(&msg);
					DispatchMessage(&msg);
				}
			} else {
				if (!existingWindows.length) {
                    auto args = new TerminateEventArgs;
                    onNoWindows(args);
                    if (args.doTerminate) {
                        kill();
                    }
				} else {
					onIdle();
				}
			}
		}

		return msg.wParam;
	}
	
	Window[] existingWindows;
private:
	bool running = false;
}