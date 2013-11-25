module maybe;

import std.exception;
import std.traits;

struct Nothing {}

Nothing nothing;

struct Maybe( T ) if ( !is( T.MaybeImpl ) ) {
	struct MaybeImpl {
		alias T PayloadType;
		T payload;
		bool none = true;
	}
	private MaybeImpl Maybe;
	
	this( Nothing value ) {
		Maybe.none = true;
	}
	
	this( T value ) {
		Maybe.payload = value;
		static if ( __traits( compiles, { value == null; } ) ) {
			Maybe.none = value == null;
		} else {
			Maybe.none = false;
		}
	}
	
	static if ( !is( Sure!T == T ) ) {
		this( Sure!T value ) {
			Maybe.none = false;
			Maybe.payload = value;
		}
	}
	
	typeof( this ) opAssign( Sure!T value ) {
		Maybe.none = false;
		Maybe.payload = value;
		return this;
	}
	
	typeof( this ) opAssign( T value ) {
		Maybe.none = false;
		Maybe.payload = value;
		return this;
	}
	
	U opCast( U )( ) if ( is( U == Sure!T ) ) {
		assert( !Maybe.none, typeof( this ).stringof ~ " is of type Nothing, not " ~ U.stringof );
		return Maybe.payload;
	}
	
	Nothing opCast( U : Nothing )( ) {
		assert( Maybe.none, typeof( this ).stringof ~ " is of type " ~ T.stringof ~ ", not Nothing" );
		return nothing;
	}
}

template Maybe( T ) if ( is( T.MaybeImpl ) ) {
	alias T Maybe;
}

struct Sure( T ) if ( hasIndirections!T && !is( T.MaybeImpl ) && !is( T.Sure ) ) {
	alias T Sure;
	T _payload;
	alias _payload this;
	
	this( Maybe!T value )
	in {
		assert( !value.Maybe.none, "Attempted to initialize " ~ typeof( this ).stringof ~ " with Nothing." );
	} body {
		this( value.Maybe.payload );
	}
	
	this( T value )
	in {
		assert( value !is null, "Attempted to initialize " ~ typeof( this ).stringof ~ " with null." );
	} body {
		_payload = value;
	}
}

template Sure( T ) if ( hasIndirections!T && is( T.Sure ) ) {
	alias T Sure;
}

template Sure( T ) if ( hasIndirections!T && is( T.MaybeImpl ) ) {
	alias Sure!( T.MaybeImpl.PayloadType ) Sure;
}

template Sure( T ) if ( !hasIndirections!T ) {
	alias T Sure;
}

auto sure( T )( T value ) {
	Sure!T tmp = value;
	return tmp;
}

class C {}

void main( ) {
	Maybe!int n = 4;
	auto a = cast(Sure!int)n * 2;
	Maybe!int m;
	auto b = cast(Nothing)m;
	Maybe!C c = new C( );
	auto d = sure( c );
	Maybe!C e;
	assert( !__traits( compiles, { e == null; } ) );
	assert( !__traits( compiles, { e == new C( ); } ) );
}