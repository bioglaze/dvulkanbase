import core.stdc.string;
import erupted;
import erupted.vulkan_lib_loader;
import matrix4x4;
import std.conv;
import std.exception;
import std.stdio;
version(linux)
{
    import X11.Xlib_xcb;
    public import xcb.xcb;
    import erupted.platform_extensions;
    mixin Platform_Extensions!USE_PLATFORM_XCB_KHR;
}

version(Windows)
{
    import core.sys.windows.windows;
    import erupted.platform_extensions;
    mixin Platform_Extensions!USE_PLATFORM_WIN32_KHR;
}

const(char*) getObjectType( VkObjectType type ) nothrow @nogc
{
    switch( type )
    {
    case VK_OBJECT_TYPE_QUERY_POOL: return "VK_OBJECT_TYPE_QUERY_POOL";
    case VK_OBJECT_TYPE_OBJECT_TABLE_NVX: return "VK_OBJECT_TYPE_OBJECT_TABLE_NVX";
    case VK_OBJECT_TYPE_SAMPLER_YCBCR_CONVERSION: return "VK_OBJECT_TYPE_SAMPLER_YCBCR_CONVERSION";
    case VK_OBJECT_TYPE_SEMAPHORE: return "VK_OBJECT_TYPE_SEMAPHORE";
    case VK_OBJECT_TYPE_SHADER_MODULE: return "VK_OBJECT_TYPE_SHADER_MODULE";
    case VK_OBJECT_TYPE_SWAPCHAIN_KHR: return "VK_OBJECT_TYPE_SWAPCHAIN_KHR";
    case VK_OBJECT_TYPE_SAMPLER: return "VK_OBJECT_TYPE_SAMPLER";
    case VK_OBJECT_TYPE_INDIRECT_COMMANDS_LAYOUT_NVX: return "VK_OBJECT_TYPE_INDIRECT_COMMANDS_LAYOUT_NVX";
    case VK_OBJECT_TYPE_DEBUG_REPORT_CALLBACK_EXT: return "VK_OBJECT_TYPE_DEBUG_REPORT_CALLBACK_EXT";
    case VK_OBJECT_TYPE_IMAGE: return "VK_OBJECT_TYPE_IMAGE";
    case VK_OBJECT_TYPE_UNKNOWN: return "VK_OBJECT_TYPE_UNKNOWN";
    case VK_OBJECT_TYPE_DESCRIPTOR_POOL: return "VK_OBJECT_TYPE_DESCRIPTOR_POOL";
    case VK_OBJECT_TYPE_COMMAND_BUFFER: return "VK_OBJECT_TYPE_COMMAND_BUFFER";
    case VK_OBJECT_TYPE_BUFFER: return "VK_OBJECT_TYPE_BUFFER";
    case VK_OBJECT_TYPE_SURFACE_KHR: return "VK_OBJECT_TYPE_SURFACE_KHR";
    case VK_OBJECT_TYPE_INSTANCE: return "VK_OBJECT_TYPE_INSTANCE";
    case VK_OBJECT_TYPE_VALIDATION_CACHE_EXT: return "VK_OBJECT_TYPE_VALIDATION_CACHE_EXT";
    case VK_OBJECT_TYPE_IMAGE_VIEW: return "VK_OBJECT_TYPE_IMAGE_VIEW";
    case VK_OBJECT_TYPE_DESCRIPTOR_SET: return "VK_OBJECT_TYPE_DESCRIPTOR_SET";
    case VK_OBJECT_TYPE_DESCRIPTOR_SET_LAYOUT: return "VK_OBJECT_TYPE_DESCRIPTOR_SET_LAYOUT";
    case VK_OBJECT_TYPE_COMMAND_POOL: return "VK_OBJECT_TYPE_COMMAND_POOL";
    case VK_OBJECT_TYPE_PHYSICAL_DEVICE: return "VK_OBJECT_TYPE_PHYSICAL_DEVICE";
    case VK_OBJECT_TYPE_DISPLAY_KHR: return "VK_OBJECT_TYPE_DISPLAY_KHR";
    case VK_OBJECT_TYPE_BUFFER_VIEW: return "VK_OBJECT_TYPE_BUFFER_VIEW";
    case VK_OBJECT_TYPE_DEBUG_UTILS_MESSENGER_EXT: return "VK_OBJECT_TYPE_DEBUG_UTILS_MESSENGER_EXT";
    case VK_OBJECT_TYPE_FRAMEBUFFER: return "VK_OBJECT_TYPE_FRAMEBUFFER";
    case VK_OBJECT_TYPE_DESCRIPTOR_UPDATE_TEMPLATE: return "VK_OBJECT_TYPE_DESCRIPTOR_UPDATE_TEMPLATE";
    case VK_OBJECT_TYPE_PIPELINE_CACHE: return "VK_OBJECT_TYPE_PIPELINE_CACHE";
    case VK_OBJECT_TYPE_PIPELINE_LAYOUT: return "VK_OBJECT_TYPE_PIPELINE_LAYOUT";
    case VK_OBJECT_TYPE_DEVICE_MEMORY: return "VK_OBJECT_TYPE_DEVICE_MEMORY";
    case VK_OBJECT_TYPE_FENCE: return "VK_OBJECT_TYPE_FENCE";
    case VK_OBJECT_TYPE_QUEUE: return "VK_OBJECT_TYPE_QUEUE";
    case VK_OBJECT_TYPE_DEVICE: return "VK_OBJECT_TYPE_DEVICE";
    case VK_OBJECT_TYPE_RENDER_PASS: return "VK_OBJECT_TYPE_RENDER_PASS";
    case VK_OBJECT_TYPE_DISPLAY_MODE_KHR: return "VK_OBJECT_TYPE_DISPLAY_MODE_KHR";
    case VK_OBJECT_TYPE_EVENT:return "VK_OBJECT_TYPE_EVENT";
    case VK_OBJECT_TYPE_PIPELINE: return "VK_OBJECT_TYPE_PIPELINE";
    default:
        return "unhandled type";
    }
}

