struct Foo(int x) {
    auto bar() {
		auto a = is(Foo!3) == is(Foo!3);
        Nonexistent();
    }
}

void main( ) {
    Foo!2 a;
}
