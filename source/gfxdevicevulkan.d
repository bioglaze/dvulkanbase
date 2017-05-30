import erupted;
import std.stdio;

extern(System) VkBool32 MyDebugReportCallback(
    VkDebugReportFlagsEXT       flags,
    VkDebugReportObjectTypeEXT  objectType,
    uint64_t                    object,
    size_t                      location,
    int32_t                     messageCode,
    const (char)*                 pLayerPrefix,
    const (char)*                 pMessage,
    void*                       pUserData) nothrow @nogc
{
    import std.stdio;
    printf( "ObjectType: %i  \n", objectType );
    printf( pMessage );
    printf( "\n" );
    return VK_FALSE;
}

void enforceVk( VkResult res )
{
    import std.exception;
    import std.conv;
    enforce( res is VkResult.VK_SUCCESS, res.to!string );
}

class GfxDeviceVulkan
{
    this( int width, int height, void* windowHandle )
    {
        DerelictErupted.load();
        VkApplicationInfo appinfo;
        appinfo.pApplicationName = "VulkanBase";
        appinfo.apiVersion = VK_MAKE_VERSION( 1, 0, 2 );

        const(char*)[3] extensionNames = [
        "VK_KHR_surface",
        "VK_KHR_win32_surface",
          //"VK_KHR_xlib_surface",
        "VK_EXT_debug_report"
        ];
        uint extensionCount = 0;
        vkEnumerateInstanceExtensionProperties( null, &extensionCount, null );

        auto extensionProps = new VkExtensionProperties[]( extensionCount );
        vkEnumerateInstanceExtensionProperties( null, &extensionCount, extensionProps.ptr );
        
        uint layerCount = 0;
        vkEnumerateInstanceLayerProperties( &layerCount, null );

        auto layerProps = new VkLayerProperties[]( layerCount );
        vkEnumerateInstanceLayerProperties( &layerCount, layerProps.ptr );

        const(char*)[1] validationLayers = ["VK_LAYER_LUNARG_standard_validation"];
        
        VkInstanceCreateInfo createinfo;
        createinfo.sType = VkStructureType.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
        createinfo.pApplicationInfo = &appinfo;
        createinfo.enabledExtensionCount = cast(uint)extensionNames.length;
        createinfo.ppEnabledExtensionNames = extensionNames.ptr;
        createinfo.enabledLayerCount = validationLayers.length;
        createinfo.ppEnabledLayerNames = validationLayers.ptr;

        enforceVk( vkCreateInstance( &createinfo, null, &instance ) );

        loadInstanceLevelFunctions( instance );

        auto debugcallbackCreateInfo = VkDebugReportCallbackCreateInfoEXT(
           VkStructureType.VK_STRUCTURE_TYPE_DEBUG_REPORT_CALLBACK_CREATE_INFO_EXT,
           null,
           VkDebugReportFlagBitsEXT.VK_DEBUG_REPORT_ERROR_BIT_EXT |
           VkDebugReportFlagBitsEXT.VK_DEBUG_REPORT_WARNING_BIT_EXT |
           VkDebugReportFlagBitsEXT.VK_DEBUG_REPORT_PERFORMANCE_WARNING_BIT_EXT,
           &MyDebugReportCallback,
           null
        );
        
        VkDebugReportCallbackEXT callback;
        enforceVk( vkCreateDebugReportCallbackEXT( instance, &debugcallbackCreateInfo, null, &callback ) );

        //version(windows)
        {
            VkWin32SurfaceCreateInfoKHR surfaceCreateInfo;
            surfaceCreateInfo.sType = VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR;
            surfaceCreateInfo.hinstance = 0;
            surfaceCreateInfo.hwnd = windowHandle;
            enforceVk( vkCreateWin32SurfaceKHR( instance, &surfaceCreateInfo, null, &surface ) );
        }

        createDevice( width, height );
        createDepthStencil( width, height );
        createSemaphores();

        drawCmdBuffers = new VkCommandBuffer[ swapChainBuffers.length ];

        VkCommandBufferAllocateInfo commandBufferAllocateInfo;
        commandBufferAllocateInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
        commandBufferAllocateInfo.commandPool = cmdPool;
        commandBufferAllocateInfo.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
        commandBufferAllocateInfo.commandBufferCount = cast(uint)drawCmdBuffers.length;

        enforceVk( vkAllocateCommandBuffers( device, &commandBufferAllocateInfo, drawCmdBuffers.ptr ) );
        
        commandBufferAllocateInfo.commandBufferCount = 1;
        
        enforceVk( vkAllocateCommandBuffers( device, &commandBufferAllocateInfo, &postPresentCmdBuffer ) );
        enforceVk( vkAllocateCommandBuffers( device, &commandBufferAllocateInfo, &prePresentCmdBuffer ) );
    }

