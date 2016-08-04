module fruit.vulkan.vertex;

import fruit.other.linalg;
import erupted;

struct Vertex {
	vec3 position;
	vec3 color;

	static VkVertexInputBindingDescription getBindingDescription() {
		//dfmt off
		VkVertexInputBindingDescription desc = {
			binding: 0,
			stride: Vertex.sizeof,
			inputRate: VK_VERTEX_INPUT_RATE_VERTEX
		};
		//dfmt on

		return desc;
	}

	static VkVertexInputAttributeDescription[] getAttributeDescriptions() {
		//dfmt off
		VkVertexInputAttributeDescription[] desc = [{
			binding: 0,
			location: 0,
			format: VK_FORMAT_R32G32B32_SFLOAT,
			offset: Vertex.position.offsetof
		}, {
			binding: 0,
			location: 1,
			format: VK_FORMAT_R32G32B32_SFLOAT,
			offset: Vertex.color.offsetof
		}];
		//dfmt on

		return desc;
	}


}
