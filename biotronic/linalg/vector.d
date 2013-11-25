module biotronic.linalg.vector;

import biotronic.utils;

version (unittest) {
    import std.stdio;
    import std.conv : to;
    import std.exception : assertThrown;
}

import std.math : sqrt, feqrel;
import std.algorithm : map, reduce;
import std.range : isInputRange, ElementType, zip, iota;
import std.typetuple : TypeTuple, allSatisfy;
import std.array : array;
import std.traits : Unqual;

@safe: pure: nothrow:
    
template componentIndex( char name ) {
    static size_t componentIndexImpl( ) {
        switch ( name ) {
            case 'x': return 0;
            case 'y': return 1;
            case 'z': return 2;
            case 'w': return 3;
            case 'r': return 0;
            case 'g': return 1;
            case 'b': return 2;
            case 'a': return 3;
            default: return -1;
        }
    }
    enum componentIndex = componentIndexImpl( );
}

template isVectorComponentName( char name ) {
    enum isVectorComponentName = componentIndex!name != -1;
}

template noRepeatingIndexes( alias name ) {
    static bool helper( ) {
        foreach ( i1, e1; arrayToTuple!name ) {
            foreach ( i2, e2; arrayToTuple!name ) {
                if ( i1 != i2 && e1 == e2 ) {
                    return false;
                }
            }
        }
        return true;
    }
    enum noRepeatingIndexes = helper( );
}

struct Vector( T, size_t size = 4 ) if ( is( T == Unqual!T ) ) {
    T[size == 3 ? 4 : size] components;
    alias components this;
    
    this( U )( U[size] value ) {
        components[] = value[].map!(a => cast(T)a).array();
    } unittest {
        T[size] v = 1;
        Vector a = v;
        foreach ( e; a ) {
            assert( e == 1 );
        }
    }
    
    this( U )( U[] value ) {
        foreach ( i, e; value ) {
            components[i] = e;
        }
        //components[] = value[].map!(a => cast(T)a).array();
    } unittest {
        T[size] v = 1;
        Vector a = v[];
        foreach ( e; a ) {
            assert( e == 1 );
        }
    }
    
    this( U )( const Vector!( U, size ) value ) {
        foreach ( i, e; value ) {
            components[i] = e;
        }
        //components[] = value[].map!(a => cast(T)a).array();
    } unittest {
        Vector!( float, size ) f;
        Vector!( double, size ) d;
        Vector!( real, size ) r;
        f[] = 1;
        d[] = 2;
        r[] = 3;
        Vector vf = f;
        Vector vd = d;
        Vector vr = r;
        foreach ( e; vf ) {
            assert( e == 1 );
        }
        foreach ( e; vd ) {
            assert( e == 2 );
        }
        foreach ( e; vr ) {
            assert( e == 3 );
        }
    }
    
    this( T... )( T value ) if ( T.length == size && __traits( compiles, {components = [value];} ) ) {
        components = [value];
    } unittest {
        auto v1 = Vector( Repeat!( size, 1 ) );
        foreach ( e; v1 ) {
            assert( e == 1 );
        }
        assert( !__traits( compiles, {
            auto v2 = Vector( Repeat!( size - 1, 1 ) );
        } ) );
        assert( !__traits( compiles, {
            auto v2 = Vector( Repeat!( size + 1, 1 ) );
        } ) );
    }
    
    template isValidVectorComponentName( char name ) {
        enum isValidVectorComponentName = isVectorComponentName!name && componentIndex!name < size;
    } unittest {
        assert( isValidVectorComponentName!'x' == (size >= 1));
        assert( isValidVectorComponentName!'y' == (size >= 2));
        assert( isValidVectorComponentName!'z' == (size >= 3));
        assert( isValidVectorComponentName!'w' == (size >= 4));
        assert( isValidVectorComponentName!'r' == (size >= 1));
        assert( isValidVectorComponentName!'g' == (size >= 2));
        assert( isValidVectorComponentName!'b' == (size >= 3));
        assert( isValidVectorComponentName!'a' == (size >= 4));
        assert( !isValidVectorComponentName!'q' );
        assert( !isValidVectorComponentName!'1' );
        assert( !isValidVectorComponentName!'_' );
        assert( !isValidVectorComponentName!' ' );
    }
    
