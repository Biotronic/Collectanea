module biotronic.taggedunion;

import std.typetuple : staticIndexOf, staticMap, allSatisfy;
import std.traits : EnumMembers;
import biotronic.utils;

version (unittest) {
    import std.typecons : Tuple;
}

struct Else {
    @disable this();
}

alias Maybe(T) = TaggedUnion!(typeof(null), T);

version (DDOC) {
    struct TaggedUnion(T...) if (T.length > 1 && allSatisfy!(isType, T) && hasNoDuplicates!T);
}

template TaggedUnion(T...) if (T.length > 1 && allSatisfy!(isType, T) && !isSorted!T && hasNoDuplicates!T) {
    alias TaggedUnion!(StaticSort!(sortPred, T)) TaggedUnion;
}

struct TaggedUnion(T...) if (T.length > 1 && allSatisfy!(isType, T) && isSorted!T && hasNoDuplicates!T) {
public:
    alias T Types;
    
    @disable this();
    this(U)(U value) if (__traits(compiles, opAssign(value))) {
        opAssign(value);
    }
    unittest {
        assert(!__traits(compiles, {TaggedUnion a;}));
        foreach (Type; Types) {
            assert( __traits(compiles, (Type t){TaggedUnion a = t;}));
        }
    }
    
    mixin(makeOpAssigns!0);
    unittest {
        assert(!__traits(compiles, {
                TaggedUnion a = Types[0].init;
                a = Tuple!(Types).init;
                }));
        foreach (Type; Types) {
            assert( __traits(compiles, (Type t){
                TaggedUnion a = t;
                a = t;
                }));
        }
    }
    
    @property const
    bool isType(Type, string file = __FILE__, int line = __LINE__)( ) const {
        enum typeIdx = staticIndexOf!(Type, Types);
        staticEnforce!(typeIdx != -1, TaggedUnion.stringof ~ " can never have a value of type " ~ Type.stringof, file, line)();
        return typeIdx == whichType;
    } unittest {
        foreach (i, Type; Types) {
            ubyte[(Type[1]).sizeof] buf;
            TaggedUnion tu = *cast(Type*)(buf.ptr);
            assert( tu.isType!Type);
            assert(!tu.isType!(Types[(i+1)%Types.length]));
        }
    }
    
    @property
    inout(Type) as(Type, string file = __FILE__, int line = __LINE__)() inout {
        assert( isType!(Type, file, line));
        return values[staticIndexOf!(Type, Types)];
    }
    
    string toString() const {
        import std.conv : to;
        return this.match!(
            a => to!string(a)
            );
    }
    
    mixin(makeOpEquals!0);
private:
    alias TypeEnum!Types WhichType;
    WhichType whichType;
    union {
        Types values = void;
    }
    
    /*
     *  These should have been template mixins for more readable code, but mixins inside mixins are overridden by outer mixins.
     *  ...Perhaps more understandable:
     *    void foo(int){}
     *    void foo(string){}
     *  form an overload set. If these were created by two separate mixins, the last mixined one takes precedence, and the others are hidden. This is bad.
     */
    template makeOpEquals(int n) {
        static if (n < Types.length) {
            static if (isComparable!(const(Types[n]), Types[n])) { // Bug #11226, possibly others.
				enum makeOpEquals = "bool opEquals()(auto ref const Types[" ~ n.stringof ~ "] value) const {
						if (whichType != WhichType._" ~ n.stringof ~ ") {
							return false;
						}
						return values[" ~ n.stringof ~ "] == value;
					}" ~ makeOpEquals!(n+1);
			} else static if (is(Unqual!(Types[n]) == typeof(null))) { // Bug #11226
				enum makeOpEquals = "bool opEquals(T)(T value) const if (is(Unqual!T == typeof(null))) {
					return whichType == WhichType._" ~ n.stringof ~ ";
				}" ~ makeOpEquals!(n+1);
            } else {
				enum makeOpEquals = "bool opEquals(string file = __FILE__, int line = __LINE__)(auto ref const Types[" ~ n.stringof ~ "] value) const {
						staticEnforce!(false, \"Cannot compare " ~ typeof(this).stringof ~ " with type " ~ Types[n].stringof ~ "\", file, line);
					}" ~ makeOpEquals!(n+1);
            }
        } else {
            enum makeOpEquals = "bool opEquals()(auto ref const TaggedUnion other) const {
				if (whichType != other.whichType) {
					return false;
				} else {
					switch (whichType) {
						foreach (i, e; EnumMembers!WhichType) {
							case e:
								return values[i] == other.values[i];
						}
						default:
							assert(false);
					}
				}
			}

            bool opEquals(U...)(auto ref const TaggedUnion!U other) const if (TypeSet!T.strictSuperSetOf!U) {
                return other.match!(
                        a => this == a
                    );
            }
            ";
        }
    }
    
    template makeOpAssigns(int n) {
        static if (n < Types.length) {
            enum makeOpAssigns = "ref TaggedUnion opAssign(Types[" ~ n.stringof ~ "] value) {
                    whichType = WhichType._" ~ n.stringof ~ ";
                    values[" ~ n.stringof ~ "] = value;
                    return this;
                }\n" ~ makeOpAssigns!(n+1);
        } else {
            enum makeOpAssigns = "ref TaggedUnion opAssign(U...)(TaggedUnion!U other) if (TypeSet!T.superSetOf!U) {
                    switch (other.whichType) {
                        foreach (i, e; EnumMembers!(other.WhichType)) {
                            case e:
                                this = other.as!(U[i]);
                                return this;
                        }
                        default:
                            assert(false);
                    }
                }\n";
        }
    }
}

template isComparable(T, U) {
    enum isComparable = __traits(compiles, (T a, U b) => a == b);
} unittest {
    assert( isComparable!(int, int));
    assert(!isComparable!(typeof(null), const(typeof(null))));
}

template isTaggedUnion(T) {
    enum isTaggedUnion = is(T == TaggedUnion!U, U...);
} unittest {
    assert(!isTaggedUnion!float);
    assert( isTaggedUnion!(TaggedUnion!(float, string)));
}

template match(Handlers...) {
    template findHandler(T, int n = 0) {
        static if (n >= Handlers.length) {
            enum findHandler = -1;
        } else static if (__traits(compiles, Handlers[n](T.init))) {
            enum findHandler = n;
        } else {
            enum findHandler = findHandler!(T, n+1);
        }
    }
    
    @property
    auto match(TU, string file = __FILE__, int line = __LINE__)(TU value) if (isTaggedUnion!TU) {
        
        enum elseClause = findHandler!Else;
        static if (elseClause != -1) {
            alias elseHandler = Handlers[elseClause];
        }
        
        final switch (value.whichType) {
            foreach (i, e; EnumMembers!(TU.WhichType)) {
                case e: {
                    alias Type = TU.Types[i];
                    enum handlerIdx = findHandler!Type;
                    
                    static if (handlerIdx != -1) {
                        return Handlers[handlerIdx](value.values[i]);
                    } else {
                        staticEnforce!(is(typeof(elseHandler)), TU.stringof ~ ": no match in pattern for type " ~ Type.stringof, file, line)();
                        return elseHandler(Else.init);
                    }
                }
            }
        }
        assert(false);
    }
}