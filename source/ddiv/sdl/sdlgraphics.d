module ddiv.sdl.sdlgraphics;

import ddiv.log;
import ddiv.core.aux : Singleton;
public import ddiv.sdl.graphspod;

import bindbc.sdl;
import bindbc.sdl.image;

import std.typecons;

class SDLWrapper  {
    package shared graphStorageLock = new Object();
    package __gshared Graph[GraphId] graphStorage; // Storage of graphics associated to a ID

    mixin Singleton;
    private this() {}

    bool initVideo(string[] args)
    {
        import std.conv : to;

        info("Init SDL libraries...");

        const sdlFlags = SDL_INIT_VIDEO | SDL_INIT_TIMER;
        if (SDL_Init(sdlFlags) != 0) {
            critical("SDL_Init: ", to!string(SDL_GetError()));
            return false;
        }
        this._initializedSdl = true;

        const imageFlags = IMG_INIT_PNG | IMG_INIT_JPG | IMG_INIT_TIF;
        if ((IMG_Init(imageFlags) & imageFlags) != imageFlags) {
            critical("IMG_Init: ", to!string(IMG_GetError()));
            return false;
        }
        this._initializedSdlImage = true;

        return true;
    }

    void createWindow()
    {
        import std.string : toStringz;

        SDL_SetHint(SDL_HINT_RENDER_VSYNC, "1");

        const windowFlags = SDL_WINDOW_OPENGL | SDL_WINDOW_RESIZABLE | SDL_WINDOW_ALLOW_HIGHDPI | SDL_WINDOW_SHOWN;
        this._appWindow = SDL_CreateWindow(this._windowTitle.toStringz,
        SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED,
        this._width, this._height,
        windowFlags
        );
        if (this._appWindow is null) {
            critical("SDL_CreateWindow: ", SDL_GetError());
            return;
        }
        //Create and init the renderer
        this._renderer = SDL_CreateRenderer(this._appWindow, -1, SDL_RENDERER_ACCELERATED);
        if( this._renderer is null) {
            critical("SDL_CreateRenderer: ", SDL_GetError());
            return;
        }
    }

    void quit() @nogc nothrow
    {
        if (this._initializedSdl) {
            // Close and destroy the renderer
            if (this._renderer !is null) {
                SDL_DestroyRenderer(this._renderer);
            }
            // Close and destroy the window
            if (this._appWindow !is null) {
                SDL_DestroyWindow(this._appWindow);
            }

            // Finalizes SDL Image
            if (this._initializedSdlImage) {
                IMG_Quit();
            }
            // Finalices SDL
            SDL_Quit();
        }
    }

    void pullEvents() @nogc nothrow
    {
        SDL_PumpEvents();
    }

    void clearScreen() @nogc nothrow
    {
        SDL_RenderSetLogicalSize(this._renderer, this._width, this._height);
        SDL_SetRenderDrawColor(this._renderer, 0, 0, 0, SDL_ALPHA_OPAQUE );
        SDL_RenderClear(this._renderer );
    }

    void render()
    {
        // Cap framerate to desired FPS
        const ticksForNextFrame = this.getTicksForNextFrame();
        while (this._lastTime - SDL_GetTicks() < ticksForNextFrame) {
            SDL_Delay(1);
        }

        // TODO RenderCpy etc

        SDL_RenderPresent(this._renderer );
        this._lastTime = SDL_GetTicks();
    }

    private int getTicksForNextFrame() pure nothrow @nogc @safe
    {
        return 1000 / this._desiredFps;
    }

    private Tuple!(Texture*, int, int) createTextureFromMap(string path)
    //in (path !is null)
    {
        import std.conv : to;
        import std.string : toStringz;

        Tuple!(Texture*, int, int) retTuple = tuple(null, int.init, int.init);

        // Load image to RAM
        SDL_Surface* surface = IMG_Load(path.toStringz);
        if (surface is null) {
            error("IMG_Load: ", to!string(IMG_GetError()));
            return retTuple;
        }
        scope(exit) {
            // Close and destroy the surface
            if (surface !is null) {
                SDL_FreeSurface(surface);
            }
        }
        retTuple[1] = surface.w;
        retTuple[2] = surface.h;

        // Converting the surface to a texture
        SDL_Texture* texture = SDL_CreateTextureFromSurface(this._renderer, surface);
        if( texture is null) {
            error("SDL_CreateTextureFromSurface: ", to!string(SDL_GetError()));
            return retTuple;
        }
        retTuple[0] = texture;
        return retTuple;
    }

    // Must be called inside of a synchronized (graphStorage) block
    package GraphId generateGraphId()
    {
        if (graphStorage.length == 0) {
            return 1;
        }
        // TODO if num of Ids > THRESOULD and num of deleted graphs > DELETE_THRESOULD , then try to reuse ids
        import std.algorithm : maxElement;
        return graphStorage.byKey().maxElement + 1;
    }

    package void destroyTexture(Texture* texture)
    {
        SDL_DestroyTexture(texture);
        debug {
            const char* errorStr = SDL_GetError();
            if (*errorStr) {
                import std.conv : to;
                error("SDL error: ", to!string(errorStr));
                SDL_ClearError();
            }
        }
    }

    /**
     * Reads a graphics image file and store it as a GPU texture
     *
     * Params:
     *  path : Path to the image file
     * Returns : A GraphId on sucess, or NullGraph on case of error
     */
    GraphId loadMap(string path)
    {
        // TODO Check if file exists
        auto t = createTextureFromMap(path);
        if (t[0] is null) {
            return NullGraph;
        }
        GraphId id = NullGraph;
        synchronized (graphStorageLock) {
            id = this.generateGraphId();
            if (id == NullGraph) {
                destroyTexture(t[0]);
                return NullGraph;
            }

            graphStorage[id] = Graph(id, t[0], t[1], t[2]);
        }
        return id;
    }

    /**
     * Unloads a graphic from GPU Texture
     */
    void unloadMap(GraphId id)
    {
        synchronized (graphStorageLock) {
            Graph* g = id in graphStorage;
            if (g !is null) {
                destroyTexture(g.texture);
            }
            graphStorage.remove(id);
        }
    }

private:
    bool _initializedSdl = false;
    bool _initializedSdlImage = false;
    string _windowTitle = "(noname)";
    int _width = 800;
    int _height = 600;
    int _desiredFps = 60;
    int _lastTime = 0;

    SDL_Window* _appWindow = null;
    SDL_Renderer* _renderer = null;
}
