/**
Code to load SDL libraries with Bindbc
*/
module ddiv.sdl.sdlloader;

import bindbc.sdl;
import bindbc.sdl.image;

/// Loads SDL libs
bool loadSDLLibraries()
{
    import std.stdio : writeln;
    writeln("Loading SDL libraries...");
    return loadSDL() && loadSDLImage();
}

private bool loadSDL()
{
    const SDLSupport ret = bindbc.sdl.loadSDL();
    if (ret != sdlSupport) {
        import std.stdio : stderr, writeln;
        if (ret == SDLSupport.noLibrary) {
            stderr.writeln( "This application requires the SDL library.");
        } else {
            stderr.writeln( "Error loading SDL dll.");
        }
        return false;
    }
    return true;
}

private bool loadSDLImage()
{
    const ret = bindbc.sdl.image.loadSDLImage();
    if (ret != sdlImageSupport) {
        import std.stdio : stderr, writeln;
        if (ret == SDLImageSupport.noLibrary) {
            stderr.writeln( "This application requires the SDL Image library.");
        } else {
            stderr.writeln( "Error loading SDL Image dll.");
        }
        return false;
    }
    return true;
}
