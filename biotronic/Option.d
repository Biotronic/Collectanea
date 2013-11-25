import std.traits;

struct None {}


//
// Possible point of specialization for the future - use null or NaN value
// to discern none-ness.
//
template hasNull( T ) {
    enum hasNull = __traits( compiles, (T t) => t is null );
}

///
/// An optional value.
///
struct Option( T ) if ( !hasNull!T ) {
	private bool none = true;
	private T payload;
	
	this( T t ) {
		payload = t;
		none = false;
	}
	
	this( None n ) {
		none = true;
	}
	
	ref Option opAssign( None n ) {
		none = true;
		return this;
	}
	
	ref Option opAssign( T t ) {
		payload = t;
		none = false;
		return this;
	}
    
    ref Option opAssign( Option other ) {
        none = other.none;
        if ( none ) {
            payload = other.payload;
        }
        return this;
    }
    
    /*
    @property const
    bool hasValue( ) {
        return !none;
    }
    
    ///
    /// Pattern matching. Requires that the programmer handle both the normal and the None case.
    ///
    @property
	auto match( alias fnNone, alias fnPayload )( )
    if (is( typeof( fnNone( None( ) ) ) ) && is( typeof( fnPayload( payload ) ) ) ) {
		if ( none ) {
			return fnNone( None( ) );
		} else {
			return fnPayload( payload );
		}
	}
	
    /// ditto
    @property
	auto match( alias fnPayload, alias fnNone )( )
    if (is( typeof( fnNone( None( ) ) ) ) && is( typeof( fnPayload( payload ) ) ) ) {
		if ( none ) {
			return fnNone( None( ) );
		} else {
			return fnPayload( payload );
		}
	}
    */
    
    // Helper template
    private template isPropertyImpl( T ) {
        static if ( /*isFunctionPointer!T || isDelegate!T ||*/ is(T == function) ) {
            enum isPropertyImpl = functionAttributes!T & FunctionAttribute.property;
        } else {
            enum isPropertyImpl = true;
        }
    }
    
    // Helper template
    private template isProperty( string name ) {
        enum isProperty = isPropertyImpl!(typeof(__traits( getMember, T, name )));
    }
    
    // Helper template
    private template PropertyType( string name ) {
        static if ( is( typeof( __traits( getMember, T, name ) ) == function ) ) {
            alias ReturnType!( __traits( getMember, T, name ) ) PropertyType;
        } else {
            alias typeof( __traits( getMember, T, name ) ) PropertyType;
        }
    }
    
    // Helper template
    private template hasVoidAssignResult( string name ) {
        alias PropertyType!name V;
        enum hasVoidAssignResult = is( typeof( __traits( getMember, T, name ) = V.init ) == void);
    }
    
    ///
    /// Accesses fields and properties of the wrapped type.
    /// The returned value will be an Option, or void in the case of setters returning void.
    /// 
    ///
    @property
    auto opDispatch( string name, U... )( U args )
    if ( isProperty!name && U.length < 2 ) {
        static if ( U.length == 0 ) {
            Option!( PropertyType!name ) result;
            if ( !none ) {
                mixin( "result = payload." ~ name ~ ";" );
                //result = __traits( getMember, payload, name );
            }
            return result;
        } else  {
            static if ( hasVoidAssignResult!name ) {
                if ( !none ) {
                    mixin( "payload." ~ name ~ " = args[0];" );
                    //__traits( getMember, payload, name ) = args[0];
                }
            } else {
                Option!( PropertyType!name ) result;
                if ( !none ) {
                    mixin( "result = payload." ~ name ~ " = args[0];" );
                    //result = __traits( getMember, payload, name ) = args[0];
                }
                return result;
            }
        }
    }
    
    ///
    /// Access member functions of the wrapped type.
    /// In the case of None, no function call will take place, and the return value
    /// will be Option!U, with U being the original return type.
    /// If the function returns void, void will be returned here too.
    ///
    auto opDispatch( string name, U... )( U args )
    if ( !isProperty!name ){
        alias typeof( mixin( "payload." ~ name ~ "( args )" ) ) ReturnType;
        static if ( is( ReturnType == void ) ) {
            if ( !none ) {
                mixin( "payload." ~ name ~ "( args );" );
                // __traits( getMember, payload, name )( args );
            }
        } else {
            Option!ReturnType result;
            if ( !none ) {
                mixin( "result = payload." ~ name ~ "( args );" );
                // result = __traits( getMember, payload, name )( args );
            }
            return result;
        }
    }
}

bool hasValue( T )( Option!T v ) {
    return !v.none;
}

@property
auto match( alias value, alias fnA, alias fnB )( ) {
    pragma( msg, typeof( fnA( value.payload ) ) );
    return 0;
}

version ( unittest ) {
    struct S {
        int n;
        
        @property
        float f( ) {
            return 0.0;
        }
        @property
        float f( float value ) const {
            return 0.0;
        }
        
        @property
        double d( ) {
            return 0.0;
        }
        
        @property
        void d( double value ) {
        }
        
        void foo( ) {
        }
        
        int bar( ) {
            return 3;
        }
    } unittest {
        Option!S s;
        
        assert( s.isProperty!"n" );
        assert( is( s.PropertyType!"n" == int ) );
        assert( !s.hasVoidAssignResult!"n" );
        assert( s.isProperty!"f" );
        assert( is( s.PropertyType!"f" == float ) );
        assert( !s.hasVoidAssignResult!"f" );
        assert( s.isProperty!"d" );
        assert( is( s.PropertyType!"d" == double ) );
        assert( s.hasVoidAssignResult!"d" );
        assert( !s.isProperty!"foo" );
        assert( !s.isProperty!"bar" );
        
        auto f = s.f;
        assert( is( typeof( f ) == Option!float ) );
        f = s.f = 4;
        
        s.d = 4;
        
        s.foo( );
        
        auto b = s.bar( );
        assert( is( typeof( b ) == Option!int ) );
    }
}

unittest {
    Option!int a;
    assert( !hasValue( a ) );
    a = 4;
    assert( hasValue( a ) );
    a = None( );
    assert( !hasValue( a ) );
    
    a = 4;
    
    int n = match!( a,
        (int x)  => x,
        (None n) => 0
    );
    
    assert( n == 4 );
    
    a = None( );
    n = match!( a,
        (int x)  => x,
        (None n) => 0
    );
    /*
    n = match!( a,
        (None n) => 0,
        (int x)  => x
    );*/
    
    assert( n == 0 );
}


struct Foo {
    @disable this( );
}

struct Bar {
    Foo f;
    this( int n ) {
    }
}

void main( ) {
    Bar b; // Error
}