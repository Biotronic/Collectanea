struct Named(T, string name) {
    T value;
    alias value this;
}

template named(string name) {
    Named!(T, name) named(T)(T value) {
        return typeof(return)(value);
    }
}

void test(int arg1, Named!(int, "arg2") arg2, Named!(int, "arg3") arg3) {
}

void main() {
    test(4, named!"arg2"(4), named!"arg3"(12));
}