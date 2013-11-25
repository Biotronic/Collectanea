module biotronic.DCC.util.color;

struct Color {
	union {
		uint value;
		struct {
			ubyte R, G, B, A;
		}
	}
}