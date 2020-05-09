/**
Graphics structs, datatypes and helpers to abstract SDL
*/
module ddiv.sdl.graphspod;

import bindbc.sdl;

/// Point POD
alias Point = SDL_Point;
/// Rectangle POD
alias Rect = SDL_Rect;
/// GPU Texture/Graph
alias Texture = SDL_Texture;

import std.traits : isType;

/// Supported blend modes used on graphics
enum BlendMode {
    None,
    Alpha,
    Additive,
    Modulate
}

/// Converts from abstract blending mode to SDL blending modes
T to(T, S)(S blendMode)
if ( is(T == SDL_BlendMode) && is(S == BlendMode))
{
    final switch(blendMode) {
        case BlendMode.None:
            return SDL_BLENDMODE_NONE;
        case BlendMode.Alpha:
            return SDL_BLENDMODE_BLEND;
        case BlendMode.Additive:
            return SDL_BLENDMODE_ADD;
        case BlendMode.Modulate:
            return SDL_BLENDMODE_MOD;
    }
}

@("to!SDL_BlendMode")
unittest {
    assert(BlendMode.None.to!SDL_BlendMode == SDL_BLENDMODE_NONE);
    assert(BlendMode.Alpha.to!SDL_BlendMode == SDL_BLENDMODE_BLEND);
    assert(BlendMode.Additive.to!SDL_BlendMode == SDL_BLENDMODE_ADD);
    assert(BlendMode.Modulate.to!SDL_BlendMode == SDL_BLENDMODE_MOD);
}

/// Graph Id
alias GraphId = uint;
enum NullGraph = 0; /// Inavlid graph Id

/// A game sprite
struct Graph {
    GraphId id;
    Texture* texture;
    int w;
    int h;
    // TODO Alpha and blending properties ?
}
