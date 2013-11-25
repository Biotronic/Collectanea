import std.conv : to;
import std.traits : isFloatingPoint;
debug import std.stdio : writeln;
import std.math;

alias std.math.log ln;

@property
void log( string file = __FILE__, int line = __LINE__ ) {
    int n;
    import core.sys.windows.stacktrace;
    //writeln( new StackTrace );
    writeln( file, ":", line, " ", &n );
}

template isCayleyDickson( T ) {
    static if ( is( T t == CayleyDickson!U, U... ) ) {
        enum isCayleyDickson = true;
    } else {
        enum isCayleyDickson = false;
    }
}

@property
T conjugate( T )( T value ) if ( isFloatingPoint!T ) {
    log;
    return value;
}

@property
T norm( T )( T value ) if ( isFloatingPoint!T ) {
    log;
    return fabs(value);
}

@property
T normSquared( T )( T value ) if ( isFloatingPoint!T ) {
    log;
    return value * value;
}

@property
T Imaginary( T )( T t ) if ( isFloatingPoint!T ) {
    log;
	return 0.0;
}

@property
T Real( T, U )( T t, U u ) {
    log;
    static if ( is( typeof( { t._Real = u; } ) ) ) {
        t._Real = u;
    } else {
        t = u;
    }
    return t;
}

@property
T Real( T )( T t ) {
    log;
    static if ( is( typeof( t._Real ) ) ) {
        return t._Real;
    } else {
        return t;
    }
}

T exp( T )( T t ) if ( isFloatingPoint!T ) {
    log;
    return std.math.exp( t );
}

CayleyDickson!(T, gamma) exp( T, int gamma = 1 )( const CayleyDickson!(T, gamma) t ) {
    log;
    if ( t.norm == 0.0 ) {
        return CayleyDickson!(T, gamma)( 1.0 );
    } else {
        immutable v = t.Imaginary.normalized;
        
        return exp(t.Real) * (
                cos( v.norm ) +
                v.normalized * sin( v.norm )
                );
    }
} unittest {
    auto f = CayleyDickson!(float)( 1.0 );
    assert( exp( f ) == exp(1.0) );
}

struct CayleyDickson( T, int gamma = 1 ) {
	T a, b;

    this( U )( U a ) {
        log;
        static if ( is( U : const( CayleyDickson ) ) ) {
            this.a = a.a;
            this.b = a.b;
        } else {
            this.a = to!T( a );
            this.b = to!T( 0.0 );
        }
    } unittest {
        auto f = CayleyDickson( 0.0 );
        assert( f.a == 0.0 );
        assert( f.b == 0.0 );
    }

    this( U, V )( U a, V b ) {
        log;
        this.a = to!T( a );
        this.b = to!T( b );
    } unittest {
        auto f = CayleyDickson( 1.0, 2.0 );
        assert( f.a == 1.0 );
        assert( f.b == 2.0 );
    }

    @property
    auto _Real( )( ) const {
        log;
        return a.Real;
    } unittest {
        auto f = CayleyDickson( 1.0, 2.0 );
        assert( f.Real == 1.0 );
    }
    
    @property
    void _Real( U )( U value ) {
        log;
        a.Real = to!T( value );
    } unittest {
        auto f = CayleyDickson( 1.0, 2.0 );
        f.Real = 3;
        assert( f == CayleyDickson( 3.0, 2.0 ) );
    }

	@property
	CayleyDickson Imaginary( ) const {
        log;
		return CayleyDickson( a.Imaginary, b );
	} unittest {
        auto f = CayleyDickson( 1.0, 2.0 );
        assert( f.Imaginary.a == f.a.Imaginary );
        assert( f.Imaginary.b == f.b );
    }

    @property
    CayleyDickson conjugate( ) const {
        log;
        return CayleyDickson( a.conjugate, -b );
    } unittest {
        auto f = CayleyDickson( 0.0, 1.0 );
        assert( f.conjugate.a == 0.0 );
        assert( f.conjugate.b == -1.0 );
    }

    @property
    auto normSquared( ) const {
        log;
        return a.normSquared + b.normSquared;
    } unittest {
        auto f = CayleyDickson( 1.0 );
        assert( f.normSquared == 1.0 );
        f = CayleyDickson( 2.0 );
        assert( f.normSquared == 4.0 );
        f = CayleyDickson( 0.0, 1.0 );
        assert( f.normSquared == 1.0 );
    }

    @property
    auto norm( ) const {
        log;
        return normSquared ^^ 0.5;
    } unittest {
        auto f = CayleyDickson( 1.0 );
        assert( f.norm == 1.0 );
        f = CayleyDickson( 2.0 );
        assert( f.norm == 2.0 );
    }
    
    @property
    auto normalized( ) const {
        log;
        if ( norm == 0.0 ) {
            return CayleyDickson( 0.0, 0.0 );
        } else {
            return this / norm;
        }
    } unittest {
        auto f = CayleyDickson( 1.0 );
        assert( f.normalized.a == 1.0 );
        assert( f.normalized.b == 0.0 );
        
        f = CayleyDickson( 0.0, 1.0 );
        assert( f.normalized.a == 0.0 );
        assert( f.normalized.b == 1.0 );
    }

