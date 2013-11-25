/**
 * Type-based, i.e. statically checked, _units of measurement.
 *
 * A $(I quantity) is a wrapper struct around an arbitrary value type,
 * parametrized with a certain unit. A $(I unit) is basically little more than
 * a marker type to keep different kinds of quantities apart, but might
 * additionally have an associated name and symbol string, and – more
 * more importantly – define $(I conversions) to other _units. While all
 * of the possible conversions must be defined statically for type-checking,
 * arbitrary callables are supported for actually converting the values, which
 * do not necessarily need to be evauatable at compile time.
 *
 * Conversions only happen if explicitly requested and there is no different
 * internal representation of values – for example $(D 1 * kilo(metre)) is
 * stored just as 1 in memory, not as 1000 or relative to any other »canonical
 * unit«.
 *
 * On top of the template core of the module, to which units are types only,
 * a layer making use of »dummy« unit instances with operators defined on them
 * makes it possible to work with quantities and units in a natural way, such
 * that the actual unit types never need to be user directly in client code
 * (see the example below).
 *
 * In the design of this module, the explicit concept of $(I dimensions) does
 * not appear, because it would add a fair amount of complication to both the
 * interface and the implementation for little benefit. Rather, the notion is
 * established implicitly by defining conversions between pairs of _units – to
 * see if two _units share the same dimension, just check for convertibility.
 *
 * The $(D std.si) module defines SI prefixes and _units for use with this
 * module.
 *
 * Example:
 * ---
 * enum foo = baseUnit!("foo", "f");
 * enum bar = scale!(foo, 21, "bar", "b");
 *
 * auto a = 2 * bar;
 * assert(convert!foo(a) == 42 * foo);
 * ---
 *
 * Todo:$(UL
 *  $(LI Integration with the rest of Phobos ($(D std.datetime), $(D std.math), …))
 *  $(LI Replace the proof-of-concept unit conversion implementation with an
 *   optimized one – currently some unneeded function calls are generated.)
 *  $(LI For $(D scale)/$(D ScaledUnit), use runtime rational/two longs
 *   instead of double conversion per default, to avoid precision issues?)
 *  $(LI Benchmark quantity operations vs. plain value type operations.)
 *  $(LI Make quantities of the same unit implicitly convertible if the value
 *   types are – e.g. via $(D ImplicitConversionTargets) once multiple
 *   alias this statements are allowed.)
 *  $(LI Are multiple conversion targets for a unit really needed? Disallowing
 *   that would remove some odd corner cases.)
 *  $(LI Just forward $(LREF Quantity) instanciations with unit
 *   $(LREF dimensionless) to the value type altogether to avoid the current
 *   limitations regarding $(D alias this)?)
 * )
 *
 * License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors: $(WEB klickverbot.at, David Nadlinger)
 */
module biotronic.units;

@trusted:

/*
 * General implementation notes:
 *
 * In the unit tests, enums and static asserts are used quite frequently to
 * make sure all of the simple functionality is usable at compile time. In
 * real code, of course, most of the time stuff would be executed at runtime.
 */

import std.conv : to;
import std.functional : compose;
import std.traits : isAssignable, mangledName, Unqual, isFloatingPoint;

// @@BUG@@: Only importing TypeTuple, allSatisfy and staticMap leads to a
// compilation error (Error: undefined identifier module units.std) in
// UnitImpl.
import std.typetuple;

/**
 * Mixin template containing the implementation of the unit instance operators.
 *
 * Furthermore, it marks the surrounding type as unit – every unit type has to
 * mixin this template.
 *
 * In addition, a unit type might also define a toString() function returning
 * a custom unit symbol/name, and a list of $(LREF Conversion)s. The example
 * shows how a unit type for inches might be defined if $(LREF scale) and
 * $(LREF ScaledUnit) did not exist (which remove the need to write
 * boilerplate code like this).
 *
 * Example:
 * ---
 * struct Inch {
 *     mixin UnitImpl;
 *
 *     static string toString(UnitString type = UnitString.name) {
 *         final switch (type) {
 *             case UnitString.name: return "inch";
 *             case UnitString.symbol: return "in";
 *         }
 *     }
 *
 *     alias TypeTuple!(
 *         Conversion!(centi(metre), toCm, fromCm)
 *     ) Conversions;
 *
 *     static V toCm(V)(V v) {
 *         return cast(V)(v * 2.54);
 *     }
 *     static V fromCm(V)(V v) {
 *         return cast(V)(v / 2.54);
 *     }
 * }
 * enum inch = Inch.init; // Unit instance to use with abbreviated syntax.
 * ---
 *
 * Note: Two existing units $(D a) and $(D c) can't be retroactively extended
 * with a direct conversion between them. This is by design, as it would break
 * D's modularization/encapsulation approach (alternative: use mixin template
 * for defining conversion functions, then it would be possible to have
 * different behavior of the conversion function in each module). However,
 * currently it $(I is) possible to create a third unit $(D b) which is
 * convertible to both $(D a) and $(D c), and then perform the conversion in
 * two steps: $(D convert!c(convert!b(1 * a))))
 */
mixin template UnitImpl() {
    /**
     * Multiplication/division of two unit instances, yielding a unit instance
     * representing the product/quotient unit.
     *
     * Example:
     * ---
     * enum joule = newton * metre;
     * enum watt = joule / second;
     * ---
     */
    auto opBinary(string op : "*", Rhs)(Rhs rhs) const if (isUnit!Rhs) {
        return ProductUnit!(typeof(this), Rhs).Result.init;
    }

    /// ditto
    auto opBinary(string op : "/", Rhs)(Rhs rhs) const if (isUnit!Rhs) {
        return QuotientUnit!(typeof(this), Rhs).Result.init;
    }

    /**
     * Multiplication/division of an unit and a value type, constructing a
     * Quantity instance.
     *
     * Example:
     * ---
     * auto a = 2 * metre;
     * auto b = 2 / metre;
     * auto c = metre * 2;
     * auto d = metre / 2;
     * ---
     */
    auto opBinary(string op : "*", V)(V rhs) const if (!(isUnit!V || isQuantity!V)) {
        return Quantity!(typeof(this), V).fromValue(rhs);
    }

    /// ditto
    auto opBinary(string op : "/", V)(V rhs) const if (!(isUnit!V || isQuantity!V)) {
        // We cannot just do rhs ^^ -1 because integer types cannot be raised
        // to negative powers.
        return Quantity!(Unqual!(typeof(this)), V).fromValue((rhs ^^ 0) / rhs);
    }

    /// ditto
    auto opBinaryRight(string op : "*", V)(V lhs) const if (!(isUnit!V || isQuantity!V)) {
        return Quantity!(Unqual!(typeof(this)), V).fromValue(lhs);
    }

    /// ditto
    auto opBinaryRight(string op : "/", V)(V lhs) const if (!(isUnit!V || isQuantity!V)) {
        return Quantity!(PowerUnit!(typeof(this), Rational!(-1)), V).fromValue(lhs);
    }

    alias void SuperSecretAliasToMarkThisAsUnit; // See isUnit(T) below.
}

/**
 * Possible string representations of units.
 */
enum UnitString {
    name, /// Use full unit names when constructing strings.
    symbol /// Use unit symbols when constructing strings.
}

/*private*/public {
    template isUnit(T) {
        // KLUDGE: To avoid operator overloading ambiguities due to the
        // opBinaryRight definitions in the dummy unit instances and Quantity,
        // we need to know whether a type is a unit or not.
        // Another solution would be to limit the possible unit types to
        // BaseUnit/DerivedUnit/… instances, but this is not really desirable,
        // especially because units with large custom type conversion tables
        // are often clearer as custom structs.
        enum isUnit = __traits(compiles, T.SuperSecretAliasToMarkThisAsUnit);
    }
    template isUnitInstance(alias T) {
        static if (!__traits(compiles, isUnit!T)) {
            enum isUnitInstance = isUnit!(typeof(T));
        } else static if (!isUnit!T) {
            enum isUnitInstance = isUnit!(typeof(T));
        } else {
            enum isUnitInstance = false;
        }
    }

    /*
     * Returns a string for the unit U, falling back to stringof if U doesn't
     * have toString() defined.
     *
     * If ct is given, the result is guaranteed to be evaluatable at compile
     * time (for use in error messages). In theory, this should not be
     * necessary, as all of the toString functions in here should be CTFE'able,
     * but due to a @@BUG@@ not yet tracked down, the ones for ScaledUnit
     * and AffineUnit are not (maybe related to the alias parameters?).
     */
    string getUnitString(U, bool ct = false)(UnitString type = UnitString.name) {
        static if (__traits(compiles, { enum a = U.toString(UnitString.init); })) {
            return U.toString(type);
        } else static if (!ct && __traits(compiles,
            { auto a = U.toString(UnitString.init); }))
        {
            return U.toString(type);
        } else static if (__traits(compiles, { enum a = U.toString(); })) {
            return U.toString();
        } else static if (!ct && __traits(compiles, { auto a = U.toString(); })) {
            return U.toString();
        } else {
            return U.stringof;
        }
    }
}

