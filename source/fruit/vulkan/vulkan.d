module fruit.vulkan.vulkan;

import std.stdio;
import std.string;
import std.exception;
import std.algorithm;

import fruit.other.window;
import fruit.other.x11xcb;
import fruit.other.io;
import fruit.other.linalg;
import fruit.vulkan.vkdestroy;
import fruit.vulkan.vertex;
import fruit.vulkan.buffer;

import erupted;

enum ENGINE_NAME = "Avocado";
enum ENGINE_VERSION = VK_MAKE_VERSION(1, 0, 0);

//dfmt off
immutable Vertex[] vertices = [
	Vertex(vec3(-0.5f, -0.5f, 0.0f), vec3(1.0f, 0.0f, 0.0f)),
	Vertex(vec3(0.5f, -0.5f, 0.0f), vec3(0.0f, 1.0f, 0.0f)),
	Vertex(vec3(0.5f, 0.5f, 0.0f), vec3(0.0f, 0.0f, 1.0f)),
	Vertex(vec3(-0.5f, 0.5f, 0.0f), vec3(1.0f, 1.0f, 1.0f))
];
immutable ushort[] indices = [
	0, 1, 2,
	2, 3, 0
];
//dfmt on

void enforceVK(VkResult res) {
	import std.conv : to;

	enforce(res == VkResult.VK_SUCCESS, res.to!string);
}

shared static this() {
	DerelictErupted.load();
	DerelictX11XCB.load();
}

class Vulkan {
public:
	this(string name, uint major, uint minor, uint patch, Window window) {
		const(char*)[] layers;
		this.window = window;

		createVkDestroy();

		createInstance(name, major, minor, patch, layers);
		createSurface(window);
		selectPhysDevice();
		createDevice(layers);
		createSwapChain();
		createImageViews();
		createRenderPass();
		createGraphicsPipeline();
		createFramebuffers();
		createCommandPool();
		createVertexBuffer();
		createIndexBuffer();
		createCommandBuffers();
		createSemaphores();
	}

	~this() {
		WaitForIdle();
	}

	void RenderFrame() {
		WaitForIdle();
		uint imageIndex;
		VkResult r = vkAcquireNextImageKHR(device, swapChain, ulong.max, imageAvailableSemaphore, VK_NULL_HANDLE, &imageIndex);
		if (r == VK_ERROR_OUT_OF_DATE_KHR) {
			RecreateRendering();
			return RenderFrame();
		} else if (r != VK_SUBOPTIMAL_KHR)
			r.enforceVK;

		VkSemaphore[] waitSemaphores = [imageAvailableSemaphore];
		VkPipelineStageFlags[] waitStages = [VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT];
		VkSemaphore[] signalSemaphores = [renderFinishedSemaphore];
		//dfmt off
		VkSubmitInfo submitInfo = {
			waitSemaphoreCount: 1,
			pWaitSemaphores: waitSemaphores.ptr,
			pWaitDstStageMask: waitStages.ptr,
			commandBufferCount: 1,
			pCommandBuffers: &commandBuffers[imageIndex],
			signalSemaphoreCount: 1,
			pSignalSemaphores: signalSemaphores.ptr
		};
		//dfmt on
		vkQueueSubmit(graphicsQueue, 1, &submitInfo, VK_NULL_HANDLE).enforceVK;

		VkSwapchainKHR[] swapChains = [swapChain];
		//dfmt off
		VkPresentInfoKHR presentInfo = {
			waitSemaphoreCount: 1,
			pWaitSemaphores: signalSemaphores.ptr,
			swapchainCount: 1,
			pSwapchains: swapChains.ptr,
			pImageIndices: &imageIndex,
			pResults: null
		};
		//dfmt on

		r = vkQueuePresentKHR(presentQueue, &presentInfo);
		if (r == VK_ERROR_OUT_OF_DATE_KHR || r == VK_SUBOPTIMAL_KHR) {
			RecreateRendering();
		} else
			r.enforceVK;
	}

	void WaitForIdle() {
		vkDeviceWaitIdle(device);
	}

	void RecreateRendering() {
		WaitForIdle();

		createSwapChain();
		createImageViews();
		createRenderPass();
		createGraphicsPipeline();
		createFramebuffers();
		createCommandBuffers();

		RenderFrame();
	}

	@property ref VkPhysicalDevice PhysDevice() {
		return physDevice;
	}

	@property ref VkDestroy!VkDevice Device() {
		return device;
	}

	@property ref VkDestroy!VkCommandPool CommandPool() {
		return commandPool;
	}

	@property ref VkQueue GraphicsQueue() {
		return graphicsQueue;
	}

private:
	struct swapChainSupportDetails {
		VkSurfaceCapabilitiesKHR capabilities;
		VkSurfaceFormatKHR[] formats;
		VkPresentModeKHR[] presentModes;
	}