    void submitPostPresentBarrier()
    {
        VkCommandBufferBeginInfo cmdBufInfo;
        cmdBufInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;

        enforceVk( vkBeginCommandBuffer( postPresentCmdBuffer, &cmdBufInfo ) );

        VkImageMemoryBarrier postPresentBarrier;
        postPresentBarrier.sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
        postPresentBarrier.pNext = null;
        postPresentBarrier.srcAccessMask = VK_ACCESS_MEMORY_READ_BIT;
        postPresentBarrier.dstAccessMask = VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT;
        postPresentBarrier.oldLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;
        postPresentBarrier.newLayout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;
        postPresentBarrier.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
        postPresentBarrier.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
        postPresentBarrier.subresourceRange = VkImageSubresourceRange( VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1 );
        postPresentBarrier.image = swapChainBuffers[ currentBuffer ].image;

        vkCmdPipelineBarrier(
                             postPresentCmdBuffer,
                             VK_PIPELINE_STAGE_ALL_COMMANDS_BIT,
                             VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT,
                             0,
                             0, null,
                             0, null,
                             1, &postPresentBarrier );

        enforceVk( vkEndCommandBuffer( postPresentCmdBuffer ) );

        VkSubmitInfo submitPostInfo;
        submitPostInfo.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO;
        submitPostInfo.commandBufferCount = 1;
        submitPostInfo.pCommandBuffers = &postPresentCmdBuffer;

        enforceVk( vkQueueSubmit( graphicsQueue, 1, &submitPostInfo, VK_NULL_HANDLE ) );
    }

    void submitPrePresentBarrier()
    {
        VkCommandBufferBeginInfo cmdBufInfo;
        cmdBufInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;

        enforceVk( vkBeginCommandBuffer( prePresentCmdBuffer, &cmdBufInfo ) );

        VkImageMemoryBarrier prePresentBarrier;
        prePresentBarrier.sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
        prePresentBarrier.pNext = null;
        prePresentBarrier.srcAccessMask = VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT;
        prePresentBarrier.dstAccessMask = VK_ACCESS_MEMORY_READ_BIT;
        prePresentBarrier.oldLayout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;
        prePresentBarrier.newLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;
        prePresentBarrier.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
        prePresentBarrier.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
        prePresentBarrier.subresourceRange = VkImageSubresourceRange( VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1 );
        prePresentBarrier.image = swapChainBuffers[ currentBuffer ].image;

        vkCmdPipelineBarrier(
                             prePresentCmdBuffer,
                             VK_PIPELINE_STAGE_ALL_COMMANDS_BIT,
                             VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT,
                             0,
                             0, null,
                             0, null,
                             1, &prePresentBarrier );

        enforceVk( vkEndCommandBuffer( prePresentCmdBuffer ) );

        VkSubmitInfo submitInfo;
        submitInfo.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO;
        submitInfo.commandBufferCount = 1;
        submitInfo.pCommandBuffers = &prePresentCmdBuffer;

        enforceVk( vkQueueSubmit( graphicsQueue, 1, &submitInfo, VK_NULL_HANDLE ) );
    }

    void beginFrame()
    {
        enforceVk( vkAcquireNextImageKHR( device, swapChain, ulong.max, presentCompleteSemaphore, null, &currentBuffer ) );
        submitPostPresentBarrier();
    }

    void endFrame()
    {

    }
  
