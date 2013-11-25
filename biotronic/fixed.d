module biotronic.fixed;

import std.traits;
import std.stdio;
import std.typetuple;
import std.conv;

pure:
@trusted:
nothrow:

template isFixed( T ) {
	static if ( is( T t == Fixed!( m, d ), int m, int d ) ) {
		enum isFixed = true;
	} else {
		enum isFixed = false;
	}
} unittest {
	assert( isFixed!( Fixed!( 4, 3 ) ) );
	assert( isFixed!( Fixed!( 13, 2 ) ) );
	assert( !isFixed!int );
	assert( !isFixed!string );
}

template staticIota( int a, int b ) if ( a <= b ) {
	static if ( a == b ) {
		alias TypeTuple!( ) staticIota;
	} else {
		alias TypeTuple!( a, staticIota!( a+1, b ) ) staticIota;
	}
}

struct Fixed( int before, int after ) if ( before > 0 && after > 0 && ( before + after == 7 || before + after == 15 || before + after == 31 || before + after == 63 ) ) {
	
	static if ( before + after == 7 ) {
		alias byte Representation;
	} else static if ( before + after == 15 ) {
		alias short Representation;
	} else static if ( before + after == 31 ) {
		alias int Representation;
	} else static if ( before + after == 63 ) {
		alias long Representation;
	}
	
	private Representation payload;
	
	private static Fixed make( Representation payload ) {
		Fixed result;
		result.payload = payload;
		return result;
	}
	
	// Properties
	enum min = make( 1 );
	enum epsilon = make( 1 );
	enum max = make( Representation.max );
	
	
	// Constructors
	this( U )( U value ) if ( isNumeric!U ){
		payload = cast(Representation)( value * ( 1L << after ) );
	} unittest {
		Fixed a = 0.5;
		assert( cast(float)a.payload / ( 1L << after ) == 0.5 );
		a = Fixed( 1.5 );
		assert( cast(float)a.payload / ( 1L << after ) == 1.5 );
		a = Fixed( 1 );
		assert( a.payload >> after == 1 );
	}
	
	this( int m, int n)( const Fixed!( m, n ) value ) {
		static if ( n < after ) {
			payload = cast( Representation )( cast( long )value.payload << ( after - n ) );
		} else if ( n > after ) {
			payload = cast( Representation )( cast( long )value.payload >> ( n - after ) );
		} else {
			payload = cast( Representation )value.payload;
		}
	} unittest {
		Fixed a = Fixed!(26, 5)(0.5);
		assert( cast(float)a == 0.5 );
		Fixed b = Fixed!(2, 5)(1.5);
		assert( b == 1.5 );
	}
	
	
	// Cast operators
	U opCast( U )( ) const if ( isNumeric!U ) {
		return cast( U )( cast( real )payload / ( 1L << after ) );
	} unittest {
		Fixed a = 0.5;
		assert( cast(float)a == 0.5 );
		assert( cast(int)a == 0 );
		a = Fixed( 1.5 );
		assert( cast(int)a == 1 );
		assert( cast(float)a == 1.5 );
	}
	
	U opCast( U )( ) const if ( isFixed!U ) {
		return U( this );
	} unittest {
		Fixed a = 0.5;
		assert( cast( Fixed!( 4, 3 ) )a == 0.5 );
		a = 1.5;
		assert( cast( Fixed!( 4, 27 ) )a == 1.5 );
	}
	
	
	// Assignment
	Fixed opAssign( U )( U value ) if ( isNumeric!U ) {
		payload = cast(Representation)( value * ( 1L << after ) );
		return this;
	} unittest {
		Fixed a = 0.5;
		a = 1;
		assert( a == 1 );
		a = 1.5;
		assert( a == 1.5 );
	}
	
	Fixed opAssign( int m, int n )( const Fixed!(m, n) value ) {
		payload = Fixed(value).payload;
		return this;
	} unittest {
		Fixed a = 0.5;
		a = Fixed( 1.5 );
		assert( a == 1.5 );
		a = Fixed( 1.0 );
		assert( a == 1.0 );
	}
	
	private template supportsUnaryOp( string op ) {
		enum supportsUnaryOp = staticIndexOf!( op, TypeTuple!( "+", "-" ) ) != -1;
	}
	
	// Unary operators
	Fixed opUnary( string op )( ) const if ( supportsUnaryOp!op ) {
		static if ( op == "-" ) {
			Fixed result;
			result.payload = -payload;
			return result;
		} else static if ( op == "+" ) {
			return this;
		}
	} unittest {
		Fixed a = 0.5;
		assert( -a == -0.5 );
		a = -1.5;
		assert( -a == 1.5 );
		assert( +a == a );
	}
	
	private template supportsBinaryOp( string op ) {
		enum supportsBinaryOp = staticIndexOf!( op, TypeTuple!( "+", "-", "*", "/" ) ) != -1;
	}
	
	// Binary operators:
	Fixed opBinary( string op, U )( const U value ) const if ( isNumeric!U && supportsBinaryOp!op ) {
		static if ( op == "*" || op == "/" ) {
			Fixed result;
			mixin( "result.payload = cast( Representation )( payload " ~ op ~ " value );" );
			return result;
		} else {
			mixin( "return this " ~ op ~ " Fixed( value );" );
		}
	} unittest {
		Fixed a = 0.5;
		a = a * 3;
		assert( a == 1.5 );
		a = a / 3;
		assert( a == 0.5 );
		a = a + 1.0;
		assert( a == 1.5 );
		a = a - 0.5;
		assert( a == 1.0 );
	}
	