    ref inout(T) opDispatch( string name )( ) inout if ( name.length == 1 && isValidVectorComponentName!(name[0]) ) {
        return components[componentIndex!(name[0])];
    } @trusted unittest {
        auto v = Vector( iota(1, size+1).array( ) );
        assert( __traits( compiles, { T t = v.x; v.x = t; } ) == ( size >= 1 ) );
        assert( __traits( compiles, { T t = v.r; v.x = t; } ) == ( size >= 1 ) );
        assert( __traits( compiles, { T t = v.y; v.y = t; } ) == ( size >= 2 ) );
        assert( __traits( compiles, { T t = v.g; v.g = t; } ) == ( size >= 2 ) );
        //assert( __traits( compiles, { T t = v.z; v.z = t; } ) == ( size >= 3 ) );
        //assert( __traits( compiles, { T t = v.b; v.b = t; } ) == ( size >= 3 ) );
        //assert( __traits( compiles, { T t = v.w; v.w = t; } ) == ( size >= 4 ) );
        //assert( __traits( compiles, { T t = v.a; v.a = t; } ) == ( size >= 4 ) );
    }
    
    auto opDispatch( string name )( ) const if ( name.length > 1 && allSatisfy!( isValidVectorComponentName, arrayToTuple!name ) ) {
        Vector!(T, name.length) result;
        foreach ( i, e; arrayToTuple!name ) {
            result[i] = components[componentIndex!e];
        }
        return result;
    } @trusted unittest {
        auto v = Vector( iota(1, size+1).array( ) );
        assert( __traits( compiles, { Vector!(T, 2) t = v.xy; } ) == ( size >= 2 ) );
        assert( __traits( compiles, { Vector!(T, 2) t = v.yy; } ) == ( size >= 2 ) );
        assert( __traits( compiles, { Vector!(T, 2) t = v.rx; } ) == ( size >= 2 ) );
        assert( __traits( compiles, { Vector!(T, 2) t = v.xz; } ) == ( size > 2 ) );
        assert( __traits( compiles, { Vector!(T, 3) t = v.xyz; } ) == ( size >= 3 ) );
        assert( __traits( compiles, { Vector!(T, 3) t = v.zxy; } ) == ( size >= 3 ) );
        assert( __traits( compiles, { Vector!(T, 3) t = v.xyz; } ) == ( size >= 3 ) );
        assert( __traits( compiles, { Vector!(T, 3) t = v.xzw; } ) == ( size > 3 ) );
    }
    
    auto opDispatch( string name, U )( U value ) if ( name.length > 1 && allSatisfy!( isValidVectorComponentName, arrayToTuple!name ) && noRepeatingIndexes!( name ) ) {
        Vector!(T, name.length) result;
        foreach ( i, e; arrayToTuple!name ) {
            result[i] = components[componentIndex!e] = value[i];
        }
        return result;
    } unittest {
        auto v = Vector( iota(1, size+1).array( ) );
        assert( __traits( compiles, { v.yx = v.xy; } ) == ( size >= 2 ) );
        assert( __traits( compiles, { v.zyx = v.xyz; } ) == ( size >= 3 ) );
        assert( __traits( compiles, { v.wzyx = v.xyzw; } ) == ( size >= 4 ) );
    }
    
    @property
    NormalizedVector!(T, size) normalized( ) const {
        return NormalizedVector!(T, size)( this );
    } unittest {
        auto v = Vector( iota(1, size+1).array( ) );
        NormalizedVector!( T, size ) n;
        assert( __traits( compiles, { n = v.normalized; } ) );
        v = Vector( Repeat!( size, 0 ) );
        assertThrown!(core.exception.AssertError)( NormalizedVector!( T, size )( v ) );
    }
    
    @property
    auto magnitude( ) const {
        return sqrt( magnitudeSquared );
    } unittest {
        auto v = Vector( Repeat!( size, 2 ) );
        assert( v.magnitude == sqrt( cast( T )size * 4 ) );
    }
    
    @property
    auto magnitudeSquared( ) const {
        return dot( this );
    } unittest {
        auto v = Vector( Repeat!( size, 2 ) );
        assert( v.magnitudeSquared == cast( T )size * 4 );
    }
    
    static if ( size == 3 || size == 3 ) {
        Vector cross( const Vector other ) const {
            Vector result;
            
            result.x = this.y * other.z - this.z * other.y;
            result.y = this.x * other.z - this.z * other.x;
            result.z = this.x * other.y - this.y * other.x;
            
            return result;
        } unittest {
            auto v1 = Vector( 1, 0, 0 );
            auto v2 = Vector( 0, 1, 0 );
            auto v3 = Vector( 0, 0, 1 );
            assert( v1.cross( v2 ) == v3 || v1.cross( v2 ) == -v3 );
            assert( v1.cross( v2 ) == -v2.cross( v1 ) );
        }
    }
    
