import erupted;
import std.conv;
import core.stdc.string;
import std.exception;

private int max( int x, int y )
{
    return x > y ? x : y;
}

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
    public void createCheckerboard( VkDevice device, VkPhysicalDeviceMemoryProperties memoryProperties, VkCommandBuffer cmdBuffer, VkQueue graphicsQueue, int aWidth, int aHeight )
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

		setImageLayout(
					   cmdBuffer,
					   image,
					   VK_IMAGE_ASPECT_COLOR_BIT,
					   VK_IMAGE_LAYOUT_UNDEFINED,
					   VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
					   1,
					   0,
					   imageCreateInfo.mipLevels );

		vkCmdCopyBufferToImage(
							   cmdBuffer,
							   stagingBuffer,
							   image,
							   VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
							   1,
							   &bufferCopyRegion );

		for (int i = 1; i < imageCreateInfo.mipLevels; ++i)
		{
			const int mipWidth = max( width >> i, 1 );
			const int mipHeight = max( height >> i, 1 );

			VkImageBlit imageBlit;
			imageBlit.srcSubresource.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
			imageBlit.srcSubresource.baseArrayLayer = 0;
			imageBlit.srcSubresource.layerCount = 1;
			imageBlit.srcSubresource.mipLevel = 0;
			imageBlit.srcOffsets[ 0 ] = VkOffset3D( 0, 0, 0 );
			imageBlit.srcOffsets[ 1 ] = VkOffset3D( width, height, 1 );

			imageBlit.dstSubresource.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
			imageBlit.dstSubresource.baseArrayLayer = 0;
			imageBlit.dstSubresource.layerCount = 1;
			imageBlit.dstSubresource.mipLevel = i;
			imageBlit.dstOffsets[ 0 ] = VkOffset3D( 0, 0, 0 );
			imageBlit.dstOffsets[ 1 ] = VkOffset3D( mipWidth, mipHeight, 1 );

			vkCmdBlitImage( cmdBuffer, image, VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL, image,
							VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, 1, &imageBlit, VK_FILTER_LINEAR );
		}

		auto imageLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
		setImageLayout(
					   cmdBuffer,
					   image,
					   VK_IMAGE_ASPECT_COLOR_BIT,
					   VK_IMAGE_LAYOUT_UNDEFINED,
					   imageLayout,
					   1,
					   0,
					   imageCreateInfo.mipLevels );

		enforceVk( vkEndCommandBuffer( cmdBuffer ) );

        VkSubmitInfo submitInfo = {};
        submitInfo.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO;
        submitInfo.commandBufferCount = 1;
        submitInfo.pCommandBuffers = &cmdBuffer;

		enforceVk( vkQueueSubmit( graphicsQueue, 1, &submitInfo, VK_NULL_HANDLE ) );

        enforceVk( vkQueueWaitIdle( graphicsQueue ) );

        vkFreeMemory( device, stagingMemory, null );
        vkDestroyBuffer( device, stagingBuffer, null );

        VkImageViewCreateInfo viewInfo;
        viewInfo.sType = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
        viewInfo.pNext = null;
        viewInfo.viewType = VK_IMAGE_VIEW_TYPE_2D;
        viewInfo.format = imageCreateInfo.format;
        viewInfo.components = VkComponentMapping( VK_COMPONENT_SWIZZLE_R, VK_COMPONENT_SWIZZLE_G, VK_COMPONENT_SWIZZLE_B, VK_COMPONENT_SWIZZLE_A );
        viewInfo.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
        viewInfo.subresourceRange.baseMipLevel = 0;
        viewInfo.subresourceRange.baseArrayLayer = 0;
        viewInfo.subresourceRange.layerCount = 1;
        viewInfo.subresourceRange.levelCount = imageCreateInfo.mipLevels;
        viewInfo.image = image;
        enforceVk( vkCreateImageView( device, &viewInfo, null, &view ) );
    }

	private void setImageLayout( VkCommandBuffer cmdbuffer, VkImage image, VkImageAspectFlags aspectMask, VkImageLayout oldImageLayout,
						 VkImageLayout newImageLayout, int layerCount, int mipLevel, int mipLevelCount )
    {
        VkImageMemoryBarrier imageMemoryBarrier;
        imageMemoryBarrier.sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
        imageMemoryBarrier.pNext = null;
        imageMemoryBarrier.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
        imageMemoryBarrier.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;

        imageMemoryBarrier.oldLayout = oldImageLayout;
        imageMemoryBarrier.newLayout = newImageLayout;
        imageMemoryBarrier.image = image;
        imageMemoryBarrier.subresourceRange.aspectMask = aspectMask;
        imageMemoryBarrier.subresourceRange.baseMipLevel = mipLevel;
        imageMemoryBarrier.subresourceRange.levelCount = mipLevelCount;
        imageMemoryBarrier.subresourceRange.layerCount = layerCount;

        if (oldImageLayout == VK_IMAGE_LAYOUT_PREINITIALIZED)
        {
            imageMemoryBarrier.srcAccessMask = VK_ACCESS_HOST_WRITE_BIT | VK_ACCESS_TRANSFER_WRITE_BIT;
        }

        if (oldImageLayout == VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL)
        {
            imageMemoryBarrier.srcAccessMask = VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT;
        }

        if (oldImageLayout == VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL)
        {
            imageMemoryBarrier.srcAccessMask = VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT;
        }

        if (oldImageLayout == VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL)
        {
            imageMemoryBarrier.srcAccessMask = VK_ACCESS_TRANSFER_READ_BIT;
        }

        if (oldImageLayout == VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL)
        {
            imageMemoryBarrier.srcAccessMask = VK_ACCESS_SHADER_READ_BIT;
        }

        if (newImageLayout == VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL)
        {
            imageMemoryBarrier.dstAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;
        }

        if (newImageLayout == VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL)
        {
            imageMemoryBarrier.srcAccessMask = imageMemoryBarrier.srcAccessMask | VK_ACCESS_TRANSFER_READ_BIT;
            imageMemoryBarrier.dstAccessMask = VK_ACCESS_TRANSFER_READ_BIT;
        }

        if (newImageLayout == VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL)
        {
            imageMemoryBarrier.dstAccessMask = VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT;
            imageMemoryBarrier.srcAccessMask = VK_ACCESS_TRANSFER_READ_BIT;
        }

        if (newImageLayout == VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL)
        {
            imageMemoryBarrier.dstAccessMask = imageMemoryBarrier.dstAccessMask | VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT;
        }

        if (newImageLayout == VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL)
        {
            imageMemoryBarrier.srcAccessMask = VK_ACCESS_HOST_WRITE_BIT | VK_ACCESS_TRANSFER_WRITE_BIT;
            imageMemoryBarrier.dstAccessMask = VK_ACCESS_SHADER_READ_BIT;
        }

        if (oldImageLayout == VK_IMAGE_LAYOUT_UNDEFINED)
        {
            imageMemoryBarrier.srcAccessMask = 0;
        }

        if (newImageLayout == VK_IMAGE_LAYOUT_PRESENT_SRC_KHR)
        {
            imageMemoryBarrier.dstAccessMask = VK_ACCESS_MEMORY_READ_BIT;
        }

        VkPipelineStageFlags srcStageFlags = VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT;
        VkPipelineStageFlags destStageFlags = VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT;

        if (imageMemoryBarrier.dstAccessMask == VK_ACCESS_TRANSFER_WRITE_BIT)
        {
            destStageFlags = VK_PIPELINE_STAGE_TRANSFER_BIT;
        }

        if (imageMemoryBarrier.dstAccessMask == VK_ACCESS_SHADER_READ_BIT)
        {
            destStageFlags = VK_PIPELINE_STAGE_VERTEX_SHADER_BIT | VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT;
        }

        if (imageMemoryBarrier.dstAccessMask == VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT)
        {
            destStageFlags = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
        }

        if (imageMemoryBarrier.dstAccessMask == VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT)
        {
            destStageFlags = VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT;
        }

        if (imageMemoryBarrier.dstAccessMask == VK_ACCESS_TRANSFER_READ_BIT)
        {
            destStageFlags = VK_PIPELINE_STAGE_TRANSFER_BIT;
        }

        vkCmdPipelineBarrier(
							 cmdbuffer,
							 srcStageFlags,
							 destStageFlags,
							 0,
							 0, null,
							 0, null,
							 1, &imageMemoryBarrier );
    }

    private static void enforceVk( VkResult res )
    {
        enforce( res is VkResult.VK_SUCCESS, res.to!string );
    }

    public VkImageView getView()
    {
        return view;
    }

    private VkImage image = VK_NULL_HANDLE;
    private VkImageView view = VK_NULL_HANDLE;
	private VkDeviceMemory deviceMemory = VK_NULL_HANDLE;
    private int width;
    private int height;
}
