import core.simd;
import derelict.sdl2.sdl;
import gfxdevicevulkan;
import matrix4x4;
import std.stdio;
import std.string;

/** TODO:
    * Process 2 frames
*/

void main()
{
    int4 v = 7;
    writeln( "jeejee: ", v.array[0] );

    Matrix4x4 a, b, c;
    multiply( a, b, c );
    writeln( "c: ", c.m[0] );

    int width = 800;
    int height = 600;

    DerelictSDL2.load();
    if (SDL_Init( SDL_INIT_VIDEO ) < 0)
    {
        const(char)* message = SDL_GetError();
        writeln( "Failed to initialize SDL: ", message );
    }

    auto sdlWindow = SDL_CreateWindow( "vulkan basecode", 0, 0, width, height, SDL_WINDOW_SHOWN );
    SDL_SysWMinfo info;
    auto success = SDL_GetWindowWMInfo( sdlWindow, &info );
    GfxDeviceVulkan gfxdevice = new GfxDeviceVulkan( width, height, info.info.win.window );

    bool quit = false;

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

        gfxdevice.beginFrame( width, height );
        gfxdevice.endFrame();
    }
}
