module biotronic.stack;

import std.exception;

struct Stack( T ) {
    private T[] store;
    private size_t firstIndex;
    
    pure:
    
    @safe nothrow
    invariant( ) {
        if ( store.length ) {
            assert( firstIndex <= store.length );
        } else {
            assert( firstIndex == 0 );
        }
    }
    
    @safe nothrow
    this( T[] arr ) {
        store = arr;
        realloc( arr.length );
        firstIndex = store.length - arr.length;
    } unittest {
        Stack s = [T.init, T.init];
        assert( s.length == 2 );
    }
    
    @safe nothrow
    this( const size_t size )
    out {
        assert( size == length );
    } body {
        realloc( size );
        firstIndex = store.length - size;
    } unittest {
        Stack s = Stack( 3 );
        assert( s.length == 3 );
    }
    
    @safe nothrow
    this( this ) {
        auto tmp = store;
        store = new T[tmp.length];
        store[] = tmp;
    } unittest {
        Stack s = [T.init];
        Stack s2 = s;
        assert( s == s2 );
        assert( s[] !is s2[] );
    }
    
    @safe nothrow
    private void realloc( size_t size ) {
        size--;
        size |= size >> 1;
        size |= size >> 2;
        size |= size >> 4;
        size |= size >> 8;
        size |= size >> 16;
        static if ( size_t.sizeof == 8 ) {
            size |= size >> 32;
        }
        size++;
        
        if ( size > store.length ) {
            auto tmp = store;
            store = new T[size];
            store[$-tmp.length..$] = tmp;
            firstIndex += store.length - tmp.length;
        }
    } unittest {
        Stack s = [T.init, T.init];
        assert( s.store.length == 2 );
        s.push( T.init );
        assert( s.store.length == 4 );
    }
    
    @safe nothrow
    @property
    size_t length( ) const {
        return store.length - firstIndex;
    } unittest {
        Stack s;
        assert( s.length == 0 );
        s.push( T.init );
        assert( s.length == 1 );
    }
    
    alias opDollar = length;
    
    @safe nothrow
    @property
    bool empty( ) const {
        return store.length == 0 || firstIndex >= store.length;
    } unittest {
        Stack s;
        assert( s.empty );
        s.push( T.init );
        assert( !s.empty );
    }
    
    @property
    ref inout(T) top( ) inout {
        enforce( !empty );
        return store[firstIndex];
    } unittest {
        Stack s;
        s.push( T.init );
        assert( s.top is T.init );
        s.pop( );
        assertThrown( s.bottom );
    }
    
    @property
    ref inout(T) bottom( ) inout {
        enforce( !empty );
        return store[$-1];
    } unittest {
        Stack s;
        s.push( T.init );
        assert( s.bottom is T.init );
        s.pop( );
        assertThrown( s.bottom );
    }
    
    void pop( ) {
        enforce( !empty );
        store[firstIndex] = T.init;
        firstIndex++;
    } unittest {
        Stack s;
        s.push( T.init );
        assert( s.length == 1 );
        s.pop( );
        assert( s.length == 0 );
        assertThrown( s.pop( ) );
    }
    
    @safe nothrow
    void push( T value ) {
        firstIndex--;
        realloc( store.length - firstIndex );
        store[firstIndex] = value;
    } unittest {
        Stack s;
        assert( s.length == 0 );
        s.push( T.init );
        assert( s.length == 1 );
    }
    
    @safe nothrow
    void clear( ) {
        store = [];
        firstIndex = 0;
    } unittest {
        Stack s;
        s.push( T.init );
        s.clear( );
        assert( s.empty );
    }
    
    @safe nothrow
    inout(T)[] opSlice( ) inout
    out ( result ) {
        assert( result.length == length );
    } body {
        return store[firstIndex..$];
    } unittest {
        Stack s;
        s.push( T.init );
        assert( s[] == [T.init] );
        s.pop;
        assert( s[] == [] );
    }
    
    @safe
    inout(T)[] opSlice( const size_t begin, const size_t end ) inout
    out ( result ) {
        assert( result.length == end - begin );
    } body {
        enforce( begin <= end );
        enforce( end <= length );
        return store[firstIndex + begin..firstIndex + end];
    } unittest {
        Stack s;
        s.push( T.init );
        assert( s[0..$] == [T.init] );
        assert( s[0..0] == [] );
        assert( s[1..1] == [] );
        assert( s[$..$] == [] );
        assertThrown( s[0..$+1] );
        assertThrown( s[1..0] );
    }
    
    ref Stack opAssign( Stack other ) {
        store = other.store.dup;
        firstIndex = other.firstIndex;
        return this;
    } unittest {
        Stack s1 = [T.init, T.init, T.init];
        Stack s2;
        s2 = s1;
        assert( s1 == s2 );
        assert( s1.store !is s2.store );
    }
    
    ref Stack opAssign( T[] arr ) {
        this = Stack( arr );
        return this;
    } unittest {
        Stack s;
        assert( s.empty );
        s = [T.init, T.init];
        assert( !s.empty );
        assert( s[] == [T.init, T.init] );
    }
    
    ref Stack opOpAssign( string op : "~" )( T[] arr ) {
        auto tmp = store;
        realloc( store.length + arr.length );
        auto tmpIndex = firstIndex;
        firstIndex -= arr.length;
        store[firstIndex..tmpIndex] = arr[];
        return this;
    } unittest {
        Stack s = [T.init];
        assert( s.length == 1 );
        s ~= [T.init];
        assert( s.length == 2 );
    }
    
    @safe nothrow
    bool opEquals( ref const Stack other ) const {
        return this[] == other[];
    } unittest {
        Stack s1 = [T.init];
        Stack s2 = [T.init];
        assert( s1 == s2 );
    }
}

unittest {
    Stack!int si;
    Stack!string ss;
    
    struct S {
        @disable this();
    }
    
    Stack!S sS;
    
    class C {
    }
    
    Stack!C sc;
}

void main( ) {
}