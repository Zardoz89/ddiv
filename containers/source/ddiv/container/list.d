module ddiv.container.list;

import ddiv.core.memory;
import ddiv.core.exceptions;
import ddiv.container.common;
import std.experimental.allocator.mallocator : Mallocator;
import std.traits : isArray, hasIndirections;

/**
 Simple NoGC dynamic array that uses std.experimental.allocator

 Only can contain scalar and structs
 */
struct SimpleList(T, Allocator = Mallocator, bool supportGC = hasIndirections!T)
if (isAllocator!Allocator && !isArray!T) {
    private T[] elements = void;
    private size_t arrayLength = 0;

    mixin AllocatorState!Allocator;

    static if (stateSize!Allocator != 0) {
        /// No default construction if an allocator must be provided.
        this() @disable;

        /**
		 * Use the given `allocator` for allocations.
		 */
        this(Allocator allocator)
        in {
            assert(allocator !is null, "Allocator must not be null");
        }
        do {
            this.allocator = allocator;
        }
    }

    ~this() @nogc @trusted scope {
        this.free();
    }

    void free() @nogc @trusted scope {
        if (!(this.elements is null)) {

            static if ((is(T == struct) || is(T == union)) && __traits(hasMember, T, "__xdtor")) {
                foreach (ref element; elements[0 .. this.length]) {
                    element.__xdtor();
                }
            }

            static if (supportGC) {
                import core.memory : GC;

                GC.removeRange(elements.ptr);
            }

            allocator.dispose(this.elements);
            this.elements = null;
        }
        this.clear();
    }

    void reserve(size_t newCapacity) @trusted
    in (newCapacity > 0, "Invalid capacity. Must greater that 0") {
        if (this.length >= newCapacity) {
            return;
        }

        if (this.elements is null) {
            this.elements = allocator.make!(T[])(newCapacity);
            static if (supportGC) {
                import core.memory : GC;
                GC.addRange(this.elements.ptr, this.elements.length * T.sizeof);
            }
        } else {
            static if (supportGC) {
                void* oldPtr = this.elements.ptr;
            }
            if (newCapacity > this.capacity) {
                allocator.expandArray!T(this.elements, newCapacity - this.capacity);
            } else {
                allocator.shrinkArray!T(this.elements, this.capacity - newCapacity);
            }
            static if (supportGC) {
                import core.memory : GC;
                GC.removeRange(oldPtr);
                GC.addRange(this.elements.ptr, this.elements.length * T.sizeof);
            }
        }
    }

    void expand(size_t delta) @nogc @trusted {
        if (this.elements is null) {
            this.elements = allocator.make!(T[])(delta);
            static if (supportGC) {
                import core.memory : GC;
                GC.addRange(this.elements.ptr, this.elements.length * T.sizeof);
            }
        } else {
            static if (supportGC) {
                void* oldPtr = this.elements.ptr;
            }
            allocator.expandArray!T(this.elements, delta);
            static if (supportGC) {
                import core.memory : GC;
                GC.removeRange(oldPtr);
                GC.addRange(this.elements.ptr, this.elements.length * T.sizeof);
            }
        }
    }

    size_t capacity() const @nogc nothrow @safe {
        return this.elements.length;
    }

    size_t opDollar() const @nogc nothrow @safe {
        return this.arrayLength;
    }

    alias length = opDollar;

    bool empty() const @nogc nothrow @safe {
        return this.elements is null || this.arrayLength == 0;
    }

    /// O(1)
    void insertBack(T value) nothrow {
        if (this.elements is null) {
            this.reserve(32);
        }
        if (this.arrayLength >= this.capacity) {
            this.reserve(growCapacity(this.capacity));
        }
        this.elements[this.arrayLength++] = value;
    }

    alias put = insertBack;

    /// O(1)
    auto ref T back() pure @nogc @safe {
        if (this.empty) {
            throw new RangeError("SimpleList it's empty.");
        }
        return this.elements[this.arrayLength - 1];
    }

    /// O(1)
    void popBack() @nogc nothrow {
        if (!this.empty) {
            this.arrayLength--;
            static if ((is(T == struct) || is(T == union))
                    && __traits(hasMember, T, "__xdtor")) {
                this.elements[arrayLength + 1].__xdtor();
            }
        }
    }

    /// O(1)
    auto ref T front() pure @nogc @safe {
        if (this.empty) {
            throw new RangeError("SimpleList it's empty.");
        }
        return this.elements[0];
    }

    /// O(N)
    void popFront() @nogc nothrow {
        if (!this.empty) {
            static if ((is(T == struct) || is(T == union))
                    && __traits(hasMember, T, "__xdtor")) {
                this.elements[0].__xdtor();
            }
            foreach (i; 0 .. this.arrayLength - 1) {
                this.elements[i] = this.elements[i + 1];
            }
            this.arrayLength--;
        }
    }

    void clear() @nogc nothrow {
        if (!this.empty) {
            static if ((is(T == struct) || is(T == union))
                    && __traits(hasMember, T, "__xdtor")) {
                foreach (ref element; elements[0 .. this.length]) {
                    element.__xdtor();
                }
            }
            this.arrayLength = 0;
        }
    }

    static if (__traits(isScalar, T)) {
        /// O(1)
        pragma(inline, true)
        inout(T) opIndex(size_t index) inout @nogc @safe {
            if (this.empty || index > this.length) {
                throw new RangeError("Indexing out of bounds of SimpleList");
            }
            return this.elements[index];
        }
    } else {
        /// O(1)
        pragma(inline, true)
        ref inout(T) opIndex(size_t index) return inout @nogc @safe {
            if (this.empty || index > this.length) {
                throw new RangeError("Indexing out of bounds of SimpleList");
            }
            return this.elements[index];
        }
    }

    /// O(1)
    void opOpAssign(string op)(T value) nothrow
    if (op == "~") {
        this.insertBack(value);
    }

    import std.range.primitives : isInputRange;

    /// O(N)
    void opOpAssign(string op, R)(R range) nothrow
    if (op == "~" && isInputRange!R) {
        foreach (element; range) {
            this.insertBack(element);
        }
    }

    /// Returns a forward range
    auto range(this This)() return @nogc nothrow @safe {
        static struct Range {
            private This* self;
            private size_t index;
            private size_t end;

            Range save() {
                return this;
            }

            auto front() {
                return (*self)[index];
            }

            void popFront() @nogc {
                ++index;
            }

            bool empty() const @nogc {
                return index >= end;
            }

            auto length() const @nogc {
                return self.length;
            }
        }

        import std.range.primitives : isForwardRange;

        static assert(isForwardRange!Range);

        return Range(() @trusted { return &this; }(), 0, this.length);
    }

    auto opSlice(this This)() @safe scope return {
        return this.elements[0 .. this.length];
    }

    auto opSlice(this This)(size_t start, size_t end) @safe @nogc scope return {
        if (end < start) {
            throw new RangeError(
                    "Slicing with invalid range. Start must be equal or less that end.");
        }
        if (end > this.length) {
            throw new RangeError("Slicing out of bounds of SimpleList.");
        }
        return this.elements[start .. end];
    }

    auto ptr(this This)() return scope {
        return &this.elements[0];
    }
}