    auto dot( U )( const Vector!( U, size ) other ) const {
        typeof( T.init * U.init ) result = 0;
        foreach ( i; 0..size ) {
            result += this[i] * other[i]; 
        }
        return result;
    } unittest {
        foreach ( Type; TypeTuple!( float, double, real ) ) {
            auto v1 = Vector( Repeat!( size, 1 ) );
            auto v2 = Vector!( Type, size )( Repeat!( size, 2 ) );
            assert( v1.dot( v2 ) == 2 * size );
        }
    }
    
    auto opUnary( string op : "+" )( ) const {
        return this;
    } unittest {
        auto v1 = Vector( Repeat!( size, 1 ) );
        assert( v1 == +v1 );
    }
    
    auto opUnary( string op : "-" )( ) const {
        Vector result;
        result[] = -this[];
        return result;
    } unittest {
        auto v1 = Vector( iota(1, size+1).array( ) );
        auto v2 = -v1;
        foreach ( i; 0..size ) {
            assert( v2[i] == -v1[i] );
        }
    }
    
    auto opBinary( string op : "+" )( const Vector other ) const {
        Vector result;
        result[] = this[] + other[];
        return result;
    } unittest {
        auto v1 = Vector( iota(1, size+1).array( ) );
        auto v2 = v1 + v1;
        
        foreach ( i; 0..size ) {
            assert( v2[i] == v1[i] + v1[i] );
        }
    }
    
    auto opBinary( string op : "-" )( const Vector other ) const {
        Vector result;
        result[] = this[] - other[];
        return result;
    } unittest {
        auto v0 = Vector( Repeat!( size, 1 ) );
        auto v1 = Vector( iota(1, size+1).array( ) );
        auto v2 = Vector( iota(2, size+2).array( ) );
        auto v3 = v2 - v1;
        assert( v0 == v3 );
    }
    
    auto opBinary( string op : "/" )( T other ) const {
        Vector result;
        if ( __ctfe ) {
            foreach ( i, ref e; result ) {
                e = this[i] / other;
            }
        } else {
            result[] = this[] / other;
        }
        return result;
    } unittest {
        auto v1 = Vector( iota(2, (size+1) * 2, 2).array( ) );
        auto v2 = v1 / 2;
        auto v3 = Vector( iota(1, size+1).array( ) );
        assert( v2 == v3 );
    }
    
    auto opBinary( string op : "*" )( const Vector other ) const {
        Vector result;
        if ( __ctfe ) {
            foreach ( i, ref e; result ) {
                e = this[i] * other[i];
            }
        } else {
            result[] = this[] * other[];
        }
        return result;
    } unittest {
        auto v1 = Vector( Repeat!( size, 2 ) );
        auto v2 = Vector( Repeat!( size, 3 ) );
        auto v3 = Vector( Repeat!( size, 6 ) );
        
        assert( v1 * v2 == v3 );
        assert( v2 * v1 == v3 );
    }
    
    auto opBinary( string op : "*", U )( U other ) const if ( hasNumericBehavior!U ) {
        Vector result;
        if ( __ctfe ) {
            foreach ( i, ref e; result ) {
                e = this[i] * other;
            }
        } else {
            result[] = this[] * other;
        }
        return result;
    } unittest {
        auto v1 = Vector( Repeat!( size, 2 ) );
        auto v2 = Vector( Repeat!( size, 4 ) );
        
        assert( v1 * 2 == v2 );
    }
    
    auto opBinaryRight( string op : "*" )( T other ) const {
        Vector result;
        result[] = other * this[];
        return result;
    } unittest {
        auto v1 = Vector( Repeat!( size, 2 ) );
        auto v2 = Vector( Repeat!( size, 4 ) );
        
        assert( 2 * v1 == v2 );
    }
    
    auto opOpAssign( string op : "+", U )( const Vector!( U, size ) other ) {
        foreach ( i, ref e; this ) {
            e += other[i];
        }
        return this;
    } unittest {
        foreach ( Type; TypeTuple!( float, double, real ) ) {
            auto v1 = Vector( Repeat!( size, 1 ) );
            auto v2 = Vector!(Type, size)( Repeat!( size, 2 ) );
            auto v3 = Vector( Repeat!( size, 3 ) );
            v1 += v2;
            assert( v1 == v3 );
        }
    }
    