	Window window;

	VkDestroy!VkInstance instance;
	debug VkDestroy!VkDebugReportCallbackEXT callback;
	VkDestroy!VkSurfaceKHR surface;
	VkPhysicalDevice physDevice;
	VkDestroy!VkDevice device;

	int graphicsFamily;
	int presentFamily;
	VkQueue graphicsQueue;
	VkQueue presentQueue;

	VkDestroy!VkSwapchainKHR swapChain;
	VkImage[] swapChainImages;
	VkFormat swapChainImageFormat;
	VkExtent2D swapChainExtent;
	VkDestroy!(VkImageView[]) swapChainImageViews;

	VkDestroy!VkShaderModule vertShaderModule;
	VkDestroy!VkShaderModule fragShaderModule;

	VkDestroy!VkRenderPass renderPass;

	VkDestroy!VkPipelineLayout pipelineLayout;
	VkDestroy!VkPipeline graphicsPipeline;

	VkDestroy!(VkFramebuffer[]) swapChainFramebuffers;

	VkDestroy!VkCommandPool commandPool;

	VkDestroy!Buffer vertexBuffer;
	VkDestroy!Buffer indexBuffer;

	VkDestroy!(VkCommandBuffer[]) commandBuffers;

	VkDestroy!VkSemaphore imageAvailableSemaphore;
	VkDestroy!VkSemaphore renderFinishedSemaphore;

	void createVkDestroy() {
		instance.__ctor(vkDestroyInstance);
		debug callback.__ctor(instance, vkDestroyDebugReportCallbackEXT);
		surface.__ctor(instance, vkDestroySurfaceKHR);
		device.__ctor(vkDestroyDevice);
		swapChain.__ctor(device, vkDestroySwapchainKHR);

		swapChainImageViews.__ctor(() {
			foreach (imageView; swapChainImageViews)
				vkDestroyImageView(device, imageView, null);
		});

		vertShaderModule.__ctor(device, vkDestroyShaderModule);
		fragShaderModule.__ctor(device, vkDestroyShaderModule);

		renderPass.__ctor(device, vkDestroyRenderPass);

		pipelineLayout.__ctor(device, vkDestroyPipelineLayout);
		graphicsPipeline.__ctor(device, vkDestroyPipeline);

		swapChainFramebuffers.__ctor(() {
			foreach (frameBuffer; swapChainFramebuffers)
				vkDestroyFramebuffer(device, frameBuffer, null);
		});

		commandPool.__ctor(device, vkDestroyCommandPool);

		vertexBuffer.__ctor(() { vertexBuffer.obj.destroy; });
		indexBuffer.__ctor(() { indexBuffer.obj.destroy; });

		commandBuffers.__ctor(() {
			if (commandBuffers.length)
				vkFreeCommandBuffers(device, commandPool, cast(uint)commandBuffers.length, commandBuffers.ptr);
		});

		renderFinishedSemaphore.__ctor(device, vkDestroySemaphore);
		imageAvailableSemaphore.__ctor(device, vkDestroySemaphore);
	}

	void createInstance(string name, uint major, uint minor, uint patch, ref const(char*)[] layers) {
		VkExtensionProperties[] availableExtensions;
		VkLayerProperties[] availableLayers;
		getExtensionsAndLayers(availableExtensions, availableLayers);
		scope (exit) {
			availableExtensions.destroy;
			availableLayers.destroy;
		}

		//TODO: Switch these? A foreach would be better to no loop throu the whole list each time
		alias hasExtension = (extension) => !!availableExtensions.map!(a => a.extensionName.ptr.fromStringz).count(extension);
		alias hasLayer = (layer) => !!availableLayers.map!(a => a.layerName.ptr.fromStringz).count(layer);

		enforce(hasExtension(VK_KHR_SURFACE_EXTENSION_NAME));
		const(char*)[] extensions = [VK_KHR_SURFACE_EXTENSION_NAME];

		version (Have_xcb_d) {
			enforce(hasExtension(VK_KHR_XCB_SURFACE_EXTENSION_NAME));
			extensions ~= VK_KHR_XCB_SURFACE_EXTENSION_NAME;
		} else
			pragma(error, "Unsupported surface extenstion");

		debug {
			enum VK_LAYER_LUNARG_standard_validation = "VK_LAYER_LUNARG_standard_validation";
			enforce(hasExtension(VK_EXT_DEBUG_REPORT_EXTENSION_NAME));
			extensions ~= VK_EXT_DEBUG_REPORT_EXTENSION_NAME;
			enforce(hasLayer(VK_LAYER_LUNARG_standard_validation), "Debug builds require 'VK_LAYER_LUNARG_standard_validation'");
			layers ~= VK_LAYER_LUNARG_standard_validation;
		}

		//dfmt off
		VkApplicationInfo appInfo = {
			pApplicationName: name.toStringz,
			applicationVersion: VK_MAKE_VERSION(major, minor, patch),
			pEngineName: ENGINE_NAME,
			engineVersion: ENGINE_VERSION,
			apiVersion : VK_MAKE_VERSION(1, 0, 2)
		};

		VkInstanceCreateInfo instInfo = {
			pApplicationInfo: &appInfo,
			enabledLayerCount: cast(uint)layers.length,
			ppEnabledLayerNames: layers.ptr,
			enabledExtensionCount: cast(uint)extensions.length,
			ppEnabledExtensionNames: extensions.ptr,
		};
		//dfmt on

		vkCreateInstance(&instInfo, null, instance.Ptr).enforceVK;
		loadInstanceLevelFunctions(instance);

		debug {
			//dfmt off
			VkDebugReportCallbackCreateInfoEXT callbackCreateInfo = {
				flags: VK_DEBUG_REPORT_ERROR_BIT_EXT | VK_DEBUG_REPORT_WARNING_BIT_EXT | VK_DEBUG_REPORT_PERFORMANCE_WARNING_BIT_EXT,
				pfnCallback: cast(PFN_vkDebugReportCallbackEXT)&debugCallback
			};
			//dfmt on
			vkCreateDebugReportCallbackEXT(instance, &callbackCreateInfo, null, callback.Ptr).enforceVK;
		}
	}