extern(System) VkBool32 myDebugReportCallback( VkDebugUtilsMessageSeverityFlagBitsEXT msgSeverity, VkDebugUtilsMessageTypeFlagsEXT msgType,
                                        const VkDebugUtilsMessengerCallbackDataEXT* callbackData, void* /*userData*/ ) nothrow @nogc
{
    if (msgSeverity & VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT)
    {
        printf( "ERROR: %s\n", callbackData.pMessage );
    }
    else if (msgSeverity & VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT)
    {
        printf( "WARNING: %s\n", callbackData.pMessage );
    }
    else if (msgSeverity & VK_DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT)
    {
        printf( "INFO: %s\n", callbackData.pMessage );
    }
    else if (msgSeverity & VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT)
    {
        printf( "VERBOSE: %s\n", callbackData.pMessage );
    }

    if (msgType & VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT)
    {
        printf( "GENERAL: %s\n", callbackData.pMessage );
    }
    else if (msgType & VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT)
    {
        printf( "PERF: %s\n", callbackData.pMessage );
    }

    if (callbackData.objectCount > 0)
    {
        printf( "Objects: %u\n", callbackData.objectCount );

        for (int i = 0; i < callbackData.objectCount; ++i)
        {
            const char* name = callbackData.pObjects[ i ].pObjectName ? callbackData.pObjects[ i ].pObjectName : "unnamed";
            printf( "Object %u: name: %s, type: %s\n", i, name, getObjectType( callbackData.pObjects[ i ].objectType ) );
            //printf( "Object %u: name: %s, type: TODO\n", i, name );
        }
    }

    printf( "Vulkan validation error!" );
    return VK_FALSE;
}

void enforceVk( VkResult res )
{
    enforce( res is VkResult.VK_SUCCESS, res.to!string );
}

enum BlendMode
{
    Off,
}

enum DepthFunc
{
    NoneWriteOff,
}

enum CullMode
{
    Off,
}

struct UniformBuffer
{
    Matrix4x4 modelToClip;
    float[ 4 ] tintColor;
    int textureIndex;
}

struct InstanceData
{
    float[ 3 ] pos;
    float[ 2 ] uv;
    float[ 4 ] color;
}

class GfxDeviceVulkan
{
    private bool isDebug = true;
    
    this( int width, int height, void* windowHandleOrWindow, void* display, uint window )
    {
        loadGlobalLevelFunctions();
        VkApplicationInfo appinfo;
        appinfo.pApplicationName = "VulkanBase";
        appinfo.apiVersion = VK_MAKE_VERSION( 1, 0, 2 );

        version(Windows)
        {
            const(char*)[3] extensionNames = [
                                            "VK_KHR_surface",
                                            "VK_KHR_win32_surface",
                                            "VK_EXT_debug_utils",
                                            ];
        }
        version(linux)
        {
            const(char*)[3] extensionNames = [
                                            "VK_KHR_surface",
                                            "VK_KHR_xcb_surface",
                                            //"VK_KHR_wayland_surface",
                                            "VK_EXT_debug_utils",
                                            ];
        }
        
        uint extensionCount = 0;
        vkEnumerateInstanceExtensionProperties( null, &extensionCount, null );

        auto extensionProps = new VkExtensionProperties[]( extensionCount );
        vkEnumerateInstanceExtensionProperties( null, &extensionCount, extensionProps.ptr );
        
        uint layerCount = 0;
        vkEnumerateInstanceLayerProperties( &layerCount, null );

        auto layerProps = new VkLayerProperties[]( layerCount );
        vkEnumerateInstanceLayerProperties( &layerCount, layerProps.ptr );

        const(char*)[1] validationLayers = ["VK_LAYER_KHRONOS_validation"];
        
        VkInstanceCreateInfo createinfo;
        createinfo.sType = VkStructureType.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
        createinfo.pApplicationInfo = &appinfo;
        createinfo.enabledExtensionCount = isDebug ? cast(uint)extensionNames.length : 2;
        createinfo.ppEnabledExtensionNames = extensionNames.ptr;
        createinfo.enabledLayerCount = isDebug ? validationLayers.length : 0;
        createinfo.ppEnabledLayerNames = isDebug ? validationLayers.ptr : null;

        enforceVk( vkCreateInstance( &createinfo, null, &instance ) );

        loadInstanceLevelFunctions( instance );

        if (isDebug)
        {
            VkDebugUtilsMessengerCreateInfoEXT dbg_messenger_create_info;
            dbg_messenger_create_info.sType = VkStructureType.VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT;
            dbg_messenger_create_info.messageSeverity = VkDebugUtilsMessageSeverityFlagBitsEXT.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT | VkDebugUtilsMessageSeverityFlagBitsEXT.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT;
            dbg_messenger_create_info.messageType = VkDebugUtilsMessageTypeFlagBitsEXT.VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT | VkDebugUtilsMessageTypeFlagBitsEXT.VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT | VkDebugUtilsMessageTypeFlagBitsEXT.VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT;
            dbg_messenger_create_info.pfnUserCallback = &myDebugReportCallback;
            VkDebugUtilsMessengerEXT dbgMessenger;
            enforceVk( vkCreateDebugUtilsMessengerEXT( instance, &dbg_messenger_create_info, null, &dbgMessenger ) );
        }
        
        version(Windows)
        {
            VkWin32SurfaceCreateInfoKHR surfaceCreateInfo;
            surfaceCreateInfo.sType = VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR;
            surfaceCreateInfo.hinstance = windowHandleOrWindow;
            surfaceCreateInfo.hwnd = windowHandleOrWindow;
            enforceVk( vkCreateWin32SurfaceKHR( instance, &surfaceCreateInfo, null, &surface ) );
        }
        version(linux)
        {
            auto xcbInfo = VkXcbSurfaceCreateInfoKHR(
              VkStructureType.VK_STRUCTURE_TYPE_XCB_SURFACE_CREATE_INFO_KHR,
              null,
              0,
              XGetXCBConnection( cast(xcb_connection_t*)display ),
              window
            );
            enforceVk( vkCreateXcbSurfaceKHR( instance, &xcbInfo, null, &surface ) );

            /*auto waylandInfo = VkWaylandSurfaceCreateInfoKHR(
              VkStructureType.VK_STRUCTURE_TYPE_WAYLAND_SURFACE_CREATE_INFO_KHR,
              null,
              0,
              cast(wl_display*)display,
              cast(wl_surface*)windowHandleOrWindow
            );
            enforceVk( vkCreateWaylandSurfaceKHR( instance, &waylandInfo, null, &surface ) );*/
        }

        createDevice( width, height );
        createDepthStencil( width, height );
        createSemaphores();
        createRenderPass();
        flushSetupCommandBuffer();
        createDescriptorSetLayout();
        createDescriptorPool();
        createUniformBuffer( quad1Ubo );
        createIndirectCommands();
        createInstanceData();
        
        drawCmdBuffers = new VkCommandBuffer[ swapChainBuffers.length ];
        frameBuffers = new VkFramebuffer[ swapChainBuffers.length ];

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

        for (uint32_t bufferIndex = 0; bufferIndex < swapChainBuffers.length; ++bufferIndex)
        {
            attachments[ 0 ] = swapChainBuffers[ bufferIndex ].view;
            enforceVk( vkCreateFramebuffer( device, &frameBufferCreateInfo, null, &frameBuffers[ bufferIndex ] ) );
        }

		VkCommandBufferAllocateInfo cmdBufInfo;
        cmdBufInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
        cmdBufInfo.commandPool = cmdPool;
        cmdBufInfo.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
        cmdBufInfo.commandBufferCount = 1;

        enforceVk( vkAllocateCommandBuffers( device, &cmdBufInfo, &texCmdBuffer ) );

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
    
        shader.load( "assets/shader_vert_hlsl.spv", "assets/shader_frag_hlsl.spv", device );
    }

