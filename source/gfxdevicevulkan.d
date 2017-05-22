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
    this( int width, int height )
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

        version(windows)
        {
            auto surfaceInfo = VkWin32SurfaceCreateInfoKHR(
                                                          VkStructureType.VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR,
                                                        null,
                                                        0,
                                                        sdlWindowInfo.info.win.window,
                                                        sdlWindowInfo.info.win.window
                                                        );
            enforceVk( vkCreateWin32SurfaceKHR( instance, &surfaceInfo, null, &surface ) );
        }

        createPhysicalDevice();
    }


    private void createPhysicalDevice()
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

    }
  
    VkSurfaceKHR surface;
    VkInstance instance;
    VkPhysicalDevice physicalDevice;
}
