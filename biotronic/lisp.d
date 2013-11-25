module biotronic.lisp;

import biotronic.taggedunion;
import std.bigint;
import std.conv : to;


alias LispType = TaggedUnion!(BigInt, string, real, Cons, Symbol*, LispFunc*);
alias LispFunction = LispType function(LispType);

struct LispFunc {
    LispFunction fn;
}

private struct ConsImpl {
private:
	LispType car, cdr;
    this(T, U)(T _car, U _cdr) {
        car = _car;
        cdr = _cdr;
    }
	
	bool opEquals()(auto ref const ConsImpl other) const {
		return (car == other.car) && (cdr == other.cdr);
	}
}

bool cmpImpls(const ConsImpl* a, const ConsImpl* b) {
	return *a == *b;
}

struct Cons {
	ConsImpl* impl;
    
    this(T, U)(T _car, U _cdr) if (__traits(compiles, {impl.car = _car; impl.cdr = _cdr;})) {
		impl = new ConsImpl(_car, _cdr);
    }
	
	bool opEquals()(auto ref const Cons other) const {
		return cmpImpls(impl, other.impl);
	}
	
	string toString() {
		return "(" ~ impl.car.to!string ~ " . " ~ impl.cdr.to!string ~ ")";
	}
}

struct Symbol {
    immutable string  name;
    LispType value;
    Cons propertyList;
}

final abstract class SpecialSymbols {
	static:
    Symbol* nil() {
        static Symbol* _nil = null;
        if (!_nil) {
            _nil = new Symbol("nil", LispType(0.0), Cons("", ""));
            _nil.propertyList = Cons(_nil, _nil);
            _nil.value = _nil;
        }
        return _nil;
    }
}

LispType parse(string s) {
    import std.array : front, popFront;
	if (s.front == '(') {
		
	}
    return LispType(Cons("a", "b"));
}

unittest {
    assert(parse("(a . b)") == Cons("a", "b"));
    assert(parse("(a . c)") == Cons("a", "c"));
}

void main() {
}