    @property
    CayleyDickson inverse( ) const {
        log;
        immutable c = this.conjugate;
        immutable d = normSquared;
        return CayleyDickson( c.a / d, c.b / d );
    } unittest {
        auto f = CayleyDickson( 1.0 );
        assert( f.inverse == 1.0 );
        f = CayleyDickson( 2.0 );
        assert( f.inverse == 0.5 );
    }

    CayleyDickson opUnary( string op )( ) const if ( op == "-" || op == "+" ) {
        log;
        return mixin( "CayleyDickson( " ~ op ~ "a, " ~ op ~ "b )" );
    } unittest {
        auto f = -CayleyDickson( 1.0, 2.0 );
        assert( f.b == -2.0 );
        assert( f.a == -1.0 );
        assert( (+f).b == -2.0 );
        assert( (+f).a == -1.0 );
    }

    CayleyDickson opBinary( string op : "+", U )( U other ) const {
        log;
        CayleyDickson _other = other;
        return CayleyDickson( a + _other.a, b + _other.b );
    } unittest {
        auto f = CayleyDickson( 1.0, 2.0 );
        auto f2 = f + f;
        assert( f2.a == 2.0 );
        assert( f2.b == 4.0 );
    }

    CayleyDickson opBinary( string op : "-", U )( U other ) const {
        log;
        CayleyDickson _other = other;
        return CayleyDickson( a - _other.a, b - _other.b );
    } unittest {
        auto f = CayleyDickson( 1.0, 2.0 );
        auto f2 = f - f;
        assert( f2.a == 0.0 );
        assert( f2.b == 0.0 );
    }

    CayleyDickson opBinary( string op : "*", U )( U other ) const {
        log;
        CayleyDickson _other = other;
        return CayleyDickson( a * _other.a - gamma * _other.b.conjugate * b, _other.b * a + b * _other.a.conjugate );
    } unittest {
        auto f = CayleyDickson( 1.0, 0.0 );
        assert( (f * 2.0).a == 2.0 );
        f = CayleyDickson( 0.0, 1.0 );
        assert( (f * f).a == -1.0 * gamma );
    }

    CayleyDickson opBinary( string op : "/", U )( U other ) const {
        log;
        CayleyDickson _other = other;
        return this * _other.inverse;
    } unittest {
        auto f = CayleyDickson( 1.0, 0.0 );
        assert( (f / 2.0).a == 0.5 );
    }

    CayleyDickson opBinary( string op : "^^", U )( U other ) const {
        log;
        CayleyDickson _other = other;
        immutable v = Imaginary.normalized;
        return exp( other * ( ln( norm ) + v ) );
    } unittest {
        auto f = CayleyDickson( 2.0 );
        assert( f ^^ f == 4.0 );
        f = CayleyDickson( 0.0, 1.0 );
    }

    CayleyDickson opBinaryRight( string op, U )( U other ) const if ( ( op == "-" || op == "+" || op == "*" || op == "/" || op == "^^" ) && ( !is( U : const(CayleyDickson) ) ) ) {
        log;
        CayleyDickson _other = other;
        return mixin( "_other " ~ op ~ " this" );
    } unittest {
        assert( 1.0 -  CayleyDickson( 2.0 ) == CayleyDickson( 1.0 ) -  2.0 );
        assert( 1.0 +  CayleyDickson( 2.0 ) == CayleyDickson( 1.0 ) +  2.0 );
        assert( 1.0 *  CayleyDickson( 2.0 ) == CayleyDickson( 1.0 ) *  2.0 );
        assert( 1.0 /  CayleyDickson( 2.0 ) == CayleyDickson( 1.0 ) /  2.0 );
        assert( 1.0 ^^ CayleyDickson( 2.0 ) == CayleyDickson( 1.0 ) ^^ 2.0 );
    }

    bool opEquals( U )( U other ) const {
        log;
        CayleyDickson _other = other;
        return a == _other.a && b == _other.b;
    } unittest {
        auto f = CayleyDickson( 1.0 );
        assert( f == f );
        auto g = CayleyDickson( 2.0 );
        assert( g != f );
    }
    
    string toString( bool asMember = false ) const {
        log;
        if ( b == 0.0 ) {
            return to!string( a );
        } else if ( asMember ) {
            static if ( isFloatingPoint!T ) {
                return to!string( a ) ~ ", " ~ to!string( b );
            } else {
                return a.toString( true ) ~ ", " ~ b.toString( true );
            }
        } else {
            return "(" ~ toString( true ) ~ ")";
        }
    } unittest {
        auto f = CayleyDickson( 1.5 );
        assert( to!string( f ) == "1.5" );
    }
}

unittest {
    import std.typetuple : TypeTuple;
    
    foreach ( t; TypeTuple!( float, double, real ) ) {
        foreach ( g; TypeTuple!( -1, 0, 1 ) ) {
            log;
            auto z = to!(CayleyDickson!(t,g))(0.0);
            log;
            auto q = to!(CayleyDickson!(CayleyDickson!(t,g)))(0.0);
            log;
            auto o = to!(CayleyDickson!(CayleyDickson!(CayleyDickson!(t,g))))(0.0);
            log;
            auto s = to!(CayleyDickson!(CayleyDickson!(CayleyDickson!(CayleyDickson!(t,g)))))(0.0);
            log;
        }
    }
}

void main( ) {
//    CayleyDickson!(float, -1) q;
//    q.Real = 4;
}