    private void createDevice( int width, int height )
    {
        uint32_t gpuCount;
        enforceVk( vkEnumeratePhysicalDevices( instance, &gpuCount, null ) );

        if (gpuCount < 1)
        {
            assert( false, "Your system doesn't have Vulkan capable GPU." );
        }

        enforceVk( vkEnumeratePhysicalDevices( instance, &gpuCount, &physicalDevice ) );

        uint32_t queueCount;
        vkGetPhysicalDeviceQueueFamilyProperties( physicalDevice, &queueCount, null );

        VkQueueFamilyProperties[] queueProps = new VkQueueFamilyProperties[ queueCount ];
        vkGetPhysicalDeviceQueueFamilyProperties( physicalDevice, &queueCount, queueProps.ptr );
        uint32_t graphicsQueueIndex = 0;

        for (graphicsQueueIndex = 0; graphicsQueueIndex < queueCount; ++graphicsQueueIndex)
        {
            if (queueProps[ graphicsQueueIndex ].queueFlags & VK_QUEUE_GRAPHICS_BIT)
            {
                break;
            }
        }

        assert( graphicsQueueIndex < queueCount, "Could not find graphics queue" );
        queueNodeIndex = graphicsQueueIndex;
        
        float queuePriorities = 0;
        VkDeviceQueueCreateInfo queueCreateInfo;
        queueCreateInfo.sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
        queueCreateInfo.queueFamilyIndex = graphicsQueueIndex;
        queueCreateInfo.queueCount = 1;
        queueCreateInfo.pQueuePriorities = &queuePriorities;

        const(char*)[] deviceExtensions = [ "VK_KHR_swapchain" ];

        uint32_t deviceExtensionCount;
        vkEnumerateDeviceExtensionProperties( physicalDevice, null, &deviceExtensionCount, null );
        VkExtensionProperties[] availableDeviceExtensions = new VkExtensionProperties[ deviceExtensionCount ];
        vkEnumerateDeviceExtensionProperties( physicalDevice, null, &deviceExtensionCount, availableDeviceExtensions.ptr );

        for (int i = 0; i < availableDeviceExtensions.length; ++i)
        {
            if (availableDeviceExtensions[ i ].extensionName == VK_EXT_DEBUG_MARKER_EXTENSION_NAME)
            {
                writeln("Found debug marker extension");
                deviceExtensions ~= VK_EXT_DEBUG_MARKER_EXTENSION_NAME;
            }
        }

        VkPhysicalDeviceFeatures enabledFeatures;
        enabledFeatures.tessellationShader = true;
        enabledFeatures.shaderTessellationAndGeometryPointSize = true;
        enabledFeatures.shaderClipDistance = true;
        enabledFeatures.shaderCullDistance = true;

        VkDeviceCreateInfo deviceCreateInfo;
        deviceCreateInfo.sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
        deviceCreateInfo.pNext = null;
        deviceCreateInfo.queueCreateInfoCount = 1;
        deviceCreateInfo.pQueueCreateInfos = &queueCreateInfo;
        deviceCreateInfo.pEnabledFeatures = &enabledFeatures;
        deviceCreateInfo.enabledExtensionCount = cast(uint)deviceExtensions.length;
        deviceCreateInfo.ppEnabledExtensionNames = deviceExtensions.ptr;

        enforceVk( vkCreateDevice( physicalDevice, &deviceCreateInfo, null, &device ) );

        vkGetPhysicalDeviceMemoryProperties( physicalDevice, &deviceMemoryProperties );
        loadDeviceLevelFunctions( device );
        vkGetDeviceQueue( device, graphicsQueueIndex, 0, &graphicsQueue );

        const VkFormat[] depthFormats = [ VK_FORMAT_D24_UNORM_S8_UINT, VK_FORMAT_D16_UNORM_S8_UINT, VK_FORMAT_D16_UNORM ];
        bool depthFormatFound = false;

        foreach (format; depthFormats)
        {
            VkFormatProperties formatProps;
            vkGetPhysicalDeviceFormatProperties( physicalDevice, format, &formatProps );

            if (formatProps.optimalTilingFeatures & VK_FORMAT_FEATURE_DEPTH_STENCIL_ATTACHMENT_BIT)
            {
                depthFormat = format;
                depthFormatFound = true;
                break;
            }
        }

        assert( depthFormatFound, "No suitable depth format found" );

        uint32_t formatCount;
        enforceVk( vkGetPhysicalDeviceSurfaceFormatsKHR( physicalDevice, surface, &formatCount, null ) );
        assert( formatCount > 0, "no surface formats" );

        VkSurfaceFormatKHR[]  surfFormats = new VkSurfaceFormatKHR[ formatCount ];
        enforceVk( vkGetPhysicalDeviceSurfaceFormatsKHR( physicalDevice, surface, &formatCount, surfFormats.ptr ) );

        VkFormat colorFormat;
        
        if (formatCount == 1 && surfFormats[ 0 ].format == VK_FORMAT_UNDEFINED)
        {
            colorFormat = VK_FORMAT_B8G8R8A8_UNORM;
        }
        else
        {
            colorFormat = surfFormats[ 0 ].format;
        }

        VkColorSpaceKHR colorSpace = surfFormats[ 0 ].colorSpace;

        // Create swap chain
        
        VkSurfaceCapabilitiesKHR surfCaps;
        enforceVk( vkGetPhysicalDeviceSurfaceCapabilitiesKHR( physicalDevice, surface, &surfCaps ) );

        uint32_t presentModeCount = 0;
        enforceVk( vkGetPhysicalDeviceSurfacePresentModesKHR( physicalDevice, surface, &presentModeCount, null ) );
        assert( presentModeCount > 0, "no present modes" );

        VkPresentModeKHR[] presentModes = new VkPresentModeKHR[ presentModeCount ];
        enforceVk( vkGetPhysicalDeviceSurfacePresentModesKHR( physicalDevice, surface, &presentModeCount, presentModes.ptr ) );

        VkExtent2D swapchainExtent;
        
        if (surfCaps.currentExtent.width == 0)
        {
            swapchainExtent.width = width;
            swapchainExtent.height = height;
        }
        else
        {
            swapchainExtent = surfCaps.currentExtent;
            //windowWidth = surfCaps.currentExtent.width;
            //windowHeight = surfCaps.currentExtent.height;
        }

        uint32_t desiredNumberOfSwapchainImages = surfCaps.minImageCount + 1;
        writeln("swap chain images: ", desiredNumberOfSwapchainImages);

        VkSurfaceTransformFlagsKHR preTransform;

        if (surfCaps.supportedTransforms & VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR)
        {
            preTransform = VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR;
        }
        else
        {
            preTransform = surfCaps.currentTransform;
        }

        VkSwapchainCreateInfoKHR swapchainInfo;
        swapchainInfo.sType = VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR;
        swapchainInfo.pNext = null;
        swapchainInfo.surface = surface;
        swapchainInfo.minImageCount = desiredNumberOfSwapchainImages;
        swapchainInfo.imageFormat = colorFormat;
        swapchainInfo.imageColorSpace = colorSpace;
        swapchainInfo.imageExtent.width = swapchainExtent.width;
        swapchainInfo.imageExtent.height = swapchainExtent.height;
        swapchainInfo.imageUsage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;
        swapchainInfo.preTransform = cast(VkSurfaceTransformFlagBitsKHR)preTransform;
        swapchainInfo.imageArrayLayers = 1;
        swapchainInfo.imageSharingMode = VK_SHARING_MODE_EXCLUSIVE;
        swapchainInfo.queueFamilyIndexCount = 0;
        swapchainInfo.pQueueFamilyIndices = null;
        swapchainInfo.presentMode = VK_PRESENT_MODE_FIFO_KHR;
        swapchainInfo.clipped = VK_TRUE;
        swapchainInfo.compositeAlpha = VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR;

        enforceVk( vkCreateSwapchainKHR( device, &swapchainInfo, null, &swapChain ) );

        uint32_t imageCount;
        enforceVk( vkGetSwapchainImagesKHR( device, swapChain, &imageCount, null ) );

        assert( imageCount > 0, "imageCount" );

        swapChainImages = new VkImage[ imageCount ];
        swapChainBuffers = new SwapChainBuffer[ imageCount ];
        
        enforceVk( vkGetSwapchainImagesKHR( device, swapChain, &imageCount, swapChainImages.ptr ) );

        allocateSetupCommandBuffer();
        
        for (uint32_t i = 0; i < imageCount; ++i)
        {
            VkImageViewCreateInfo colorAttachmentView;
            colorAttachmentView.sType = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
            colorAttachmentView.pNext = null;
            colorAttachmentView.format = colorFormat;
            colorAttachmentView.components = VkComponentMapping( VK_COMPONENT_SWIZZLE_R, VK_COMPONENT_SWIZZLE_G,
                                                                 VK_COMPONENT_SWIZZLE_B, VK_COMPONENT_SWIZZLE_A );
            colorAttachmentView.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
            colorAttachmentView.subresourceRange.baseMipLevel = 0;
            colorAttachmentView.subresourceRange.levelCount = 1;
            colorAttachmentView.subresourceRange.baseArrayLayer = 0;
            colorAttachmentView.subresourceRange.layerCount = 1;
            colorAttachmentView.viewType = VK_IMAGE_VIEW_TYPE_2D;
            colorAttachmentView.flags = 0;

            swapChainBuffers[ i ].image = swapChainImages[ i ];

            setImageLayout(
                           setupCmdBuffer,
                           swapChainBuffers[ i ].image,
                           VK_IMAGE_ASPECT_COLOR_BIT, VK_IMAGE_LAYOUT_UNDEFINED,
                           VK_IMAGE_LAYOUT_PRESENT_SRC_KHR, 1, 0, 1 );

            colorAttachmentView.image = swapChainBuffers[ i ].image;

            enforceVk( vkCreateImageView( device, &colorAttachmentView, null, &swapChainBuffers[ i ].view ) );
        }
    }