    private void createDescriptorSetLayout()
    {
        // Binding 0 : Uniform buffer
        VkDescriptorSetLayoutBinding layoutBindingUBO;
        layoutBindingUBO.binding = 0;
        layoutBindingUBO.descriptorType = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER;
        layoutBindingUBO.descriptorCount = 1;
        layoutBindingUBO.stageFlags = VK_SHADER_STAGE_VERTEX_BIT | VK_SHADER_STAGE_FRAGMENT_BIT | VK_SHADER_STAGE_COMPUTE_BIT;
        layoutBindingUBO.pImmutableSamplers = null;

        // Binding 1 : Image (Fragment shader)
        VkDescriptorSetLayoutBinding layoutBindingImage;
        layoutBindingImage.binding = 1;
        layoutBindingImage.descriptorType = VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE;
        layoutBindingImage.descriptorCount = 3;
        layoutBindingImage.stageFlags = VK_SHADER_STAGE_FRAGMENT_BIT;
        layoutBindingImage.pImmutableSamplers = null;

        // Binding 2 : Sampler (Fragment shader)
        VkDescriptorSetLayoutBinding layoutBindingSampler;
        layoutBindingSampler.binding = 2;
        layoutBindingSampler.descriptorType = VK_DESCRIPTOR_TYPE_SAMPLER;
        layoutBindingSampler.descriptorCount = 1;
        layoutBindingSampler.stageFlags = VK_SHADER_STAGE_FRAGMENT_BIT;
        layoutBindingSampler.pImmutableSamplers = null;

        VkDescriptorSetLayoutBinding[ 3 ] bindings = [ layoutBindingUBO, layoutBindingImage, layoutBindingSampler ];

        VkDescriptorSetLayoutCreateInfo descriptorLayout;
        descriptorLayout.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO;
        descriptorLayout.pNext = null;
        descriptorLayout.bindingCount = bindings.length;
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
        const int count = 2;
        VkDescriptorPoolSize[ 3 ] typeCounts;
        typeCounts[ 0 ].type = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER;
        typeCounts[ 0 ].descriptorCount = count;
        typeCounts[ 1 ].type = VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE;
        typeCounts[ 1 ].descriptorCount = 3 * 3;
        typeCounts[ 2 ].type = VK_DESCRIPTOR_TYPE_SAMPLER;
        typeCounts[ 2 ].descriptorCount = count;

        VkDescriptorPoolCreateInfo descriptorPoolInfo;
        descriptorPoolInfo.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO;
        descriptorPoolInfo.pNext = null;
        descriptorPoolInfo.poolSizeCount = typeCounts.length;
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
                             VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
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

    private void createUniformBuffer( ref Ubo ubo )
    {
        const VkDeviceSize uboSize = 256;

        VkBufferCreateInfo bufferInfo;
        bufferInfo.sType = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO;
        bufferInfo.size = uboSize;
        bufferInfo.usage = VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT;

        enforceVk( vkCreateBuffer( device, &bufferInfo, null, &ubo.ubo ) );

        VkMemoryRequirements memReqs;
        vkGetBufferMemoryRequirements( device, ubo.ubo, &memReqs );

        VkMemoryAllocateInfo allocInfo;
        allocInfo.sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
        allocInfo.pNext = null;
        allocInfo.allocationSize = memReqs.size;
        allocInfo.memoryTypeIndex = getMemoryType( memReqs.memoryTypeBits, VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT );
        enforceVk( vkAllocateMemory( device, &allocInfo, null, &ubo.memory ) );

        enforceVk( vkBindBufferMemory( device, ubo.ubo, ubo.memory, 0 ) );

        ubo.desc.buffer = ubo.ubo;
        ubo.desc.offset = 0;
        ubo.desc.range = uboSize;

        enforceVk( vkMapMemory( device, ubo.memory, 0, uboSize, 0, cast(void **)&ubo.data ) );
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

        ++currentFrame;
    }

    private void beginRenderPass( int windowWidth, int windowHeight )
    {
        VkCommandBufferBeginInfo cmdBufInfo;
        cmdBufInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
        cmdBufInfo.pNext = null;

        VkClearColorValue clearColor;
        clearColor.int32 = [ 1, 0, 0, 1 ];
        VkClearValue[ 2 ] clearValues;
        clearValues[ 0 ].color = clearColor;
        clearValues[ 1 ].depthStencil = VkClearDepthStencilValue( 1.0f, 0 );

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
        viewport.x = 0.0f;
        viewport.y = 0.0f;
        viewport.height = cast(float)windowHeight;
        viewport.width = cast(float)windowWidth;
        viewport.minDepth = 0.0f;
        viewport.maxDepth = 1.0f;
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
        enabledFeatures.shaderTessellationAndGeometryPointSize = VK_TRUE;
        enabledFeatures.shaderClipDistance = VK_TRUE;
        enabledFeatures.shaderCullDistance = VK_TRUE;
        enabledFeatures.multiDrawIndirect = VK_TRUE;
        
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
        
        if (surfCaps.currentExtent.width == cast(uint)-1)
        {
            swapchainExtent.width = width;
            swapchainExtent.height = height;
        }
        else
        {
            swapchainExtent = surfCaps.currentExtent;
        }

        uint32_t desiredNumberOfSwapchainImages = surfCaps.minImageCount + 1;

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

        VkSamplerCreateInfo samplerInfo;
        samplerInfo.sType = VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO;
        samplerInfo.pNext = null;
        samplerInfo.magFilter = VK_FILTER_NEAREST;
        samplerInfo.minFilter = samplerInfo.magFilter;
        samplerInfo.mipmapMode = VK_SAMPLER_MIPMAP_MODE_NEAREST;
        samplerInfo.addressModeU = VK_SAMPLER_ADDRESS_MODE_REPEAT;
        samplerInfo.addressModeV = samplerInfo.addressModeU;
        samplerInfo.addressModeW = samplerInfo.addressModeU;
        samplerInfo.mipLodBias = 0;
        samplerInfo.compareOp = VK_COMPARE_OP_NEVER;
        samplerInfo.minLod = 0;
        samplerInfo.maxLod = VK_LOD_CLAMP_NONE;
        samplerInfo.maxAnisotropy = 1;
        samplerInfo.anisotropyEnable = VK_FALSE;
        samplerInfo.borderColor = VK_BORDER_COLOR_FLOAT_OPAQUE_WHITE;
        enforceVk( vkCreateSampler( device, &samplerInfo, null, &samplerNearestRepeat ) );
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
        mem_alloc.memoryTypeIndex = getMemoryType( memReqs.memoryTypeBits, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT );
        enforceVk( vkAllocateMemory( device, &mem_alloc, null, &depthStencil.mem ) );

        enforceVk( vkBindImageMemory( device, depthStencil.image, depthStencil.mem, 0 ) );

        setImageLayout( setupCmdBuffer, depthStencil.image, VK_IMAGE_ASPECT_DEPTH_BIT | VK_IMAGE_ASPECT_STENCIL_BIT,
                        VK_IMAGE_LAYOUT_UNDEFINED, VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL, 1, 0, 1 );

        depthStencilView.image = depthStencil.image;
        enforceVk( vkCreateImageView( device, &depthStencilView, null, &depthStencil.view ) );
    }

    uint32_t getMemoryType( uint32_t typeBits, VkFlags properties )
    {
        for (uint32_t i = 0; i < 32; ++i)
        {
            if ((typeBits & 1) == 1)
            {
                if ((deviceMemoryProperties.memoryTypes[ i ].propertyFlags & properties) == properties)
                {
                    return i;
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

        VkMemoryRequirements memReqs;
        VkMemoryAllocateInfo memAlloc;
        memAlloc.sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;

        vkGetBufferMemoryRequirements( device, buffer, &memReqs );
        memAlloc.allocationSize = memReqs.size;
        memAlloc.memoryTypeIndex = getMemoryType( memReqs.memoryTypeBits, memoryFlags );
        enforceVk( vkAllocateMemory( device, &memAlloc, null, &memory ) );
        enforceVk( vkBindBufferMemory( device, buffer, memory, 0 ) );
        assert( buffer != VK_NULL_HANDLE, "buffer is null" );
    }

    private uint64_t getPsoHash( VertexBuffer vb, Shader aShader, BlendMode blendMode, DepthFunc depthFunc, CullMode cullMode )
    {
        uint64_t result = cast(uint64_t)&vb;
        result += cast(uint64_t)&aShader;
        result += cast(uint64_t)blendMode;
        result += cast(uint64_t)depthFunc;
        result += cast(uint64_t)cullMode;
        return result;
    }
  
    public void updateDescriptorSet( VkSampler sampler, VkImageView view1, VkImageView view2, VkImageView view3 )
    {
        descriptorSetIndex = currentFrame % 2;

        // Binding 0 : Uniform buffer
        VkWriteDescriptorSet uboSet;
        uboSet.sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
        uboSet.dstSet = descriptorSets[ descriptorSetIndex ];
        uboSet.descriptorCount = 1;
        uboSet.descriptorType = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER;
        uboSet.pBufferInfo = &quad1Ubo.desc;
        uboSet.dstBinding = 0;

        // Binding 1 : Image
        VkDescriptorImageInfo samplerDesc;
        samplerDesc.sampler = sampler;
        samplerDesc.imageView = view1;
        samplerDesc.imageLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
        VkDescriptorImageInfo[ 3 ] samplerDescs = [ samplerDesc, samplerDesc, samplerDesc ];
        samplerDescs[ 1 ].imageView = view2;
        samplerDescs[ 2 ].imageView = view3;
        
        VkWriteDescriptorSet imageSet;
        imageSet.sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
        imageSet.dstSet = descriptorSets[ descriptorSetIndex ];
        imageSet.descriptorCount = samplerDescs.length;
        imageSet.descriptorType = VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE;
        imageSet.pImageInfo = samplerDescs.ptr;
        imageSet.dstBinding = 1;

        // Binding 2: Sampler
        VkWriteDescriptorSet samplerSet;
        samplerSet.sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
        samplerSet.dstSet = descriptorSets[ descriptorSetIndex ];
        samplerSet.descriptorCount = 1;
        samplerSet.descriptorType = VK_DESCRIPTOR_TYPE_SAMPLER;
        samplerSet.pImageInfo = &samplerDesc;
        samplerSet.dstBinding = 2;

        VkWriteDescriptorSet[ 3 ] sets = [ uboSet, imageSet, samplerSet ];
        vkUpdateDescriptorSets( device, sets.length, sets.ptr, 0, null );
    }

    public void draw( VertexBuffer vb, Shader aShader, BlendMode blendMode, DepthFunc depthFunc, CullMode cullMode, UniformBuffer unif )
    {
        memcpy( quad1Ubo.data, &unif, unif.sizeof );

        uint64_t psoHash = getPsoHash( vb, aShader, blendMode, depthFunc, cullMode );

        if (psoHash !in psoCache)
        {
            createPso( vertexBuffer, shader, blendMode, depthFunc, cullMode, psoHash );
        }

        vkCmdBindDescriptorSets( drawCmdBuffers[ currentBuffer ], VK_PIPELINE_BIND_POINT_GRAPHICS, pipelineLayout, 0, 1, &descriptorSets[ descriptorSetIndex ], 0, null );
        vkCmdBindPipeline( drawCmdBuffers[ currentBuffer ], VK_PIPELINE_BIND_POINT_GRAPHICS, psoCache[ psoHash ] );

        VkDeviceSize[ 3 ] offsets = [ 0, 0, 0 ];
        VkBuffer[ 3 ] buffers = [ vb.positionBuffer, vb.uvBuffer, vb.colorBuffer ];
        // Vertex buffer
        vkCmdBindVertexBuffers( drawCmdBuffers[ currentBuffer ], 0, buffers.length, buffers.ptr, offsets.ptr );
        // Instance data buffer
        VkDeviceSize[ 1 ] instanceOffsets = [ 0 ];
        vkCmdBindVertexBuffers( drawCmdBuffers[ currentBuffer ], 3, 1, &instanceBuffer, instanceOffsets.ptr );
        
        vkCmdBindIndexBuffer( drawCmdBuffers[ currentBuffer ], vb.indexBuffer, 0, VK_INDEX_TYPE_UINT16 );

        int indirectDrawCount = 1;
        vkCmdDrawIndexedIndirect( drawCmdBuffers[ currentBuffer ], indirectBuffer, 0, indirectDrawCount, VkDrawIndexedIndirectCommand.sizeof );
    }
    
    private void createIndirectCommands()
    {
        indirectCommands = new VkDrawIndexedIndirectCommand[ 1 ];

        int instanceCount = 2;
        int indexCount = 6;
        
        indirectCommands[ 0 ].instanceCount = instanceCount;
        indirectCommands[ 0 ].firstInstance = 0 * instanceCount;
        indirectCommands[ 0 ].firstIndex = 0;
        indirectCommands[ 0 ].indexCount = indexCount;

        VkBuffer stagingBuffer;
        VkBufferCreateInfo bufferInfo;
        bufferInfo.sType = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO;
        bufferInfo.size = indirectCommands.length * VkDrawIndexedIndirectCommand.sizeof;
        bufferInfo.usage = VK_BUFFER_USAGE_TRANSFER_SRC_BIT;
        enforceVk( vkCreateBuffer( device, &bufferInfo, null, &stagingBuffer ) );

        VkDeviceMemory stagingMemory;
        VkMemoryRequirements memReqs;
        VkMemoryAllocateInfo memAlloc;
        memAlloc.sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;

        vkGetBufferMemoryRequirements( device, stagingBuffer, &memReqs );
        memAlloc.allocationSize = memReqs.size;
        memAlloc.memoryTypeIndex = getMemoryType( memReqs.memoryTypeBits, VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT );
        enforceVk( vkAllocateMemory( device, &memAlloc, null, &stagingMemory ) );
        enforceVk( vkBindBufferMemory( device, stagingBuffer, stagingMemory, 0 ) );

        bufferInfo.sType = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO;
        bufferInfo.size = indirectCommands.length * VkDrawIndexedIndirectCommand.sizeof;
        bufferInfo.usage = VK_BUFFER_USAGE_INDIRECT_BUFFER_BIT | VK_BUFFER_USAGE_TRANSFER_DST_BIT;
        enforceVk( vkCreateBuffer( device, &bufferInfo, null, &indirectBuffer ) );

        vkGetBufferMemoryRequirements( device, indirectBuffer, &memReqs );
        memAlloc.allocationSize = memReqs.size;
        memAlloc.memoryTypeIndex = getMemoryType( memReqs.memoryTypeBits, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT );
        enforceVk( vkAllocateMemory( device, &memAlloc, null, &indirectMemory ) );
        enforceVk( vkBindBufferMemory( device, indirectBuffer, indirectMemory, 0 ) );

        void* mappedStagingMemory;
        enforceVk( vkMapMemory( device, stagingMemory, 0, bufferInfo.size, 0, &mappedStagingMemory ) );
        memcpy( mappedStagingMemory, indirectCommands.ptr, bufferInfo.size );
        
        copyBuffer( stagingBuffer, indirectBuffer, cast(int)bufferInfo.size );
    }

    private void createInstanceData()
    {
        int instanceDataCount = 2;
        
        VkBuffer stagingBuffer;
        VkBufferCreateInfo bufferInfo;
        bufferInfo.sType = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO;
        bufferInfo.size = instanceDataCount * InstanceData.sizeof;
        bufferInfo.usage = VK_BUFFER_USAGE_TRANSFER_SRC_BIT;
        enforceVk( vkCreateBuffer( device, &bufferInfo, null, &stagingBuffer ) );

        VkDeviceMemory stagingMemory;
        VkMemoryRequirements memReqs;
        VkMemoryAllocateInfo memAlloc;
        memAlloc.sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;

        vkGetBufferMemoryRequirements( device, stagingBuffer, &memReqs );
        memAlloc.allocationSize = memReqs.size;
        memAlloc.memoryTypeIndex = getMemoryType( memReqs.memoryTypeBits, VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT );
        enforceVk( vkAllocateMemory( device, &memAlloc, null, &stagingMemory ) );
        enforceVk( vkBindBufferMemory( device, stagingBuffer, stagingMemory, 0 ) );

        bufferInfo.sType = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO;
        bufferInfo.size = instanceDataCount * InstanceData.sizeof;
        bufferInfo.usage = VK_BUFFER_USAGE_VERTEX_BUFFER_BIT | VK_BUFFER_USAGE_TRANSFER_DST_BIT;
        enforceVk( vkCreateBuffer( device, &bufferInfo, null, &instanceBuffer ) );

        vkGetBufferMemoryRequirements( device, instanceBuffer, &memReqs );
        memAlloc.allocationSize = memReqs.size;
        memAlloc.memoryTypeIndex = getMemoryType( memReqs.memoryTypeBits, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT );
        enforceVk( vkAllocateMemory( device, &memAlloc, null, &instanceMemory ) );
        enforceVk( vkBindBufferMemory( device, instanceBuffer, instanceMemory, 0 ) );

        InstanceData[ 2 ] instanceDatas;
        instanceDatas[ 0 ].pos = [ 0, 0, 0 ];
        instanceDatas[ 0 ].uv = [ 0, 0 ];
        instanceDatas[ 0 ].color = [ 1, 1, 1, 1 ];
        instanceDatas[ 1 ].pos = [ 100, 0, 0 ];
        instanceDatas[ 1 ].uv = [ 0, 0 ];
        instanceDatas[ 1 ].color = [ 1, 1, 1, 1 ];
        
        void* mappedStagingMemory;
        enforceVk( vkMapMemory( device, stagingMemory, 0, bufferInfo.size, 0, &mappedStagingMemory ) );
        memcpy( mappedStagingMemory, &instanceDatas, bufferInfo.size );
        
        copyBuffer( stagingBuffer, instanceBuffer, cast(int)bufferInfo.size );
    }
    
    private void createPso( VertexBuffer vb, Shader shader, BlendMode blendMode, DepthFunc depthFunc, CullMode cullMode, uint64_t psoHash )
    {
        VkPipelineInputAssemblyStateCreateInfo inputAssemblyState;
        inputAssemblyState.sType = VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO;
        inputAssemblyState.topology = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST;
        inputAssemblyState.primitiveRestartEnable = VK_FALSE;
        
        VkPipelineRasterizationStateCreateInfo rasterizationState;
        rasterizationState.sType = VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO;
        rasterizationState.polygonMode = VK_POLYGON_MODE_FILL;

        rasterizationState.cullMode = VK_CULL_MODE_NONE;
        rasterizationState.frontFace = VK_FRONT_FACE_COUNTER_CLOCKWISE;
        rasterizationState.depthClampEnable = VK_FALSE;
        rasterizationState.depthBiasClamp = 0.0f;
        rasterizationState.rasterizerDiscardEnable = VK_FALSE;
        rasterizationState.depthBiasEnable = VK_FALSE;
        rasterizationState.depthBiasSlopeFactor = 0.0f;
        rasterizationState.depthBiasConstantFactor = 0.0f;
        rasterizationState.lineWidth = 1;

        VkPipelineColorBlendAttachmentState[ 1 ] blendAttachmentState;
        blendAttachmentState[ 0 ].colorWriteMask = 0xF;
        blendAttachmentState[ 0 ].blendEnable = VK_FALSE;

        VkPipelineColorBlendStateCreateInfo colorBlendState;
        colorBlendState.sType = VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO;
        colorBlendState.attachmentCount = 1;
        colorBlendState.pAttachments = blendAttachmentState.ptr;

        VkPipelineDynamicStateCreateInfo dynamicState;
        VkDynamicState[ 2 ] dynamicStateEnables;
        dynamicStateEnables[ 0 ] = VK_DYNAMIC_STATE_VIEWPORT;
        dynamicStateEnables[ 1 ] = VK_DYNAMIC_STATE_SCISSOR;
        dynamicState.sType = VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO;
        dynamicState.pDynamicStates = &dynamicStateEnables[ 0 ];
        dynamicState.dynamicStateCount = 2;

        VkPipelineDepthStencilStateCreateInfo depthStencilState;
        depthStencilState.sType = VK_STRUCTURE_TYPE_PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO;
        depthStencilState.depthTestEnable = VK_FALSE;
        depthStencilState.depthWriteEnable = VK_TRUE;
        depthStencilState.depthCompareOp = VK_COMPARE_OP_LESS_OR_EQUAL;
        depthStencilState.depthBoundsTestEnable = VK_FALSE;
        depthStencilState.back.failOp = VK_STENCIL_OP_KEEP;
        depthStencilState.back.passOp = VK_STENCIL_OP_KEEP;
        depthStencilState.back.compareOp = VK_COMPARE_OP_ALWAYS;
        depthStencilState.stencilTestEnable = VK_FALSE;
        depthStencilState.front = depthStencilState.back;

        VkPipelineMultisampleStateCreateInfo multisampleState;
        multisampleState.sType = VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO;
        multisampleState.pSampleMask = null;
        multisampleState.rasterizationSamples = VK_SAMPLE_COUNT_1_BIT;
        multisampleState.minSampleShading = 0.0f;
        
        VkPipelineShaderStageCreateInfo[ 2 ] shaderStages;

        shaderStages[ 0 ] = shader.vertexInfo;
        shaderStages[ 1 ] = shader.fragmentInfo;

        VkPipelineViewportStateCreateInfo viewportState;
        viewportState.sType = VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO;
        viewportState.viewportCount = 1;
        viewportState.scissorCount = 1;

        VkGraphicsPipelineCreateInfo pipelineCreateInfo;

        pipelineCreateInfo.sType = VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO;
        pipelineCreateInfo.layout = pipelineLayout;
        pipelineCreateInfo.renderPass = renderPass;
        pipelineCreateInfo.pVertexInputState = &vb.inputState;
        pipelineCreateInfo.pInputAssemblyState = &inputAssemblyState;
        pipelineCreateInfo.pRasterizationState = &rasterizationState;
        pipelineCreateInfo.pColorBlendState = &colorBlendState;
        pipelineCreateInfo.pMultisampleState = &multisampleState;
        pipelineCreateInfo.pViewportState = &viewportState;
        pipelineCreateInfo.pDepthStencilState = &depthStencilState;
        pipelineCreateInfo.stageCount = 2;
        pipelineCreateInfo.pStages = shaderStages.ptr;
        pipelineCreateInfo.pDynamicState = &dynamicState;

        VkPipeline pso;
        enforceVk( vkCreateGraphicsPipelines( device, pipelineCache, 1, &pipelineCreateInfo, null, &pso ) );
        psoCache[ psoHash ] = pso;
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
                
                char[] vertexCode = new char[ file.size ];
                auto vertexSlice = file.rawRead( vertexCode );
                
                VkShaderModuleCreateInfo moduleCreateInfo;
                moduleCreateInfo.sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO;
                moduleCreateInfo.pNext = null;
                moduleCreateInfo.codeSize = vertexSlice.length;
                moduleCreateInfo.pCode = cast(uint*)vertexCode.ptr;
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

                char[] fragmentCode = new char[ file.size ];
                auto fragmentSlice = file.rawRead( fragmentCode );

                VkShaderModuleCreateInfo moduleCreateInfo;
                moduleCreateInfo.sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO;
                moduleCreateInfo.pNext = null;
                moduleCreateInfo.codeSize = fragmentSlice.length;
                moduleCreateInfo.pCode = cast(uint*)fragmentCode.ptr;
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

    struct Ubo
    {
        VkBuffer ubo;
        VkDeviceMemory memory;
        VkDescriptorBufferInfo desc;
        uint8_t* data;
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
	VkCommandBuffer texCmdBuffer;
    VkCommandBuffer[] drawCmdBuffers;
    VkCommandBuffer prePresentCmdBuffer;
    VkCommandBuffer postPresentCmdBuffer;
    VkCommandPool cmdPool;
    VkSemaphore presentCompleteSemaphore;
    VkSemaphore renderCompleteSemaphore;
    VkFramebuffer[] frameBuffers;
    VkRenderPass renderPass;
    VkDescriptorSetLayout descriptorSetLayout;
    VkDescriptorSet[] descriptorSets;
    VkDescriptorPool descriptorPool;
    VkSampler samplerNearestRepeat;
    VkPipelineLayout pipelineLayout;
    VkDrawIndexedIndirectCommand[] indirectCommands;
    VkBuffer indirectBuffer;
    VkDeviceMemory indirectMemory;
    VkBuffer instanceBuffer;
    VkDeviceMemory instanceMemory;
    
    int queueNodeIndex;
    uint currentBuffer;
    uint currentFrame;
    SwapChainBuffer[] swapChainBuffers;
    DepthStencil depthStencil;

    VertexPTC[] quadVertices;
    Face[] quadIndices;
    Ubo quad1Ubo;
    Shader shader;

    VkPipeline[ uint64_t ] psoCache;
    VkPipelineCache pipelineCache;
    int descriptorSetIndex;
  
    struct VertexBuffer
    {
        void generate( VertexPTC[] vertices, Face[] indices, GfxDeviceVulkan gfxDevice )
        {
            float[] positions = new float[ vertices.length * 3 ];
            float[] uvs = new float[ vertices.length * 2 ];
            float[] colors = new float[ vertices.length * 4 ];

            for (int vertexIndex = 0; vertexIndex < vertices.length; ++vertexIndex)
            {
                positions[ vertexIndex * 3 + 0 ] = vertices[ vertexIndex ].x;
                positions[ vertexIndex * 3 + 1 ] = vertices[ vertexIndex ].y;
                positions[ vertexIndex * 3 + 2 ] = vertices[ vertexIndex ].z;

                uvs[ vertexIndex * 2 + 0 ] = vertices[ vertexIndex ].u;
                uvs[ vertexIndex * 2 + 1 ] = vertices[ vertexIndex ].v;

                colors[ vertexIndex * 4 + 0 ] = vertices[ vertexIndex ].r;
                colors[ vertexIndex * 4 + 1 ] = vertices[ vertexIndex ].g;
                colors[ vertexIndex * 4 + 2 ] = vertices[ vertexIndex ].b;
                colors[ vertexIndex * 4 + 3 ] = vertices[ vertexIndex ].a;
            }
            
            struct StagingBuffer
            {
                VkDeviceMemory memory;
                VkBuffer buffer;
            }

            struct StagingBuffers
            {
                StagingBuffer positions;
                StagingBuffer uvs;
                StagingBuffer colors;
                StagingBuffer indices;
            }

            StagingBuffers stagingBuffers;

            void* bufferData = null;
            
            // Position buffer
            {
                int positionBufferSize = cast(int)(positions.length * float.sizeof);
              
                gfxDevice.createBuffer( stagingBuffers.positions.buffer, positionBufferSize, stagingBuffers.positions.memory, VK_BUFFER_USAGE_TRANSFER_SRC_BIT, VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT, "staging position buffer" );

                enforceVk( vkMapMemory( gfxDevice.device, stagingBuffers.positions.memory, 0, positionBufferSize, 0, &bufferData ) );

                memcpy( bufferData, positions.ptr, positionBufferSize );
                vkUnmapMemory( gfxDevice.device, stagingBuffers.positions.memory );

                gfxDevice.createBuffer( positionBuffer, positionBufferSize, positionMem, VK_BUFFER_USAGE_VERTEX_BUFFER_BIT | VK_BUFFER_USAGE_TRANSFER_DST_BIT, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, "position buffer" );
                assert( positionBuffer != VK_NULL_HANDLE, "position buffer is null" );
                gfxDevice.copyBuffer( stagingBuffers.positions.buffer, positionBuffer, positionBufferSize );

                vkDestroyBuffer( gfxDevice.device, stagingBuffers.positions.buffer, null );
                vkFreeMemory( gfxDevice.device, stagingBuffers.positions.memory, null );
            }

            // UV buffer
            {
                int uvBufferSize = cast(int)(uvs.length * float.sizeof);
              
                gfxDevice.createBuffer( stagingBuffers.uvs.buffer, uvBufferSize, stagingBuffers.uvs.memory, VK_BUFFER_USAGE_TRANSFER_SRC_BIT, VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT, "staging uv buffer" );

                enforceVk( vkMapMemory( gfxDevice.device, stagingBuffers.uvs.memory, 0, uvBufferSize, 0, &bufferData ) );

                memcpy( bufferData, uvs.ptr, uvBufferSize );
                vkUnmapMemory( gfxDevice.device, stagingBuffers.uvs.memory );

                gfxDevice.createBuffer( uvBuffer, uvBufferSize, uvMem, VK_BUFFER_USAGE_VERTEX_BUFFER_BIT | VK_BUFFER_USAGE_TRANSFER_DST_BIT, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, "uv buffer" );
                assert( uvBuffer != VK_NULL_HANDLE, "uv buffer is null" );
                gfxDevice.copyBuffer( stagingBuffers.uvs.buffer, uvBuffer, uvBufferSize );

                vkDestroyBuffer( gfxDevice.device, stagingBuffers.uvs.buffer, null );
                vkFreeMemory( gfxDevice.device, stagingBuffers.uvs.memory, null );
            }

            // Color buffer
            {
                int colorBufferSize = cast(int)(colors.length * float.sizeof);
              
                gfxDevice.createBuffer( stagingBuffers.colors.buffer, colorBufferSize, stagingBuffers.colors.memory, VK_BUFFER_USAGE_TRANSFER_SRC_BIT, VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT, "staging color buffer" );

                enforceVk( vkMapMemory( gfxDevice.device, stagingBuffers.colors.memory, 0, colorBufferSize, 0, &bufferData ) );

                memcpy( bufferData, colors.ptr, colorBufferSize );
                vkUnmapMemory( gfxDevice.device, stagingBuffers.colors.memory );

                gfxDevice.createBuffer( colorBuffer, colorBufferSize, colorMem, VK_BUFFER_USAGE_VERTEX_BUFFER_BIT | VK_BUFFER_USAGE_TRANSFER_DST_BIT, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, "color buffer" );
                assert( colorBuffer != VK_NULL_HANDLE, "color buffer is null" );
                gfxDevice.copyBuffer( stagingBuffers.colors.buffer, colorBuffer, colorBufferSize );

                vkDestroyBuffer( gfxDevice.device, stagingBuffers.colors.buffer, null );
                vkFreeMemory( gfxDevice.device, stagingBuffers.colors.memory, null );
            }
            
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

            const int POSITION_INDEX = 0;
            const int TEXCOORD_INDEX = 1;
            const int COLOR_INDEX = 2;
            
            bindingDescriptions = new VkVertexInputBindingDescription[ 4 ];
            bindingDescriptions[ 0 ].binding = 0;
            bindingDescriptions[ 0 ].stride = 3 * float.sizeof;
            bindingDescriptions[ 0 ].inputRate = VK_VERTEX_INPUT_RATE_VERTEX;

            bindingDescriptions[ 1 ].binding = 1;
            bindingDescriptions[ 1 ].stride = 2 * float.sizeof;
            bindingDescriptions[ 1 ].inputRate = VK_VERTEX_INPUT_RATE_VERTEX;

            bindingDescriptions[ 2 ].binding = 2;
            bindingDescriptions[ 2 ].stride = 4 * float.sizeof;
            bindingDescriptions[ 2 ].inputRate = VK_VERTEX_INPUT_RATE_VERTEX;

            bindingDescriptions[ 3 ].binding = 3;
            bindingDescriptions[ 3 ].stride = InstanceData.sizeof;
            bindingDescriptions[ 3 ].inputRate = VK_VERTEX_INPUT_RATE_INSTANCE;

            attributeDescriptions = new VkVertexInputAttributeDescription[ 6 ];

            // Location 0 : Position
            attributeDescriptions[ 0 ].binding = 0;
            attributeDescriptions[ 0 ].location = POSITION_INDEX;
            attributeDescriptions[ 0 ].format = VK_FORMAT_R32G32B32_SFLOAT;
            attributeDescriptions[ 0 ].offset = 0;

            // Location 1 : TexCoord
            attributeDescriptions[ 1 ].binding = 1;
            attributeDescriptions[ 1 ].location = TEXCOORD_INDEX;
            attributeDescriptions[ 1 ].format = VK_FORMAT_R32G32_SFLOAT;
            attributeDescriptions[ 1 ].offset = 0;

            // Location 2 : Color
            attributeDescriptions[ 2 ].binding = 2;
            attributeDescriptions[ 2 ].location = COLOR_INDEX;
            attributeDescriptions[ 2 ].format = VK_FORMAT_R32G32B32A32_SFLOAT;
            attributeDescriptions[ 2 ].offset = 0;

            // Location 3 : Instanced position
            attributeDescriptions[ 3 ].binding = 3;
            attributeDescriptions[ 3 ].location = 3;
            attributeDescriptions[ 3 ].format = VK_FORMAT_R32G32B32_SFLOAT;
            attributeDescriptions[ 3 ].offset = 0;

            // Location 4 : Instanced texcoord
            attributeDescriptions[ 4 ].binding = 3;
            attributeDescriptions[ 4 ].location = 4;
            attributeDescriptions[ 4 ].format = VK_FORMAT_R32G32_SFLOAT;
            attributeDescriptions[ 4 ].offset = 0;

            // Location 5 : Instanced color
            attributeDescriptions[ 5 ].binding = 3;
            attributeDescriptions[ 5 ].location = 5;
            attributeDescriptions[ 5 ].format = VK_FORMAT_R32G32B32A32_SFLOAT;
            attributeDescriptions[ 5 ].offset = 0;

            inputState.sType = VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO;
            inputState.pNext = null;
            inputState.vertexBindingDescriptionCount = cast(uint32_t)bindingDescriptions.length;
            inputState.pVertexBindingDescriptions = bindingDescriptions.ptr;
            inputState.vertexAttributeDescriptionCount = cast(uint32_t)attributeDescriptions.length;
            inputState.pVertexAttributeDescriptions = attributeDescriptions.ptr;
        }

        VkBuffer positionBuffer;
        VkBuffer uvBuffer;
        VkBuffer colorBuffer;
        VkDeviceMemory positionMem;
        VkDeviceMemory uvMem;
        VkDeviceMemory colorMem;
        VkPipelineVertexInputStateCreateInfo inputState;
        VkBuffer indexBuffer;
        VkDeviceMemory indexMem;
        VkVertexInputBindingDescription[] bindingDescriptions;
        VkVertexInputAttributeDescription[] attributeDescriptions;
    }

    VertexBuffer vertexBuffer;
}
