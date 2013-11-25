/*
 * International System of Units (SI) units and prefixes for use with
 * $(D std.units).
 *
 * The definitions have been taken from the NIST Special Publication 330,
 * $(WEB http://physics.nist.gov/Pubs/SP330/sp330.pdf, The International
 * System of Units), 2008 edition.
 *
 * Todo: $(UL
 *  $(LI Do something about the derived unit types being expanded in the
 *   generated documentation.)
 * )
 *
 * License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors: $(WEB klickverbot.at, David Nadlinger)
 */
module biotronic.si;

import biotronic.units;

/**
 * The full $(XREF units, PrefixSystem) of SI prefixes.
 *
 * For each prefix, a helper template like $(D kilo!()) for prefixing units
 * is provided (see $(XREF units, prefixTemplate)).
 */
alias PrefixSystem!(10, { return [
    Prefix(-24, "yocto", "y"),
    Prefix(-21, "zepto", "z"),
    Prefix(-18, "atto", "a"),
    Prefix(-15, "femto", "f"),
    Prefix(-12, "pico", "p"),
    Prefix(-9, "nano", "n"),
    Prefix(-6, "micro", "µ"),
    Prefix(-3, "milli", "m"),
    Prefix(-2, "centi", "c"),
    Prefix(-1, "deci", "d"),
    Prefix(1, "deka", "da"),
    Prefix(2, "hecto", "h"),
    Prefix(3, "kilo", "k"),
    Prefix(6, "mega", "M"),
    Prefix(9, "giga", "G"),
    Prefix(12, "tera", "T"),
    Prefix(15, "peta", "P"),
    Prefix(18, "exa", "E"),
    Prefix(21, "zetta", "Z"),
    Prefix(24, "yotta", "Y")
]; }) SiPrefixSystem;

mixin DefinePrefixSystem!(SiPrefixSystem);

alias BaseUnit!("Ampere", "A") Ampere;
alias BaseUnit!("candela", "cd") Candela;
alias BaseUnit!("gram", "g") Gram;
alias BaseUnit!("Kelvin", "K") Kelvin;
alias BaseUnit!("metre", "m") Metre;
alias BaseUnit!("mole", "mol") Mole;
alias BaseUnit!("second", "s") Second;
alias BaseUnit!("radian", "rad") Radian;
alias BaseUnit!("steradian", "sr") Steradian;

/**
 * SI base units.
 */
enum ampere = Ampere.init;
enum candela = Candela.init; /// ditto
enum gram = Gram.init;       /// ditto
enum kilogram = kilo!gram;   /// ditto
enum kelvin = Kelvin.init;   /// ditto
enum metre = Metre.init;     /// ditto
alias metre meter;           /// ditto
enum mole = Mole.init;       /// ditto
enum second = Second.init;   /// ditto

/**
 * SI supplementary units for angles.
 */
enum radian = Radian.init;
enum steradian = Steradian.init; /// ditto

/**
 * SI derived units.
 */
enum hertz = dimensionless / second;
enum newton = kilogram * metre / pow!2(second); /// ditto
enum pascal = newton / pow!2(metre);            /// ditto
enum joule = newton * metre;                    /// ditto
enum watt = joule / second;                     /// ditto
enum coulomb = ampere * second;                 /// ditto
enum volt = watt / ampere;                      /// ditto
enum farad = coulomb / volt;                    /// ditto
enum ohm = volt / ampere;                       /// ditto
enum siemens = ampere / volt;                   /// ditto
enum weber = volt * second;                     /// ditto
enum tesla = weber / pow!2(metre);              /// ditto
enum henry = weber / ampere;                    /// ditto
enum lumen = candela * steradian;               /// ditto
enum lux = lumen / pow!2(metre);                /// ditto
enum becquerel = dimensionless / second;        /// ditto
enum gray = joule / kilogram;                   /// ditto
enum sievert = joule / kilogram;                /// ditto
enum katal = mole / second;                     /// ditto
/*
unittest {
    auto work(Quantity!newton force, Quantity!metre displacement) {
        return force * displacement;
    }
    Quantity!(mole, V) idealGasAmount(V)(
        Quantity!(pascal, V) pressure,
        Quantity!(pow!3(meter), V) volume,
        Quantity!(kelvin, V) temperature
    ) {
        enum R = 8.314471 * joule / (kelvin * mole);
        return (pressure * volume) / (temperature * R);
    }

    enum force = 1.0 * newton;
    enum displacement = 1.0 * metre;
    enum Quantity!joule e = work(force, displacement);
    static assert(e == 1.0 * joule);

    enum T = (273. + 37.) * kelvin;
    enum p = 1.01325e5 * pascal;
    enum r = 0.5e-6 * meter;
    enum V = (4.0 / 3.0) * 3.141592 * pow!3(r);
    enum n = idealGasAmount!double(p, V, T); // Need to explicitly specify double due to @@BUG5801@@.
    static assert(n == 0xb.dd95ef4ddcb82f7p-59 * mole);

    static assert(convert!gram(2 * kilogram) == 2000 * gram);
    static assert(convert!kilogram(2000 * gram) == 2 * kilogram);
    static assert(convert!(milli!newton)(1000 * newton) == 1000000 * milli!newton);
}*/