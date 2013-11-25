template bar(T...) {
    alias bar = void;
}

void foo()() {}

void main() {
    assert(!__traits(compiles, {struct A{bar!foo tmp;}}));
    assert(!is(typeof({struct A{bar!foo tmp;}})));
}