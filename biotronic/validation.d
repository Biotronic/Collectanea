module biotronic.validation;

import std.conv : to;
import biotronic.utils;

version (unittest) {
    import std.exception : assertThrown, assertNotThrown;
}

version (D_Ddoc) {
/**
Encapsulates a validated value, the validation of which is enforced through $(LREF validate). $(BR)
The unadorned value is available through $(LREF value), and through alias this. $(BR)
The constraints can either throw on their own, or return a bool value of true if the constraint passed, false if it didn't. $(BR)

Example:
----
bool isPositive(int value) {
    return value >= 0;
}

void checkLessThan42(int value) {
    enforce(value < 42);
}

void foo(Validated!(int, isPositive) value) {
}

foo(13); // Refuses to compile.

Validated!(int, isPositive, checkLessThan42) x = validate!(isPositive, checkLessThan42)(14); // Would throw on invalid input
foo(x); // It works!
----

A validated value A whose constraints are a superset of those of another validated type B may be implicitly converted. The opposite is not possible.

Example:
----
alias A = Validated!(int, isPositive, checkLessThan42);
alias B = Validated!(int, isPostive);

A a = 13;
B b = a;

a = b; // Error
----

If the wrapped type is convertible, and the constraints match, a type conversion is performed.

Example:
----
Validated!(int, isPositive) a = validate!isPositive(4);

Validated!(long, isPositive) b = a;
----

**/
    struct Validated(T, Constraints) if (Constraints.length > 0 && hasNoDuplicates!Constraints) {
        /// The wrapped value.
        @property public T value() { return T.init; }
    }
}

template Validated(T, _Constraints...) if (_Constraints.length > 0 && !isSorted!_Constraints && hasNoDuplicates!_Constraints) {
    alias Validated!(T, StaticSort!(sortPred, _Constraints)) Validated;
}

struct Validated(T, _Constraints...) if (_Constraints.length > 0 && isSorted!_Constraints && hasNoDuplicates!_Constraints) {
    alias _Constraints constraints;
    
    private T _value;
    @property inout
    public inout(T) value() {
        return _value;
    }
    alias value this;
    
    @disable this();
    
    debug {
        this(int line = __LINE__, string file = __FILE__)(T other) {
            alias create = validate!constraints;
            this = create!(T, line, file)(other);
        }
    } else {
        this(T other) {
            this = validate!constraints(other);
        }
    }
    
    this(U)(U other) if (isValidated!U && TypeSet!(U.constraints).superSetOf!(constraints) ) {
        _value = other._value;
    }
    
    typeof(this) opAssign(U)(U other) if (isValidated!U && TypeSet!(U.constraints).superSetOf!(constraints) && is(typeof(_value = other._value))) {
        _value = other._value;
        return this;
    }
    
    inout(U) opCast(U)() inout if (isValidated!U && TypeSet!(constraints).superSetOf!(U.constraints) && is(typeof(other._value = cast(typeof(other._value))_value))) {
        U result = void;
        result._value = cast(typeof(other._value))_value;
        return result;
    }
    
    inout(U) opCast(U)() inout if (is(T : U)) {
        return value;
    }
}

template isValidated(T...) if (T.length == 1) {
    static if (is(typeof(T))) {
        enum isValidated = isValidated!(typeof(T));
    } else {
        enum isValidated = is(T[0] == Validated!U, U...);
    }
} unittest {
    assert(isValidated!(Validated!(int, isPositive)));
    assert(isValidated!(validate!(isPositive)(4)));
    assert(!isValidated!string);
    assert(!isValidated!"foo");
}

/**
validate checks that the value passes all constraints, and returns a $(LREF Validated).

Example:
----
void foo(Validated!(int, isPositive) value) {
}

auto a = validate!isPositive(4);
foo(a);
----

Multiple constraints may be passed to validate.

Example:
----
auto b = validate!(isPositive, checkLessThan42)(54); // Will throw at runtime.
----
**/
template validate(Constraints...) if (Constraints.length > 0) {
    auto validateImpl(string loc, T)(T value) {
        import std.exception : enforce;
        import std.typetuple : TypeTuple;
        
        static if (isValidated!T) {
            alias actualConstraints = TypeSet!Constraints.complement!(T.constraints);
        } else {
            alias actualConstraints = Constraints;
        }
        
        foreach (fn; actualConstraints) {
            staticEnforce!(is(typeof(fn(value))), loc ~ "Invalid constraint " ~ TypeTuple!(fn).stringof[6..$-1] ~ " for value of type " ~ T.stringof);
            static if (is(typeof({if (fn(value)){}}))) {
                enforce(fn(value), loc ~ "Validation failed for value (" ~ value.to!string ~ "). Constraint: " ~ TypeTuple!(fn).stringof[6..$-1]);
            }
            fn(value);
        }
        
        static if (isValidated!T) {
            Validated!(typeof(T._value), NoDuplicates!(Constraints, T.constraints)) result = void;
        } else {
            Validated!(T, Constraints) result = void;
        }
        result._value = value;
        return result;
    }
    debug {
        auto validate(T, int line = __LINE__, string file = __FILE__)(T value) {
            return validateImpl!(file ~ "(" ~ line.to!string ~ "): ")(value);
        }
    } else {
        auto validate(T)(T value) {
            return validateImpl!""(value);
        }
    }
} unittest {
    assertNotThrown(validate!(isPositive)(3));
    assertThrown(validate!(isPositive)(-4));
}

/**
assumeValidated does not run any checks on the passed value, and assumes that the programmer has done so himself. This is useful when checks may be prohibitively expensive or in inner loops where maximum speed is required.

Example:
----
auto a = assumeValidated!isPositive(-4);
----
**/
template assumeValidated(Constraints...) if (Constraints.length > 0) {
    auto assumeValidated(T)(T value) {
        version (alwaysValidate) {
            return validate!Constraints(value);
        } else {
            Validated!(T, Constraints) result = void;
            result._value = value;
            return result;
        }
    }
} unittest {
    assertNotThrown(assumeValidated!isPositive(-2));
}

version (unittest) {
    import std.exception : enforce;
    bool isPositive(int value) {
        return value >= 0;
    }
    void checkLessThan42(int value) {
        enforce(value < 42);
    }
    void checkString(string value) {
    }
    bool notNull(int* p) {
        return p !is null;
    }
}

unittest {
    void test1(int a) {}
    void test2(Validated!(int, isPositive)) {}
    void test3(Validated!(int, isPositive, checkLessThan42)) {}
    
    Validated!(int, isPositive, checkLessThan42) a = void;
    Validated!(int, isPositive) b = void;
    Validated!(long, isPositive) r = a;
    
    // Bug 11601
    pragma(msg, "Please ignore this warning:");
    assert(!__traits(compiles, {Validated!(int, checkString) s = validate!checkString(3);}));
    
    a = validate!(checkLessThan42, isPositive)(3);
    b = a;
    a = validate!(checkLessThan42)(b);
    
    test1(b);
    test1(a);
    test3(a);
    assert(!__traits(compiles, test2(3)));
    assert(!__traits(compiles, test3(b)));
    
    
    Validated!(int*, notNull) n = validate!notNull(new int);
}

void main() {
}