module biotronic.DCC.containercontrol;


import biotronic.DCC.windowmessage;
import biotronic.DCC.control;
import biotronic.DCC.util.windowenums;
import biotronic.DCC.controlcontainer;

import win32.windows;
import std.exception : enforce;

class ContainerControl : Control {
public:
	this() {
		_controls = ControlContainer(this);
	}

	final { @property {
	inout(Control) activeControl() inout {
		return _activeControl;
	}

	Control activeControl(Control value) {
		if (!value) {
			return value;
		}
		if (value.focused && value == _activeControl) {
			return value;
		}
		enforce(contains(value));

		sendMessage(WindowMessage(WM_NEXTDLGCTL, value.handle, true));

		return value;
	}
	}} // final @property

	final
	bool contains(const(Control) value) const {
		foreach (ctrl; _controls) {
			if (ctrl == value) {
				return true;
			}
			if (auto cctrl = cast(ContainerControl)ctrl) {
				if (cctrl.contains(value)) {
					return true;
				}
			}
		}
		return false;
	}
protected:
    override
	CreationParameters getCreationParameters() {
        CreationParameters result = super.getCreationParameters();
		result.exStyle |= WsExStyles.ControlParent;
        return result;
    }
private:
	Control _activeControl;
package:
	ControlContainer _controls;
}