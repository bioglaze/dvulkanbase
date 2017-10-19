import core.simd;
import derelict.sdl2.sdl;
import gfxdevicevulkan;
import matrix4x4;
import std.stdio;
import std.string;
import texture2d;

void main()
{
    immutable int width = 800;
    immutable int height = 600;

    DerelictSDL2.load();

    auto sdlWindow = SDL_CreateWindow( "vulkan basecode", 100, 0, width, height, SDL_WINDOW_SHOWN );
    SDL_SysWMinfo info;
    auto success = SDL_GetWindowWMInfo( sdlWindow, &info );

    version(Windows)
    {
        GfxDeviceVulkan gfxdevice = new GfxDeviceVulkan( width, height, info.info.win.window, null );
    }
    version(linux)
    {
        //GfxDeviceVulkan gfxdevice = new GfxDeviceVulkan( width, height, info.info.x11.window, info.info.x11.display );
        GfxDeviceVulkan gfxdevice = new GfxDeviceVulkan( width, height, info.info.wl.surface, info.info.wl.display );
    }

    bool quit = false;

    Matrix4x4 projection;
    makeProjection( 0, width, height, 0, 0, 1, projection );

    UniformBuffer ubo;
    ubo.modelToClip = projection;
    ubo.tintColor = [ 1, 1, 0, 1 ];

    Texture2D texture = new Texture2D();
    texture.createCheckerboard( gfxdevice.device, gfxdevice.deviceMemoryProperties, gfxdevice.texCmdBuffer, gfxdevice.graphicsQueue, 256, 256 );
    
    int frame = 0;
    
    while (!quit)
    {
        SDL_Event event;

        while (SDL_PollEvent( &event ))
        {
            if (event.type == SDL_WINDOWEVENT && event.window.event == SDL_WINDOWEVENT_CLOSE)
            {
                quit = true;
            }
            if (event.type == SDL_KEYDOWN && event.key.keysym.sym == SDLK_ESCAPE)
            {
                quit = true;
            }
        }

        ubo.tintColor = ((frame % 10) < 5) ? [ 1, 0, 0, 1 ] : [ 0, 1, 0, 1 ];
        gfxdevice.beginFrame( width, height );
        gfxdevice.draw( gfxdevice.vertexBuffer, 0, 2, gfxdevice.shader, BlendMode.Off, DepthFunc.NoneWriteOff, CullMode.Off, ubo, texture.getView(), gfxdevice.samplerNearestRepeat );
        gfxdevice.endFrame();

        ++frame;
    }
}