/**
 * Shordhand for creating a basic unit with a name and a symbol, and no
 * conversions defined.
 *
 * When using BaseUnit, in virtually every use case, you also want to define
 * an associated unit instance, as shown below. As there should be no real use
 * for the unit type in user case anyway, you can also use baseUnit which
 * directly returns a unit instance.
 *
 * Example:
 * ---
 * alias BaseUnit!("Ampere", "A") Ampere;
 * enum ampere = Ampere.init;
 * // or
 * enum ampere = baseUnit!("Ampere", "A");
 * ---
 */
struct BaseUnit(string name, string symbol = null) {
    mixin UnitImpl;
    static string toString(UnitString type = UnitString.name) {
        switch (type) {
            case UnitString.symbol: if (symbol) return symbol;
            default: return name;
        }
    }
}

/// ditto
template baseUnit(string name, string symbol = null) {
    enum baseUnit = (BaseUnit!(name, symbol)).init;
}

version (unittest) private {
    // Some types for use as base units in unit tests.
    alias BaseUnit!("foo", "f") Foo;
    enum foo = Foo.init;
    static assert(baseUnit!("foo", "f") == foo);

    alias BaseUnit!("bar", "br") Bar;
    enum bar = Bar.init;

    alias BaseUnit!("baz", "bz") Baz;
    enum baz = Baz.init;
}

/**
 * A special unit used to represent dimensionless quantities.
 */
struct Dimensionless {
    mixin UnitImpl;
    static string toString(UnitString type = UnitString.name) {
        final switch (type) {
            case UnitString.name: return "dimensionless";
            case UnitString.symbol: return "";
        }
    }
}
enum dimensionless = Dimensionless.init; /// ditto

/**
 * A pair of a (base) unit and a compile-time rational exponent.
 *
 * Multiple BaseUnitExps make up a $(LREF DerivedUnit).
 */
template BaseUnitExp(B, R) if (!isDerivedUnit!B && isUnit!B && isRational!R && !is(B == Unqual!B)) {
    alias BaseUnitExp = BaseUnitExp!(Unqual!B, R);
}
struct BaseUnitExp(B, R) if (!isDerivedUnit!B && isUnit!B && isRational!R && is(B == Unqual!B)) {
    alias B BaseUnit;
    alias R Exp;
}

private {
    template isBaseUnitExp(T) {
        // We can't fold this into a single expression because the special
        // is syntax works only inside static ifs.
        static if (is(T _ : BaseUnitExp!(B, R), B, R)) {
            enum isBaseUnitExp = true;
        } else {
            enum isBaseUnitExp = false;
        }
    }
    unittest {
        static assert(isBaseUnitExp!(BaseUnitExp!(Foo, Rational!1)));
        static assert(!isBaseUnitExp!(Rational!1));
    }
}

/**
 * Constructs a derived unit, consisting of a number of base units and
 * associated exponents.
 *
 * Usually, constructing unit types using the operators defined on the unit
 * instances is preferred over using this template directly.
 *
 * Internally, derived units are represented as DUnit instances, but never try
 * to use it directly – the DerivedUnit template performs canonicalization to
 * ensure that semantically equivalent units share the same underlying types.
 * Also, the result will not actually be a DUnit in some cases, but rather
 * Dimensionless or a single base unit without exponent.
 *
 * Example:
 * ---
 * alias DerivedUnit!(
 *     BaseUnitExp!(Ampere, Rational!1),
 *     BaseUnitExp!(Second, Rational!1)
 * ) Coulomb;
 * enum coulomb = Coulomb.init;
 *
 * // In most cases, you would want to just use the operators
 * // on the unit instances instead:
 * enum coulomb = ampere * second;
 * ---
 */
template DerivedUnit(T...) if (allSatisfy!(isBaseUnitExp, T)) {
    alias MakeDerivedUnit!(T).Result DerivedUnit;
}

