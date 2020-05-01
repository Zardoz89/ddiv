module ddiv.core.mainprocess;

import ddiv.core.abstractmainprocess;
import ddiv.sdl.sdlgraphics;

/// Base class to build the main process of any game, using SDL2
abstract class MainProcess : AbstractMainProcess
{
    /**
     * Creates the initial process
     * @param args Arguments
     * @param mainFunction Code to be execute as main
     */
    this(string[] args)
    {
        import ddiv.sdl.sdlloader : loadSDLLibraries;
        super( args, [ &loadSDLLibraries]);
    }

    override bool initLibs()
    {
        auto graphics = SDLWrapper.get();
        if (!graphics.initVideo( this._args)) {
            return false;
        }
        graphics.createWindow(); // TODO Move this to another method
        return true;
    }

    override void quitLibs()
    {
        SDLWrapper.get().quit();
    }

    override void frameStart()
    {
        super.frameStart();
        auto graphics = SDLWrapper.get();

        graphics.clearScreen();
    }

    override void frameEnd()
    {
        super.frameEnd();
        SDLWrapper.get().render();
        SDLWrapper.get().pullEvents();
    }

private:
    string _windowTitle = "a";
}
