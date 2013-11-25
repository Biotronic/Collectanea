module algebraic;

import std.conv;
import std.typetuple;
import std.traits;
import std.typecons;

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

template Algebraic( T... ) if ( T.length > 0 && !isSorted!T && hasNoDuplicates!T ) {
    alias Algebraic!( StaticSort!( sortPred, T ) ) Algebraic;
}

mixin template makeOpAssigns(int n, T...) {
    static if (T.length) {
        ref Algebraic opAssign(T[0] value) {
            whichType = n;
            values[n] = value;
            return this;
        }
        mixin makeOpAssign!(n+1, T[1..$]);
    }
}

mixin template makeConstructors(int n, T...) {
    static if (T.length) {
        this(T[0] value) {
            opAssign(value);
        }
        mixin makeConstructors!(n+1, T[1..$]);
    }
}

struct Algebraic( T... ) if ( T.length > 0 && isSorted!T && hasNoDuplicates!T ) {
    public:
    mixin makeConstructors!(0, T);
    mixin makeOpAssigns!(0, T);
    
    @property const
    bool isType( Type, string file = __FILE__, int line = __LINE__ )( ) {
        static if ( staticIndexOf!( Type, T ) == -1 ) {
            pragma( msg, to!(string)( file ~ "(" ~ to!string( line ) ~ "): Error: Type " ~ Type.stringof ~ " is not comparable with " ~ typeof( this ).stringof ) );
            static assert( false );
        }
        return staticIndexOf!( Type, T ) == whichType;
    }
    
    alias T Types;
    
    private:
    size_t whichType;
    union {
        T values;
    }
}

template hasNoDuplicates( T... ) {
    enum hasNoDuplicates = is( CMP!T == CMP!(NoDuplicates!T) );
}

template sortPred(T...) if (T.length == 2) {
    static if ( T[0].stringof < T[1].stringof ) {
        enum sortPred = -1;
    } else static if ( T[0].stringof > T[1].stringof ) {
        enum sortPred = 1;
    } else {
        enum sortPred = 0;
    }
} unittest {
    assert( sortPred!(int, string) == -sortPred!( string, int ) );
}

template isSorted( T... ) {
    enum isSorted = is( T == StaticSort!( sortPred, T ) );
} unittest {
    assert( isSorted!() );
    assert( isSorted!int );
    assert( isSorted!(int, int) );
    assert( isSorted!(int, string) );
    assert( !isSorted!(string, int) );
}

template Types( T... ) {
    template Except( U, V... ) {
        alias Types!( Erase!( U, T ) ).Except!V Except;
    }
    template Except( ) {
        alias T Except;
    }
} unittest {
    assert( is( CMP!( Types!( int, float, string ).Except!( int, float ) ) == CMP!string ) );
}

abstract final class OpaqueTypeTuple( T... ) {
    alias T params;
}

template CompareTypeAndStuff( T1, T2 ) {
    enum CompareTypeAndStuff = sortPred!( T1.params[0], T2.params[0] );
}

template TypeAndStuff( alias A ) {
    alias OpaqueTypeTuple!( Unqual!( ParameterTypeTuple!A[0] ), A ) TypeAndStuff;
}

template Match( Handlers... ) {
    @property
    auto Match( T, string file = __FILE__, int line = __LINE__ )( T value ) {
        static if ( is( T t == Algebraic!U, U... ) ) {
            alias StaticSort!( CompareTypeAndStuff, staticMap!( TypeAndStuff, Handlers ) ) sortedHandlers;
            alias StaticSort!( sortPred, staticMap!( Unqual, staticMap!( ParameterTypeTuple, Handlers ) ) ) HandledTypes;
            static if ( is( CMP!( staticMap!( Unqual, U ) ) == CMP!( HandledTypes ) ) ) {
                switch ( value.whichType ) {
                    foreach ( i, e; Handlers ) {
                        case i:
                            return sortedHandlers[i].params[1]( value.values[i] )( );
                    }
                    default:
                        break;
                }
            } else {
                static if ( Types!HandledTypes.Except!(NoDuplicates!HandledTypes).length ) {
                    pragma( msg, to!(string)( file ~ "(" ~ to!string( line ) ~ "): Error: Duplicate types in pattern: " ~ Types!HandledTypes.Except!(NoDuplicates!HandledTypes).stringof ) );
                }
                static if ( Types!U.Except!HandledTypes.length ) {
                    pragma( msg, to!(string)( file ~ "(" ~ to!string( line ) ~ "): Error: Unhandled types in pattern: " ~ Types!U.Except!HandledTypes.stringof ) );
                }
                static if ( Types!(NoDuplicates!HandledTypes).Except!U.length ) {
                    pragma( msg, to!(string)( file ~ "(" ~ to!string( line ) ~ "): Error: Superfluous types in pattern: " ~ Types!(NoDuplicates!HandledTypes).Except!U.stringof ) );
                }
                static assert( false );
            }
        } else {
            pragma( msg, to!(string)( file ~ "(" ~ to!string( line ) ~ "): Error: Cannot pattern match a non-enumerated type" ) );
            static assert( false );
        }
        assert( false );
    }
}

struct Nothing {};

template Maybe( T ) {
    alias Algebraic!( T, Nothing ) Maybe;
}

void main() {}