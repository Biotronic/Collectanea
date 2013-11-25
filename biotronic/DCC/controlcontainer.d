module biotronic.DCC.controlcontainer;

import biotronic.DCC.control;
import biotronic.DCC.containercontrol;

import std.exception : enforce;

struct ControlContainer {
public:
	@disable this();
	this(ContainerControl owner) {
		_owner = owner;
	}

	void add(Control value) {
		if (!value) {
			return;
		}
		if (auto cc = cast(ContainerControl)value) {
			enforce(!cc.contains(_owner));
		}
		enforce(!value.topLevel);


		if (value.parent == _owner) {
			value.sendToBack();
		} else {
			if (value.parent) {
				value.parent._controls.remove(value);
			}
			_list ~= value;
			value.changeParent(_owner);
			//owner.onControlAdded(value);
		}
	}

	void remove(Control value) {
		import std.algorithm : remove;
		if (!value || value.parent != _owner) {
			return;
		}

		value.changeParent(null);
		_list.remove!(a => a==value);
		//owner.onControlRemoved(value);
	}

	void moveChild(Control child, int index) {
	}

	inout(Control)[] opSlice() inout {
		return _list;
	}
private:
	ContainerControl _owner;
	Control[] _list;
}