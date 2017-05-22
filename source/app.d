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

    DerelictSDL2.load();
    auto sdlWindow = SDL_CreateWindow( "vulkan basecode", 0, 0, 800, 600, 0 );

    GfxDeviceVulkan gfxdevicevulkan = new GfxDeviceVulkan( 800, 600 );

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
        }
    }
}
