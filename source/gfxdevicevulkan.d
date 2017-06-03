import erupted;
import std.stdio;
import core.stdc.string;

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
    //printf( "ObjectType: %i  \n", objectType );
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
            surfaceCreateInfo.hinstance = windowHandle;
            surfaceCreateInfo.hwnd = windowHandle;
            enforceVk( vkCreateWin32SurfaceKHR( instance, &surfaceCreateInfo, null, &surface ) );
        }

        createDevice( width, height );
        createDepthStencil( width, height );
        createSemaphores();
        createRenderPass();
        flushSetupCommandBuffer();
        createDescriptorSetLayout();
        createDescriptorPool();
        
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

        VkImageView[ 2 ] attachments;

        attachments[ 1 ] = depthStencil.view;

        VkFramebufferCreateInfo frameBufferCreateInfo;
        frameBufferCreateInfo.sType = VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO;
        frameBufferCreateInfo.pNext = null;
        frameBufferCreateInfo.renderPass = renderPass;
        frameBufferCreateInfo.attachmentCount = 2;
        frameBufferCreateInfo.pAttachments = attachments.ptr;
        frameBufferCreateInfo.width = cast(uint32_t) width;
        frameBufferCreateInfo.height = cast(uint32_t) height;
        frameBufferCreateInfo.layers = 1;

        for (uint32_t bufferIndex = 0; bufferIndex < 2; ++bufferIndex)
        {
            attachments[ 0 ] = swapChainBuffers[ bufferIndex ].view;
            enforceVk( vkCreateFramebuffer( device, &frameBufferCreateInfo, null, &frameBuffers[ bufferIndex ] ) );
        }

        const float s = 100;
        quadVertices = new VertexPTC[ 4 ];
        quadVertices[ 0 ] = VertexPTC( 0, 0, 0, 0, 0 );
        quadVertices[ 1 ] = VertexPTC( s, 0, 0, 1, 0 );
        quadVertices[ 2 ] = VertexPTC( s, s, 0, 1, 1 );
        quadVertices[ 3 ] = VertexPTC( 0, s, 0, 0, 1 );

        quadIndices = new Face[ 2 ];
        quadIndices[ 0 ] = Face( 0, 1, 2 );
        quadIndices[ 1 ] = Face( 2, 3, 0 );

        vertexBuffer.generate( quadVertices, quadIndices, this );
    
        shader.load( "unlit_vert.spv", "unlit_frag.spv", device );
    }

    private void createDescriptorSetLayout()
    {
        // Binding 0 : Uniform buffer (Vertex shader)
        VkDescriptorSetLayoutBinding layoutBindingUBO;
        layoutBindingUBO.binding = 0;
        layoutBindingUBO.descriptorType = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER;
        layoutBindingUBO.descriptorCount = 1;
        layoutBindingUBO.stageFlags = VK_SHADER_STAGE_VERTEX_BIT;
        layoutBindingUBO.pImmutableSamplers = null;

        // Binding 1 : Sampler (Fragment shader)
        VkDescriptorSetLayoutBinding layoutBindingSampler;
        layoutBindingSampler.binding = 1;
        layoutBindingSampler.descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
        layoutBindingSampler.descriptorCount = 1;
        layoutBindingSampler.stageFlags = VK_SHADER_STAGE_FRAGMENT_BIT;
        layoutBindingSampler.pImmutableSamplers = null;

        VkDescriptorSetLayoutBinding[ 2 ] bindings = [ layoutBindingUBO, layoutBindingSampler ];

        VkDescriptorSetLayoutCreateInfo descriptorLayout;
        descriptorLayout.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO;
        descriptorLayout.pNext = null;
        descriptorLayout.bindingCount = 2;
        descriptorLayout.pBindings = bindings.ptr;

        enforceVk( vkCreateDescriptorSetLayout( device, &descriptorLayout, null, &descriptorSetLayout ) );

        VkPipelineLayoutCreateInfo pipelineLayoutCreateInfo;
        pipelineLayoutCreateInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO;
        pipelineLayoutCreateInfo.pNext = null;
        pipelineLayoutCreateInfo.setLayoutCount = 1;
        pipelineLayoutCreateInfo.pSetLayouts = &descriptorSetLayout;

        enforceVk( vkCreatePipelineLayout( device, &pipelineLayoutCreateInfo, null, &pipelineLayout ) );
    }

    void createDescriptorPool()
    {
        const int count = 20;
        VkDescriptorPoolSize[ 2 ] typeCounts;
        typeCounts[ 0 ].type = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER;
        typeCounts[ 0 ].descriptorCount = count;
        typeCounts[ 1 ].type = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
        typeCounts[ 1 ].descriptorCount = count;

        VkDescriptorPoolCreateInfo descriptorPoolInfo;
        descriptorPoolInfo.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO;
        descriptorPoolInfo.pNext = null;
        descriptorPoolInfo.poolSizeCount = 2;
        descriptorPoolInfo.pPoolSizes = typeCounts.ptr;
        descriptorPoolInfo.maxSets = count;
        descriptorPoolInfo.flags = VK_DESCRIPTOR_POOL_CREATE_FREE_DESCRIPTOR_SET_BIT;

        enforceVk( vkCreateDescriptorPool( device, &descriptorPoolInfo, null, &descriptorPool ) );

        descriptorSets = new VkDescriptorSet[ count ];

        for (int i = 0; i < descriptorSets.length; ++i)
        {
            VkDescriptorSetAllocateInfo allocInfo;
            allocInfo.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO;
            allocInfo.descriptorPool = descriptorPool;
            allocInfo.descriptorSetCount = 1;
            allocInfo.pSetLayouts = &descriptorSetLayout;

            enforceVk( vkAllocateDescriptorSets( device, &allocInfo, &descriptorSets[ i ] ) );
        }
    }

    void createRenderPass()
    {
        VkAttachmentDescription[ 2 ] attachments;
        attachments[ 0 ].format = colorFormat;
        attachments[ 0 ].samples = VK_SAMPLE_COUNT_1_BIT;
        attachments[ 0 ].loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR;
        attachments[ 0 ].storeOp = VK_ATTACHMENT_STORE_OP_STORE;
        attachments[ 0 ].stencilLoadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE;
        attachments[ 0 ].stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE;
        attachments[ 0 ].initialLayout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;
        attachments[ 0 ].finalLayout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;
        attachments[ 0 ].flags = 0;

        attachments[ 1 ].format = depthFormat;
        attachments[ 1 ].samples = VK_SAMPLE_COUNT_1_BIT;
        attachments[ 1 ].loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR;
        attachments[ 1 ].storeOp = VK_ATTACHMENT_STORE_OP_STORE;
        attachments[ 1 ].stencilLoadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE;
        attachments[ 1 ].stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE;
        attachments[ 1 ].initialLayout = VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL;
        attachments[ 1 ].finalLayout = VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL;
        attachments[ 1 ].flags = 0;

        VkAttachmentReference colorReference;
        colorReference.attachment = 0;
        colorReference.layout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;

        VkAttachmentReference depthReference;
        depthReference.attachment = 1;
        depthReference.layout = VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL;

        VkSubpassDescription subpass;
        subpass.pipelineBindPoint = VK_PIPELINE_BIND_POINT_GRAPHICS;
        subpass.flags = 0;
        subpass.inputAttachmentCount = 0;
        subpass.pInputAttachments = null;
        subpass.colorAttachmentCount = 1;
        subpass.pColorAttachments = &colorReference;
        subpass.pResolveAttachments = null;
        subpass.pDepthStencilAttachment = &depthReference;
        subpass.preserveAttachmentCount = 0;
        subpass.pPreserveAttachments = null;

        VkRenderPassCreateInfo renderPassInfo;
        renderPassInfo.sType = VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO;
        renderPassInfo.pNext = null;
        renderPassInfo.attachmentCount = 2;
        renderPassInfo.pAttachments = attachments.ptr;
        renderPassInfo.subpassCount = 1;
        renderPassInfo.pSubpasses = &subpass;
        renderPassInfo.dependencyCount = 0;
        renderPassInfo.pDependencies = null;

        enforceVk( vkCreateRenderPass( device, &renderPassInfo, null, &renderPass ) );
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

    private void flushSetupCommandBuffer()
    {
        if (setupCmdBuffer == VK_NULL_HANDLE)
        {
            return;
        }

        enforceVk( vkEndCommandBuffer( setupCmdBuffer ) );

        VkSubmitInfo submitInfo;
        submitInfo.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO;
        submitInfo.commandBufferCount = 1;
        submitInfo.pCommandBuffers = &setupCmdBuffer;

        enforceVk( vkQueueSubmit( graphicsQueue, 1, &submitInfo, VK_NULL_HANDLE ) );
        enforceVk( vkQueueWaitIdle( graphicsQueue ) );

        vkFreeCommandBuffers( device, cmdPool, 1, &setupCmdBuffer );
        setupCmdBuffer = VK_NULL_HANDLE;
    }
  
    void beginFrame( int width, int height )
    {
        enforceVk( vkAcquireNextImageKHR( device, swapChain, ulong.max, presentCompleteSemaphore, null, &currentBuffer ) );
        submitPostPresentBarrier();
        beginRenderPass( width, height );
    }

    void endFrame()
    {
        endRenderPass();

        VkPipelineStageFlags pipelineStages = VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT;

        VkSubmitInfo submitInfo;
        submitInfo.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO;
        submitInfo.pWaitDstStageMask = &pipelineStages;
        submitInfo.waitSemaphoreCount = 1;
        submitInfo.pWaitSemaphores = &presentCompleteSemaphore;
        submitInfo.commandBufferCount = 1;
        submitInfo.pCommandBuffers = &drawCmdBuffers[ currentBuffer ];
        submitInfo.signalSemaphoreCount = 1;
        submitInfo.pSignalSemaphores = &renderCompleteSemaphore;

        enforceVk( vkQueueSubmit( graphicsQueue, 1, &submitInfo, VK_NULL_HANDLE ) );

        submitPrePresentBarrier();

        VkPresentInfoKHR presentInfo;
        presentInfo.sType = VK_STRUCTURE_TYPE_PRESENT_INFO_KHR;
        presentInfo.pNext = null;
        presentInfo.swapchainCount = 1;
        presentInfo.pSwapchains = &swapChain;
        presentInfo.pImageIndices = &currentBuffer;
        presentInfo.pWaitSemaphores = &renderCompleteSemaphore;
        presentInfo.waitSemaphoreCount = 1;
        enforceVk( vkQueuePresentKHR( graphicsQueue, &presentInfo ) );

        enforceVk( vkQueueWaitIdle( graphicsQueue ) );
    }

    private void beginRenderPass( int windowWidth, int windowHeight )
    {
        enforceVk( vkDeviceWaitIdle( device ) );

        VkCommandBufferBeginInfo cmdBufInfo;
        cmdBufInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
        cmdBufInfo.pNext = null;

        VkClearColorValue clearColor;
        clearColor.int32 = [ 1, 0, 0, 1 ];
        VkClearValue[ 2 ] clearValues;
        clearValues[ 0 ].color = clearColor;
        //clearValues[ 1 ].depthStencil = { 1.0f, 0 };

        VkRenderPassBeginInfo renderPassBeginInfo;
        renderPassBeginInfo.sType = VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO;
        renderPassBeginInfo.pNext = null;
        renderPassBeginInfo.renderPass = renderPass;
        renderPassBeginInfo.renderArea.offset.x = 0;
        renderPassBeginInfo.renderArea.offset.y = 0;
        renderPassBeginInfo.renderArea.extent.width = windowWidth;
        renderPassBeginInfo.renderArea.extent.height = windowHeight;
        renderPassBeginInfo.clearValueCount = 2;
        renderPassBeginInfo.pClearValues = &clearValues[ 0 ];
        renderPassBeginInfo.framebuffer = frameBuffers[ currentBuffer ];

        enforceVk( vkBeginCommandBuffer( drawCmdBuffers[ currentBuffer ], &cmdBufInfo ) );

        vkCmdBeginRenderPass( drawCmdBuffers[ currentBuffer ], &renderPassBeginInfo, VK_SUBPASS_CONTENTS_INLINE );

        VkViewport viewport;
        viewport.height = cast(float)windowHeight;
        viewport.width = cast(float)windowWidth;
        viewport.minDepth = cast(float) 0.0f;
        viewport.maxDepth = cast(float) 1.0f;
        vkCmdSetViewport( drawCmdBuffers[ currentBuffer ], 0, 1, &viewport );

        VkRect2D scissor;
        scissor.extent.width = windowWidth;
        scissor.extent.height = windowHeight;
        scissor.offset.x = 0;
        scissor.offset.y = 0;
        vkCmdSetScissor( drawCmdBuffers[ currentBuffer ], 0, 1, &scissor );
    }

    private void endRenderPass()
    {
        vkCmdEndRenderPass( drawCmdBuffers[ currentBuffer ] );
        enforceVk( vkEndCommandBuffer( drawCmdBuffers[ currentBuffer ] ) );
        enforceVk( vkDeviceWaitIdle( device ) );
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

        VkBool32[] supportsPresent = new VkBool32[ queueCount ];

        for (uint32_t i = 0; i < queueCount; ++i)
        {
            vkGetPhysicalDeviceSurfaceSupportKHR( physicalDevice, i, surface, &supportsPresent[ i ] );
        }

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

    void copyBuffer( VkBuffer source, ref VkBuffer destination, int bufferSize )
    {
        VkCommandBufferAllocateInfo cmdBufInfo;
        cmdBufInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
        cmdBufInfo.commandPool = cmdPool;
        cmdBufInfo.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
        cmdBufInfo.commandBufferCount = 1;

        VkCommandBuffer copyCommandBuffer;
        enforceVk( vkAllocateCommandBuffers( device, &cmdBufInfo, &copyCommandBuffer ) );

        VkCommandBufferBeginInfo cmdBufferBeginInfo;
        cmdBufferBeginInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
        cmdBufferBeginInfo.pNext = null;

        VkBufferCopy copyRegion;
        copyRegion.size = bufferSize;

        enforceVk( vkBeginCommandBuffer( copyCommandBuffer, &cmdBufferBeginInfo ) );

        vkCmdCopyBuffer( copyCommandBuffer, source, destination, 1, &copyRegion );

        enforceVk( vkEndCommandBuffer( copyCommandBuffer ) );

        VkSubmitInfo copySubmitInfo;
        copySubmitInfo.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO;
        copySubmitInfo.commandBufferCount = 1;
        copySubmitInfo.pCommandBuffers = &copyCommandBuffer;

        enforceVk( vkQueueSubmit( graphicsQueue, 1, &copySubmitInfo, VK_NULL_HANDLE ) );
        enforceVk( vkQueueWaitIdle( graphicsQueue ) );

        vkFreeCommandBuffers( device, cmdBufInfo.commandPool, 1, &copyCommandBuffer );
    }

    void createBuffer( ref VkBuffer buffer, int bufferSize, ref VkDeviceMemory memory, VkBufferUsageFlags usageFlags, VkMemoryPropertyFlags memoryFlags, string debugName )
    {
        VkBufferCreateInfo bufferInfo;
        bufferInfo.sType = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO;
        bufferInfo.size = bufferSize;
        bufferInfo.usage = usageFlags;
        enforceVk( vkCreateBuffer( device, &bufferInfo, null, &buffer ) );
        //debug::SetObjectName( gDevice, (std::uint64_t)buffer, VK_DEBUG_REPORT_OBJECT_TYPE_BUFFER_EXT, debugName );

        VkMemoryRequirements memReqs;
        VkMemoryAllocateInfo memAlloc;
        memAlloc.sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;

        vkGetBufferMemoryRequirements( device, buffer, &memReqs );
        memAlloc.allocationSize = memReqs.size;
        getMemoryType( memReqs.memoryTypeBits, memoryFlags, &memAlloc.memoryTypeIndex );
        enforceVk( vkAllocateMemory( device, &memAlloc, null, &memory ) );
        enforceVk( vkBindBufferMemory( device, buffer, memory, 0 ) );
        assert( buffer != VK_NULL_HANDLE, "buffer is null" );
    }

    struct SwapChainBuffer
    {
        VkImage image;
        VkImageView view;
    }

    struct DepthStencil
    {
        VkImage image;
        VkDeviceMemory mem;
        VkImageView view;
    }

    struct VertexPTC
    {
        this( float aX, float aY, float aZ, float aU, float aV )
        {
            x = aX;
            y = aY;
            z = aZ;
            u = aU;
            v = aV;
        }

        float x = 0, y = 0, z = 0;
        float u = 0, v = 0;
        float r = 0, g = 0, b = 0, a = 0;
    }

    struct Face
    {
        this( ushort aA, ushort aB, ushort aC )
        {
            a = aA;
            b = aB;
            c = aC;
        }

        ushort a = 0, b = 0, c = 0;
    }

    struct Shader
    {
      void load( string vertexPath, string fragmentPath, VkDevice device )
        {
            // Vertex shader
            {
                auto file = File( vertexPath, "r" );

                if (!file.isOpen())
                {
                    assert( false, "Could not open vertex shader file" );
                }
                
                char[] vertexData = new char[ 100 ];

                VkShaderModuleCreateInfo moduleCreateInfo;
                moduleCreateInfo.sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO;
                moduleCreateInfo.pNext = null;
                moduleCreateInfo.codeSize = vertexData.length;
                moduleCreateInfo.pCode = cast(uint*)vertexData.ptr;
                moduleCreateInfo.flags = 0;

                VkShaderModule shaderModule;
                enforceVk( vkCreateShaderModule( device, &moduleCreateInfo, null, &shaderModule ) );

                vertexInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
                vertexInfo.stage = VK_SHADER_STAGE_VERTEX_BIT;
                vertexInfo._module = shaderModule;
                vertexInfo.pName = "main";
                vertexInfo.pNext = null;
                vertexInfo.flags = 0;
                vertexInfo.pSpecializationInfo = null;
            }

            // Fragment shader
            {
                auto file = File( fragmentPath, "r" );
                
                if (!file.isOpen())
                {
                    assert( false, "Could not open fragment shader file" );
                }

                char[] fragmentData = new char[ 100 ];

                VkShaderModuleCreateInfo moduleCreateInfo;
                moduleCreateInfo.sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO;
                moduleCreateInfo.pNext = null;
                moduleCreateInfo.codeSize = fragmentData.length;
                moduleCreateInfo.pCode = cast(uint*)fragmentData.ptr;
                moduleCreateInfo.flags = 0;

                VkShaderModule shaderModule;
                enforceVk( vkCreateShaderModule( device, &moduleCreateInfo, null, &shaderModule ) );

                fragmentInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
                fragmentInfo.stage = VK_SHADER_STAGE_FRAGMENT_BIT;
                fragmentInfo._module = shaderModule;
                fragmentInfo.pName = "main";
                fragmentInfo.pNext = null;
                fragmentInfo.flags = 0;
                fragmentInfo.pSpecializationInfo = null;
            }
        }
      
        VkPipelineShaderStageCreateInfo vertexInfo;
        VkPipelineShaderStageCreateInfo fragmentInfo;
    }

    VkSurfaceKHR surface;
    VkDevice device;
    VkInstance instance;
    VkPhysicalDevice physicalDevice;
    VkFormat depthFormat;
    VkFormat colorFormat;
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
    VkFramebuffer[ 2 ] frameBuffers;
    VkRenderPass renderPass;
    VkDescriptorSetLayout descriptorSetLayout;
    VkDescriptorSet[] descriptorSets;
    VkDescriptorPool descriptorPool;
    VkPipelineLayout pipelineLayout;
    int queueNodeIndex;
    uint currentBuffer;  
    SwapChainBuffer[] swapChainBuffers;
    DepthStencil depthStencil;
    VertexPTC[] quadVertices;
    Face[] quadIndices;
    Shader shader;
  
    struct VertexBuffer
    {
        void generate( VertexPTC[] vertices, Face[] indices, GfxDeviceVulkan gfxDevice )
        {
            struct StagingBuffer
            {
                VkDeviceMemory memory;
                VkBuffer buffer;
            }

            struct StagingBuffers
            {
                StagingBuffer vertices;
                StagingBuffer indices;
            }

            StagingBuffers stagingBuffers;
            
            int vertexBufferSize = cast(int)(vertices.length * VertexPTC.sizeof);

            // Vertex buffer
            gfxDevice.createBuffer( stagingBuffers.vertices.buffer, vertexBufferSize, stagingBuffers.vertices.memory, VK_BUFFER_USAGE_TRANSFER_SRC_BIT, VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT, "staging vertex buffer" );

            void* bufferData = null;
            enforceVk( vkMapMemory( gfxDevice.device, stagingBuffers.vertices.memory, 0, vertexBufferSize, 0, &bufferData ) );

            memcpy( bufferData, vertices.ptr, vertexBufferSize );
            vkUnmapMemory( gfxDevice.device, stagingBuffers.vertices.memory );

            gfxDevice.createBuffer( vertexBuffer, vertexBufferSize, vertexMem, VK_BUFFER_USAGE_VERTEX_BUFFER_BIT | VK_BUFFER_USAGE_TRANSFER_DST_BIT, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, "vertex buffer" );
            assert( vertexBuffer != VK_NULL_HANDLE, "vertex buffer is null" );
            gfxDevice.copyBuffer( stagingBuffers.vertices.buffer, vertexBuffer, vertexBufferSize );

            vkDestroyBuffer( gfxDevice.device, stagingBuffers.vertices.buffer, null );
            vkFreeMemory( gfxDevice.device, stagingBuffers.vertices.memory, null );

            // Index buffer
            int indexBufferSize = cast(int)(indices.length * Face.sizeof);

            gfxDevice.createBuffer( stagingBuffers.indices.buffer, indexBufferSize, stagingBuffers.indices.memory, VK_BUFFER_USAGE_TRANSFER_SRC_BIT, VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT, "staging index buffer" );

            enforceVk( vkMapMemory( gfxDevice.device, stagingBuffers.indices.memory, 0, indexBufferSize, 0, &bufferData ) );

            memcpy( bufferData, indices.ptr, indexBufferSize );
            vkUnmapMemory( gfxDevice.device, stagingBuffers.indices.memory );

            gfxDevice.createBuffer( indexBuffer, indexBufferSize, indexMem, VK_BUFFER_USAGE_INDEX_BUFFER_BIT | VK_BUFFER_USAGE_TRANSFER_DST_BIT, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, "index buffer" );
            gfxDevice.copyBuffer( stagingBuffers.indices.buffer, indexBuffer, indexBufferSize );

            vkDestroyBuffer( gfxDevice.device, stagingBuffers.indices.buffer, null );
            vkFreeMemory( gfxDevice.device, stagingBuffers.indices.memory, null );

            const int VERTEX_BUFFER_BIND_ID = 0;
            const int POSITION_INDEX = 0;
            const int TEXCOORD_INDEX = 1;
            const int COLOR_INDEX = 2;
            
            bindingDescriptions = new VkVertexInputBindingDescription[ 1 ];
            bindingDescriptions[ 0 ].binding = VERTEX_BUFFER_BIND_ID;
            bindingDescriptions[ 0 ].stride = VertexPTC.sizeof;
            bindingDescriptions[ 0 ].inputRate = VK_VERTEX_INPUT_RATE_VERTEX;

            attributeDescriptions = new VkVertexInputAttributeDescription[ 3 ];

            // Location 0 : Position
            attributeDescriptions[ 0 ].binding = VERTEX_BUFFER_BIND_ID;
            attributeDescriptions[ 0 ].location = POSITION_INDEX;
            attributeDescriptions[ 0 ].format = VK_FORMAT_R32G32B32_SFLOAT;
            attributeDescriptions[ 0 ].offset = 0;

            // Location 1 : TexCoord
            attributeDescriptions[ 1 ].binding = VERTEX_BUFFER_BIND_ID;
            attributeDescriptions[ 1 ].location = TEXCOORD_INDEX;
            attributeDescriptions[ 1 ].format = VK_FORMAT_R32G32_SFLOAT;
            attributeDescriptions[ 1 ].offset = float.sizeof * 3;

            // Location 2 : Color
            attributeDescriptions[ 2 ].binding = VERTEX_BUFFER_BIND_ID;
            attributeDescriptions[ 2 ].location = COLOR_INDEX;
            attributeDescriptions[ 2 ].format = VK_FORMAT_R32G32B32A32_SFLOAT;
            attributeDescriptions[ 2 ].offset = float.sizeof * 5;

            inputState.sType = VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO;
            inputState.pNext = null;
            inputState.vertexBindingDescriptionCount = cast(uint32_t)bindingDescriptions.length;
            inputState.pVertexBindingDescriptions = bindingDescriptions.ptr;
            inputState.vertexAttributeDescriptionCount = cast(uint32_t)attributeDescriptions.length;
            inputState.pVertexAttributeDescriptions = attributeDescriptions.ptr;
        }

        VkBuffer vertexBuffer;
        VkDeviceMemory vertexMem;
        VkPipelineVertexInputStateCreateInfo inputState;
        VkBuffer indexBuffer;
        VkDeviceMemory indexMem;
        VkVertexInputBindingDescription[] bindingDescriptions;
        VkVertexInputAttributeDescription[] attributeDescriptions;
    }

    VertexBuffer vertexBuffer;
}
