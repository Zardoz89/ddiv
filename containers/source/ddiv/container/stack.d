module ddiv.container.stack;

import ddiv.core.memory;
import ddiv.core.exceptions;
import ddiv.container.common;
import std.experimental.allocator.mallocator : Mallocator;
import std.traits : isArray;

/**
 Simple NoGC stack that uses std.experimental.allocator

 Only can contain scalar  and structs
 */
struct SimpleStack(T, Allocator = Mallocator)
        if (isAllocator!Allocator && !isArray!T && !is(T == class))
{
    private T[] elements = void;
    private size_t arrayLength = 0;

    // Gets the struct constructor
    mixin StructAllocator!Allocator;

    ~this() @nogc @trusted
    {
        this.free();
    }

    void free() @nogc @trusted
    {
        if (!(this.elements is null))
        {
            allocator.dispose(this.elements);
            this.elements = null;
        }
        this.clear();
    }

    void reserve(size_t newCapacity) @nogc @trusted
    in (newCapacity > 0, "Invalid capacity. Must greater that 0")
    {
        if (this.elements is null)
        {
            this.elements = allocator.make!(T[])(newCapacity);
        }
        else if (newCapacity > this.capacity)
        {
            allocator.expandArray!T(this.elements, newCapacity - this.capacity);
        }
        else
        {
            allocator.shrinkArray!T(this.elements, this.capacity - newCapacity);
        }
    }

    void expand(size_t delta) @nogc @trusted
    {
        if (this.elements is null)
        {
            this.elements = allocator.make!(T[])(delta);
        }
        else
        {
            allocator.expandArray!T(this.elements, delta);
        }
    }

    size_t capacity() const @nogc nothrow @safe
    {
        return this.elements.length;
    }

    size_t opDollar() const @nogc nothrow @safe
    {
        return this.arrayLength;
    }

    alias length = opDollar;

    bool empty() const @nogc @safe
    {
        return this.elements is null || this.arrayLength == 0;
    }

    void insertBack(T value) @nogc @safe
    {
        if (this.elements is null)
        {
            this.reserve(DEFAULT_INITIAL_SIZE);
        }
        if (this.arrayLength >= this.capacity)
        {
            this.reserve(growCapacity(this.capacity));
        }
        this.elements[this.arrayLength++] = value;
    }

    alias push = insertBack;
    alias put = insertBack;

    static if (__traits(isScalar, T))
    {
        /// O(1)
        T top() @nogc @safe
        {
            if (this.empty)
            {
                throw new RangeError("SimpleStack it's empty.");
            }
            return this.elements[this.arrayLength - 1];
        }
    }
    else
    {
        /// O(1)
        pragma(inline, true)
        ref inout(T) top() return inout @nogc @safe
        {
            if (this.empty)
            {
                throw new RangeError("SimpleStack it's empty.");
            }
            return this.elements[this.arrayLength - 1];
        }
    }
    alias back = top;

    /// O(1)
    T pop() @nogc @safe
    {
        if (this.empty)
        {
            throw new RangeError("SimpleStack it's empty.");
        }
        T value = this.top();
        this.arrayLength--;
        return value;
    }

    alias popBack = pop;

    static if (__traits(isScalar, T))
    {
        /// O(N)
        bool contains(T value) @nogc @safe
        {
            if (this.empty)
            {
                return false;
            }
            import std.algorithm.searching : canFind;

            return canFind(this.elements[0 .. this.length], value);
        }
    }

    void clear() @nogc @safe
    {
        this.arrayLength = 0;
    }

    inout(T) opIndex(size_t index) inout @nogc nothrow @safe
    {
        if (this.empty || index > this.length)
        {
            throw new RangeError("Indexing out of bounds of SimpleStack.");
        }
        return this.elements[index];
    }

    /// O(1)
    void opOpAssign(string op)(T value) @nogc nothrow @safe if (op == "~")
    {
        this.insertBack(value);
    }

    import std.range.primitives : isInputRange;

    /// O(N)
    void opOpAssign(string op, R)(R range) @nogc nothrow @safe
            if (op == "~" && isInputRange!R)
    {
        foreach (element; range)
        {
            this.insertBack(element);
        }
    }

    /// Returns a forward range
    auto range(this This)() return @nogc nothrow @safe
    {
        static struct Range
        {
            private This* self;
            private size_t index;

            Range save()
            {
                return this;
            }

            auto front()
            {
                return (*self)[index];
            }

            void popFront() @nogc
            {
                --index;
            }

            bool empty() const @nogc
            {
                return index <= 0;
            }

            auto length() const @nogc
            {
                return self.length;
            }
        }

        import std.range.primitives : isForwardRange;

        static assert(isForwardRange!Range);

        return Range(() @trusted { return &this; }(), this.length - 1);
    }

    auto ptr(this This)() return
    {
        return &this.elements[0];
    }
}