	void createSurface(Window window) {
		SDL_SysWMinfo wminfo;
		wminfo.version_ = SDL_version(SDL_MAJOR_VERSION, SDL_MINOR_VERSION, SDL_PATCHLEVEL);
		enforce(SDL_GetWindowWMInfo(window.SDLWindow, &wminfo));

		switch (wminfo.subsystem) {
			version (Have_xcb_d) {
		case SDL_SYSWM_X11:
				//dfmt off
				VkXcbSurfaceCreateInfoKHR createInfo = {
					connection: XGetXCBConnection(wminfo.info.x11.display),
					window: wminfo.info.x11.window
				};
				//dfmt on

				vkCreateXcbSurfaceKHR(instance, &createInfo, null, surface.Ptr).enforceVK;
				break;
			}
		default:
			writeln("Unsupported subsystem %i", wminfo.subsystem);
			enforce(0, "Unsupported subsystem");
			break;
		}
	}

	void getExtensionsAndLayers(ref VkExtensionProperties[] availableExtensions, ref VkLayerProperties[] availableLayers) {
		uint count = 0;

		vkEnumerateInstanceExtensionProperties(null, &count, null).enforceVK;
		availableExtensions.length = count;
		vkEnumerateInstanceExtensionProperties(null, &count, availableExtensions.ptr).enforceVK;

		vkEnumerateInstanceLayerProperties(&count, null).enforceVK;
		availableLayers.length = count;
		vkEnumerateInstanceLayerProperties(&count, availableLayers.ptr).enforceVK;
	}

	void selectPhysDevice() {
		uint numPhysDevices;
		vkEnumeratePhysicalDevices(instance, &numPhysDevices, null).enforceVK;
		enforce(numPhysDevices, "No physical devices available");

		VkPhysicalDevice[] physDevices;
		physDevices.length = numPhysDevices;
		scope (exit)
			physDevices.destroy;
		vkEnumeratePhysicalDevices(instance, &numPhysDevices, physDevices.ptr).enforceVK;

		uint score;
		foreach (VkPhysicalDevice device; physDevices) {
			const uint currentScore = scorePhysDevice(device);
			if (currentScore > score) {
				physDevice = device;
				score = currentScore;
			}
		}

		enforce(physDevice, "Couldn't select a suitable physical device");
	}

	VkQueueFamilyProperties[] getQueueFamilies(VkPhysicalDevice physDevice) {
		VkQueueFamilyProperties[] queueFamilies;
		uint count;

		vkGetPhysicalDeviceQueueFamilyProperties(physDevice, &count, null);
		queueFamilies.length = count;
		vkGetPhysicalDeviceQueueFamilyProperties(physDevice, &count, queueFamilies.ptr);

		return queueFamilies;
	}

	bool hasRenderingQueueFamily(VkPhysicalDevice physDevice) {
		VkQueueFamilyProperties[] queueFamilies = getQueueFamilies(physDevice);
		scope (exit)
			queueFamilies.destroy;

		foreach (queueFamily; queueFamilies)
			if (queueFamily.queueCount && queueFamily.queueFlags & VK_QUEUE_GRAPHICS_BIT)
				return true;
		return false;
	}

	VkExtensionProperties[] getDeviceExtensions(VkPhysicalDevice physDevice) {
		VkExtensionProperties[] availableDeviceExtensions;
		uint count;

		vkEnumerateDeviceExtensionProperties(physDevice, null, &count, null).enforceVK;
		availableDeviceExtensions.length = count;
		vkEnumerateDeviceExtensionProperties(physDevice, null, &count, availableDeviceExtensions.ptr).enforceVK;

		return availableDeviceExtensions;
	}

