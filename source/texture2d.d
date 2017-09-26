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
    public void createCheckerboard( VkDevice device, VkPhysicalDeviceMemoryProperties memoryProperties, int aWidth, int aHeight )
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

		uint8_t* stagingData = null;
		enforceVk( vkMapMemory( device, stagingMemory, 0, memReqs.size, 0, cast(void**)&stagingData ) );
		//memcpy( stagingData, data, imageSize );
		vkUnmapMemory( device, stagingMemory );
    }

    private static void enforceVk( VkResult res )
    {
        enforce( res is VkResult.VK_SUCCESS, res.to!string );
    }

    private VkImage image = VK_NULL_HANDLE;
    private VkImageView view = VK_NULL_HANDLE;
    private int width;
    private int height;
}