    auto opOpAssign( string op : "-", U )( const Vector!( U, size ) other ) {
        foreach ( i, ref e; this ) {
            e -= other[i];
        }
        return this;
    } unittest {
        foreach ( Type; TypeTuple!( float, double, real ) ) {
            auto v1 = Vector( Repeat!( size, 1 ) );
            auto v2 = Vector!(Type, size)( Repeat!( size, 2 ) );
            auto v3 = Vector( Repeat!( size, -1 ) );
            v1 -= v2;
            assert( v1 == v3 );
        }
    }
    
    auto opOpAssign( string op : "*", U )( const Vector!( U, size ) other ) {
        foreach ( i, ref e; this ) {
            e *= other[i];
        }
        return this;
    } unittest {
        foreach ( Type; TypeTuple!( float, double, real ) ) {
            auto v1 = Vector( Repeat!( size, 2 ) );
            auto v2 = Vector!(Type, size)( Repeat!( size, 3 ) );
            auto v3 = Vector( Repeat!( size, 6 ) );
            v1 *= v2;
            assert( v1 == v3 );
        }
    }
    
    auto opOpAssign( string op : "*", U )( U other ) if ( __traits( compiles, { components[0] *= other; } ) ) {
        this[] *= other;
        return this;
    } unittest {
        foreach ( Type; TypeTuple!( float, double, real ) ) {
            auto v1 = Vector( Repeat!( size, 2 ) );
            auto v2 = Vector( Repeat!( size, 4 ) );
            Type two = 2;
            v1 *= two;
            assert( v1 == v2 );
        }
    }
    
    auto opOpAssign( string op : "/", U )( const Vector!( U, size) other ) {
        foreach ( i, ref e; this ) {
            e /= other[i];
        }
        return this;
    } unittest {
        foreach ( Type; TypeTuple!( float, double, real ) ) {
            auto v1 = Vector( Repeat!( size, 4 ) );
            auto v2 = Vector!( Type, size)( Repeat!( size, 2 ) );
            auto v3 = Vector( Repeat!( size, 2 ) );
            v1 /= v2;
            assert( v1 == v3 );
        }
    }
    
    auto opOpAssign( string op : "/", U )( U other ) if ( __traits( compiles, { components[0] /= other; } ) ) {
        this[] /= other;
        return this;
    } unittest {
        foreach ( Type; TypeTuple!( float, double, real ) ) {
            auto v1 = Vector( Repeat!( size, 4 ) );
            auto v2 = Vector( Repeat!( size, 2 ) );
            Type two = 2;
            v1 /= two;
            assert( v1 == v2 );
        }
    }
    
    auto opAssign( U )( const Vector!( U, size ) other ) {
        foreach ( i, ref e; this[] ) {
            e = other[i];
        }
        return this;
    } unittest {
        foreach ( Type; TypeTuple!( float, double, real ) ) {
            auto v1 = Vector( Repeat!( size, 1 ) );
            auto v2 = Vector!( Type, size )( Repeat!( size, 2 ) );
            auto v3 = Vector( Repeat!( size, 2 ) );
            v1 = v2;
            assert( v1 == v3 );
        }
    }
    
    auto opAssign( U )( U[] other ) {
        assert( other.length == size );
        foreach ( i, ref e; this[] ) {
            e = other[i];
        }
        return this;
    } unittest {
        foreach ( Type; TypeTuple!( float, double, real ) ) {
            Type[] arr = [Repeat!( size, 2 )];
            auto v1 = Vector( Repeat!( size, 1 ) );
            auto v2 = Vector( Repeat!( size, 2 ) );
            v1 = arr;
            assert( v1 == v2 );
        }
    }
    
    auto opAssign( U )( U[size] other ) {
        foreach ( i, ref e; this[] ) {
            e = other[i];
        }
        return this;
    } unittest {
        foreach ( Type; TypeTuple!( float, double, real ) ) {
            Type[size] arr = [Repeat!( size, 2 )];
            auto v1 = Vector( Repeat!( size, 1 ) );
            auto v2 = Vector( Repeat!( size, 2 ) );
            v1 = arr;
            assert( v1 == v2 );
        }
    }
}

struct NormalizedVector( T, size_t size = 4 ) if ( is( T == Unqual!T ) ) {
    private Vector!(T, size) value;
    
