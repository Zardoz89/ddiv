module ddiv.core.exceptions;
import mir.exception : MirException, MirError;

/// NoGc RangeError
class RangeError : MirError
{
    /++
    Params:
        msg = message. No-scope `msg` is assumed to have the same lifetime as the throwable. scope strings are copied to internal buffer.
        file = file name, zero terminated global string
        line = line number
        nextInChain = next exception in the chain (optional)
    +/
    @nogc @safe pure nothrow this(scope const(char)[] msg, string file = __FILE__, size_t line = __LINE__, Throwable nextInChain = null)
    {
        super(msg, file, line, nextInChain);
    }

    /// ditto
    @nogc @safe pure nothrow this(scope const(char)[] msg, Throwable nextInChain, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, nextInChain, file, line);
    }

    /// ditto
    @nogc @safe pure nothrow this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable nextInChain = null)
    {
        super(msg, file, line, nextInChain);
    }

    /// ditto
    @nogc @safe pure nothrow this(string msg, Throwable nextInChain, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line, nextInChain);
    }
}
