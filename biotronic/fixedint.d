module biotronic.fixedint;

import std.traits : isMutable;

template isIntegerLike(T) {
    static if (isMutable!T)     {
        enum bool isIntegerLike = is(typeof({
            T n;
            n = 2;
            n = n;
            n <<= 1;
            n >>= 1;
            n += n;
            n += 2;
            n *= n;
            n *= 2;
            n /= n;
            n /= 2;
            n -= n;
            n -= 2;
            n %= 2;
            n %= n;
            bool foo = n < 2;
            bool bar = n == 2;
            bool goo = n < n + 1;
            bool tar = n == n;

            return n;
        }));
    } else {
        alias isIntegerLike = isIntegerLike!(Unqual!T);
    }
} unittest {
import std.typetuple : TypeTuple;
    foreach (T; TypeTuple!(byte, ubyte, short, ushort, int, uint, long, ulong)) {
        assert(isIntegerLike!T);
    }
    
    static struct S {}
    
    foreach (T; TypeTuple!(string, int*, S, float, double, real)) {
        assert(!isIntegerLike!T);
    }
}

struct Fixed(T, size_t offset) if (offset < (T.sizeof * 8) && offset > 0 && isIntegerLike!T) {
    
}

unittest {
    assert(is(Fixed!(int, 31)));
    assert(!is(Fixed!(int, 32)));
    assert(!is(Fixed!(int, 0)));
    assert(is(Fixed!(int, 1)));
}

void main() {
}