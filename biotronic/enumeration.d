module enumeration;

import std.typetuple : TypeTuple;
import std.conv : to;
import std.exception : enforce, assertThrown, assertNotThrown;

nothrow:
@safe:
private:

/**
 * Checks if a string is a valid enum body.
**/
template isValidFlagEnumBody( string s ) {
	enum isValidFlagEnumBody = __traits( compiles, { mixin( "enum foo { " ~ s ~ " }" ); } );
} unittest {
	assert( isValidFlagEnumBody!q{a} );
	assert( isValidFlagEnumBody!q{a,b} );
	assert( !isValidFlagEnumBody!q{a.} );
}

/**
 * Build an enum from a string. Mostly to use D's own parser instead of implementing one on my own.
**/
template MakeEnum( string s ) {
	mixin( "enum MakeEnum { " ~ s ~ " }" );
}

/**
 *  Extract enum names from a string representation.
**/
template parsedString( string s ) {
	alias TypeTuple!( __traits( allMembers, MakeEnum!s ) ) parsedString;
}

unittest {
	assert( parsedString!"a"[0] == "a" );
	assert( parsedString!"a".length == 1 );
	assert( parsedString!"a,b"[0] == "a" );
	assert( parsedString!"a,b"[1] == "b" );
	assert( parsedString!"a,b".length == 2 );
}

/**
 *  Check if a type is an enumeration or not.
**/
template isEnumeration( T... ) if ( T.length == 1 ) {
    static if ( is( T[0] b == Enumeration!U, U... ) ) {
        enum isEnumeration = true;
    } else {
        enum isEnumeration = false;
    }
}

/**
 * An enumeration of names.
 * Ignores any and all specified values, but otherwise accepts normal enum format.
 * Second parameter is a base enum, should you wish to extend one.
**/
struct Enumeration( string s, BaseEnum = void ) if ( isValidFlagEnumBody!s && ( isEnumeration!BaseEnum || is( BaseEnum == void ) ) ) {
    static if ( isEnumeration!BaseEnum ) {
        private alias TypeTuple!( BaseEnum.memberNames, parsedString!s ) memberNames;
    } else {
        private alias parsedString!s memberNames;
    }
    
    // Determine enum size.
	static if ( memberNames.length <= 256 ) {
		private alias ubyte Representation;
	} else static if ( memberNames.length <= 65_536 ) {
		private alias ushort Representation;
	} else static if ( memberNames.length <= 4_294_967_296 ) {
		private alias uint Representation;
	} else static if ( memberNames.length <= 18_446_744_073_709_551_615UL ) {
		private alias ulong Representation;
	} else {
        static assert( false, "What the *hell* is wrong with you? How did you even end up with more than 18 quintillion enum members?!?!" );
    }
	private Representation value;

	mixin template enumerationMembers( ulong N ) { }
	mixin template enumerationMembers( ulong N, string name, U... ) {
		mixin( "enum " ~ name ~ " = typeof(this)( N );" );
		mixin enumerationMembers!( N + 1, U );
	}
	mixin enumerationMembers!( 0, memberNames );
    
    // If we extend a base enum, allow assignment from that to this, but not the other way around.
    static if ( isEnumeration!BaseEnum ) {
        typeof(this) opAssign( BaseEnum other ) {
            value = to!Representation( other );
            return this;
        }
        
        typeof(this) opAssign( typeof(this) other ) {
            value = other.value;
            return this;
        }
        
        int opCmp( BaseEnum other ) {
            return value - other.value;
        }
    }
	
    /**
     * Returns a string representation of the enum.
    **/
	string toString( ) const {
		return [memberNames][value];
	}
    
    /**
     * Compares two enumeration values
    **/
    int opCmp( typeof(this) other ) {
        return value - other.value;
    }
    
    /**
     * Converts the value to whatever 
    **/
    @trusted
    U opCast( U )( ) if ( is( typeof( to!U( value ) ) ) ) {
        static if ( is( U == BaseEnum ) ) {
            enforce( value < BaseEnum.memberNames.length, "Value of enumeration outside range of base enumeration." );
        }
        return to!U( value );
    }
	
    /**
     * Iterate over all the members of the enum.
    **/
    @trusted
	static int opApply( int delegate(ref typeof(this)) fn ) {
		foreach ( e; memberNames ) {
			if ( auto ret = fn( mixin( "typeof(this)." ~ e ) ) != 0 ) {
				return ret;
			}
		}
		return 0;
	} unittest {
        int n = 0;
        foreach ( e; typeof( this ) ) {
            n++;
        }
        assert( n == memberNames.length );
    }
}

@system
unittest {
	alias Enumeration!q{a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z} Letters;
	
	assert( !__traits( compiles, Letters.a + Letters.b ) );
	assert( !__traits( compiles, Letters.a - Letters.b ) );
	assert( !__traits( compiles, Letters.a * Letters.b ) );
	assert( !__traits( compiles, Letters.a / Letters.b ) );
	assert( !__traits( compiles, Letters.a | Letters.b ) );
	assert( !__traits( compiles, Letters.a & Letters.b ) );
	assert( !__traits( compiles, Letters.a ^ Letters.b ) );
    
	assert( __traits( compiles, Letters.a < Letters.b ) );
	assert( __traits( compiles, Letters.a == Letters.b ) );
	
	assert( !__traits( compiles, Letters.a + 1 ) );
	assert( !__traits( compiles, Letters.a - 1 ) );
	assert( !__traits( compiles, Letters.a * 1 ) );
	assert( !__traits( compiles, Letters.a / 1 ) );
	assert( !__traits( compiles, Letters.a | 1 ) );
	assert( !__traits( compiles, Letters.a & 1 ) );
	assert( !__traits( compiles, Letters.a ^ 1 ) );
	assert( !__traits( compiles, Letters.a == 1 ) );
	assert( !__traits( compiles, Letters.a < 1 ) );
	assert( !__traits( compiles, Letters.a = 1 ) );
    
    assert( Letters.r.toString() == "r" );
    assert( cast(int)Letters.a == 0 );
    assert( cast(int)Letters.z == 25 );
    
    alias Enumeration!q{a,b} BaseEnum;
    alias Enumeration!(q{c,d}, BaseEnum) ExtEnum;
    
    assert( is( typeof( ExtEnum.a ) ) );
    assert( is( typeof( ExtEnum.b ) ) );
    assert( is( typeof( ExtEnum.c ) ) );
    assert( is( typeof( ExtEnum.d ) ) );
    
    BaseEnum b1;
    ExtEnum e1;
    
    e1 = BaseEnum.a;
    assert( e1 == ExtEnum.a );
    e1 = BaseEnum.b;
    assert( e1 == ExtEnum.b );
    e1 = ExtEnum.a;
    assert( e1 == ExtEnum.a );
    e1 = ExtEnum.b;
    assert( e1 == ExtEnum.b );
    e1 = ExtEnum.c;
    assert( e1 == ExtEnum.c );
    e1 = ExtEnum.d;
    assert( e1 == ExtEnum.d );
    
    assert( BaseEnum.a < ExtEnum.b );
    
    assert( !__traits( compiles, b1 = ExtEnum.a ) );
    
    e1 = ExtEnum.d;
    assertThrown( cast(BaseEnum)e1 );
    e1 = ExtEnum.a;
    assertNotThrown( cast(BaseEnum)e1 );
}

void main() {}
