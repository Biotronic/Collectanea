module biotronic.staticparallelstuff;

import std.typetuple : TypeTuple;

// When to stop doing things in parallel.
enum parallelThreshold = 499;

// Non-parallel compile-time filter on typetuples. 
template staticFilter( alias F, T... ) {
    static if ( T.length > parallelThreshold ) {
        // It's too big! Chop it in half!
        alias TypeTuple!(
            staticFilter!( F, T[0..$/2] ),
            staticFilter!( F, T[$/2..$] ) ) staticFilter;
    } else static if ( T.length > 1 ) {
        // Just a bog-standard recursive filter.
        alias TypeTuple!(
            staticFilter!( F, T[0] ),
            staticFilter!( F, T[1..$] ) ) staticFilter;
    } else static if ( T.length == 1 && F!T ) {
        // We have a match.
        alias TypeTuple!( T[0] ) staticFilter;
    } else {
        // And nope.
        alias TypeTuple!( ) staticFilter;
    }
}

template Alias( T ) {
    alias T Alias;
}

template staticReduce( alias F, T0, T... ) {
    alias staticReduce!( F, Alias!T0, T ) staticReduce;
}

template staticReduce( alias F, alias T0, T... ) {
    static if ( T.length > parallelThreshold ) {
        alias F!(
            staticReduce!( F, T0, T[1..$/2] ),
            staticReduce!( F, T0, T[$/2..$] )
            ) staticReduce;
    } else static if ( T.length > 0 ) {
        alias F!( staticReduce!( F, T0, T[0..$-1] ), T[$-1] ) staticReduce;
    } else {
        alias T0 staticReduce;
    }
}

template staticMap( alias F, T... ) {    
    static if ( T.length > parallelThreshold ) {
        alias TypeTuple!(
            staticMap!( F, T[0..$/2] ),
            staticMap!( F, T[$/2..$] )
            ) staticMap;
    } else static if ( T.length > 1 ) {
        alias TypeTuple!( F!( T[0] ), staticMap!( F, T[1..$] ) ) staticMap;
    } else {
        alias TypeTuple!( ) staticMap;
    }
}

template staticIota( long start, long end, long step = 1 ) {
    static if ( start >= end ) {
        alias TypeTuple!( ) staticIota;
    } else static if ( (end - start) / step > parallelThreshold ) {
        alias TypeTuple!(
            staticIota!( start, start + ((( end - start ) / step / 2) * step), step ),
            staticIota!( start + ((( end - start ) / step / 2) * step), end, step )
            ) staticIota;
    } else {
        alias TypeTuple!( start, staticIota!( start + step, end, step ) ) staticIota;
    }
}

version ( unittest ) {
    template Add( alias a, alias b ) {
        enum Add = a + b;
    } unittest {
        assert( Add!( 1, 2 ) == 3 );
    }
    
    template Even( alias a ) {
        enum Even = (a & 1) == 0;
    } unittest {
        assert( Even!2 );
    }
    
    template True( T ){
        enum True = true;
    }
    template True( alias a ) {
        enum True = true;
    } unittest {
        assert( True!1 );
        assert( True!int  );
    }
}

unittest {
    //pragma( msg, staticReduce!( Add, staticIota!( 0, 10000 ) ) );
    assert( staticReduce!( Add, 1,2,3,4 ) == 10 );
    
    assert( staticReduce!( Add, staticFilter!( Even, 1,2,3,4 ) ) == 6 );
    
    //pragma( msg, staticMap!( Even, staticIota!( 0, 1000, 1 ) ) );
}