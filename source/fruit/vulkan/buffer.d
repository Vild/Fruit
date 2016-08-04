module fruit.vulkan.buffer;

import erupted;
import fruit.vulkan.vulkan;
import fruit.vulkan.vkdestroy;
import fruit.vulkan.vertex;

class Buffer {
public:
	this(Vulkan vulkan, VkDeviceSize size, VkBufferUsageFlags usage, VkMemoryPropertyFlags properties) {
		buffer.__ctor(vulkan.Device, vkDestroyBuffer);
		bufferMemory.__ctor(vulkan.Device, vkFreeMemory);

		this.vulkan = vulkan;
		this.size = size;

		//dfmt off
		const VkBufferCreateInfo bufferInfo = {
			size: size,
			usage: usage,
			sharingMode: VK_SHARING_MODE_EXCLUSIVE
		};
		//dfmt on

		vkCreateBuffer(vulkan.Device, &bufferInfo, null, buffer.Ptr).enforceVK;

		VkMemoryRequirements memRequirements;
		vkGetBufferMemoryRequirements(vulkan.Device, buffer, &memRequirements);

		//dfmt off
		VkMemoryAllocateInfo allocInfo = {
			allocationSize: memRequirements.size,
			memoryTypeIndex: findMemoryType(memRequirements.memoryTypeBits, properties)
		};
		//dfmt on

		vkAllocateMemory(vulkan.Device, &allocInfo, null, bufferMemory.Ptr).enforceVK;
		vkBindBufferMemory(vulkan.Device, buffer, bufferMemory, 0);
	}

	void* Map() {
		void* data;
		vkMapMemory(vulkan.Device, bufferMemory, 0, size, 0, &data);
		return data;
	}

	void Unmap() {
		vkUnmapMemory(vulkan.Device, bufferMemory);
	}

	void CopyTo(.Buffer other, VkDeviceSize size) {
		//dfmt off
		VkCommandBufferAllocateInfo allocInfo = {
			level: VK_COMMAND_BUFFER_LEVEL_PRIMARY,
			commandPool: vulkan.CommandPool,
			commandBufferCount: 1
		};
		//dfmt on

		VkCommandBuffer commandBuffer;
		vkAllocateCommandBuffers(vulkan.Device, &allocInfo, &commandBuffer).enforceVK;

		//dfmt off
		VkCommandBufferBeginInfo beginInfo = {
			flags: VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT
		};
		//dfmt on

		vkBeginCommandBuffer(commandBuffer, &beginInfo);

		//dfmt off
		VkBufferCopy copyRegion = {
			srcOffset: 0,
			dstOffset: 0,
			size: size
		};
		//dfmt on
		vkCmdCopyBuffer(commandBuffer, buffer, other.Buffer, 1, &copyRegion);
		vkEndCommandBuffer(commandBuffer);

		//dfmt off
		VkSubmitInfo submitInfo = {
			commandBufferCount: 1,
			pCommandBuffers: &commandBuffer
		};
		//dfmt on
		vkQueueSubmit(vulkan.GraphicsQueue, 1, &submitInfo, VK_NULL_HANDLE);
		vkQueueWaitIdle(vulkan.GraphicsQueue);
		vkFreeCommandBuffers(vulkan.Device, vulkan.CommandPool, 1, &commandBuffer);
	}

	void CopyFrom(.Buffer other, VkDeviceSize size) {
		other.CopyTo(this, size);
	}

	@property VkBuffer Buffer() {
		return buffer;
	}

protected:
	VkDeviceSize size;
	Vulkan vulkan;
	VkDestroy!VkBuffer buffer;
	VkDestroy!VkDeviceMemory bufferMemory;

private:
	uint findMemoryType(uint typeFilter, VkMemoryPropertyFlags properties) {
		VkPhysicalDeviceMemoryProperties memProperties;
		vkGetPhysicalDeviceMemoryProperties(vulkan.PhysDevice, &memProperties);

		for (uint i = 0; i < memProperties.memoryTypeCount; i++) {
			if (typeFilter & (1 << i) && (memProperties.memoryTypes[i].propertyFlags & properties) == properties) {
				return i;
			}
		}

		import std.exception : enforce;

		enforce(0, "failed to find suitable memory type!");
		assert(0);
	}
}
