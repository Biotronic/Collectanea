module biotronic.rope;

import std.traits : isSomeChar;

struct Rope( CharType ) if ( isSomeChar!CharType ) {
    immutable struct Node {
        size_t weight;
        Node* left, right;
        immutable(CharType)[] value;
    }
    
    Node root;
    
    private static CharType _opIndex( const(Node) node, size_t i ) {
        if ( node.weight < i ) {
            return _opIndex( *node.right, i - node.weight );
        } else if ( node.left ) {
            return _opIndex( *node.left, i );
        } else {
            return node.value[i];
        }
    }
    
    CharType opIndex( size_t i ) const {
        return _opIndex( root, i );
    }
    
    Rope opBinary( string op : "~" )( Rope other ) const {
        
    }
    
    Rope opSlice( ) const {
        return this;
    }
    
    Rope opSlice( size_t start, size_t end ) const {
        return splitEnd( start ).splitEnd( end - start );
    }
    
    
}

void main( ) {
    Rope!dchar a;
}