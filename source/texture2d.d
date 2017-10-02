import erupted;
import std.conv;
import core.stdc.string;
import std.exception;

private void getMemoryType( VkPhysicalDeviceMemoryProperties memoryProperties, uint32_t typeBits, VkFlags properties, uint32_t* typeIndex )
{
	for (uint32_t i = 0; i < 32; ++i)
	{
		if ((typeBits & 1) == 1)
		{
			if ((memoryProperties.memoryTypes[ i ].propertyFlags & properties) == properties)
			{
				*typeIndex = i;
				return;
			}
		}
		typeBits >>= 1;
	}

	assert( false, "Could not find suitable memory type" );
}

class Texture2D
{
    public void createCheckerboard( VkDevice device, VkPhysicalDeviceMemoryProperties memoryProperties, VkCommandBuffer cmdBuffer, int aWidth, int aHeight )
    {
        width = aWidth;
        height = aHeight;
        
        VkMemoryAllocateInfo memAllocInfo;
        memAllocInfo.sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
        memAllocInfo.pNext = null;
        memAllocInfo.memoryTypeIndex = 0;

        VkBuffer stagingBuffer = VK_NULL_HANDLE;
        VkDeviceMemory stagingMemory = VK_NULL_HANDLE;
        VkDeviceSize imageSize = width * height * 4;

        VkBufferCreateInfo bufferCreateInfo;
        bufferCreateInfo.sType = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO;
        bufferCreateInfo.size = imageSize;
        bufferCreateInfo.usage = VK_BUFFER_USAGE_TRANSFER_SRC_BIT;
        bufferCreateInfo.sharingMode = VK_SHARING_MODE_EXCLUSIVE;
        enforceVk( vkCreateBuffer( device, &bufferCreateInfo, null, &stagingBuffer ) );

		VkMemoryRequirements memReqs;
		vkGetBufferMemoryRequirements( device, stagingBuffer, &memReqs );

		memAllocInfo.allocationSize = memReqs.size;
		getMemoryType( memoryProperties, memReqs.memoryTypeBits, VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT, &memAllocInfo.memoryTypeIndex );

		enforceVk( vkAllocateMemory( device, &memAllocInfo, null, &stagingMemory ) );

		enforceVk( vkBindBufferMemory( device, stagingBuffer, stagingMemory, 0 ) );

		uint8_t[] data = new uint8_t[ width * height * 4 ];
		
		for (int i = 0; i < width * height * 4; ++i)
		{
			data[ i ] = 0xFF;
		}

		uint8_t* stagingData = null;
		enforceVk( vkMapMemory( device, stagingMemory, 0, memReqs.size, 0, cast(void**)&stagingData ) );
		memcpy( stagingData, data.ptr, imageSize );
		vkUnmapMemory( device, stagingMemory );

		VkBufferImageCopy bufferCopyRegion;
		bufferCopyRegion.imageSubresource.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
        bufferCopyRegion.imageSubresource.mipLevel = 0;
        bufferCopyRegion.imageSubresource.baseArrayLayer = 0;
        bufferCopyRegion.imageSubresource.layerCount = 1;
        bufferCopyRegion.imageExtent.width = width;
        bufferCopyRegion.imageExtent.height = height;
        bufferCopyRegion.imageExtent.depth = 1;
        bufferCopyRegion.bufferOffset = 0;

		VkImageCreateInfo imageCreateInfo;
		imageCreateInfo.sType = VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO;
		imageCreateInfo.pNext = null;
		imageCreateInfo.imageType = VK_IMAGE_TYPE_2D;
		imageCreateInfo.format = VK_FORMAT_R8G8B8A8_SRGB;
		imageCreateInfo.mipLevels = 1;
		imageCreateInfo.arrayLayers = 1;
		imageCreateInfo.samples = VK_SAMPLE_COUNT_1_BIT;
		imageCreateInfo.tiling = VK_IMAGE_TILING_OPTIMAL;
		imageCreateInfo.sharingMode = VK_SHARING_MODE_EXCLUSIVE;
		imageCreateInfo.initialLayout = VK_IMAGE_LAYOUT_PREINITIALIZED;
		imageCreateInfo.extent = VkExtent3D( width, height, 1 );
		imageCreateInfo.usage = VK_IMAGE_USAGE_TRANSFER_SRC_BIT | VK_IMAGE_USAGE_TRANSFER_DST_BIT | VK_IMAGE_USAGE_SAMPLED_BIT;

		enforceVk( vkCreateImage( device, &imageCreateInfo, null, &image ) );

		vkGetImageMemoryRequirements( device, image, &memReqs );

		memAllocInfo.allocationSize = memReqs.size;
		getMemoryType( memoryProperties, memReqs.memoryTypeBits, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, &memAllocInfo.memoryTypeIndex );

		enforceVk( vkAllocateMemory( device, &memAllocInfo, null, &deviceMemory ) );
		enforceVk( vkBindImageMemory( device, image, deviceMemory, 0 ) );

		VkCommandBufferBeginInfo cmdBufInfo;
		cmdBufInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
		cmdBufInfo.pNext = null;
		cmdBufInfo.pInheritanceInfo = null;
		cmdBufInfo.flags = 0;

		enforceVk( vkBeginCommandBuffer( cmdBuffer, &cmdBufInfo ) );
    }

    private static void enforceVk( VkResult res )
    {
        enforce( res is VkResult.VK_SUCCESS, res.to!string );
    }

    private VkImage image = VK_NULL_HANDLE;
    private VkImageView view = VK_NULL_HANDLE;
	private VkDeviceMemory deviceMemory = VK_NULL_HANDLE;
    private int width;
    private int height;
}