	bool hasSwapChain(VkPhysicalDevice physDevice) {
		VkExtensionProperties[] availableDeviceExtensions = getDeviceExtensions(physDevice);
		scope (exit)
			availableDeviceExtensions.destroy;

		foreach (prop; availableDeviceExtensions)
			if (prop.extensionName.ptr.fromStringz == VK_KHR_SWAPCHAIN_EXTENSION_NAME)
				return true;
		return false;
	}

	swapChainSupportDetails querySwapChainSupport(VkPhysicalDevice physDevice) {
		swapChainSupportDetails details;
		uint count;

		vkGetPhysicalDeviceSurfaceCapabilitiesKHR(physDevice, surface, &details.capabilities).enforceVK;
		vkGetPhysicalDeviceSurfaceFormatsKHR(physDevice, surface, &count, null).enforceVK;
		details.formats.length = count;
		vkGetPhysicalDeviceSurfaceFormatsKHR(physDevice, surface, &count, details.formats.ptr).enforceVK;

		vkGetPhysicalDeviceSurfacePresentModesKHR(physDevice, surface, &count, null).enforceVK;
		details.presentModes.length = count;
		vkGetPhysicalDeviceSurfacePresentModesKHR(physDevice, surface, &count, details.presentModes.ptr).enforceVK;

		return details;
	}

	uint scorePhysDevice(VkPhysicalDevice physDevice) {
		VkPhysicalDeviceProperties properties;
		VkPhysicalDeviceFeatures features;
		vkGetPhysicalDeviceProperties(physDevice, &properties);
		vkGetPhysicalDeviceFeatures(physDevice, &features);

		uint score;
		if (properties.deviceType == VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU)
			score += 10_000;

		score += properties.limits.maxImageDimension2D;

		auto details = querySwapChainSupport(physDevice);

		if (!features.geometryShader || !hasRenderingQueueFamily(physDevice) || !hasSwapChain(physDevice)
				|| !details.formats.length || !details.presentModes.length)
			score = 0;
		writeln("Device: ", properties.deviceName, " got score: ", score);

		return score;
	}

	void createDevice(const(char*)[] layers) {
		VkQueueFamilyProperties[] queueFamilies = getQueueFamilies(physDevice);
		scope (exit)
			queueFamilies.destroy;

		graphicsFamily = -1;
		presentFamily = -1;

		foreach (uint i, queueFamily; queueFamilies) {
			if (!queueFamily.queueCount)
				continue;
			if (queueFamily.queueFlags & VK_QUEUE_GRAPHICS_BIT)
				graphicsFamily = i;
			/*else*/{ //TODO: Research if they can be the same queue family
				VkBool32 presentSupport = false;
				vkGetPhysicalDeviceSurfaceSupportKHR(physDevice, i, surface, &presentSupport).enforceVK;
				if (presentSupport)
					presentFamily = i;
			}
			if (graphicsFamily != -1 && presentFamily != -1)
				break;
		}

		VkDeviceQueueCreateInfo[] queueCreateInfos;
		int[] uniqueQueueFamilies = [graphicsFamily, presentFamily];
		foreach (queueFamily; uniqueQueueFamilies) {
			float queuePriority = 1.0f;
			//dfmt off
			VkDeviceQueueCreateInfo queueCreateInfo = {
				queueFamilyIndex: queueFamily,
				queueCount: 1,
				pQueuePriorities: &queuePriority
			};
			//dfmt on
			queueCreateInfos ~= queueCreateInfo;
		}

		VkPhysicalDeviceFeatures deviceFeatures = {};

		const(char*)[] extensions = [VK_KHR_SWAPCHAIN_EXTENSION_NAME];
		//dfmt off
		VkDeviceCreateInfo deviceCreateInfo = {
			pQueueCreateInfos: queueCreateInfos.ptr,
			queueCreateInfoCount: cast(uint)queueCreateInfos.length,
			pEnabledFeatures: &deviceFeatures,
			enabledLayerCount: cast(uint)layers.length,
			enabledExtensionCount: cast(uint)extensions.length,
			ppEnabledExtensionNames: extensions.ptr,
			ppEnabledLayerNames: layers.ptr,
		};
		//dfmt on

		vkCreateDevice(physDevice, &deviceCreateInfo, null, device.Ptr).enforceVK;
		enforce(device.obj, "Couldn't create device");

		loadDeviceLevelFunctions(device);
		vkGetDeviceQueue(device, graphicsFamily, 0, &graphicsQueue);
		vkGetDeviceQueue(device, presentFamily, 0, &presentQueue);

		writeln("graphicsFamily: ", graphicsFamily, " graphicsQueue: ", graphicsQueue);
		writeln("presentFamily: ", presentFamily, " presentQueue: ", presentQueue);
	}

