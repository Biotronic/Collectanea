module biotronic.flags;

import biotronic.staticparallelstuff;

pure:
nothrow:
@safe:

template hasOnlyOneMember(string s) {
    struct T {
        mixin("enum Test {" ~ s ~ "}");
    }
    enum hasOnlyOneMember = __traits(allMembers, T).length == 1;
} unittest {
    assert( hasOnlyOneMember!"a");
    assert( hasOnlyOneMember!"a,b");
    assert(!hasOnlyOneMember!"a,b} enum rrr {a");
}

template isValidFlagEnumBody(string s) {
    static if (__traits( compiles, {mixin( "enum foo {" ~ s ~ "}" );})) {
        enum isValidFlagEnumBody = hasOnlyOneMember!s;
    } else {
        enum isValidFlagEnumBody = false;
    }
} unittest {
	assert( isValidFlagEnumBody!q{a});
	assert( isValidFlagEnumBody!q{a,b});
	assert(!isValidFlagEnumBody!q{a.});
    assert(!isValidFlagEnumBody!"a} enum bar {b");
    assert(!isValidFlagEnumBody!"a} struct bar {");
    assert(!isValidFlagEnumBody!"a} template bar( ) {");
    assert(!isValidFlagEnumBody!"a} void bar() {");
}

template MakeEnum(string s) {
	mixin("enum MakeEnum {" ~ s ~ "}");
}

template parsedString(string s) {
    import std.typetuple : TypeTuple;
	alias TypeTuple!(__traits(allMembers, MakeEnum!s)) parsedString;
} unittest {
    assert(parsedString!"a,b".length == 2);
    assert(parsedString!"a,b"[0] == "a");
    assert(parsedString!"a,b"[1] == "b");
}

template getMemberValue(T) {
    enum getMemberValue(string s) = __traits(getMember, T, s);
}

template parsedValues(string s) {
    import std.typetuple : TypeTuple, staticMap;
	alias staticMap!(getMemberValue!(MakeEnum!s), TypeTuple!(__traits(allMembers, MakeEnum!s))) parsedValues;
} unittest {
	assert( parsedString!"a"[0] == "a");
	assert( parsedString!"a".length == 1);
	assert( parsedString!"a,b"[0] == "a");
	assert( parsedString!"a,b"[1] == "b");
	assert( parsedString!"a,b".length == 2);
}

template uintByBitLength(size_t length) {
	static if ( length <= 8 ) {
		alias ubyte uintByBitLength;
	} else static if ( length <= 16 ) {
		alias ushort uintByBitLength;
	} else static if ( length <= 32 ) {
		alias uint uintByBitLength;
	} else static if ( length <= 64 ) {
		alias ulong uintByBitLength;
	} else {
        static assert(false, "No uint with bit size >= " ~ length.stringof ~ ".");
    }
} unittest {
    import std.conv : to;
    assert(!__traits(compiles, uintByBitLength!65));
    assert(!__traits(compiles, uintByBitLength!96));
    assert(!__traits(compiles, uintByBitLength!(-1)));
    foreach (i; staticIota!(0,8)) {
        assert(is(uintByBitLength!i == ubyte), "uintByBitLength!"~i.stringof~" results in "~uintByBitLength!i.stringof~", not ubyte.");
    }
    foreach (i; staticIota!(9,16)) {
        assert(is(uintByBitLength!i == ushort), "uintByBitLength!"~i.stringof~" results in "~uintByBitLength!i.stringof~", not ushort.");
    }
    foreach (i; staticIota!(17,32)) {
        assert(is(uintByBitLength!i == uint), "uintByBitLength!"~i.stringof~" results in "~uintByBitLength!i.stringof~", not uint.");
    }
    foreach (i; staticIota!(33,64)) {
        assert(is(uintByBitLength!i == ulong), "uintByBitLength!"~i.stringof~" results in "~uintByBitLength!i.stringof~", not ulong.");
    }
}

struct Flags(string s, bool generateAll = true) if ( isValidFlagEnumBody!s && parsedString!s.length <= 64 ) {
	private alias parsedString!s memberNames;
    mixin("private enum memberEnum {" ~ s ~ "}");
	static if ( memberNames.length <= 8 ) {
		private alias ubyte Representation;
	} else static if ( memberNames.length <= 16 ) {
		private alias ushort Representation;
	} else static if ( memberNames.length <= 32 ) {
		private alias uint Representation;
	} else static if ( memberNames.length <= 64 ) {
		private alias ulong Representation;
	}
	private Representation value;
    
    static if (generateAll) {
        enum valueString(int ___n, string name) = (1UL << ___n);
    } else {
        enum valueString(int ___n, string name) = __traits(getMember, memberEnum, name);
    }
    
