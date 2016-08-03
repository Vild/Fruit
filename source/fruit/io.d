module fruit.io;

import std.stdio;

ubyte[] readFile(string file) {
	File f = File(file, "rb");
	scope (exit)
		f.close();

	ulong size = f.size();
	assert(size < ulong.max);

	ubyte[] data = new ubyte[](size);
	f.rawRead(data);
	return data;
}
