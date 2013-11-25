import std.stdio : writeln;
import std.math;
import std.traits;

template isBasis( T ) {
    static if ( is( T t == Basis!(_origin, _unitsPerRotation), double _origin, double _unitsPerRotation ) ) {
        enum isBasis = true;
    } else {
        enum isBasis = false;
    }
}

struct Direction( basis ) if ( isBasis!basis ) {
    double offset;
    
    Direction opBinary( string op : "+", otherBasis )( Rotation!otherBasis rot ) const {
        static if ( is( otherBasis == basis ) ) {
            return Direction( value + rot.value );
        } else {
            return this + Rotation!basis( rot );
        }
    }
    
    Direction opBinary( string op : "-", otherBasis )( Rotation!otherBasis rot ) const {
        static if ( is( otherBasis == basis ) ) {
            return Direction( value - rot.value );
        } else {
            return this - Rotation!basis( rot );
        }
    }
}

struct Rotation( basis ) if ( isBasis!basis ) {
    double value;
    
    enum Rotation Zero = Rotation( 0.0 );
    enum Rotation One  = Rotation( basis.FullRotationValue );
    enum Rotation NaR  = Rotation( double.nan );
    
    this( T = void )( double other ) {
        value = other;
    }
    
    this( otherBasis )( Rotation!otherBasis other ) {
        value = other.value / otherBasis.FullRotation.value * basis.FullRotation.value;
    }
    
    Rotation opUnary( string op : "+" )( ) const {
        return this;
    }
    
    Rotation opUnary( string op : "-" )( ) const {
        return Rotation( -value );
    }
    
    double opBinary( string op : "/", otherBasis )( Rotation!otherBasis other ) const {
        static if ( is( otherBasis == basis ) ) {
            return value / other.value;
        } else {
            return this / Rotation( other );
        }
    }
    
    double opBinary( string op : "+", otherBasis )( Rotation!otherBasis other ) const {
        static if ( is( otherBasis == basis ) ) {
            return Rotation( value + other.value );
        } else {
            return this + Rotation( other );
        }
    } 
    
    double opBinary( string op : "-", otherBasis )( Rotation!otherBasis other ) const {
        static if ( is( otherBasis == basis ) ) {
            return Rotation( value - other.value );
        } else {
            return this - Rotation( other );
        }
    } 
    
    Rotation opBinary( string op : "/" )( double other ) const {
        return Rotation( value / other );
    }
    
    Rotation opBinary( string op : "*" )( double other ) const {
        return Rotation( value * other );
    }
    
    bool opEquals( otherBasis )( Rotation!otherBasis other ) const {
        static if ( is( otherBasis == basis ) ) {
            return value == other.value;
        } else {
            return this == Rotation( other );
        }
    }
    
    double opCmp( otherBasis )( Rotation!otherBasis other ) const {
        static if ( is( otherBasis == basis ) ) {
            return value - other.value;
        } else {
            return this.opCmp( Rotation( other ) );
        }
    }
}

struct Basis( double _origin, double _unitsPerRotation ) {
    alias Rotation!Basis RotationType;
    alias Direction!Basis DirectionType;
    
    enum FullRotation = RotationType( _unitsPerRotation );
    private enum FullRotationValue = _unitsPerRotation;
    enum Origin = DirectionType( 0 );
}

unittest {
    alias Basis!(0, 360) DegreeBasis;
    alias Basis!(PI/2, PI * 2) RadianBasis;
    
    alias Rotation!DegreeBasis DegreeRotation;
    alias Rotation!RadianBasis RadianRotation;
    
    alias Direction!DegreeBasis DegreeDirection;
    alias Direction!RadianBasis RadianDirection;
    
    auto a = DegreeRotation( 180 );
    auto b = RadianRotation( PI );
    
    assert( a == RadianBasis.FullRotation / 2 );
    assert( b == DegreeBasis.FullRotation / 2 );
    
    auto c = Rotation!RadianBasis( PI / 2 );
    
    assert( c < b );
    assert( c < a );
    assert( a <= b );
}

void main( ) {
}