module biotronic.xml;

struct SaxParser( R ) if ( isInputRange!R ) {
    struct Node {
        enum NodeType {
            Tag,
            Text,
            Attribute,
        }
    }
}