	mixin template flagsMembers( int ___n ) {
	}
    mixin template flagsMembers(int ___n, string name, more...) {
        mixin( "@property static pure nothrow @safe
                Flags " ~ name ~ "() {
                    enum value = Flags(" ~valueString!(___n, name).stringof~ ");
                    return value;
                }" );
        mixin flagsMembers!(___n + 1, more);
    }
	mixin flagsMembers!(0, memberNames);
    
	private this(Representation value) {
		this.value = value;
	}
	
	Flags opBinary(string op)(Flags other) const if (op == "|" || op == "^" || op == "&") {
		Flags result = this;
        result.opOpAssign!op(other);
        return result;
	}
	
	ref Flags opOpAssign(string op)(Flags other) if (op == "|" || op == "^" || op == "&") {
		mixin( "value " ~ op ~ "= other.value;" );
		return this;
	}
	
	T opCast(T)( ) const if (is(Representation : T)) {
		return value;
	}
	
	bool opCast(T : bool)( ) const {
		return value != 0;
	}
	
	string toString( ) const {
        import std.array : join;
		string[] result;
		
		foreach (i, e; memberNames) {
			if (value & (1L << i)) {
				result ~= e;
			}
		}
		return "<" ~ result.join(", ") ~ ">";
	}
} unittest {
	// Test sizes of created types.
	alias Flags!"a" myFlags1;
	alias Flags!"a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p" myFlags2;
	alias Flags!"a1,b1,c1,d1,e1,f1,g1,h1,i1,j1,k1,l1,m1,n1,o1,p1,s1,a2,b2,c2,d2,e2,f2,g2,h2,i2,j2,k2,l2,m2,n2,o2" myFlags3;
	alias Flags!"a1,b1,c1,d1,e1,f1,g1,h1,i1,j1,k1,l1,m1,n1,o1,p1,s1,a2,b2,c2,d2,e2,f2,g2,h2,i2,j2,k2,l2,m2,n2,o2,p2,s2,a3,b3,c3,d3,e3,f3,g3,h3,i3,j3,k3,l3,m3,n3,o3,p3,s3,a4,b4,c4,d4,e4,f4,g4,h4,i4,j4,k4,l4,m4" myFlags4;
	assert(myFlags1.sizeof == 1);
	assert(myFlags2.sizeof == 2);
	assert(myFlags3.sizeof == 4);
	assert(myFlags4.sizeof == 8);
	
	// Test that valid types do compile, and invalid types not.
	assert( __traits( compiles, Flags!"a"));
	assert( __traits( compiles, Flags!"a, b"));
	assert(!__traits( compiles, Flags!""));
	assert(!__traits( compiles, Flags!"a."));
	assert(!__traits( compiles, Flags!"a1,b1,c1,d1,e1,f1,g1,h1,i1,j1,k1,l1,m1,n1,o1,p1,s1,a2,b2,c2,d2,e2,f2,g2,h2,i2,j2,k2,l2,m2,n2,o2,p2,s2,a3,b3,c3,d3,e3,f3,g3,h3,i3,j3,k3,l3,m3,n3,o3,p3,s3,a4,b4,c4,d4,e4,f4,g4,h4,i4,j4,k4,l4,m4,n4"));
	
	alias Flags!q{ a, b } TestFlags;
    
	// Test that operators work.
	auto o = TestFlags.a | TestFlags.b;
	assert(o != TestFlags.a);
	assert(o != TestFlags.b);
	assert(o.value != 0);
	
	auto p = o ^ TestFlags.a;
	assert(p == TestFlags.b);
	assert(p != TestFlags.a);
	
	auto q = o & TestFlags.a;
	assert(q == TestFlags.a);
	assert(o != TestFlags.b);
	
	o &= TestFlags.a;
	assert(o == TestFlags.a);
	
	p |= TestFlags.a;
	assert(p == (TestFlags.a | TestFlags.b));
	
	q ^= TestFlags.a;
	assert( q.value == 0 );
	
	
	// Test toString.
	assert(TestFlags.a.toString() == "<a>");
	assert(TestFlags.b.toString() == "<b>");
	assert(( TestFlags.a | TestFlags.b ).toString() == "<a, b>");
	assert(TestFlags().toString() == "<>");
	
	// Test casting.
	assert(!TestFlags( ));
	assert( TestFlags.a);
	assert( TestFlags.b);
	assert( TestFlags.a | TestFlags.b);
	assert( cast(bool)TestFlags() == false);
	assert( cast(bool)TestFlags.a == true);
	assert( cast(int)TestFlags() == 0);
	assert( cast(int)TestFlags.a != 0);
	
	// Test invalid comparisons.
	assert(!__traits( compiles, {TestFlags.a == 1;}));
	assert(!__traits( compiles, {TestFlags.a == true;}));
	
	// Test invalid conversions.
	assert(!__traits( compiles, {int i = TestFlags.a;}));
	assert(!__traits( compiles, {bool b = TestFlags.a;}));
	
	// Test operators with invalid types.
	assert(!__traits( compiles, {auto tmp = TestFlags.b | myFlags1.a;}));
	assert(!__traits( compiles, {auto tmp = TestFlags.b | 1;}));
    
    
    alias Flags!("
        Overlapped       = 0x00000000,
        Tiled            = Overlapped,
        MaximizeBox      = 0x00010000,
        MinimizeBox      = 0x00020000,
        TabStop          = 0x00010000,
        Group            = 0x00020000,
        ThickFrame       = 0x00040000,
        SizeBox          = ThickFrame,
        SysMenu          = 0x00080000,
        HScroll          = 0x00100000,
        VScroll          = 0x00200000,
        DlgFrame         = 0x00400000,
        Border           = 0x00800000,
        Caption          = 0x00c00000,
        OverlappedWindow = Overlapped | Caption | SysMenu | ThickFrame | MinimizeBox | MaximizeBox,
        TiledWindow      = OverlappedWindow,
        Maximize         = 0x01000000,
        ClipChildren     = 0x02000000,
        ClipSiblings     = 0x04000000,
        Disabled         = 0x08000000,
        Visible          = 0x10000000,
        Minimize         = 0x20000000,
        Iconic           = Minimize,
        Child            = 0x40000000,
        ChildWindow      = 0x40000000,
        Popup            = 0x80000000,
        PopupWindow      = Popup | Border | SysMenu,
    ", false) WsExStyle;
    
    auto i = cast(int)WsExStyle.Popup;
    assert(i == 0x80000000);
    
}