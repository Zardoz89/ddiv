/**
Helper internal functions
*/
module ddiv.container.common;

/// Round up's a unsigned value to the next power of 2
pragma(inline, true)
T nextPower2(T = size_t)(T value) nothrow pure @nogc @safe
if (__traits(isUnsigned, T)) // TODO and if T isn't a bool
{
    value--;
    value |= value >> 1;
    value |= value >> 2;
    value |= value >> 4;
    static if (T.sizeof >= ushort.sizeof) {
        value |= value >> 8;
    }
    static if (T.sizeof >= uint.sizeof) {
        value |= value >> 16;
    }
    static if (T.sizeof >= ulong.sizeof) {
        value |= value >> 32;
    }
    value++;
    return value;
}

version(unittest) import pijamas;

@("Next power 2 helper")
@safe unittest {
    nextPower2!ubyte(16).should.be.equal(16);
    nextPower2!size_t(32).should.be.equal(32);
    nextPower2!size_t(33).should.be.equal(64);
    nextPower2!uint(65_534).should.be.equal(65_536);
}

/// Grows a capacity trying to aproximate to the ideal value of Phi (x 1.618...)
pragma(inline, true)
T growCapacity(T = size_t)(T value) nothrow pure @nogc @safe
if (is(T == size_t) || is(T == uint) || is(T == ulong))
{
    return 1 + value + (value >>> 1); // Grows to (1/capacity + 1.5) . For smaller values, it aproximates to 1.6
}

@("Grow capacity")
@safe unittest {
    growCapacity!ulong(32).should.be.equal(49);
    growCapacity!size_t(3000).should.be.equal(4501);

    size_t startValue = 512;
    size_t growValue = growCapacity(startValue); // 769
    growValue.should.be.equal(769);
    size_t diff = growValue - startValue; // 257
    growValue = growCapacity(growValue); // 1154
    growValue.should.be.equal(1154);
    diff += growValue - startValue; //  642
    // Free ram holes, are reusable
    diff.should.be.biggerThan(startValue);
}