unittest {
    alias DerivedUnit!(BaseUnitExp!(Foo, Rational!(-2))) A;
    static assert(is(
        A.BaseUnitExps == TypeTuple!(BaseUnitExp!(Foo, Rational!(-2)))
    ), "Basic compound unit construction does not work.");

    static assert(is(
        DerivedUnit!(
            BaseUnitExp!(Foo, Rational!2),
            BaseUnitExp!(Bar, Rational!1),
            BaseUnitExp!(Baz, Rational!3)
        ) == DerivedUnit!(
            BaseUnitExp!(Bar, Rational!1),
            BaseUnitExp!(Baz, Rational!3),
            BaseUnitExp!(Foo, Rational!2)
        )
    ), "Base unit sorting does not work.");

    // FIXME: Another problem probably related to signed/unsigned integer
    // literals, uncomment BarBU-related arguments below to see the assert fail.
    static assert(is(
        DerivedUnit!(
            BaseUnitExp!(Foo, Rational!2), BaseUnitExp!(Foo, Rational!1)/+,
            BaseUnitExp!(Bar, Rational!(-3)), BaseUnitExp!(Bar, Rational!2)+/
        ) == DerivedUnit!(
            BaseUnitExp!(Foo, Rational!3), /+BaseUnitExp!(Bar, Rational!(-1)+/
        )
    ), "Base unit joining does not work.");

    static assert(is(
        DerivedUnit!(
            BaseUnitExp!(Foo, Rational!2),
            BaseUnitExp!(Foo, Rational!(-2))
        ) == Dimensionless
    ), "Zero exponent base unit pruning does not work.");

    static assert(is(
        DerivedUnit!(
            BaseUnitExp!(Dimensionless, Rational!1),
            BaseUnitExp!(Foo, Rational!1)
        ) == Foo
    ), "Removing Dimensionless during zero exponent pruning does not work.");

    static assert(is(
        DerivedUnit!(BaseUnitExp!(Foo, Rational!1)) == Foo
    ), "Demotion of trivial compound units to base units does not work.");
}

private {
    /// ditto
    struct DUnit(T...) {
        alias T BaseUnitExps;
        mixin UnitImpl;

        /**
         * Returns a formatted unit string consisting of base unit names and
         * exponents.
         *
         * As recommended in the SI manual, the units are sorted alphabetically.
         */
        @trusted
        static string toString(UnitString type = UnitString.name) {
            string[] bueStrings;

            foreach (i, Bue; BaseUnitExps) {
                immutable n = Bue.Exp.numerator;
                immutable d = Bue.Exp.denominator;
                if (n == 0) continue;

                string current = getUnitString!(Bue.BaseUnit)(type);
                if (n != 1) {
                    current ~= "^";

                    immutable parens = n < 0 || d != 1;
                    if (parens) current ~= "(";

                    current ~= to!string(n);
                    if (d != 1) {
                        current ~= "/" ~ to!string(d);
                    }

                    if (parens) current ~= ")";
                }
                bueStrings ~= current;
            }

            // std.algorithm.sort() is currently buggy at compile-time, use
            // our custom makeIndex implementation instead.
            auto indices = new size_t[bueStrings.length];
            makeIndexCtfe(bueStrings, indices);

            string result = bueStrings[indices[0]];
            foreach (i; indices[1..$]) {
                result ~= " " ~ bueStrings[i];
            }
            return result;
        }
    }

    /*
     * Returns the canonical unit type for the passed parameters.
     *
     * The rest of unit handling code does not care about canonicalization, it
     * just uses DerivedUnit where necessary.
     */
    template MakeDerivedUnit(T...) {
        static if (T.length == 0) {
            alias Dimensionless Result;
        } else {
            alias CanonicalizeBaseUnitExps!T.Result CanonicalBUEs;
            static if (CanonicalBUEs.length == 0) {
                alias Dimensionless Result;
            } else {
                alias CanonicalBUEs[0] A;
                static if (CanonicalBUEs.length == 1 && is(A.Exp == Rational!1)) {
                    // If we just have a single base unit with exponent 1,
                    // don't construct a DUnit, but just return that base unit
                    // instead.
                    alias A.BaseUnit Result;
                } else {
                    alias DUnit!CanonicalBUEs Result;
                }
            }
        }
    }

    template CanonicalizeBaseUnitExps(T...) {
        // Sort the BaseUnitExp list by the mangled name of the base unit
        // types. Just .mangleof could be used here as well, but
        // mangledName conveniently is a template already.
        template GetBU(BUE) {
            alias BUE.BaseUnit GetBU;
        }
        alias staticMap!(mangledName, staticMap!(GetBU, T)) BaseUnitNames;
        alias IndexedTuple!(makeArgumentIndex(BaseUnitNames), T) SortedBUEs;

        alias PruneZeroBaseUnitExps!(
            JoinBaseUnitExps!(SortedBUEs).Result
        ).Result Result;
    }

    /*
     * Takes a type tuple of BaseUnitExps and joins adjacent sets which share
     * the same BaseUnit.
     *
     * The resulting type tuple is accesible via JoinBaseUnitExps.Result.
     */
    template JoinBaseUnitExps(T...) {
        static if (T.length < 2) {
            alias TypeTuple!T Result;
        } else {
            // Have to alias T[0] and T[1] here because otherwise trying to
            // access T[0].BaseUnit results in a syntax error. If it
            // wasn't for that, this could be an eponymous template. Is this
            // a @@BUG@@?
            alias T[0] A;
            alias T[1] B;
            static if (is(A.BaseUnit == B.BaseUnit)) {
                alias JoinBaseUnitExps!(
                    BaseUnitExp!(A.BaseUnit, Sum!(A.Exp, B.Exp)),
                    T[2 .. $]
                ).Result Result;
            } else {
                alias TypeTuple!(A, JoinBaseUnitExps!(T[1..$]).Result) Result;
            }
        }
    }

    /*
     * Takes a type tuple of BaseUnitExps and removes ones with exponent zero
     * or unit Dimensionless (this can happen if »dimensionless« is used
     * directly).
     *
     * The pruned list is accesible via PruneZeroBaseUnitExps.Result.
     */
    template PruneZeroBaseUnitExps(T...) {
        static if (T.length == 0) {
            alias TypeTuple!() Result;
        } else {
            alias T[0] A;
            static if (A.Exp.numerator == 0 || is(A.BaseUnit == Dimensionless)) {
                alias PruneZeroBaseUnitExps!(T[1..$]).Result Result;
            } else {
                alias TypeTuple!(A, PruneZeroBaseUnitExps!(T[1..$]).Result) Result;
            }
        }
    }

    template isDerivedUnit(T) {
        // Matching DUnit with its type tuple parameter directly doesn't work,
        // so take advantage of the fact that we can access BaseUnitExps from
        // outside.
        static if (is(T.BaseUnitExps) && is(T : DUnit!(T.BaseUnitExps))) {
            enum isDerivedUnit = true;
        } else {
            enum isDerivedUnit = false;
        }
    }
}

/**
 * An affine unit – the most common case being a unit that is related to other
 * units representing the same physical quantity not by a scale factor, but by
 * a shift in the zero point.
 *
 * This is not a fundamentally new concept, adding a constant offset could
 * just be implemented in a custom conversion function as well (see the
 * $(LREF UnitImpl) documentation). However, Quantity is specialized on
 * affine units such as to only provide operations which make sense for them:
 *
 * Informally speaking, an affine space is a vector space which »forgot« its
 * origin, its elements are points, not vectors. Thus, a quantity of an
 * affine unit cannot be added to another (as it makes no sense to add two
 * points), but like vectors can be added to points to yield a new point, a
 * quantity of the underlying base unit can be. Also, two affine quantities
 * can be substracted to yield a quantity of the base unit (just as two
 * points can be substracted to get a vector pointing from one to another).
 *
 * The most common example for this are units of temperature like degrees
 * Celsius or Fahrenheit, as demonstrated below.
 *
 * Example:
 * ---
 * enum celsius = affine!(273.15, "degrees Celsius", "°C")(kelvin);
 * auto t = 3.0 * celsius;
 * t += 1.0 * kelvin; // adding Kelvin is okay
 * assert(!__traits(compiles, t += 2.0 * celsius)); // adding Celsius is not
 * writeln(t - 0.0 * celsius); // 4 Kelvin, not degrees Celsius
 * ---
 */
struct AffineUnit(BaseUnit, alias toBaseOffset, string name,
    string symbol = null) if (isUnit!BaseUnit)
{
    alias BaseUnit LinearBaseUnit;
    mixin UnitImpl;

    static string toString(UnitString type = UnitString.name) {
        switch (type) {
            case UnitString.symbol: if (symbol) return symbol;
            default: return name;
        }
    }

    alias TypeTuple!(Conversion!(BaseUnit, toBase, fromBase)) Conversions;

    static V toBase(V)(V v) {
        return cast(V)(v + toBaseOffset);
    }
    static V fromBase(V)(V v) {
        return cast(V)(v - toBaseOffset);
    }
}

/// ditto
template AffineUnit(alias baseUnit, alias toBaseOffset, string name,
    string symbol = null) if (isUnitInstance!baseUnit)
{
    alias AffineUnit!(typeof(baseUnit), toBaseOffset, name, symbol) AffineUnit;
}

/// ditto
auto affine(alias toBaseOffset, string name, string symbol = null, U)(U u)
    if (isUnit!U)
{
    alias AffineUnit!(U, toBaseOffset, name, symbol) New;
    return New.init;
}

/**
 * A quantity consisting of a value and an associated unit of measurement.
 *
 * The unary plus, unary minus, addition, subtraction, multiplication,
 * division, comparison, increment and decrement operators are forwarded to
 * the underlying value type, if the operation is meaningful for the given
 * unit(s).
 *
 * A quantity is only implicitly convertible to the underlying value type
 * (via $(D alias this)) if it is dimensionless – divide a quantity by its
 * unit if you want to access the raw value.
 */

template Quantity(Unit, ValueType = double) if (isUnit!Unit && !(is(Unit == Unqual!Unit) && is(ValueType == Unqual!ValueType))) {
    alias Quantity = Quantity!(Unqual!Unit, Unqual!ValueType);
}

struct Quantity(Unit, ValueType = double) if (isUnit!Unit && is(Unit == Unqual!Unit) && is(ValueType == Unqual!ValueType)) {
    enum unit = Unit.init; /// An instance of Unit.

    /**
     * Two quantites of the same unit are implicitely convertible on
     * assignment if the underlying value types are.
     *
     * Example:
     * ---
     * Quantity!(metre, float) a = 2 * metre;
     * ---
     */
    this(OtherV)(Quantity!(Unit, OtherV) other) if (
        isAssignable!(ValueType, OtherV)
    ) {
        value = other.value;
    }

    /// ditto
    ref Quantity opAssign(OtherV)(Quantity!(Unit, OtherV) other) if (
        isAssignable!(ValueType, OtherV)
    ) {
        value = other.value;
        return this;
    }

    /**
     * A quantity is castable to another one with the same unit if the value
     * type can be casted to the new one.
     *
     * For converting a quantity to another unit, see $(LREF convert) instead.
     *
     * Example:
     * ---
     * auto a = 2.0 * metre;
     * assert(cast(Quantity!(metre, int))a == 2 * metre);
     * ---
     */
    Quantity!(Unit, NewV) opCast(T : Quantity!(Unit, NewV), NewV)() if (
        is(typeof(cast(NewV)ValueType.init))
    ) {
        return Quantity!(Unit, NewV).fromValue(cast(NewV)value);
    }

    // No way to specialize Quantity on AffineUnit (since it takes an alias
    // template parameter), so just check if we can access its
    // LinearBaseUnit here.
    static if (!is(Unit.LinearBaseUnit BaseUnit))
    {
        /**
         * Unary plus/minus operators.
         *
         * Example:
         * ---
         * auto l = 6 * metre;
         * assert(+l == 6 * metre);
         * assert(-l == (-6) * metre);
         * ---
         */
        auto opUnary(string op)() if (
            (op == "+" || op == "-") && is(typeof(mixin(op ~ "ValueType.init")))
        ) {
            return Quantity!(Unit, typeof(mixin(op ~ "value"))).fromValue(
                mixin(op ~ "value"));
        }

        /**
         * Prefix increment/decrement operators.
         *
         * They are only provided dimensionless quantities, because they are
         * semantically equivalent to adding the dimensionless quantity 1.
         */
        auto opUnary(string op)() if (
            (op == "++" || op == "--") && is(Unit == Dimensionless) &&
            is(typeof({ ValueType v; return mixin(op ~ "v"); }()))
        ) {
            return Quantity!(Dimensionless, typeof(mixin(op ~ "value"))).fromValue(
                mixin(op ~ "value")
            );
        }

        /**
         * Addition/substraction of a quantity with the same unit.
         *
         * Example:
         * ---
         * auto a = 3 * metre;
         * auto b = 2 * metre;
         * assert(a + b == 5 * metre);
         * a -= b;
         * assert(a == 1 * metre);
         * ---
         */
         
        auto opBinary(string op, RhsV)(Quantity!(Unit, RhsV) rhs) const if (
            (op == "+" || op == "-") &&
            is(typeof(mixin("ValueType.init" ~ op ~ "RhsV.init")))
        ) {
            return Quantity!(Unit, typeof(mixin("value" ~ op ~ "rhs.value"))).
                fromValue(mixin("value" ~ op ~ "rhs.value"));
        }

        /// ditto
        ref Quantity opOpAssign(string op, RhsV)(Quantity!(Unit, RhsV) rhs) if (
            (op == "+" || op == "-") &&
            __traits(compiles, { ValueType v; mixin("v" ~ op ~ "= RhsV.init;"); }())
        ) {
            mixin("value" ~ op ~ "= rhs.value;");
            return this;
        }

        /**
         * Multplication/division by a plain value (i.e. a dimensionless quantity
         * not represented by a Quantity instance).
         *
         * Example:
         * ---
         * auto l = 6 * metre;
         * assert(l * 2 == 12 * metre);
         * l /= 2;
         * assert(l == 3 * metre);
         * ---
         */
        auto opBinary(string op, T)(T rhs) const if (
            (op == "*" || op == "/") && !isUnit!T && !isQuantity!T &&
            is(typeof(mixin("ValueType.init" ~ op ~ "T.init")))
        ) {
            return Quantity!(Unit, typeof(mixin("value" ~ op ~ "rhs"))).fromValue(
                mixin("value " ~ op ~ " rhs"));
        }

        /// ditto
        auto opBinaryRight(string op, T)(T lhs) const if (
            (op == "*" || op == "/") && !isUnit!T && !isQuantity!T &&
            is(typeof(mixin("T.init" ~ op ~ "ValueType.init")))
        ) {
            return Quantity!(Unit, typeof(mixin("lhs" ~ op ~ "value"))).fromValue(
                mixin("lhs " ~ op ~ " value"));
        }

        /// ditto
        ref Quantity opOpAssign(string op, T)(T rhs) if (
            (op == "*" || op == "/") && !isUnit!T && !isQuantity!T &&
            __traits(compiles, { ValueType v; mixin("v" ~ op ~ "= T.init;"); }())
        ) {
            mixin("value " ~ op ~ "= rhs;");
            return this;
        }

        /**
         * Multiplication with a unit instance.
         *
         * Returns a quantity with the same value, but the new unit.
         *
         * Example:
         * ---
         * auto l = 6 * metre;
         * assert(l * metre == 6 * pow!2(metre));
         * ---
         */
        auto opBinary(string op : "*", Rhs)(Rhs rhs) const if (isUnit!Rhs) {
            return Quantity!(
                ProductUnit!(Unit, Rhs).Result,
                ValueType
            ).fromValue(value);
        }

        /// ditto
        auto opBinaryRight(string op : "*", Lhs)(Lhs lhs) const if (isUnit!Lhs) {
            return Quantity!(
                ProductUnit!(Lhs, Unit).Result,
                ValueType
            ).fromValue(value);
        }

        /**
         * Division by a unit instance.
         *
         * Returns a quantity with the same value, but the new unit.
         *
         * Example:
         * ---
         * auto l = 6 * metre;
         * assert(l / metre == 6 * dimensionless);
         * ---
         */
        auto opBinary(string op : "/", RhsU)(RhsU rhs) const if (isUnit!RhsU) {
            return Quantity!(
                QuotientUnit!(Unit, RhsU).Result,
                ValueType
            ).fromValue(value);
        }

        /// ditto
        auto opBinaryRight(string op : "/", Lhs)(Lhs rhs) const if (isUnit!Lhs) {
            // We cannot just do value ^^ -1 because integer types cannot be
            // raised to negative powers.
            return Quantity!(
                QuotientUnit!(Lhs, Unit).Result,
                ValueType
            ).fromValue((value ^^ 0) / value);
        }

        /**
         * Multiplication with another quantity.
         *
         * Example:
         * ---
         * auto w = 3 * metre;
         * auto h = 2 * metre;
         * assert(w * h == 12 * pow!2(metre));
         * ---
         */
        auto opBinary(string op : "*", RhsU, RhsV)(Quantity!(RhsU, RhsV) rhs) const {
            return Quantity!(
                ProductUnit!(Unit, RhsU).Result, typeof(value * rhs.value)
            ).fromValue(value * rhs.value);
        }

        /**
         * Division by another quantity.
         *
         * Example:
         * ---
         * auto s = 6 * metre;
         * auto t = 2 * second;
         * assert(s / t == 3 * metre / second);
         * ---
         */
        auto opBinary(string op : "/", RhsU, RhsV)(Quantity!(RhsU, RhsV) rhs) const {
            return Quantity!(
                QuotientUnit!(Unit, RhsU).Result, typeof(value / rhs.value)
            ).fromValue(value / rhs.value);
        }
    } else {
        /**
         * Substracts a quantity of the same unit, yielding a quantity of the non-
         * affine base unit.
         *
         * Example:
         * ---
         * auto a = 3 * celsius;
         * auto b = 2 * celsius;
         * assert(a - b == 1 * kelvin);
         * ---
         */
        auto opBinary(string op : "-", RhsV)(Quantity!(Unit, RhsV) rhs) const if (
            is(typeof(ValueType.init - RhsV.init))
        ) {
            return Quantity!(BaseUnit, typeof(value - rhs.value)).
                fromValue(value - rhs.value);
        }

        /**
         * Addition/substraction of a quantity with the linear base unit.
         *
         * Example:
         * ---
         * auto a = 3 * celsius;
         * auto b = 2 * kelvin;
         * assert(a + b == 5 * celsius);
         * a -= b;
         * assert(a == 1 * celsius);
         * ---
         */
        auto opBinary(string op, RhsV)(Quantity!(BaseUnit, RhsV) rhs) const if (
            (op == "+" || op == "-") &&
            is(typeof(mixin("ValueType.init" ~ op ~ "RhsV.init")))
        ) {
            return Quantity!(Unit, typeof(mixin("value" ~ op ~ "rhs.value"))).
                fromValue(mixin("value" ~ op ~ "rhs.value"));
        }

        /// ditto
        ref Quantity opOpAssign(string op, RhsV)(Quantity!(BaseUnit, RhsV) rhs) if (
            (op == "+" || op == "-") &&
            __traits(compiles, { ValueType v; mixin("v" ~ op ~ "= RhsV.init;"); }())
        ) {
            mixin("value" ~ op ~ "= rhs.value;");
            return this;
        }

        /// ditto
        auto opBinaryRight(string op : "+", RhsV)(Quantity!(BaseUnit, RhsV) lhs) const if (
            is(typeof(ValueType.init + RhsV.init))
        ) {
            return Quantity!(Unit, typeof(value + lhs.value)).
                fromValue(value + lhs.value);
        }
    }

    /**
     * Comparison with another quantity of the same unit.
     *
     * Example:
     * ---
     * auto a = 3 * metre;
     * auto b = 4 * metre;
     * auto c = 5 * second;
     * assert(a != b);
     * assert(a < b);
     * assert(!__traits(compiles, a != c));
     * assert(!__traits(compiles, a < c));
     * ---
     */
    int opEquals(RhsV)(Quantity!(Unit, RhsV) rhs) if (
        is(typeof(ValueType.init == RhsV.init) : bool)
    ) {
        return value == rhs.value;
    }

    /// ditto
    auto opCmp(RhsV)(Quantity!(Unit, RhsV) rhs) if (
        is(typeof(ValueType.init < RhsV.init) : bool)
    ) {
        static if (__traits(compiles, value - rhs.value)) {
            return value - rhs.value;
        } else {
            return (value == rhs.value) ? 0 : (value < rhs.value ? -1 : 1);
        }
    }

    /**
     * Returns a string representation of the quantity, consisting of the
     * value and a unit symbol or name.
     *
     * Example:
     * ---
     * auto l = 6 * metre / second;
     * assert(l.toString() == "6 metre second^(-1)");
     * assert(l.toString(UnitString.symbol) == "6 m s^(-1)");
     * ---
     */
    @trusted
    string toString(UnitString type = UnitString.name) {
        return to!string(value) ~ " " ~ getUnitString!Unit(type);
    }

    static if (is(Unit == Dimensionless)) {
        ValueType rawValue() @property {
            return value;
        }
        void rawValue(ValueType newValue) @property {
            value = newValue;
        }
        alias rawValue this;
    }

private:
    static Quantity fromValue(ValueType value) {
        Quantity q = void;
        q.value = value;
        return q;
    }

    ValueType value;
}

/// ditto
template Quantity(alias unit, ValueType = double) if (isUnitInstance!unit) {
    alias Quantity!(typeof(unit), ValueType) Quantity;
}

unittest {
    enum f1 = 6 * foo;
    static assert(+f1 == f1);
    static assert(-f1 == (-6) * foo);
    static assert(f1 + f1 == 12 * foo);
    static assert(f1 - f1 == 0 * foo);
    static assert({
        auto f = 2 * foo;
        f += 3 * foo;
        f -= 2 * foo;
        return f;
    }() == 3 * foo);
    static assert(f1 * 2 == 12 * foo);
    static assert(f1 / 3 == 2 * foo);
    static assert(2 * f1 == 12 * foo);
    static assert(12 / f1 == 2 * foo);
    static assert({
        auto f = 2 * foo;
        f *= 12;
        f /= 3;
        return f;
    }() == 8 * foo);

    enum f2 = 2 * foo;
    static assert(f1 * f2 == 12 * pow!2(foo));
    enum b = 2 * bar;
    static assert(f1 / b == 3 * foo / bar);
    static assert(foo / 2 == 0 * foo);
    static assert(foo / (2 * bar) == 0 * foo / bar);

    static assert(f1 == 6u * foo);
    static assert(f1 != f2);
    static assert(f1 > f2);
    static assert(!__traits(compiles, f1 != b));
    static assert(!__traits(compiles, f1 < b));

    static assert((f1 / b).toString() == "3 bar^(-1) foo");
    static assert((f1 / b).toString(UnitString.symbol) == "3 br^(-1) f");

    enum int fromDimless = f1 / foo;

    // Increment/decrement should only work for dimensionless Quantities.
    auto f3 = 1 * foo;
    static assert(!__traits(compiles, ++f3));
    static assert(!__traits(compiles, --f3));
    static assert({
        auto b = 1 * dimensionless;
        ++b;
        return b;
    }() == 2 * dimensionless);

    // Implicit conversion in assignments.
    Quantity!(foo, float) k = 5 * foo;
    k = 3 * foo;
    static assert(cast(Quantity!(foo, int))(2.1 * foo) == 2 * foo);

    // Quantities of affine units.
    enum fooa = affine!(10, "afoo", "af")(foo);
    enum fa1 = 3 * fooa;
    static assert(!__traits(compiles, fa1 + fa1));
    static assert(fa1 + f1 == 9 * fooa);
    static assert(f1 + fa1 == 9 * fooa);
    static assert(fa1 - fa1 == 0 * foo);
    static assert(fa1 - f1 == (-3) * fooa);
    auto fa2 = 2 * fooa;
    static assert(!__traits(compiles, fa2 += fa1));
    static assert(!__traits(compiles, fa2 -= fa1));
    static assert({
        auto fa = 2 * fooa;
        fa += 3 * foo;
        fa -= 2 * foo;
        return fa;
    }() == 3 * fooa);
    static assert(convert!foo(fa1) == 13 * foo);
}

/**
 * Raises a unit instance to a given power.
 *
 * Because the exponent must be known at compile-time (as the type of the
 * result depends on it), overloading the ^^ operator for units.
 *
 * Example:
 * ---
 * enum squareMetre = pow!2(metre);
 * ---
 */
auto pow(Exp, U)(U u) if (isUnit!U) {
    return PowerUnit!(U, Exp).init;
}

/// ditto
auto pow(int numerator, uint denominator = 1u, U)(U u) if (isUnit!U) {
    return pow!(Rational!(numerator, denominator))(u);
}

auto pow(int numerator, uint denominator = 1u, U)(U u) if (isFloatingPoint!U) {
    return std.math.pow(u, cast(float)numerator/cast(float)denominator);
}

/**
 * Raises a quantity to a given power.
 *
 * Because the exponent must be known at compile-time (to determine the unit
 * of the result), overloading the ^^ operator for quantities is not possible.
 *
 * Example:
 * ---
 * auto area = pow!2(5 * metre);
 * ---
 */
auto pow(Exp, Q)(Q q) if (is(Q : Quantity!(U,V), U, V)) {
    static if (is(Q : Quantity!(U,V), U, V))
    {
        return Quantity!(PowerUnit!(U, Exp), V).fromValue(q.value ^^ Exp.value);
    }
}

/// ditto
auto pow(int numerator, uint denominator = 1u, Q)(Q q) if (is(Q : Quantity!(U,V), U, V)) {
    return pow!(Rational!(numerator, denominator))(q);
}

/*private*/ public {
    template isQuantity(Q) {
        static if(is(Q _ : Quantity!(U, V), U, V)) {
            enum isQuantity = true;
        } else {
            enum isQuantity = false;
        }
    }

    template ProductUnit(Lhs, Rhs) if (isUnit!Lhs && isUnit!Rhs) {
        static if (isDerivedUnit!Lhs) {
            alias Lhs.BaseUnitExps LBUExps;
        } else {
            alias BaseUnitExp!(Lhs, Rational!1) LBUExps;
        }
        static if (isDerivedUnit!Rhs) {
            alias Rhs.BaseUnitExps RBUExps;
        } else {
            alias BaseUnitExp!(Rhs, Rational!1) RBUExps;
        }

        // Just concatenate the base unit exp lists and pass them to
        // DerivedUnit, it takes care of actually summing the exponents for
        // identical base units, etc.
        alias DerivedUnit!(LBUExps, RBUExps) Result;
    }

    template QuotientUnit(Lhs, Rhs) if (isUnit!Lhs && isUnit!Rhs) {
        // Rewrite lhs / rhs as lhs * rhs^^-1.
        alias ProductUnit!(Lhs, PowerUnit!(Rhs, Rational!(-1))) QuotientUnit;
    }

    template PowerUnit(U, Exp) if (isUnit!U && isRational!Exp) {
        static if (isDerivedUnit!U) {
            // Multiply all base unit exponents with Exp to get the new list
            // of BaseUnitExps.
            alias DerivedUnit!(
                staticMap!(Curry!(PowerBaseUnitExp, Exp), U.BaseUnitExps)
            ) PowerUnit;
        } else {
            alias DerivedUnit!(BaseUnitExp!(U, Exp)) PowerUnit;
        }
    }

    unittest {
        static assert(is(
            PowerUnit!(
                DerivedUnit!(BaseUnitExp!(Foo, Rational!(-2))),
                Rational!(1, 4u)
            ) ==
            DerivedUnit!(BaseUnitExp!(Foo, Rational!(-1, 2u)))
        ));
        static assert(is(
            PowerUnit!(
                DerivedUnit!(
                    BaseUnitExp!(Foo, Rational!2),
                    BaseUnitExp!(Bar, Rational!1)
                ),
                Rational!3
            ) ==
            DerivedUnit!(
                BaseUnitExp!(Foo, Rational!6),
                BaseUnitExp!(Bar, Rational!3)
            )
        ));
        static assert(is(
            PowerUnit!(
                DerivedUnit!(
                    BaseUnitExp!(Foo, Rational!2),
                    BaseUnitExp!(Bar, Rational!1)
                ),
                Rational!0
            ) ==
            Dimensionless
        ));
        static assert(is(
            PowerUnit!(Foo, Rational!2) ==
            DerivedUnit!(BaseUnitExp!(Foo, Rational!2))
        ));
    }

    template PowerBaseUnitExp(Exp, B) {
        alias BaseUnitExp!(B.BaseUnit, Product!(B.Exp, Exp)) PowerBaseUnitExp;
    }
}

/**
 * A conversion »link« to a target unit, consisting of a callable converting
 * a value to the target, and one for converting it back.
 *
 * Is used in the optional Conversions property of base units, see the
 * documentation for $(LREF UnitImpl).
 */
// Is a struct to be usable in static foreach.
struct Conversion(T, alias R, alias I) if (isUnit!T) {
    alias T TargetUnit;
    alias R RegularFunc;
    alias I InverseFunc;
}

/// ditto
template Conversion(alias t, alias R, alias I) if (isUnitInstance!t) {
    alias Conversion!(typeof(t), R, I) Conversion;
}

/**
 * Converts a quantity to another unit.
 *
 * The value type of the resulting quantity will be the same as the original
 * one.
 *
 * Examples:
 * ---
 * writeln(convert!gram(2 * kilogram));
 * writeln(convert!kilogram(2000 * gram));
 * writeln(convert!(milli(newton))(2 * newton));
 * writeln(convert!(kilo(newton))(2000000 * gram * meter / pow!2(second)));
 * writeln(convert!(micro(newton) / pow!2(milli(metre)))(1234.0 * pascal));
 * ---
 */
auto convert(TargetUnit, Q : Quantity!(U, V), U, V)(Q q) if (isUnit!TargetUnit) {
    alias GetConversion!(U, TargetUnit, V) C;
    static if (!__traits(compiles, C.Result)) {
        // Due to a @@BUG@@ not yet tracked down, the error message cannot be
        // passed to the static assert – from the spellcheck suggestions, it
        // seems as if the argument to static assert was evaluated in the
        // scope of some GetConversion instance.
        pragma(msg, "Error: No conversion from '" ~ getUnitString!(U, true) ~
            "' to '" ~ getUnitString!(TargetUnit, true) ~ "' could be found.");
        static assert(false);
    }
    return Quantity!(TargetUnit, V).fromValue(C.Result(q.value));
}

/// ditto
auto convert(alias targetUnit, Q : Quantity!(U, V), U, V)(Q q)
    if (isUnitInstance!targetUnit)
{
    return convert!(typeof(targetUnit))(q);
}

/**
 * Checks whether a quantity is convertible to a certain unit.
 *
 * Examples:
 * ---
 * assert(canConvert!gram(2 * kilogram));
 * assert(!canConvert!metre(2 * kilogram));
 * ---
 */
bool canConvert(TargetUnit, Q : Quantity!(U, V), U, V)(Q q) if (isUnit!TargetUnit) {
    return __traits(compiles, GetConversion!(U, TargetUnit, V).Result);
}

/// ditto
bool canConvert(alias targetUnit, Q : Quantity!(U, V), U, V)(Q q)
    if (isUnitInstance!targetUnit)
{
    return canConvert!(typeof(targetUnit))(q);
}

unittest {
    struct ConvertibleToFoo {
        mixin UnitImpl;
        alias TypeTuple!(Conversion!(Foo, toFoo, fromFoo)) Conversions;
        static string toString(UnitString type = UnitString.name) {
            final switch (type) {
                case UnitString.name: return "convertibleToFoo";
                case UnitString.symbol: return "ctf";
            }
        }

        static V toFoo(V)(V v) {
            return v * 3;
        }
        static V fromFoo(V)(V v) {
            return v / 3;
        }
    }
    enum convertibleToFoo = ConvertibleToFoo.init;

    // »Regular« conversion.
    auto c = 2 * convertibleToFoo;
    assert(convert!foo(c) == 6 * foo);

    // »Inverse« conversion.
    auto f = 9 * foo;
    assert(convert!convertibleToFoo(f) == 3 * convertibleToFoo);

    static assert(canConvert!foo(2 * convertibleToFoo));
    static assert(!canConvert!bar(2 * convertibleToFoo));
}

private {
    template GetConversion(FromUnit, ToUnit, ValueType, bool inverse = false,
        bool tryReverse = true)
    {
        static if (is(FromUnit == ToUnit)) {
            // If the destination has already been reached, just return the
            // identity function.
            enum Result = function (ValueType v) { return v; };
        } else {
            // Bring both units into the form of a list of base units and
            // exponents (a list with one element for non-derived units). This
            // way, the algorithm below can remain generic.
            alias GetBaseUnitExps!FromUnit FromBUEs;
            alias GetBaseUnitExps!ToUnit ToBUEs;

            // Try substituting every base unit part of FromUnit (resp. the
            // only one for non-derived units) with all of its conversion
            // targets and see if it can be converted then, i.e. recursively
            // walk down the tree/DAG. (Note that the same was/will be done
            // for the now ToUnit in the reverse pass.) This is currently a
            // depth first search, and thus may lead to unnecessary
            // conversions in cases such as newton -> milli(newton).

            template ChildrenSearch(size_t startIndex = 0) {
                alias FromBUEs[startIndex] Current;
                alias TypeTuple!(FromBUEs[0..startIndex],
                    FromBUEs[startIndex+1..$]) ErasedBUEs;
                static if (__traits(compiles, Current.BaseUnit.Conversions)) {
                    template canConvert(Conv) {
                        enum canConvert = is(typeof(
                            GetConversion!(
                                DerivedUnit!(
                                    ErasedBUEs,
                                    staticMap!(
                                        Curry!(PowerBaseUnitExp, Current.Exp),
                                        GetBaseUnitExps!(Conv.TargetUnit)
                                    )
                                ), ToUnit, ValueType, inverse, true
                            ).Result(ValueType.init)) : ValueType
                        );
                    }
                    alias staticFind!(canConvert, Current.BaseUnit.Conversions)
                        Search;
                }

                static if (is(Search.Result)) {
                    alias GetConversion!(
                        DerivedUnit!(
                            ErasedBUEs,
                            staticMap!(
                                Curry!(PowerBaseUnitExp, Current.Exp),
                                GetBaseUnitExps!(Search.Result.TargetUnit)
                            )
                        ), ToUnit, ValueType, inverse, true
                    ).Result ChildFunc;
                    static if (inverse) {
                        static if (isExpPositive!Current) {
                            alias compose!(PowerConvFunc!(
                                Search.Result.InverseFunc, Current.Exp),
                                ChildFunc
                            ) Result;
                        } else {
                            alias Product!(Current.Exp, Rational!(-1)) Exp;
                            alias compose!(PowerConvFunc!(
                                Search.Result.RegularFunc, Exp),
                                ChildFunc
                            ) Result;
                        }
                    } else {
                        static if (isExpPositive!Current) {
                            alias compose!(ChildFunc, PowerConvFunc!(
                                Search.Result.RegularFunc, Current.Exp)) Result;
                        } else {
                            alias Product!(Current.Exp, Rational!(-1)) Exp;
                            alias compose!(ChildFunc, PowerConvFunc!(
                                Search.Result.InverseFunc, Exp)) Result;
                        }
                    }
                } else static if (startIndex < (FromBUEs.length - 1)) {
                    alias ChildrenSearch!(startIndex + 1) Next;
                    static if (is(typeof(Next.Result(ValueType.init)) : ValueType)) {
                        alias Next.Result Result;
                    }
                }
            }
            static if(is(typeof(ChildrenSearch!(0).Result(ValueType.init)) : ValueType)) {
                alias ChildrenSearch!(0).Result Result;
            } else {
                // If going from the target unit backwards hasn't already been
                // tried, do it now.
                static if (tryReverse) {
                    alias GetConversion!(ToUnit, FromUnit, ValueType,
                        !inverse, false) Reversed;
                    static if (is(typeof(Reversed.Result(ValueType.init)) : ValueType)) {
                        alias Reversed.Result Result;
                    }
                }
            }
        }
    }

    template PowerConvFunc(alias func, Exp) if (isRational!Exp) {
        // @@BUG@@: Why doesn't this assert trigger on negative exponents?!
        static assert(Exp.numerator > 0);
        static if (Exp.denominator != 1u) {
            // Only require v ^^ to be defined in this special case.
            V PowerConvFunc(V)(V v) {
                return func((v ^^ Exp.denominator)) ^^ (1.0 / Exp.denominator);
            }
        } else {
            alias compose!(RepeatTypeTuple!(Exp.numerator, func)) PowerConvFunc;
        }
    }

    /*
     * Returns a type tuple of BaseUnitExps for the given unit.
     */
    template GetBaseUnitExps(U) {
        static if (isDerivedUnit!U) {
            alias U.BaseUnitExps GetBaseUnitExps;
        } else {
            alias TypeTuple!(BaseUnitExp!(U, Rational!1)) GetBaseUnitExps;
        }
    }

    /*
     * The sum of all the exponents in a list of BaseUnitExps.
     */
    template ExponentSum(BUEs...) {
        static if (BUEs.length == 0) {
            alias Rational!0 ExponentSum;
        } else {
            alias Sum!(BUEs[0].Exp, ExponentSum!(BUEs[1..$])) ExponentSum;
        }
    }

    template isExpPositive(BUE) {
        enum isExpPositive = (BUE.Exp.numerator > 0);
    }

    template isExpNegative(BUE) {
        enum isExpNegative = (BUE.Exp.numerator < 0);
    }
}

/**
 * Shorthands for defining base units with a single conversion factor to
 * another base unit.
 *
 * The conversion is done by simply multiplying/dividing the value by the
 * passed factor, which thus has to be defined for all value types this scaled
 * unit is used with.
 *
 * Note that a generic alias is accepted as scaling factor, which makes it
 * possible to use runtime values as scale factors without writing a custom
 * unit type.
 *
 * Example:
 * ---
 * // The following three lines define the same unit. Most of the time, the
 * // third syntax is the preferred one because it directly declares a unit
 * // instance.
 * alias ScaledUnit!(Metre, 0.0254, "inch", "in") Inch;
 * alias ScaledUnit!(metre, 0.0254, "inch", "in") Inch;
 * enum inch = scale!(metre, 0.0254, "inch", "in");
 * ---
 */
struct ScaledUnit(BaseUnit, alias toBaseFactor, string name,
    string symbol = null) if (isUnit!BaseUnit)
{
    mixin UnitImpl;

    static string toString(UnitString type = UnitString.name) {
        switch (type) {
            case UnitString.symbol:
              if (symbol) return symbol;
              else goto default;
            default: return name;
        }
    }

    alias TypeTuple!(Conversion!(BaseUnit, toBase, fromBase)) Conversions;

    static V toBase(V)(V v) {
        return cast(V)(v * toBaseFactor);
    }
    static V fromBase(V)(V v) {
        return cast(V)(v / toBaseFactor);
    }
}

/// ditto
template ScaledUnit(alias baseUnit, alias toBaseFactor, string name,
    string symbol = null) if (isUnitInstance!baseUnit)
{
    alias ScaledUnit!(typeof(baseUnit), toBaseFactor, name, symbol) ScaledUnit;
}

/// ditto
template scale(alias baseUnit, alias toBaseFactor, string name,
    string symbol = null) if (isUnitInstance!baseUnit)
{
    enum scale = ScaledUnit!(baseUnit, toBaseFactor, name, symbol).init;
}

version (unittest) {
    int fooToMile;
}
unittest {
    // Simple conversions should be possible at compile time.
    enum millifoo = scale!(foo, 0.001, "millifoo");
    static assert(convert!millifoo(1 * foo) == 1000 * millifoo);

    // Test using a global variable as conversion factor (possible because
    // ScaledUnit takes an alias).
    enum mile = scale!(foo, fooToMile, "mile");
    fooToMile = 1852;
    assert(convert!Foo(1 * mile) == 1852 * foo);

    // Conversion over two hops. This test isn't specific to ScaledUnit.
    enum microfoo = scale!(millifoo, 0.001, "microfoo");
    static assert(convert!microfoo(1 * foo) == 1000000 * microfoo);

    // Conversion over multiple hops in both directions. If A-->B represents
    // a conversion defined at A to B, the chain looks like this:
    // MicroFoo-->MilliFoo-->Foo<--KiloFoo<--MegaFoo.
    enum kilofoo = scale!(foo, 1000, "kilofoo");
    enum megafoo = scale!(kilofoo, 1000, "megafoo");
    static assert(convert!microfoo(1L * megafoo) == 10L^^12 * microfoo);
}

/**
 * A unit with a scaling prefix applied, e.g. $(D kilo(metre)).
 *
 * There is conceptually no difference between defining a regular conversion
 * and prefixing a unit. However, PrefixedUnit automatically generates the
 * name of the new unit, and it is able to fold multiple prefixes of the same
 * system, e.g. $(D milli(kilo(metre))) to just $(D metre).
 */
struct PrefixedUnit(BaseUnit, int exponent, alias System) if (
    isUnit!BaseUnit &&
    !(isPrefixedUnit!BaseUnit && (BaseUnit.prefixBase == System.base))
) {
    mixin UnitImpl;
    alias TypeTuple!(Conversion!(BaseUnit, toBase, fromBase)) Conversions;

    static string toString(UnitString type = UnitString.name) {
        string pre;
        final switch (type) {
            case UnitString.symbol:
                pre = prefix.symbol;
                break;
            case UnitString.name:
                pre = prefix.name;
                break;
        }
        static if (isDerivedUnit!BaseUnit) {
            return pre ~ "<" ~ getUnitString!BaseUnit(type) ~ ">";
        } else {
            return pre ~ getUnitString!BaseUnit(type);
        }
    }

    // This convoluted way of avoiding negative exponents to ^^ is used so
    // we can avoid to use floating point numbers (raising integers to
    // negative exponents is not defined). Need a better solution though.
    static V toBase(V)(V v) {
        static if (exponent < 0) {
            return cast(V)(v / (prefixBase ^^ (-exponent)));
        } else {
            return cast(V)(v * (prefixBase ^^ exponent));
        }
    }
    static V fromBase(V)(V v) {
        static if (exponent < 0) {
            return cast(V)(v * (prefixBase ^^ (-exponent)));
        } else {
            return cast(V)(v / (prefixBase ^^ exponent));
        }
    }

    private alias BaseUnit Base;
    private enum prefix = getPrefix!System(exponent);
    private enum prefixBase = System.base;
}

/// ditto
template PrefixedUnit(BaseUnit, int exponent, alias System) if (
    isPrefixedUnit!BaseUnit && (BaseUnit.prefixBase == System.base)
) {
    static if (exponent + BaseUnit.prefix.exponent == 0) {
        // If the exponents sum up to zero, just return the original unit.
        alias BaseUnit.Base PrefixedUnit;
    } else {
        alias PrefixedUnit!(BaseUnit.Base,
            exponent + BaseUnit.prefix.exponent, System) PrefixedUnit;
    }
}

/// ditto
template PrefixedUnit(alias baseUnit, int exponent, alias System) if (
    isUnitInstance!baseUnit
) {
    alias PrefixedUnit!(typeof(baseUnit), exponent, System)
        PrefixedUnit;
}

/**
 * A named prefix, part of a $(LREF PrefixSystem).
 */
struct Prefix {
    int exponent; /// The power the prefix represents.
    string name; /// The name of the prefix, prepended to unit names.
    string symbol; /// The symbol of the prefix, prepended to unit symbols.

    @trusted
    string toString() {
        return "(" ~ to!string(exponent) ~ ", " ~ name ~ ", " ~ symbol ~ ")";
    }
}

/**
 * A prefix system, used with $(LREF PrefixedUnit).
 *
 * Use the $(LREF DefinePrefixSystem) mixin to automatically generate a helper
 * function like $(D kilo()) for every prefix in the system.
 *
 * $(D getPrefixes) has to be a parameterless callable returning
 * $(LREF Prefix)[]. This scheme is used (instead of directly passing the
 * prefix array as a parameter) to reduce code bloat, because delegate
 * literals are mangled much shorter than array literals. The effect on the
 * binary size is quite strong because the mangled name of a PrefixSystem
 * instance is part of every symbol in which a PrefixedUnit is involved.
 *
 * Example:
 * ---
 * alias PrefixSystem!(10, { return [
 *     Prefix(-3, "milli", "m"),
 *     Prefix(3, "kilo", "k")
 * ]; }) System;
 * ---
 */
template PrefixSystem(long systemBase, alias getPrefixes)
    if (is(typeof(getPrefixes()) : Prefix[]))
{
    enum base = systemBase;
    enum prefixes = getPrefixes();
}

/**
 * Shorthand for defining prefix templates like $(D kilo!()).
 *
 * The created template, accessible via the result property, takes a unit
 * instance and applies a prefix from the given list of prefixes to it.
 *
 * Example:
 * ---
 * alias PrefixSystem!(10, { return [
 *     Prefix(-3, "milli", "m"),
 *     Prefix(3, "kilo", "k")
 * ]; }) System;
 * alias prefixTemplate!(-3, System) milli;
 * alias prefixTemplate!(3, System) kilo;
 * // Use the templates like this: milli!metre, kilo!metre, etc.
 * ---
 */
template prefixTemplate(int exponent, alias System) {
    template prefixTemplate(alias u) if (isUnitInstance!u) {
        enum prefixTemplate = PrefixedUnit!(u, exponent, System).init;
    }
}

/**
 * Mixin template for creating prefix functions for all the prefixes in a
 * prefix system. See $(LREF PrefixedUnit) and $(LREF prefixTemplate).
 *
 * Example:
 * ---
 * mixin DefinePrefixSystem!(PrefixSystem!(10, { return [
 *     Prefix(-3, "milli", "m"),
 *     Prefix(3, "kilo", "k")
 * ]; });
 * // Use milli!() and kilo!() as usual.
 * ---
 */
mixin template DefinePrefixSystem(alias System) {
    mixin({
        import std.conv;
        string code;
        foreach (p; System.prefixes) {
            code ~= "alias prefixTemplate!(" ~ to!string(p.exponent) ~
                ", System) " ~ p.name ~ ";";
        }
        return code;
    }());
}

unittest {
    alias PrefixSystem!(10, { return [
        Prefix(-6, "micro", "µ"),
        Prefix(-3, "milli", "m"),
        Prefix(3, "kilo", "k")
    ]; }) System;

    alias prefixTemplate!(3, System) kilo;
    alias prefixTemplate!(-3, System) milli;

    // FIXME: For reasons unknown, PrefixedUnit.toString() isn't CTFEable.
    enum kilofoo = kilo!foo;
    assert(kilofoo.toString() == "kilofoo");
    assert(kilofoo.toString(UnitString.symbol) == "kf");

    static assert(is(typeof(milli!(kilo!foo)) == Foo));

    enum microfoo = milli!(milli!foo);
    assert(microfoo.toString() == "microfoo");
    assert(microfoo.toString(UnitString.symbol) == "µf");

    static assert(!__traits(compiles, kilo(kilo(foo))),
        "Requesting a prefix not in the table didn't fail.");

    assert(convert!Foo(1 * kilo!foo) == 1000 * foo);

    enum millifoobar = milli!(foo * bar);
    assert(millifoobar.toString() == "milli<bar foo>");
    assert(millifoobar.toString(UnitString.symbol) == "m<br f>");
}

private {
    template isPrefixedUnit(T) {
        // I can't think of a *clean* way to check whether T is a
        // PrefixedUnit, so just use a duck typing-like approach (instead
        // of relying on the mangled names or such).
        static if (__traits(compiles, T.Base)) {
            enum isPrefixedUnit = isUnit!(T.Base) &&
                is(typeof(T.prefixBase) : long);
        } else {
            enum isPrefixedUnit = false;
        }
    }

    @trusted
    Prefix getPrefix(alias T)(int exponent) {
        foreach (t; T.prefixes) {
            if (t.exponent == exponent) {
                return t;
            }
        }
        assert(false, "Prefix for exponent " ~ to!string(exponent) ~
            " not defined in prefix list: " ~ to!string(T.prefixes));
    }
}


/*
 * Various compile-time helper functions/templates not specific to units.base.
 */
private {
    /*
     * Curries a given template by tying the first n arguments to particular
     * types (where n is the number of types passed to Curry).
     *
     * Example:
     * ---
     * struct Foo(T, U, V) {}
     * alias Curry!(Foo, A, B) CurriedFoo;
     * assert(is(CurriedFoo!(C) == Foo!(A, B, C)));
     * ---
     */
    template Curry(alias Target, T...) {
        template Curry(U...) {
            alias Target!(T, U) Curry;
        }
    }
    unittest {
        struct Test(T, U, V) {}
        alias Curry!(Test, Foo, Bar) CurriedTest;
        static assert(is(CurriedTest!Baz == Test!(Foo, Bar, Baz)));
    }

    /*
     * Creates a new type tuple containing the elements of the given one
     * several times in a row.
     */
    template RepeatTypeTuple(size_t times, T...) {
        static if (times == 0) {
            alias TypeTuple!() RepeatTypeTuple;
        } else {
            alias TypeTuple!(T, RepeatTypeTuple!(times - 1, T)) RepeatTypeTuple;
        }
    }
    unittest {
        static assert(is(RepeatTypeTuple!(3, int, float) ==
            TypeTuple!(int, float, int, float, int, float)));
    }

    /*
     * Finds the first item matching the template predicate F in the type
     * tuple T.
     *
     * If there is an occurence, it is aliased to Result, otherwise Result
     * does not exist.
     *
     * This really needs a better name, just as staticMap from std.typetuple
     * does.
     */
    template staticFind(alias F, T...) {
        static if (T.length > 0) {
            static if (F!(T[0])) {
                alias T[0] Result;
            } else {
                alias staticFind!(F, T[1..$]) staticFind;
            }
        }
    }

    /*
     * Given an array of indices, creates a new type tuple from the passed one
     * according to the index array.
     */
    template IndexedTuple(alias I, T...) {
        static if (I.length == 0) {
            alias TypeTuple!() IndexedTuple;
        } else {
            alias TypeTuple!(T[I[0]], IndexedTuple!(I[1 .. $], T)) IndexedTuple;
        }
    }

    /*
     * Creates a sorted index from the arguments.
     */
    size_t[] makeArgumentIndex(T...)(T t) {
        T[0][] elements;
        foreach (e; t) {
            elements ~= e;
        }

        auto indices = new size_t[elements.length];
        makeIndexCtfe(elements, indices);
        return indices;
    }
    unittest {
        assert(makeArgumentIndex("c", "d", "a", "b") == [2, 3, 0, 1]);
    }

    /*
     * Specialized version of std.algorithm.makeIndex because that currently
     * doesn't work with CTFE.
     *
     * Even though it is easily possible to make CTFE accept it, it silently
     * fails (for reasons not yet traced down).
     */
    void makeIndexCtfe(T)(T[] r, ref size_t[] index) {
        assert(r.length == index.length);
        if (index.length <= 1) return;

        // Can't use ref foreach here due to @@BUG3835@@.
        foreach (i, Unused; index) {
            index[i] = i;
        }

        // Just a simple insertion sort, but works in CTFE both before and
        // after Don's array handling overhaul.
        for (size_t i = 1; i < index.length; ++i) {
            auto current = index[i];
            auto j = i;
            while (j > 0 && (r[index[j - 1]] > r[current])) {
                index[j] = index[j - 1];
                --j;
            }
            index[j] = current;
        }
    }
}


/*
 * Compile-time rationals.
 */
import std.math : abs;
import std.numeric : gcd;

/**
 * A compile-time rational number.
 *
 * If you explicitely specify the denominator, be sure to use an *unsigned*
 * integer literal (e.g. 2u) – even though the template accepts only unsigned
 * integers anyway, this seems to make a difference.
 *
 * Note: This was tailored to the specific needs of the units library, and
 * isn't optimized at all.
 */
template Rational(int n) {
    alias Rational = Rational!(n, 1u);
}
template Rational(int n, int d) {
    alias Rational = Rational!(n, cast(uint)d);
}
template Rational(int n, uint d) {
    static if (gcd(cast(uint)abs(n), d) > 1) {
        alias Rational!(
            n / cast(int)gcd(cast(uint)abs(n), d),
            d / gcd(cast(uint)abs(n), d)
        ) Rational;
    } else {
        struct Rational {
            enum int numerator = n;
            enum uint denominator = d;
            enum double value = cast(double) n / d;
        }
    }
}

unittest {
    static assert(is(Rational!(2, 1u) == Rational!2));
    static assert(is(Rational!(6, 3u) == Rational!2));
}

template isRational(T) {
    // @@BUG@@: Uncommenting the explicit type check for Rational breaks the
    // unittests because some instance of Rational!(-1,1u) apparently isn't
    // matched.
    static if (is(typeof(T.numerator) : int) &&
        is(typeof(T.denominator) : uint) /+&&
        is(T : Rational!(T.numerator, T.denominator))+/
    ) {
        enum isRational = true;
    } else {
        enum isRational = false;
    }
}

unittest {
    static assert(isRational!(Rational!(-2, 1u)));
    static assert(!isRational!Foo);
}

/**
 * The sum of two compile-time rational numbers.
 */
template Sum(Lhs, Rhs) if (isRational!Lhs && isRational!Rhs) {
    // The extra cast(int) is needed because DMD apparently uses unsigned
    // literals otherwise (remove it to see the unit test below fail).
    alias Rational!(
        cast(int)((Lhs.numerator * Rhs.denominator) +
            (Rhs.numerator * Lhs.denominator)),
        cast(uint)(Lhs.denominator * Rhs.denominator)
    ) Sum;
}

unittest {
    static assert(is(
        Sum!(Rational!(1, 3u), Rational!(1, 6u)) == Rational!(1, 2u)
    ));

    static assert(is(
        Sum!(Rational!2, Rational!1) == Rational!3
    ));
}

/**
 * The difference between two compile-time rational numbers.
 */
template Difference(Lhs, Rhs) if (isRational!Lhs && isRational!Rhs) {
    // The extra cast(int) is needed because DMD apparently uses unsigned
    // literals otherwise (remove it to see the unit test below fail).
    alias Rational!(
        cast(int)((Lhs.numerator * Rhs.denominator) -
            (Rhs.numerator * Lhs.denominator)),
        Lhs.denominator * Rhs.denominator
    ) Difference;
}

unittest {
    static assert(is(
        Difference!(Rational!(1, 2u), Rational!(1, 3u)) == Rational!(1, 6u)
    ));
    static assert(is(
        Difference!(Rational!3, Rational!1) == Rational!2
    ));
}

/**
 * The product of two compile-time rational numbers.
 */
template Product(Lhs, Rhs) if (isRational!Lhs && isRational!Rhs) {
    alias Rational!(
        Lhs.numerator * Rhs.numerator,
        Lhs.denominator * Rhs.denominator
    ) Product;
}

unittest {
    static assert(is(
        Product!(Rational!(3, 2u), Rational!(2, 3u)) == Rational!1
    ));
}
