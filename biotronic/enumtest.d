module enumMagic;

template isValidEnumBody( string s ) {
    enum isValidEnumBody = __traits( compiles, { mixin( "enum foo {" ~ s ~ "}" ); } );
} unittest {
    assert( isValidEnumBody!"a" );
    assert( isValidEnumBody!"a,b" );
    assert( !isValidEnumBody!"1" );
}

template isEnumStruct( T ) {
    static if ( is( T t == Enum!s, string s ) ) {
        enum isEnumStruct = true;
    } else {
        enum isEnumStruct = false;
    }
} unittest {
    assert( isEnumStruct!( Enum!"a" ) );
}

template MakeEnum( string s ) if ( isValidEnumBody!s ) {
    mixin( "enum MakeEnum{" ~ s ~ "}" );
}

string EnumMembers( string s )( ) {
    string result = "";
    foreach ( e; __traits( allMembers, MakeEnum!s ) ) {
        result ~= "enum " ~ e ~ " = Enum( MakeEnum!s." ~ e ~ " );";
    }
    return result;
}

template Enum( T ) if ( isEnumStruct!T ) {
    alias T Enum;
}

template Enum( T, U... ) if ( isEnumStruct!T && U.length > 0 ) {
    alias Enum!( T.values ~ ", " ~ Enum!U.values ) Enum;
}

template Enum( string s, U... ) if ( isValidEnumBody!s ) {
    alias Enum!( s ~ ", " ~ Enum!U.values ) Enum;
} unittest {
    assert( is( Enum!( "a", "b" ) ) );
    assert( is( Enum!( Enum!"a", Enum!"b" ) ) );
    assert( !is( Enum!( Enum!"a", Enum!"a" ) ) );
}

struct Enum( string s ) if ( isValidEnumBody!s ) {
    private enum values = s;
    mixin( EnumMembers!s( ) );
    private this( MakeEnum!s value ) {
        this.value = value;
    }
    
    ulong value;
} unittest {
    assert( is( Enum!"a" ) );
    assert( !is( Enum!"1" ) );
    assert( is( typeof( Enum!"a".a ) ) );
}

void main( ) {
}