@("SimpleStack @nogc")
@safe @nogc unittest
{
    import pijamas;

    {
        auto s = SimpleStack!int();
        s.reserve(16);
        s.capacity.should.be.equal(16);
        s.length.should.be.equal(0);
        s.empty.should.be.True();
        s.contains(123).should.be.False();

        s ~= 100;
        s.top.should.be.equal(100);
        s.length.should.be.equal(1);
        s.empty.should.be.False();
        s.contains(100).should.be.True();
        s.contains(123).should.be.False();
        s.pop.should.be.equal(100);
        s.empty.should.be.True();

        // Stress test
        import std.range : iota, array;

        s ~= iota(0, 10_240);
        s.length.should.be.equal(10_240);
        s.capacity.should.be.biggerOrEqualThan(10_240);
        s.top.should.be.equal(10_240 - 1);
        s.contains(10_200).should.be.True;
        s.contains(0).should.be.True;
        s.contains(10_239).should.be.True;
        s.contains(10_240).should.be.False;

        import std.algorithm : isSorted, reverse;

        s.range.isSorted!("a > b").should.be.True;
        //s.range.array.should.be.equal(iota(0, 10_240).array.reverse);

        s.clear();
        s.length.should.be.equal(0);
        s.capacity.should.be.biggerOrEqualThan(10_240);
    }

    {
        struct S
        {
            int x;
            long y;

            bool opEquals()(auto ref const S rhs) const @nogc @safe pure nothrow
            {
                return this.x == rhs.x && this.y == rhs.y;
            }

            int opCmp(ref const S rhs) const @nogc @safe pure nothrow
            {
                return this.x - rhs.x;
            }

            size_t toHash() const @safe pure nothrow
            {
                static import core.internal.hash;

                return core.internal.hash.hashOf(x) + core.internal.hash.hashOf(y);
            }
        }

        auto s = SimpleStack!S();
        s.reserve(32);
        s.capacity.should.be.equal(32);
        s.length.should.be.equal(0);
        s.empty.should.be.True;

        should(() {
            auto emptyStack = SimpleStack!S();
            cast(void) emptyStack.top;
        }).Throw!RangeError;

        s ~= S(10, 20);
        s.top.should.be.equal(S(10, 20));
        s.length.should.be.equal(1);
        s.empty.should.be.False;

        s.pop;
        s.empty.should.be.True;

        // Stress test
        import std.range : iota, array;

        foreach (i; 0 .. 128)
        {
            s ~= S(i, -1);
        }
        s.length.should.be.equal(128);
        s.capacity.should.be.biggerOrEqualThan(128);
        s.top.should.be.equal(S(127, -1));

        s.top.y = 123;
        s.top.should.be.equal(S(127, 123));

        import std.algorithm.searching : canFind;

        s.range.canFind(S(120, -1)).should.be.True;
    }
}

@("SimpleStack")
@safe unittest
{
    import pijamas;

    {
        auto s = SimpleStack!int();

        should(() {
            s.top;
        }).Throw!RangeError;

        import std.range : iota, array;
        import std.algorithm : isSorted, reverse;

        s ~= iota(0, 10_240);
        s.range.isSorted!("a > b").should.be.True;
        s.range.array.should.be.equal(iota(0, 10_240).array.reverse);
    }
}
