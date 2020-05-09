/**
Code to load SDL libraries with Bindbc
*/
module ddiv.sdl.sdlloader;

import ddiv.log;

import bindbc.sdl;
import bindbc.sdl.image;

/// Loads SDL libs
bool loadSDLLibraries()
{
    info("Loading SDL libraries...");
    return loadSDL() && loadSDLImage();
}

private bool loadSDL()
{
    const SDLSupport ret = bindbc.sdl.loadSDL();
    if (ret != sdlSupport) {
        import std.stdio : stderr, writeln;
        if (ret == SDLSupport.noLibrary) {
            critical( "This application requires the SDL library.");
        } else {
            critical( "Error loading SDL dll.");
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
            critical( "This application requires the SDL Image library.");
        } else {
            critical( "Error loading SDL Image dll.");
        }
        return false;
    }
    return true;
}
