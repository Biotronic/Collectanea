import std.traits : Parameters, isTypeTuple;
import std.meta : AliasSeq, allSatisfy, Filter, staticIndexOf;

// Example type
struct Tuple(T...) {
    T fields;
    
    template isValidPattern(P) {
        template impl(int n) {
            static if (n >= P.pattern.length) {
                enum impl = true;
            } else  {
                alias e = AliasSeq!(P.pattern[n]);
                static if (ignore!e) { // Check for _
                    enum impl = impl!(n+1);
                } else static if (is(typeof(e[0] == fields[n]))) { // Check for field equals value
                    enum impl = impl!(n+1);
                } else static if (is(T[n] : e[0])) { // Check for type
                    enum impl = impl!(n+1);
                } else {
                    enum impl = false;
                }
            }
        }
        enum isValidPattern = impl!0;
    }
    
    bool opMatch(Pattern, Args...)(Pattern p, ref Args args) if (isValidPattern!Pattern) {
        foreach (i, e; p.pattern) {
            static if (isTypeTuple!e) {
                args[countTypes!(p.pattern[0..i])] = fields[i];
            } else static if (!ignore!e) {
                if (fields[i] != e) {
                    return false;
                }
            }
        }
        return true;
    }
}

auto tuple(T...)(T args) {
    return Tuple!T(args);
}

struct Algebraic(T...) {
    union {
        T fields;
    }
    size_t which;
    
    bool opMatch(Pattern, Type)(Pattern p, ref Type args) if (staticIndexOf!(Type, T) > -1) {
        enum index = staticIndexOf!(Type, T);
        if (index == which) {
            args = fields[index];
            return true;
        }
        return false;
    }
    
    this(Type)(Type value) if (staticIndexOf!(Type, T) > -1) {
        enum index = staticIndexOf!(Type, T);
        fields[index] = value;
        which = index;
    }
}



// Pattern matching implementation follows
// =======================================

/// Counts the items in T that are types.
template countTypes(T...) {
    enum countTypes = Filter!(isTypeTuple, T).length;
} unittest {
    assert(countTypes!(int, 3) == 1);
    assert(countTypes!() == 0);
    assert(countTypes!(3, "foo", _) == 0);
}

/// Check if T is _, the 'ignore' symbol.
template ignore(T...) if (T.length == 1) {
    enum ignore = __traits(isSame, T[0], _);
} unittest {
    assert(ignore!_);
    assert(!ignore!int);
    assert(!ignore!3);
}

/// The pattern to be matched, along with the function to be called after matching.
struct Pattern(Fn, T...) {
    alias pattern = T;
    private Fn fn;
    
    private this(Fn f) {
        fn = f;
    }
}

/// Temporary wrapper of match pattern, quickly decays to Pattern, above, without releasing neutrons.
struct _(T...) {
    @disable this();
    @property static
    auto opAssign(U)(U fn) {
        return Pattern!(U, T)(fn);
    }
}

/// Pattern matching implementation:
auto match(T)(ref T t) {
    struct Matcher {
        @disable this(this);
        
        template doesMatch(P) {
            enum doesMatch = is(typeof((P p) {
                Parameters!(p.fn) args = void;
                t.opMatch(p, args);
                }));
        }
        
        auto opCall(U...)(U fns) if (allSatisfy!(doesMatch, U)) {
            foreach (e; fns) {
                Parameters!(e.fn) args = void;
                if (t.opMatch(e, args)) {
                    return e.fn(args);
                }
            }
            static if (!is(typeof(return) == void)) {
                assert(false);
            }
        }
    }
    
    Matcher m;
    return m;
} unittest {
    import std.conv : to;
    import std.exception : assertThrown;
    import core.exception : AssertError;
    
    auto a = tuple(1, "qux");
    
    auto fn = () => match(a) (
        _!(1, string)  = (string s) => s,
        _!(int, "foo") = (int    i) => i.to!string,
        _!(int, _)     = (int    i) => "baz",
    );
    
    assert(fn() == "qux");
    a = tuple(4, "foo");
    assert(fn() == "4");
    a = tuple(4, "zap");
    assert(fn() == "baz");
    
    // assert(false) when no match found and return value not void.
    assertThrown!AssertError(match(a) (
            _!(3, "foo") = () => {}
        ));
    
    int n = 0;
    
    // No assert for failed matching when return value is void.
    match(a) (
        _!(3, _) = () { n = 3; }
    );
    assert(n == 0);
} unittest {
    Algebraic!(int, string, float) a = 3.14f;
    
    assert(match(a) (
        _!(int)    = (int f)    => 0,
        _!(string) = (string f) => 1,
        _!(float)  = (float f)  => 2
    ) == 2);
}