	VkSurfaceFormatKHR chooseSwapSurfaceFormat(VkSurfaceFormatKHR[] availableFormats) {
		auto bestCase = VkSurfaceFormatKHR(VK_FORMAT_B8G8R8A8_UNORM, VK_COLOR_SPACE_SRGB_NONLINEAR_KHR);

		if (availableFormats.length == 1 && availableFormats[0].format == VK_FORMAT_UNDEFINED) // No preferred format
			return bestCase;

		foreach (format; availableFormats)
			if (format == bestCase)
				return format;

		return availableFormats[0];
	}

	VkPresentModeKHR chooseSwapPresentMode(VkPresentModeKHR[] availablePresentModes) {
		foreach (mode; availablePresentModes)
			if (mode == VK_PRESENT_MODE_MAILBOX_KHR)
				return mode;

		return VK_PRESENT_MODE_FIFO_KHR;
	}

	VkExtent2D chooseSwapExtent(VkSurfaceCapabilitiesKHR capabilities) {
		if (capabilities.currentExtent.width != uint.max)
			return capabilities.currentExtent;

		//dfmt off
		VkExtent2D actualExtent = {
			width: window.Size.x.clamp(capabilities.minImageExtent.width, capabilities.maxImageExtent.width),
			height: window.Size.y.clamp(capabilities.minImageExtent.height, capabilities.maxImageExtent.height)
		};
		//dfmt on

		return actualExtent;
	}

	void createSwapChain() {
		swapChainSupportDetails swapChainSupport = querySwapChainSupport(physDevice);

		VkSurfaceFormatKHR surfaceFormat = chooseSwapSurfaceFormat(swapChainSupport.formats);
		VkPresentModeKHR presentMode = chooseSwapPresentMode(swapChainSupport.presentModes);
		VkExtent2D extent = chooseSwapExtent(swapChainSupport.capabilities);

		uint imageCount = swapChainSupport.capabilities.minImageCount + 1;
		if (swapChainSupport.capabilities.maxImageCount > 0)
			imageCount = swapChainSupport.capabilities.maxImageCount.min(swapChainSupport.capabilities.maxImageCount);

		VkSwapchainKHR oldSwapchain = swapChain.obj;
		//dfmt off
		VkSwapchainCreateInfoKHR createInfo = {
			surface: surface,
			minImageCount: imageCount,
			imageFormat: surfaceFormat.format,
			imageColorSpace: surfaceFormat.colorSpace,
			imageExtent: extent,
			imageArrayLayers: 1,
			imageUsage: VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,

			preTransform: swapChainSupport.capabilities.currentTransform,
			compositeAlpha: VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
			presentMode: presentMode,
			clipped: VK_TRUE,
			oldSwapchain: oldSwapchain
		};
		//dfmt on

		uint[] queueFamilyIndices = [graphicsFamily, presentFamily];

		if (graphicsFamily != presentFamily) {
			createInfo.imageSharingMode = VK_SHARING_MODE_CONCURRENT;
			createInfo.queueFamilyIndexCount = 2;
			createInfo.pQueueFamilyIndices = queueFamilyIndices.ptr;
		} else {
			createInfo.imageSharingMode = VK_SHARING_MODE_EXCLUSIVE; // Better performance
			createInfo.queueFamilyIndexCount = 0; // Optional
			createInfo.pQueueFamilyIndices = null; // Optional
		}

		VkSwapchainKHR newSwapChain;
		vkCreateSwapchainKHR(device, &createInfo, null, &newSwapChain).enforceVK;
		swapChain = newSwapChain;

		uint count;
		vkGetSwapchainImagesKHR(device, swapChain, &count, null).enforceVK;
		swapChainImages.length = count;
		vkGetSwapchainImagesKHR(device, swapChain, &count, swapChainImages.ptr).enforceVK;
		swapChainImageFormat = surfaceFormat.format;
		swapChainExtent = extent;
	}

