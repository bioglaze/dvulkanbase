import core.simd;
import bindbc.sdl;
import gfxdevicevulkan;
import matrix4x4;
import std.stdio;
import std.string;
import texture2d;

void main()
{
    immutable int width = 800;
    immutable int height = 600;

    SDLSupport ret = loadSDL();

    if (ret != sdlSupport)
    {
        if (ret == SDLSupport.noLibrary)
        {
            throw new Error( "Could not load SDL library!" );
        }
        else if (ret == SDLSupport.badLibrary)
        {
            throw new Error( "Bad SDL library!" );
        }
    }

    auto sdlWindow = SDL_CreateWindow( "vulkan basecode", 100, 0, width, height, SDL_WINDOW_SHOWN );
    SDL_SysWMinfo info;
    info.version_.major = 2;
    info.version_.minor = 0;
    info.version_.patch = 5;
    auto success = SDL_GetWindowWMInfo( sdlWindow, &info );

    version(Windows)
    {
        GfxDeviceVulkan gfxdevice = new GfxDeviceVulkan( width, height, info.info.win.window, null, 0 );
    }
    version(linux)
    {
        GfxDeviceVulkan gfxdevice = new GfxDeviceVulkan( width, height, null, info.info.x11.display, info.info.x11.window );
    }

    bool quit = false;

    Matrix4x4 projection;
    makeProjection( 0, width, height, 0, 0, 1, projection );

    UniformBuffer ubo;
    ubo.modelToClip = projection;
    ubo.tintColor = [ 1, 1, 0, 1 ];

    Texture2D textureRed = new Texture2D();
    textureRed.loadTGA( "assets/glider_red.tga", gfxdevice.device, gfxdevice.deviceMemoryProperties, gfxdevice.texCmdBuffer, gfxdevice.graphicsQueue, gfxdevice.texCmdBuffer );

    Texture2D textureGreen = new Texture2D();
    textureGreen.loadTGA( "assets/glider_green.tga", gfxdevice.device, gfxdevice.deviceMemoryProperties, gfxdevice.texCmdBuffer, gfxdevice.graphicsQueue, gfxdevice.texCmdBuffer );

    Texture2D textureBlue = new Texture2D();
    textureBlue.loadTGA( "assets/glider_blue.tga", gfxdevice.device, gfxdevice.deviceMemoryProperties, gfxdevice.texCmdBuffer, gfxdevice.graphicsQueue, gfxdevice.texCmdBuffer );

    int frame = 0;

    gfxdevice.updateDescriptorSet( gfxdevice.samplerNearestRepeat, textureRed.getView(), textureGreen.getView(), textureBlue.getView() );
    
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

        ubo.textureIndex = 2;
        gfxdevice.draw( gfxdevice.vertexBuffer, gfxdevice.shader, BlendMode.Off, DepthFunc.NoneWriteOff, CullMode.Off, ubo );

        gfxdevice.endFrame();

        ++frame;
    }
}
