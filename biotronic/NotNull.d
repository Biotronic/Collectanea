/* This program is free software. It comes without any warranty, to
  * the extent permitted by applicable law. You can redistribute it
  * and/or modify it under the terms of the Do What The Fuck You Want
  * To Public License, Version 2, as published by Sam Hocevar. See
  * http://sam.zoy.org/wtfpl/COPYING for more details. */
  
module biotronic.notnull;

import std.conv : to;
import std.exception : enforce;
import std.traits : isPointer, pointerTarget;

version ( unittest ) {
    import std.exception : assertThrown, assertNotThrown;
    import core.exception : AssertError;

    class Base {
        int n;
        this( int n ) {
            this.n = n;
        }
        this( ) {}
    }
    
    class Derived : Base {
        this( ) {}
    }
    
    class Separate {}
}

/**
 * A pointer or reference that can never be null.
 * Does not allow implicit conversion from nullable to NotNull.
**/
struct NotNull( T ) if ( isNullable!T ) {
    private T payload;
    
    @disable this( );
    @disable this(T);
    static @property @disable NotNull init( );
    
    //// Bug 1528
    //this( U : T )( NotNull!U other ) {
    //    payload = other.payload;
    //}
    
    @property
    inout(T) get( ) inout {
        return payload;
    }
    
    NotNull opAssign(U)(NotNull!U value) {
        payload = value;
        return this;
    }
    
    U opCast(U)( ) if (is(T : U) || is(U : T)) {
        return to!U(payload);
    }
    
    alias get this;
} unittest {
    assert(!is(NotNull!(int)));
    assert( is(NotNull!(Base)));
    assert( is(NotNull!(int*)));
    assert(!is(NotNull!(int[])));
    assert(!__traits(compiles, {NotNull!int a;}));
    assert(!__traits(compiles, {NotNull!(int*) a;}));
    assert(!__traits(compiles, {NotNull!(int*) a = null;}));
    assert(!__traits(compiles, {NotNull!(int*) a = new int;}));
    assert(!__traits(compiles, {NotNull!(int*) a = NotNull!(int*).init;}));
    assert(!__traits(compiles, {NotNull!(int*) a = NotNull!(int*)(null);}));
    assert( __traits(compiles, {NotNull!(int*) a = void;}));
    assert( __traits(compiles, {NotNull!(int*) a = void; *a = 3;}));
    assert( __traits(compiles, {NotNull!(Base) a = void; a.n = 3;}));
    
    assert(!__traits(compiles, {NotNull!(Base)[] a; a.length = 3;}));
    //// Bug 1528
    //assert(  __traits( compiles, { NotNull!Base a = assumeNotNull( new Derived() ); } ) );
    //assert(  __traits( compiles, { Base a = assumeNotNull( new Derived() ); } ) );
    //assert( !__traits( compiles, { Derived b = assumeNotNull( new Base() ); } ) );
    //assert(  __traits( compiles, { Derived b = cast(Derived)assumeNotNull( new Base() ); } ) );
    //assert( !__traits( compiles, { Separate c = cast(Separate)assumeNotNull( new Base() ); } ) );
    
    Base a; a = assumeNotNull( new Derived() );
    
    assert( __traits(compiles, {NotNull!Base a = void; a = assumeNotNull(new Derived());}));
    assert( __traits(compiles, {Base a; a = assumeNotNull(new Derived());}));
    assert(!__traits(compiles, {Derived b; b = assumeNotNull(new Base());}));
    assert( __traits(compiles, {Derived b; b = cast(Derived)assumeNotNull(new Base());}));
    assert(!__traits(compiles, {Separate c; c = cast(Separate)assumeNotNull(new Base());}));
}

/**
 * Takes the value through the back door into NotNull land.
 * This function should have zero overhead in release mode.
**/
NotNull!T assumeNotNull(T)(T value) if (isNullable!T) {
    assert(value !is null);
    NotNull!T result = void;
    result.payload = value;
    return result;
} unittest {
    assert( __traits( compiles, {NotNull!(int*) a = assumeNotNull(new int);}));
    assert(!__traits( compiles, {NotNull!(int*) a = assumeNotNull(new string);}));
    assertThrown!AssertError(assumeNotNull!(int*)(null));
}

/**
 * Checks that the passed value is not null.
 * Throws an exception if it is.
**/
NotNull!T enforceNotNull(T)(T value) if (isNullable!T) {
    enforce(value !is null);
    NotNull!T result = void;
    result.payload = value;
    return result;
} unittest {
    assert( __traits( compiles, {NotNull!(int*) a = enforceNotNull(new int);}));
    assert(!__traits( compiles, {NotNull!(int*) a = enforceNotNull(new string);}));
    assertThrown(enforceNotNull!(int*)(null));
}

/**
 * Instantiates an object of the specified type and returns a non-nullable pointer to it.
**/
template newNotNull(T) if (isNullable!T) {
    auto newNotNull(U...)(U args) if (is(T == class) && __traits(compiles, {auto a = new T(args);})) {
        return assumeNotNull(new T(args));
    }
    auto newNotNull( )( ) if (!is(T == class)) {
        return assumeNotNull(new T);
    }
} unittest {
    assert( __traits(compiles, {NotNull!Base a = newNotNull!Base(3);}));
    //// Bug 1528
    //assert( __traits(compiles, {NotNull!Base a = newNotNull!Derived(3);}));
    assert( __traits(compiles, {newNotNull!(int*)( );}));
}

/**
 * Checks if a type is nullable. Left out arrays because null arrays
 * actually do make a twisted sort of sense.
**/
template isNullable(T) {
    static if (is(T U : U*)) {
        enum isNullable = true;
    } else  {
        enum isNullable = is(T == class);
    }
} unittest {
    class A {}
    assert(isNullable!A);
    assert(isNullable!(int*));
    assert(!isNullable!(int[]));
    assert(!isNullable!int);
}