	Fixed opBinary( string op, int m, int n )( const Fixed!(m, n) value ) const if ( supportsBinaryOp!op ) {
		static if ( op == "+" || op == "-" ) {
			Fixed result;
			mixin( "result.payload = cast( Representation )( payload " ~ op ~ " value.payload );" );
			return result;
		} else static if ( op == "*" ) {
			Fixed result;
			result.payload = cast(Representation)( 
				(payload >> after) * value.payload |
				(value.payload >> n) * payload);
			return result;
		} else static if ( op == "/" ) {
			Fixed result;
			result.payload = cast(Representation)( 
				(payload >> after) / value.payload |
				payload / (value.payload >> n));
			return result;
		}
	} unittest {
		Fixed a = 1.5;
		a = a - Fixed( 0.5 );
		assert( a == 1.0 );
		a = a + Fixed( -0.5 );
		assert( a == 0.5 );
		a = a * Fixed!(27, 4)( 2 );
		assert( a == 1.0 );
		a = a / Fixed!(27, 4)( 2 );
		assert( a == 0.5 );
	}
	
	Fixed opBinaryRight( string op, U )( const U value ) const if ( isNumeric!U && supportsBinaryOp!op ) {
		static if ( op == "/" ) {
			Fixed result;
			result.payload = cast(Representation)( 
				value.payload / (payload >> after) |
				(value.payload >> n) / payload);
			return result;
		} else {
			mixin( "return this " ~ op ~ " value;" );
		}
	} unittest {
		Fixed a = 0.5;
		assert( a + 0.5 == 0.5 + a );
		assert( a + 0.5 == 1.0 );
	}
	
	
	// Modify-assign operators
	ref Fixed opOpAssign( string op, U )( const U value ) if ( isNumeric!U && supportsBinaryOp!op ) {
		mixin( "this = this " ~ op ~ " value;" );
		return this;
	} unittest {
		Fixed a = 0.5;
		a += 1.0;
		assert( a == 1.5 );
		a /= 3;
		assert( a == 0.5 );
		a -= 1.0;
		assert( a == -0.5 );
		a *= -2;
		assert( a == 1.0 );
	}
	
	ref Fixed opOpAssign( string op, int m, int n )( const Fixed!( m, n ) value ) if ( supportsBinaryOp!op ) {
		mixin( "this = this " ~ op ~ " value;" );
		return this;
	} unittest {
		Fixed a  = 0.5;
		a += a;
		assert( a == 1.0 );
		a *= a;
		assert( a == 1.0 );
		a /= a;
		assert( a == 1.0 );
		a -= a;
		assert( a == 0.0 );
	}
	
	
	// Comparison operators
	bool opEquals( U )( U other ) const if ( isNumeric!U ) {
		return (cast(U)this) == other && this == Fixed(other);
	} unittest {
		Fixed a = 0.5;
		assert( a == 0.5 );
		assert( a != 1 );
		assert( a != 0 );
		a = 1.0;
		assert( a == 1 );
		assert( a != 1.5 );
		assert( a != 1.1 );
		assert( a != 0.9 );
	}
	
	bool opEquals( int m, int n )( Fixed!( m, n ) other ) const {
		static if ( n < after ) {
			bool whole = payload >> after == other.payload >> n;
			bool fractional = 
				cast(long)(payload & ( ( 1L << after ) - 1 )) == 
				cast(long)(other.payload & ( ( 1L << n  ) - 1 )) << (after - n);
			return whole &&  fractional;
		} else static if ( n > after ) {
			bool whole = payload >> after == other.payload >> n;
			bool fractional = 
				cast(long)(payload & ( ( 1L << after ) - 1 )) << (n - after) ==
				cast(long)(other.payload & ( ( 1L << n  ) - 1 ));
			return whole &&  fractional;
		} else {
			return payload == other.payload;
		}
	} unittest {
		Fixed a = 0.5;
		assert( a == a );
		assert( a == Fixed( 0.5 ) );
		assert( a == Fixed!(16, 15)( 0.5 ) );
	}
	
	long opCmp( int m, int n )( Fixed!( m, n ) other ) const {
		static if ( n == after ) {
			return payload - other.payload;
		} else {
			if ( other == this ) {
				return 0;
			} else if ( Fixed( other ) < this || Fixed!( m, n )( this ) > other ) {
				return 1;
			} else {
				return -1;
			}
		}
	} unittest {
		assert( Fixed( 0.5 ) < Fixed!( 4, 11 )( 1.0 ) );
		assert( Fixed( 0.5 ) > Fixed!( 4, 11 )( 0.0 ) );
		assert( max > min );
	}
	
	int opCmp( U )( U other ) const if ( isNumeric!U ) {
		if ( other == this ) {
			return 0;
		} else if ( Fixed( other ) < this || cast( U )this > other ) {
			return 1;
		} else {
			return -1;
		}
	} unittest {
		assert( Fixed( 0.5 ) > 0.0 );
		assert( Fixed( 0.5 ) > 0 );
		assert( Fixed( 0.5 ) < 1.500001 );
	}
	
	string toString( ) const {
		return to!string( cast(float) this );
	} unittest {
		assert( Fixed( 0.5 ).toString( ) == to!string( 0.5 ) );
		assert( Fixed( 1.5 ).toString( ) == to!string( 1.5 ) );
	}
}

unittest {
	foreach ( m; TypeTuple!( 63, 31, 15, 7 ) ) {
		foreach( n; TypeTuple!( 0, m - 1 ) ) {
			assert( !is( Fixed!( Representation, n ) ) );
		}
		foreach( n; staticIota!( 1, m - 2 ) ) {
			assert( is( Fixed!( n, m - n ) ) );
		}
	}
}