    void setImageLayout( VkCommandBuffer cmdbuffer, VkImage image, VkImageAspectFlags aspectMask, VkImageLayout oldImageLayout,
        VkImageLayout newImageLayout, uint layerCount, uint mipLevel, uint mipLevelCount )
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

        const VkPipelineStageFlags srcStageFlags = VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT;
        const VkPipelineStageFlags destStageFlags = VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT;

        vkCmdPipelineBarrier(
                           cmdbuffer,
                           srcStageFlags,
                           destStageFlags,
                           0,
                           0, null,
                           0, null,
                           1, &imageMemoryBarrier );
    }

    void allocateSetupCommandBuffer()
    {
        if (setupCmdBuffer != VK_NULL_HANDLE)
        {
            vkFreeCommandBuffers( device, cmdPool, 1, &setupCmdBuffer );
            setupCmdBuffer = VK_NULL_HANDLE;
        }

        VkCommandPoolCreateInfo cmdPoolInfo;
        cmdPoolInfo.sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
        cmdPoolInfo.queueFamilyIndex = queueNodeIndex;
        cmdPoolInfo.flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;
        enforceVk( vkCreateCommandPool( device, &cmdPoolInfo, null, &cmdPool ) );

        VkCommandBufferAllocateInfo info;
        info.commandBufferCount = 1;
        info.commandPool = cmdPool;
        info.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
        info.pNext = null;
        info.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;

        enforceVk( vkAllocateCommandBuffers( device, &info, &setupCmdBuffer ) );

        VkCommandBufferBeginInfo cmdBufInfo;
        cmdBufInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;

        enforceVk( vkBeginCommandBuffer( setupCmdBuffer, &cmdBufInfo ) );
    }

    void createDepthStencil( int width, int height )
    {
        VkImageCreateInfo image;
        image.sType = VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO;
        image.pNext = null;
        image.imageType = VK_IMAGE_TYPE_2D;
        image.format = depthFormat;
        image.extent = VkExtent3D( width, height, 1 );
        image.mipLevels = 1;
        image.arrayLayers = 1;
        image.samples = VK_SAMPLE_COUNT_1_BIT;
        image.tiling = VK_IMAGE_TILING_OPTIMAL;
        image.usage = VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT | VK_IMAGE_USAGE_TRANSFER_SRC_BIT;
        image.flags = 0;

        VkMemoryAllocateInfo mem_alloc;
        mem_alloc.sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
        mem_alloc.pNext = null;
        mem_alloc.allocationSize = 0;
        mem_alloc.memoryTypeIndex = 0;

        VkImageViewCreateInfo depthStencilView;
        depthStencilView.sType = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
        depthStencilView.pNext = null;
        depthStencilView.viewType = VK_IMAGE_VIEW_TYPE_2D;
        depthStencilView.format = depthFormat;
        depthStencilView.flags = 0;
        depthStencilView.subresourceRange.aspectMask = VK_IMAGE_ASPECT_DEPTH_BIT | VK_IMAGE_ASPECT_STENCIL_BIT;
        depthStencilView.subresourceRange.baseMipLevel = 0;
        depthStencilView.subresourceRange.levelCount = 1;
        depthStencilView.subresourceRange.baseArrayLayer = 0;
        depthStencilView.subresourceRange.layerCount = 1;

        enforceVk( vkCreateImage( device, &image, null, &depthStencil.image ) );

        VkMemoryRequirements memReqs;
        vkGetImageMemoryRequirements( device, depthStencil.image, &memReqs );
        mem_alloc.allocationSize = memReqs.size;
        getMemoryType( memReqs.memoryTypeBits, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, &mem_alloc.memoryTypeIndex );
        enforceVk( vkAllocateMemory( device, &mem_alloc, null, &depthStencil.mem ) );

        enforceVk( vkBindImageMemory( device, depthStencil.image, depthStencil.mem, 0 ) );

        setImageLayout( setupCmdBuffer, depthStencil.image, VK_IMAGE_ASPECT_DEPTH_BIT | VK_IMAGE_ASPECT_STENCIL_BIT,
                        VK_IMAGE_LAYOUT_UNDEFINED, VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL, 1, 0, 1 );

        depthStencilView.image = depthStencil.image;
        enforceVk( vkCreateImageView( device, &depthStencilView, null, &depthStencil.view ) );
    }

    void getMemoryType( uint32_t typeBits, VkFlags properties, uint32_t* typeIndex )
    {
        for (uint32_t i = 0; i < 32; ++i)
        {
            if ((typeBits & 1) == 1)
            {
                if ((deviceMemoryProperties.memoryTypes[ i ].propertyFlags & properties) == properties)
                {
                    *typeIndex = i;
                    return;
                }
            }
            
            typeBits >>= 1;
        }

        assert( false, "could not get memory type" );
    }

    void createSemaphores()
    {
        VkSemaphoreCreateInfo presentCompleteSemaphoreCreateInfo;
        presentCompleteSemaphoreCreateInfo.sType = VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO;
        presentCompleteSemaphoreCreateInfo.pNext = null;

        enforceVk( vkCreateSemaphore( device, &presentCompleteSemaphoreCreateInfo, null, &presentCompleteSemaphore ) );

        VkSemaphoreCreateInfo renderCompleteSemaphoreCreateInfo;
        renderCompleteSemaphoreCreateInfo.sType = VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO;
        renderCompleteSemaphoreCreateInfo.pNext = null;

        enforceVk( vkCreateSemaphore( device, &renderCompleteSemaphoreCreateInfo, null, &renderCompleteSemaphore ) );
    }

    VkSurfaceKHR surface;
    VkDevice device;
    VkInstance instance;
    VkPhysicalDevice physicalDevice;
    VkFormat depthFormat;
    VkQueue graphicsQueue;
    VkPhysicalDeviceMemoryProperties deviceMemoryProperties;
    VkSwapchainKHR swapChain;
    VkImage[] swapChainImages;
    VkCommandBuffer setupCmdBuffer;
    VkCommandBuffer[] drawCmdBuffers;
    VkCommandBuffer prePresentCmdBuffer;
    VkCommandBuffer postPresentCmdBuffer;
    VkCommandPool cmdPool;
    VkSemaphore presentCompleteSemaphore;
    VkSemaphore renderCompleteSemaphore;
    int queueNodeIndex;
    uint currentBuffer;
  
    struct SwapChainBuffer
    {
        VkImage image;
        VkImageView view;
    }

    SwapChainBuffer[] swapChainBuffers;

    struct DepthStencil
    {
        VkImage image;
        VkDeviceMemory mem;
        VkImageView view;
    }

    DepthStencil depthStencil;
}
