module biotronic.linalg.quaternion;

import biotronic.utils;
import biotronic.linalg.vector;

version ( unittest ) {
    import std.conv : to;
}

import std.traits : Unqual;

struct Quaternion( T ) if ( is( T == Unqual!T ) ) {
    private Vector!( T, 4 ) _value;
    private alias _value this;
    
    this( U )( U s ) if ( hasNumericBehavior!U ) {
        this.xyz = [0, 0, 0];
        this.w = s;
    } unittest {
        foreach ( Type; TypeTuple!( float, double, real ) ) {
            Quaternion a = cast(Type)0;
            assert( a == [0, 0, 0, 0] );
        }
    }
    
    this( U )( Vector!( U, 4 ) value ) {
        _value = value;
    } unittest {
        foreach ( Type; TypeTuple!( float, double, real ) ) {
            Quaternion a = Vector!( Type, 4 )( 0, 0, 0, 0 );
            assert( a == [0, 0, 0, 0] );
        }
    }
    
    this( U... )( U args ) if ( U.length == 4 ) {
        _value = [args];
    }
    
    this( U, V )( U[3] v, V s ) {
        _value.xyz = v;
        _value.w = s;
    }
    
    this( U, V )( U[] v, V s ) {
        assert( v.length == 3 );
        _value.xyz = v;
        _value.w = s;
    }
    
    this( U, V )( Vector!( U, 3 ) v, V s ) {
        _value.xyz = v;
        _value.w = s;
    } unittest {
        foreach ( Type; TypeTuple!( float, double, real ) ) {
            auto xyz = Vector!( Type, 3 )( 1, 1, 1 );
            Type w = 2;
            auto q = Quaternion( xyz, w );
            assert( q == [1,1,1,2] );
        }
    }
    
    this( U )( U[4] value ) {
        _value = value;
    }
    
    this( U )( U[] value ) {
        assert( value.length == 4 );
        _value = value;
    }
    
    @property
    Quaternion conjugate( ) const {
        return Quaternion( -(this.xyz), this.w ); 
    } unittest {
        Quaternion q = [1,2,3,4];
        assert( q.conjugate == [-1,-2,-3,4] );
    }
    
    @property
    Quaternion inverse( ) const {
        return conjugate / magnitudeSquared;
    } unittest {
        assert( Quaternion( 1 ).inverse == 1 );
        assert( Quaternion( 2 ).inverse == 0.5 );
        assert( Quaternion( [1,1,1],1 ).inverse == Quaternion( [-0.25, -0.25, -0.25], 0.25 ) );
    }
    
    @property
    auto magnitude( ) const {
        return _value.magnitude;
    } unittest {
        auto q = Quaternion( 1 );
        assert( q.magnitude == 1 );
    }
    
    @property
    auto magnitudeSquared( ) const {
        return _value.magnitudeSquared;
    } unittest {
        auto q = Quaternion( 2 );
        assert( q.magnitudeSquared == 4 );
    }
    
    @property
    auto normalized( ) const {
        return Quaternion( _value.normalized );
    } unittest {
        auto q = Quaternion( 3 );
        assert( q.normalized == 1 );
    }
    
    Quaternion opBinary( string op : "*" )( Quaternion other ) const {
        Quaternion result;
        result.w = this.w * other.w + this.xyz.dot( other.xyz );
        result.xyz = (this.xyz * other.w) + (this.w * other.xyz) + (this.xyz.cross( other.xyz ));
        return result;
    } unittest {
        Quaternion p = 1;
        Quaternion q = 2;
        assert( p * q == 2 );
    }
    
    Quaternion opBinary( string op : "+" )( Quaternion other ) const {
        return Quaternion( _value + other._value );
    } unittest {
        Quaternion p = 1;
        Quaternion q = 2;
        assert( p + q == 3 );
    }
    
    Quaternion opBinary( string op : "-" )( Quaternion other ) const {
        return Quaternion( _value - other._value );
    } unittest {
        Quaternion p = 1;
        Quaternion q = 2;
        assert( p - q == -1 );
    }
    
    Quaternion opBinary( string op : "/" )( Quaternion other ) const {
        return this * other.inverse;
    } unittest {
        Quaternion p = 1;
        Quaternion q = 2;
        assert( p / q == 0.5 );
    }
    
    Quaternion opBinary( string op : "/", U )( U other ) const if ( hasNumericBehavior!U ) {
        return Quaternion( _value / other );
    } unittest {
        Quaternion p = 1;
        assert( p / 2 == 0.5 );
    }
    
    Quaternion opBinary( string op : "*", U )( U other ) const if ( hasNumericBehavior!U ) {
        return Quaternion( _value * other );
    } unittest {
        Quaternion p = 1;
        assert( p * 2 == 2 );
    }
    
    Quaternion opBinaryRight( string op : "*", U )( U other ) const if ( hasNumericBehavior!U ) {
        return Quaternion( other * _value );
    } unittest {
        Quaternion p = 1;
        assert( 2 * p == 2 );
    }
    
    Quaternion opBinaryRight( string op : "/", U )( U other ) const if ( hasNumericBehavior!U ) {
        return Quaternion( other ) / this;
    } unittest {
        Quaternion p = 2;
        assert( 1 / p == 0.5 );
    }
    
    ref Quaternion opAssign( U )( Quaternion!U other ) {
        _value = other._value;
        return this;
    }
    
    ref Quaternion opAssign( )( T val ) {
        _value.x = _value.y = _value.z = 0;
        _value.w = val;
        return this;
    }
    
    bool opEquals( U )( ref const Quaternion!U other ) const {
        return _value == other._value;
    }
    
    bool opEquals( U )( U value ) const if ( hasNumericBehavior!U ) {
        return this.xyz == [0,0,0] && this.w == value;
    }
    
    bool opEquals( U )( U[4] value ) const {
        return this[] == value;
    }
    
    bool opEquals( U )( U[] value ) const {
        assert( value.length == 4 );
        return this[] == value;
    }
}

unittest {
    foreach ( T; TypeTuple!( float, double, real ) ) {
        Quaternion!T a;
        assert( hasFloatBehavior!( Quaternion!T ) );
    }
}