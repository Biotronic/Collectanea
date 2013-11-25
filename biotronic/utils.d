module biotronic.utils;

import std.typetuple : TypeTuple, NoDuplicates, staticIndexOf;
import std.traits : Unqual, ParameterTypeTuple;

void staticEnforce(bool criteria, string msg)() {
    static if (!criteria) {
        pragma(msg, msg);
        static assert(false);
    }
}

void staticEnforce(bool criteria, string msg, string file, int line)() {
    staticEnforce!(criteria, file ~ "(" ~ line.stringof ~ "): Error: " ~ msg);
}

auto sum( R )( R range ) if ( isInputRange!R ) {
    ElementType!R tmp = 0;
    return reduce!( (a,b)=>a+b )( tmp, range );
}

template arrayToTuple( alias name ) {
    static if ( name.length ) {
        alias arrayToTuple = TypeTuple!( name[0], arrayToTuple!( name[1..$] ) );
    } else {
        alias arrayToTuple = TypeTuple!( );
    }
}

template Repeat( size_t n, T... ) {
    static if ( n ) {
        alias Repeat = TypeTuple!( T, Repeat!( n-1, T ) );
    } else {
        alias Repeat = TypeTuple!();
    }
}

template hasFloatBehavior( T ) {
    static if ( __traits( compiles, { T t; t = 1; return (t/2)*2 == t; } ) ) {
        enum hasFloatBehavior = { T t; t = 1; return (t/2)*2 == t; }();
    } else {
        enum hasFloatBehavior = false;
    }
} unittest {
    assert( hasFloatBehavior!float );
    assert( hasFloatBehavior!double );
    assert( hasFloatBehavior!real );
    assert( !hasFloatBehavior!int );
    assert( !hasFloatBehavior!char );
    assert( !hasFloatBehavior!string );
}

template hasNumericBehavior( T ) {
    template hasNumericBehaviorImpl( U... ) {
        static if ( U.length ) {
            enum hasNumericBehaviorImpl = is( Unqual!T == U[0] ) || hasNumericBehaviorImpl!( U[1..$] );
        } else {
            enum hasNumericBehaviorImpl = false;
        }
    }
    
    enum hasNumericBehavior = hasNumericBehaviorImpl!( byte, short, int, long, ubyte, ushort, uint, ulong, float, double, real );
} unittest {
    foreach ( Type; TypeTuple!( byte, short, int, long, ubyte, ushort, uint, ulong, float, double, real ) ) {
        assert( hasNumericBehavior!Type );
    }
    foreach ( Type; TypeTuple!( string, char, dchar, int[], void, void*) ) {
        assert( !hasNumericBehavior!Type );
    }
}

template StaticFilter(alias pred, T...) {
    static if (T.length == 0) {
        alias StaticFilter = TypeTuple!();
    } else static if (T.length == 1) {
        static if (pred!(T[0])) {
            alias StaticFilter = T;
        } else {
            alias StaticFilter = TypeTuple!();
        }
    } else {
        alias StaticFilter = TypeTuple!(
            StaticFilter!(pred, T[0..$/2]),
            StaticFilter!(pred, T[$/2..$]));
    }
}

struct CMP(T...){}

template sortPred(T...) if (T.length == 2) {
    static if ( TypeTuple!(T[0]).stringof < TypeTuple!(T[1]).stringof ) {
        enum sortPred = -1;
    } else static if ( TypeTuple!(T[0]).stringof > TypeTuple!(T[1]).stringof ) {
        enum sortPred = 1;
    } else {
        enum sortPred = 0;
    }
} unittest {
    assert( sortPred!(int, string) == -sortPred!( string, int ) );
}

template StaticSort(alias pred, T...) {
    static if (T.length == 0) {
        alias StaticSort = TypeTuple!();
    } else static if (T.length == 1) {
        alias StaticSort = T;
    } else {
        template lessPred(U...) {
            enum lessPred = pred!(T[0], U[0]) == 1;
        }
        template equalPred(U...) {
            enum equalPred = pred!(T[0], U[0]) == 0;
        }
        template morePred(U...) {
            enum morePred = pred!(T[0], U[0]) == -1;
        }
        
        
        alias eq = StaticFilter!(equalPred, T);
        alias less = StaticFilter!(lessPred, T);
        alias more = StaticFilter!(morePred, T);
        
        alias StaticSort = TypeTuple!(
            StaticSort!(pred, less),
            eq,
            StaticSort!(pred, more));
    }
} unittest {
    assert(is(StaticSort!(sortPred, int, string) == StaticSort!(sortPred, string, int)));
    assert(is(StaticSort!(sortPred, int, string) == StaticSort!(sortPred, string, int)));
    
    assert(is(CMP!(StaticSort!(sortPred, int, "waffles", string)) == CMP!(StaticSort!(sortPred, "waffles", string, int))));
}

template hasNoDuplicates( T... ) {
    enum hasNoDuplicates = is( CMP!T == CMP!(NoDuplicates!T) );
}

template isSorted( T... ) {
    enum isSorted = is( CMP!T == CMP!(StaticSort!( sortPred, T ) ) );
} unittest {
    assert( isSorted!() );
    assert( isSorted!int );
    assert( isSorted!(int, int) );
    assert( isSorted!(int, string) );
    assert( !isSorted!(string, int) );
}

template TypeEnum(T...) {
    template TypeEnumName(int n) {
        static if (n < T.length) {
            enum TypeEnumName = "_" ~ n.stringof ~ "," ~ TypeEnumName!(n+1);
        } else {
            enum TypeEnumName = "";
        }
    }
    mixin("enum TypeEnum {"~TypeEnumName!0~"}");
}
    
template ParameterTypeTupleOrVoid(T...) if (T.length == 1) {
    static if (is(ParameterTypeTuple!T)) {
        alias ParameterTypeTupleOrVoid = CMP!(ParameterTypeTuple!T);
    } else {
        alias ParameterTypeTupleOrVoid = CMP!void;
    }
}

template isType(T...) if (T.length == 1) {
    enum isType = is(T[0]);
}

template TypeSet(T...) {
    template superSetOf(U...) {
        static if (U.length == 0) {
            enum superSetOf = true;
        } else static if (U.length == 1) {
            enum superSetOf = staticIndexOf!(U, T) != -1;
        } else {
            enum superSetOf = superSetOf!(U[0..$/2]) && superSetOf!(U[$/2..$]);
        }
    }
    
    template strictSuperSetOf(U...) {
        enum strictSuperSetOf = superSetOf!U && !is(CMP!T == CMP!U);
    }
} unittest {
    assert(TypeSet!(int, string).superSetOf!(int));
    assert(TypeSet!(int, string).superSetOf!(int, string));
    assert(!TypeSet!(int, string).superSetOf!(float));
    assert(!TypeSet!(int, string).superSetOf!(float, int, string));
    assert(!TypeSet!(int, string).superSetOf!(float, int));
}