    this( U )( Vector!( U, size ) v )
    in {
        assert( v.magnitude != 0 );
    } body {
        value = v / v.magnitude;
    } unittest {
        foreach ( Type; TypeTuple!( float, double, real ) ) {
            auto v1 = Vector!( Type, size )( Repeat!( size, 0 ) );
            assertThrown!( core.exception.AssertError )( NormalizedVector( v1 ) );
            auto v2 = Vector!( Type, size )( Repeat!( size, 1 ) );
            auto n2 = NormalizedVector( v2 );
            T tVal = 1.0 / sqrt( cast(T)size );
            foreach ( e; n2 ) {
                assert( feqrel( e, tVal ) > 20 );
            }
        }
    }

    @property const
    Vector!(T, size) get( ) {
        return value;
    }
    
    alias get this;
}

struct Point( T, size_t size = 4 ) if ( is( T == Unqual!T ) ) {
    alias Vec = Vector!(T, size);
    private Vec value;
    //private alias value this;
    
    this( U )( U[size] _value ) {
        value = Vec(_value);
    } unittest {
        T[size] v = 1;
        Point a = v;
        foreach ( e; a[] ) {
            assert( e == 1 );
        }
    }
    
    this( U )( U[] _value ) {
        value = Vec(_value);
    } unittest {
        T[size] v = 1;
        Point a = v[];
        foreach ( e; a ) {
            assert( e == 1 );
        }
    }
    
    this( U )( const Vector!( U, size ) _value ) {
        value = Vec(_value);
    } unittest {
        Vector!( float, size ) f;
        Vector!( double, size ) d;
        Vector!( real, size ) r;
        f[] = 1;
        d[] = 2;
        r[] = 3;
        Point vf = f;
        Point vd = d;
        Point vr = r;
        foreach ( e; vf ) {
            assert( e == 1 );
        }
        foreach ( e; vd ) {
            assert( e == 2 );
        }
        foreach ( e; vr ) {
            assert( e == 3 );
        }
    }
    
    this( T... )( T _value ) if ( T.length == size && __traits( compiles, {value = Vec(_value);} ) ) {
        value = Vec(_value);
    } unittest {
        auto v1 = Point( Repeat!( size, 1 ) );
        foreach ( e; v1 ) {
            assert( e == 1 );
        }
        assert( !__traits( compiles, {
            auto v2 = Point( Repeat!( size - 1, 1 ) );
        } ) );
        assert( !__traits( compiles, {
            auto v2 = Point( Repeat!( size + 1, 1 ) );
        } ) );
    }
    
    auto opSlice( ) {
        return value[];
    }

    auto opBinary( string op : "-" )( const Point other ) const {
        return value - other.value;
    }
    
    auto opBinary( string op : "-" )( const Vec other ) const {
        return Point( value - other );
    }
    
    auto opBinary( string op : "+" )( const Vec other ) const {
        return Point( value + other );
    }
    
    auto opBinaryRight( string op : "+" )( const Vec other ) const {
        return Point( other + value );
    }
    
    auto opOpAssign( string op : "+" )( const Vec other ) {
        value += other;
        return this;
    }
    
    auto opOpAssign( string op : "-" )( const Vec other ) {
        value -= other;
        return this;
    }
    
    unittest {
        Point p;
        Vec v;
        assert( __traits( compiles, { p = p + v; } ) );
        assert( __traits( compiles, { p = p - v; } ) );
        assert( __traits( compiles, { p += v; } ) );
        assert( __traits( compiles, { p -= v; } ) );
        assert( __traits( compiles, { v = p - p; } ) );
        assert( __traits( compiles, { p = v + p; } ) );
    }
    
    unittest {
        Point p;
        Vec v;
        assert( !__traits( compiles, { p = v; } ) );
        //assert( !__traits( compiles, { p += p; } ) );
    }
}

unittest {
    foreach ( T; TypeTuple!( float, double, real ) ) {
        foreach ( size; TypeTuple!(2,3,4,5,6,7,8) ) {
            Vector!(T, size) a;
            NormalizedVector!( T, size ) b;
            Point!(T, size) c;
            assert( !__traits( compiles, { Vector!(const T, size) a_c; } ) );
            assert( !__traits( compiles, { Vector!(immutable T, size) a_c; } ) );
            assert( !__traits( compiles, { NormalizedVector!(const T, size) a_c; } ) );
            assert( !__traits( compiles, { NormalizedVector!(immutable T, size) a_c; } ) );
            assert( !__traits( compiles, { Point!(const T, size) a_c; } ) );
            assert( !__traits( compiles, { Point!(immutable T, size) a_c; } ) );
        }
    }
}

void main( ) {
}