@("SimpleList with scalar and simple structs @nogc")
@safe @nogc unittest {
    import pijamas;

    {
        auto l = SimpleList!int();
        l.reserve(16);
        l.capacity.should.be.equal(16);
        l.length.should.be.equal(0);
        l.empty.should.be.True;

        /+
        this instances aren't never deallocated, becasue some thing of D with anonymus functions
        should(() {
            auto l = SimpleList!int();
            l.reserve(16);
            l.back;
        }).Throw!RangeError;
        should(() {
            auto l = SimpleList!int();
            l.reserve(16);
            l.front;
        }).Throw!RangeError;
        should(() {
            auto l = SimpleList!int();
            l.reserve(16);
            cast(void) l[123];
        }).Throw!RangeError;
        +/

        l ~= 100;
        l.back.should.be.equal(100);
        l.front.should.be.equal(100);
        l.length.should.be.equal(1);
        l.empty.should.be.False;

        l.popBack;
        l.empty.should.be.True;

        // Stress test
        import std.range : iota, array;

        l ~= iota(0, 10_240);
        l.length.should.be.equal(10_240);
        l.capacity.should.be.biggerOrEqualThan(10_240);
        l.back.should.be.equal(10_240 - 1);
        l.front.should.be.equal(0);
        l[0].should.be.equal(l.front);
        l[100].should.be.equal(100);

        /+
        should(() {
            auto l = SimpleList!int();
            l ~= iota(0, 256);
            cast(void) l[-1 .. 100];
        }).Throw!RangeError;
        should(() {
            auto l = SimpleList!int();
            l ~= iota(0, 256);
            cast(void) l[200 .. 100];
        }).Throw!RangeError;
        should(() {
            auto l = SimpleList!int();
            l ~= iota(0, 256);
            cast(void) l[10 .. 20_000];
        }).Throw!RangeError;
        +/

        l.clear();
        l.length.should.be.equal(0);
        l.capacity.should.be.biggerOrEqualThan(10_240);
    }

    {
        struct S {
            int x;
            long y;

            bool opEquals()(auto ref const S rhs) const @nogc @safe pure nothrow {
                return this.x == rhs.x && this.y == rhs.y;
            }

            int opCmp(ref const S rhs) const @nogc @safe pure nothrow {
                return this.x - rhs.x;
            }

            size_t toHash() const @safe pure nothrow {
                static import core.internal.hash;

                return core.internal.hash.hashOf(x) + core.internal.hash.hashOf(y);
            }
        }

        auto l = SimpleList!S();
        l.reserve(32);
        l.capacity.should.be.equal(32);
        l.length.should.be.equal(0);
        l.empty.should.be.True;

        /+
        should(() {
            auto l = SimpleList!S();
            l.reserve(32);
            l.back;
        }).Throw!RangeError;
        should(() {
            auto l = SimpleList!S();
            l.reserve(32);
            l.front;
        }).Throw!RangeError;
        should(() {
            auto l = SimpleList!S();
            l.reserve(32);
            cast(void) l[123];
        }).Throw!RangeError;
        +/

        l ~= S(10, 20);
        l.back.should.be.equal(S(10, 20));
        l.front.should.be.equal(S(10, 20));
        l.length.should.be.equal(1);
        l.empty.should.be.False;

        l.popBack;
        l.empty.should.be.True;

        // Stress test
        import std.range : iota, array;

        foreach (i; 0 .. 128) {
            l ~= S(i, -1);
        }
        l.length.should.be.equal(128);
        l.capacity.should.be.biggerOrEqualThan(128);
        l.back.should.be.equal(S(127, -1));
        l.front.should.be.equal(S(0, -1));

        l[0].y = 123;
        l.front.should.be.equal(S(0, 123));

        import std.algorithm.searching : canFind;

        l.range.canFind(S(120, -1)).should.be.True;
    }
}

