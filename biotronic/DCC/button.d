module biotronic.DCC.button;

import biotronic.DCC.control;

class Button : Control {
public:
	this() {
		width = 60;
		height = 30;
		left = 20;
		top = 20;
	}
protected:
    override
	CreationParameters getCreationParameters() {
		CreationParameters result = super.getCreationParameters();
		result.className = "BUTTON";
		return result;
	}
private:
package:
}