module biotronic.DCC.util.getlasterrorhandler;

import win32.windows;

import std.traits;

class glException : Exception {
public:
	this(string file = __FILE__, int line = __LINE__) {
		errorCode = GetLastError();
		auto errorCode = GetLastError();

		char* buf;
		size_t size = FormatMessage(FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS,
									 null, errorCode, (LANG_NEUTRAL << 10) |SUBLANG_DEFAULT, buf, 0, null);

		string result = buf[0..size].dup;

		LocalFree(buf);
		
		super(result, file, line);
	}
private:
	int errorCode;
}

auto safe(alias fn)(ParameterTypeTuple!fn args) {
	return enforce(fn(args));
}
auto glSafe(alias fn)(ParameterTypeTuple!fn args) {
	return glEnforce(fn(args));
}

auto glEnforce(T)(lazy T value) {
	auto tmp = value;
	if (!!tmp) {
		return tmp;
	} else {
		throw new glException;
	}
}