@("SimpleList with structs with destructor @nogc")
@nogc unittest {
    import pijamas;

    static int dtor = 0;
    struct S {
        int x;
        int* z;
        ~this() @nogc nothrow {
            dtor++;
        }
    }

    auto l = SimpleList!S();
    l.reserve(32);
    dtor.should.be.equal(0);

    foreach (i; 0 .. 32) {
        l ~= S(i, null);
    }
    dtor.should.be.equal(32*3); // Destructor called x2 when appending struct value, and when replaces the S.init on the dynamic array
    l.clear();

    l.empty.should.be.True;
    dtor.should.be.equal(32*4);
}


@("SimpleList with class with destructor")
unittest {
    import pijamas;

    class C {
        int x;

        this(int x) @nogc nothrow {
            this.x = x;
        }
    }

    auto l = SimpleList!C();
    l.reserve(32);

    foreach (i; 0 .. 32) {
        l ~= new C(i);
    }
    l.front.should.be.equal(l[0]);
    l.clear();
    l.empty.should.be.True;

}


@("SimpleList with scalar and simple structs")
@safe unittest {
    import pijamas;

    {
        auto l = SimpleList!int();
        l.reserve(16);

        should(() {
            l.back;
        }).Throw!RangeError;
        should(() {
            l.front;
        }).Throw!RangeError;
        should(() {
            cast(void) l[123];
        }).Throw!RangeError;

        import std.range : iota, array;

        l ~= iota(0, 10_240);
        l[].should.be.equal(iota(0, 10_240).array);
        l[0 .. 100].should.be.equal(iota(0, 100).array);
        l[1_000 .. $].should.be.equal(iota(1_000, 10_240).array);

        should(() {
            cast(void) l[-1 .. 100];
        }).Throw!RangeError;
        should(() {
            cast(void) l[200 .. 100];
        }).Throw!RangeError;
        should(() {
            cast(void) l[10 .. 20_000];
        }).Throw!RangeError;

        import std.algorithm : isSorted;

        l.range.isSorted.should.be.True;
        l.range.array.should.be.equal(iota(0, 10_240).array);

        import std.algorithm.searching : canFind;

        l.range.canFind(512).should.be.True;
    }
}
