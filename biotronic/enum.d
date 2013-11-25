import std.traits : OriginalType;

string EnumDefAsString(T)() if (is(T == enum)) {
	string result = "";
	foreach (e; __traits(allMembers, T))
		result ~= e ~ " = T." ~ e ~ ",";
	return result;
}

template ExtendEnum(T, string s)
	if (is(T == enum) &&
	is(typeof({mixin("enum a: OriginalType!T {"~s~"}");})))
{
    mixin(
    "enum ExtendEnum : OriginalType!T {"
    ~ EnumDefAsString!T() ~ s
    ~ "}");
}

enum bar : string {
	a = "a",
	b = "r",
	c = "t",
}

enum baz {
    a = 1,
    b = 2,
    c = 3,
}

unittest {
    alias ExtendEnum!(bar, q{ // Usage example here.
        d = "Text"
    }) bar2;
    
    foreach (i, e; __traits(allMembers, bar2)) {
        static assert( e == ["a", "b", "c", "d"][i] );
    }
    assert( bar2.a == bar.a );
    assert( bar2.b == bar.b );
    assert( bar2.c == bar.c );
    assert( bar2.d == "Text" );
    static assert(!is(typeof( ExtendEnum!(int, "a"))));
    static assert(!is(typeof( ExtendEnum!(bar, "25"))));
}

unittest {
    alias ExtendEnum!(baz, q{ // Usage example here.
        d = 25
    }) baz2;
    
    foreach (i, e; __traits(allMembers, baz2)) {
        static assert( e == ["a", "b", "c", "d"][i] );
    }
    assert( baz2.a == baz.a );
    assert( baz2.b == baz.b );
    assert( baz2.c == baz.c );
    assert( baz2.d == 25 );
    static assert(!is(typeof( ExtendEnum!(baz, "25"))));
}

void main() {
}