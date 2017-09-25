import erupted;

class Texture2D
{
    public void CreateCheckerboard( int aWidth, int aHeight )
    {
        width = aWidth;
        height = aHeight;
        
        VkMemoryAllocateInfo memAllocInfo;
        memAllocInfo.sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
        memAllocInfo.pNext = nullptr;
        memAllocInfo.memoryTypeIndex = 0;

        VkBuffer stagingBuffer = VK_NULL_HANDLE;
        VkDeviceMemory stagingMemory = VK_NULL_HANDLE;
        VkDeviceSize imageSize = width * height * bytesPerPixel;

        VkBufferCreateInfo bufferCreateInfo;
        bufferCreateInfo.sType = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO;
        bufferCreateInfo.size = imageSize;
        bufferCreateInfo.usage = VK_BUFFER_USAGE_TRANSFER_SRC_BIT;
        bufferCreateInfo.sharingMode = VK_SHARING_MODE_EXCLUSIVE;
        enforceVk( vkCreateBuffer( GfxDeviceGlobal::device, &bufferCreateInfo, nullptr, &stagingBuffer ) );
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
