module fruit.vulkan.vkdestroy;

import erupted;

/// Basically a smart pointer struct, but targeted toward Vulkan types
struct VkDestroy(T) {
	alias obj this;

	this(genericDestroyer d) {
		destroyer = () => d(obj);
	}

	this(ref defaultDestroyer d) {
		auto pFun = &d;
		destroyer = () => (*pFun)(obj, null);
	}

	this(ref VkDestroy!VkInstance instance, ref instanceDestroyer d) {
		auto pIns = &instance;
		auto pFun = &d;
		destroyer = () => (*pFun)(pIns.obj, obj, null);
	}

	this(ref VkDestroy!VkDevice device, ref deviceDestroyer d) {
		auto pDev = &device;
		auto pFun = &d;
		destroyer = () => (*pFun)(pDev.obj, obj, null);
	}

	~this() {
		Clear();
	}

	void opAssign(T t) {
		Clear();
		obj = t;
	}

	void Clear() {
		if (obj && destroyer.funcptr)
			destroyer();

		obj = null;
	}

	@property T* Ptr() {
		Clear();
		return &obj;
	}

	T obj;
private:
	alias genericDestroyer = void delegate(T);
	alias defaultDestroyer = extern (C) void function(T, const(VkAllocationCallbacks)*) nothrow @nogc;
	alias instanceDestroyer = extern (C) void function(VkInstance, T, const(VkAllocationCallbacks)*) nothrow @nogc;
	alias deviceDestroyer = extern (C) void function(VkDevice, T, const(VkAllocationCallbacks)*) nothrow @nogc;

	void delegate() destroyer;
}

VkDestroy!T[] AllocVkDestroyer(T)(ulong size, VkDestroy!T val) {
	VkDestroy!T[] result = new VkDestroy!T[size];
	foreach (ref el; result)
		el = val;
	return result;
}
