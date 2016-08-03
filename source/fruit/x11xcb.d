module fruit.x11xcb;

import xcb.xcb;
import derelict.util.loader;
import derelict.util.system;

extern (System) @nogc nothrow {
	alias PFN_XGetXCBConnection = xcb_connection_t* function(void* dpy);
}

__gshared {
	PFN_XGetXCBConnection XGetXCBConnection;
}

private {
	version (Posix)
		enum libNames = "libX11-xcb.so.1";

	else
		static assert(0, "Need to implement X11-xcb. libNames for this operating system.");
}

class DerelictX11XCBLoader : SharedLibLoader {
	this() {
		super(libNames);
	}

	protected override void loadSymbols() {
		bindFunc(cast(void**)&XGetXCBConnection, "XGetXCBConnection");
	}
}

__gshared DerelictX11XCBLoader DerelictX11XCB;

shared static this() {
	DerelictX11XCB = new DerelictX11XCBLoader();
}