	void createImageViews() {
		swapChainImageViews = new VkImageView[swapChainImages.length];

		foreach (uint i, ref image; swapChainImages) {
			//dfmt off
			VkImageViewCreateInfo createInfo = {
				image: image,
				viewType: VK_IMAGE_VIEW_TYPE_2D,
				format: swapChainImageFormat,
				components: VkComponentMapping(VK_COMPONENT_SWIZZLE_IDENTITY, VK_COMPONENT_SWIZZLE_IDENTITY, VK_COMPONENT_SWIZZLE_IDENTITY, VK_COMPONENT_SWIZZLE_IDENTITY),
				subresourceRange: VkImageSubresourceRange(VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
			};
			//dfmt on
			vkCreateImageView(device, &createInfo, null, &swapChainImageViews[i]);
		}
	}

	void createShaderModule(ubyte[] code, ref VkDestroy!VkShaderModule shaderModule) {
		//dfmt off
		VkShaderModuleCreateInfo createInfo = {
			codeSize: code.length,
			pCode: cast(const(uint)*)code.ptr
		};
		//dfmt on

		vkCreateShaderModule(device, &createInfo, null, shaderModule.Ptr).enforceVK;
	}

	void createRenderPass() {
		//dfmt off
		VkAttachmentDescription colorAttachment = {
			format: swapChainImageFormat,
			samples: VK_SAMPLE_COUNT_1_BIT,
			loadOp: VK_ATTACHMENT_LOAD_OP_CLEAR,
			storeOp: VK_ATTACHMENT_STORE_OP_STORE,
			stencilLoadOp: VK_ATTACHMENT_LOAD_OP_DONT_CARE,
			stencilStoreOp: VK_ATTACHMENT_STORE_OP_DONT_CARE,
			initialLayout: VK_IMAGE_LAYOUT_UNDEFINED,
			finalLayout: VK_IMAGE_LAYOUT_PRESENT_SRC_KHR
		};

		VkAttachmentReference colorAttachmentRef = {
			attachment: 0,
			layout: VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL
		};

		VkSubpassDescription subPass = {
			pipelineBindPoint: VK_PIPELINE_BIND_POINT_GRAPHICS,
			colorAttachmentCount: 1,
			pColorAttachments: &colorAttachmentRef
		};


		VkSubpassDependency dependency = {
			srcSubpass: VK_SUBPASS_EXTERNAL,
			dstSubpass: 0,
			srcStageMask: VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT,
			srcAccessMask: VK_ACCESS_MEMORY_READ_BIT,
			dstStageMask: VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
			dstAccessMask: VK_ACCESS_COLOR_ATTACHMENT_READ_BIT | VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT
		};

		VkRenderPassCreateInfo renderPassInfo = {
			attachmentCount: 1,
			pAttachments: &colorAttachment,
			subpassCount: 1,
			pSubpasses: &subPass,
			dependencyCount: 1,
			pDependencies: &dependency
		};
		//dfmt on

		vkCreateRenderPass(device, &renderPassInfo, null, renderPass.Ptr).enforceVK;
	}

	void createGraphicsPipeline() {
		auto vertShaderCode = readFile("res/shader/generic.vert.spv");
		auto fragShaderCode = readFile("res/shader/generic.frag.spv");

		createShaderModule(vertShaderCode, vertShaderModule);
		createShaderModule(fragShaderCode, fragShaderModule);

		//dfmt off
		VkPipelineShaderStageCreateInfo vertShaderStageInfo = {
			stage: VK_SHADER_STAGE_VERTEX_BIT,
			_module: vertShaderModule,
			pName: "main".toStringz
		};
		VkPipelineShaderStageCreateInfo fragShaderStageInfo = {
			stage: VK_SHADER_STAGE_FRAGMENT_BIT,
			_module: fragShaderModule,
			pName: "main".toStringz
		};
		//dfmt on

		VkPipelineShaderStageCreateInfo[] shaderStages = [vertShaderStageInfo, fragShaderStageInfo];

		VkVertexInputBindingDescription bindingDescription = Vertex.getBindingDescription();
		VkVertexInputAttributeDescription[] attributeDescriptions = Vertex.getAttributeDescriptions();
		//dfmt off
		VkPipelineVertexInputStateCreateInfo vertexInputInfo = {
			//flags,
			vertexBindingDescriptionCount: 1,
			pVertexBindingDescriptions: &bindingDescription,
			vertexAttributeDescriptionCount: cast(uint)attributeDescriptions.length,
			pVertexAttributeDescriptions: attributeDescriptions.ptr
		};

		VkPipelineInputAssemblyStateCreateInfo inputAssembly = {
			topology: VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
			primitiveRestartEnable: VK_FALSE
		};

		VkViewport viewport = {
			x: 0.0f,
			y: 0.0f,
			width: cast(float)swapChainExtent.width,
			height: cast(float)swapChainExtent.height,
			minDepth: 0.0f,
			maxDepth: 1.0f
		};

		VkRect2D scissor = {
			offset: VkOffset2D(0, 0),
			extent: swapChainExtent
		};

		VkPipelineViewportStateCreateInfo viewportState = {
			viewportCount: 1,
			pViewports: &viewport,
			scissorCount: 1,
			pScissors: &scissor
		};

		VkPipelineRasterizationStateCreateInfo rasterizer = {
			depthClampEnable: VK_FALSE,
			rasterizerDiscardEnable: VK_FALSE,
			polygonMode: VK_POLYGON_MODE_FILL,
			lineWidth: 1.0f,
			cullMode: VK_CULL_MODE_BACK_BIT,
			frontFace: VK_FRONT_FACE_CLOCKWISE,

			depthBiasEnable: VK_FALSE,
			depthBiasConstantFactor: 0.0f, // Optional
			depthBiasClamp: 0.0f, // Optional
			depthBiasSlopeFactor: 0.0f // Optional
		};

		VkPipelineMultisampleStateCreateInfo multisampling = {
			sampleShadingEnable: VK_FALSE,
			rasterizationSamples: VK_SAMPLE_COUNT_1_BIT,
			minSampleShading: 1.0f, // Optional
			pSampleMask: null, /// Optional
			alphaToCoverageEnable: VK_FALSE, // Optional
			alphaToOneEnable: VK_FALSE // Optional
		};

		VkPipelineColorBlendAttachmentState colorBlendAttachment = {
			colorWriteMask: VK_COLOR_COMPONENT_R_BIT | VK_COLOR_COMPONENT_G_BIT | VK_COLOR_COMPONENT_B_BIT | VK_COLOR_COMPONENT_A_BIT,
			blendEnable: VK_FALSE,
			srcColorBlendFactor: VK_BLEND_FACTOR_ONE, // Optional
			dstColorBlendFactor: VK_BLEND_FACTOR_ZERO, // Optional
			colorBlendOp: VK_BLEND_OP_ADD, // Optional
			srcAlphaBlendFactor: VK_BLEND_FACTOR_ONE, // Optional
			dstAlphaBlendFactor: VK_BLEND_FACTOR_ZERO, // Optional
			alphaBlendOp: VK_BLEND_OP_ADD // Optional
		};

		VkPipelineColorBlendStateCreateInfo colorBlending = {
			sType: VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
			logicOpEnable: VK_FALSE,
			logicOp: VK_LOGIC_OP_COPY, // Optional
			attachmentCount: 1,
			pAttachments: &colorBlendAttachment,
			blendConstants: [0f, 0f, 0f, 0f]
		};

		/+VkDynamicState[] dynamicStates = [VK_DYNAMIC_STATE_VIEWPORT, VK_DYNAMIC_STATE_LINE_WIDTH];

		VkPipelineDynamicStateCreateInfo dynamicState = {
			dynamicStateCount: 2,
			pDynamicStates: dynamicStates
		};+/

		VkPipelineLayoutCreateInfo pipelineLayoutInfo = {
			setLayoutCount: 0, // Optional
			pSetLayouts: null, // Optional
			pushConstantRangeCount: 0, // Optional
			pPushConstantRanges: null // Optional
		};
		//dfmt on

		vkCreatePipelineLayout(device, &pipelineLayoutInfo, null, pipelineLayout.Ptr).enforceVK;

		//dfmt off
		VkGraphicsPipelineCreateInfo pipelineInfo = {
			stageCount: 2,
			pStages: shaderStages.ptr,
			pVertexInputState: &vertexInputInfo,
			pInputAssemblyState: &inputAssembly,
			pViewportState: &viewportState,
			pRasterizationState: &rasterizer,
			pMultisampleState: &multisampling,
			pDepthStencilState: null, // Optional
			pColorBlendState: &colorBlending,
			pDynamicState: null, // Optional
			layout: pipelineLayout,
			renderPass: renderPass,
			subpass: 0,
			basePipelineHandle: VK_NULL_HANDLE,
			basePipelineIndex: -1 // Optional
		};
		//dfmt on
		vkCreateGraphicsPipelines(device, VK_NULL_HANDLE, 1, &pipelineInfo, null, graphicsPipeline.Ptr).enforceVK;
	}

	void createFramebuffers() {
		swapChainFramebuffers = new VkFramebuffer[swapChainImageViews.length];

		foreach (uint i, ref imageView; swapChainImageViews) {
			VkImageView[] attachments = [imageView];

			//dfmt off
			VkFramebufferCreateInfo framebufferInfo = {
				renderPass: renderPass,
				attachmentCount: cast(uint)attachments.length,
				pAttachments: attachments.ptr,
				width: swapChainExtent.width,
				height: swapChainExtent.height,
				layers: 1
			};
			//dfmt on

			vkCreateFramebuffer(device, &framebufferInfo, null, &swapChainFramebuffers[i]).enforceVK;
		}

	}

	void createCommandPool() {
		//dfmt off
		VkCommandPoolCreateInfo poolInfo = {
			queueFamilyIndex: graphicsFamily,
			flags: 0
		};
		//dfmt on
		vkCreateCommandPool(device, &poolInfo, null, commandPool.Ptr).enforceVK;
	}

	void createVertexBuffer() {
		import std.c.string : memcpy;

		VkDeviceSize size = vertices.length * Vertex.sizeof;

		Buffer stagingBuffer = new Buffer(this, size, VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
				VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT);
		scope (exit)
			stagingBuffer.destroy;

		void* data = stagingBuffer.Map();
		memcpy(data, vertices.ptr, size);
		stagingBuffer.Unmap();

		vertexBuffer = new Buffer(this, size, VK_BUFFER_USAGE_TRANSFER_DST_BIT | VK_BUFFER_USAGE_VERTEX_BUFFER_BIT,
				VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);

		stagingBuffer.CopyTo(vertexBuffer, size);
	}

	void createIndexBuffer() {
		import std.c.string : memcpy;

		VkDeviceSize size = indices.length * typeof(indices[0]).sizeof;

		Buffer stagingBuffer = new Buffer(this, size, VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
				VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT);
		scope (exit)
			stagingBuffer.destroy;

		void* data = stagingBuffer.Map();
		memcpy(data, indices.ptr, size);
		stagingBuffer.Unmap();

		indexBuffer = new Buffer(this, size, VK_BUFFER_USAGE_TRANSFER_DST_BIT | VK_BUFFER_USAGE_INDEX_BUFFER_BIT,
				VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);

		stagingBuffer.CopyTo(indexBuffer, size);
	}

	void createCommandBuffers() {
		commandBuffers.length = swapChainFramebuffers.length;

		//dfmt off
		VkCommandBufferAllocateInfo allocInfo = {
			commandPool: commandPool,
			level: VK_COMMAND_BUFFER_LEVEL_PRIMARY,
			commandBufferCount: cast(uint)commandBuffers.length
		};
		//dfmt on

		vkAllocateCommandBuffers(device, &allocInfo, commandBuffers.ptr).enforceVK;

		foreach (uint i, commandBuffer; commandBuffers) {
			//dfmt off
			VkCommandBufferBeginInfo beginInfo = {
				sType: VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
				flags: VK_COMMAND_BUFFER_USAGE_SIMULTANEOUS_USE_BIT,
				pInheritanceInfo: null // Optional
			};
			//dfmt on

			vkBeginCommandBuffer(commandBuffer, &beginInfo);

			VkClearValue clearColor = VkClearValue(VkClearColorValue([0.0f, 0.0f, 0.0f, 1.0f]));
			//dfmt off
			VkRenderPassBeginInfo renderPassInfo = {
				sType: VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
				renderPass: renderPass,
				framebuffer: swapChainFramebuffers[i],
				renderArea: VkRect2D(VkOffset2D(0, 0), swapChainExtent),
				clearValueCount: 1,
				pClearValues: &clearColor
			};
			//dfmt on

			vkCmdBeginRenderPass(commandBuffer, &renderPassInfo, VK_SUBPASS_CONTENTS_INLINE);
			vkCmdBindPipeline(commandBuffer, VK_PIPELINE_BIND_POINT_GRAPHICS, graphicsPipeline);

			VkBuffer[] vertexBuffers = [vertexBuffer.Buffer];
			VkDeviceSize[] offsets = [0];
			vkCmdBindVertexBuffers(commandBuffer, 0, cast(uint)vertexBuffers.length, vertexBuffers.ptr, offsets.ptr);
			vkCmdBindIndexBuffer(commandBuffer, indexBuffer.Buffer, 0, VK_INDEX_TYPE_UINT16);

			vkCmdDrawIndexed(commandBuffer, cast(uint)indices.length, 1, 0, 0, 0);

			vkCmdEndRenderPass(commandBuffer);
			vkEndCommandBuffer(commandBuffer).enforceVK;
		}
	}

	void createSemaphores() {
		VkSemaphoreCreateInfo semaphoreInfo;
		vkCreateSemaphore(device, &semaphoreInfo, null, imageAvailableSemaphore.Ptr);
		vkCreateSemaphore(device, &semaphoreInfo, null, renderFinishedSemaphore.Ptr);
	}
}

extern (C) nothrow static VkBool32 debugCallback(uint flags, VkDebugReportObjectTypeEXT objectType, ulong object,
		ulong location, int messageCode, const(char*) pLayerPrefix, const(char*) pMessage, void* pUserData) {
	try {
		if (flags & VK_DEBUG_REPORT_ERROR_BIT_EXT)
			write("ERROR ");
		if (flags & VK_DEBUG_REPORT_WARNING_BIT_EXT)
			write("WARNING ");
		if (flags & VK_DEBUG_REPORT_PERFORMANCE_WARNING_BIT_EXT)
			write("PERFORMANCE ");
		if (flags & VK_DEBUG_REPORT_INFORMATION_BIT_EXT)
			write("INFO ");
		if (flags & VK_DEBUG_REPORT_DEBUG_BIT_EXT)
			write("DEBUG ");

		writeln("[", pLayerPrefix.fromStringz, "] Validation layer: ", pMessage.fromStringz);
	}
	catch (Exception e) {
	}
	return VK_FALSE;
}
