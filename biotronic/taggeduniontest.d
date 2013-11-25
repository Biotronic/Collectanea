module biotronic.taggeduniontest;

import std.stdio;
import biotronic.taggedunion;
import biotronic.notnull;

import std.typecons;
import std.typetuple;

unittest {
    TaggedUnion!(int, float, string) a = "foo";
    auto b = a;
    a = b;
    assert(a == "foo");
}

template SafePtr(T) if (is(T == class) || is(T == U*, U)) {
    alias SafePtr = TaggedUnion!(NotNull!T, typeof(null));
}

class C {}

unittest {
    TaggedUnion!(int, float, string) a = "foo";
    a = 3.14;
    assert(a.match!(
        (string s) => 0,
        (int n)    => 1,
        (float f)  => 2,
    ) == 2);
    
    assert(!__traits(compiles, {auto rrr = a.values;}));
    
    a.match!(
        (int i, string s) => 1,
        (Else) => 0,
    );
    
    assert(a.match!(
            (string s) => 1,
            (Else e)   => 2,
        ) == 2);
		
	assert(a == a);
        
    Maybe!int c = null;
	
    
    assert(c.match!(
        (int n)=> to!string(n),
        (typeof(null) n)=> to!string(n),
    ) == c.to!string);
	
    assert(c == null);
    
    assert(c.isType!(typeof(null)));
    assert(!__traits(compiles, c.isType!float));
    
    SafePtr!(int*) p = null;
    SafePtr!C nn = null;
    assert(nn == nn);
    
    nn.match!(
        (C c) => writeln("C"),
        (Else e) => writeln("null")
    );
}

unittest {
    TaggedUnion!(int, string) a = 3;
    TaggedUnion!(int, float, string, byte[13]) b = a;
    assert(a == b);
	assert(b == 3);
}

void main() {
}
