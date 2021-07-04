module ddiv.core.memory.allocator;

debug {
    private shared bool memoryProfilerEnabled = true;
} else {
    private shared bool memoryProfilerEnabled = false;
}
private shared size_t totalAllocatedMemory = 0;

pragma(inline, true)
private void addAllocatedMemory(size_t size) nothrow @nogc {
    import core.atomic : atomicOp;

    atomicOp!"+="(totalAllocatedMemory, size);
}

pragma(inline, true)
private void subAllocatedMemory(size_t size) nothrow @nogc {
    import core.atomic : atomicOp;

    atomicOp!"-="(totalAllocatedMemory, size);
}

void enableMemoryProfiler() @nogc @safe {
    import core.atomic : atomicStore;

    atomicStore(memoryProfilerEnabled, true);
}

void disableMemoryProfiler() @nogc @safe{
    import core.atomic : atomicStore;

    atomicStore(memoryProfilerEnabled, false);
}

bool isEnabledMemoryProfiler() @nogc @safe {
    return memoryProfilerEnabled;
}

size_t allocatedMemory() nothrow @nogc {
    return totalAllocatedMemory;
}

version(advProfiler) {
    pragma(msg, "Using the advanced memory usage profiler.");
    import ikod.containers.hashmap;

    private struct AllocationRecord {
        string type;
        size_t size;
        string file;
        int line;

    }

    private __gshared HashMap!(size_t, AllocationRecord) records;

    pragma(inline, true)
    void addRecord(void* p, string type, size_t size, string file = "[NONE]", int line = 0) @nogc nothrow {
        records.getOrAdd(cast(size_t) p, AllocationRecord(type, size, file, line));
    }

    pragma(inline, true)
    void deleteRecord(void* p) @nogc nothrow {
        records.remove(cast(size_t) p);
    }
}

/// Outputs to stdout information about the actual allocated memory
public void printMemoryLog() {
    import std.stdio;
    import core.stdc.stdio;
    import std.array;
    import std.algorithm.sorting : sort;

    printf("----- Memory allocation information -----\n");
    printf("Total amount of allocated memory: %zd bytes\n", totalAllocatedMemory);
    version(advProfiler) {
        import std.string : toStringz;
        foreach (key; records.byKey().array.sort) {
            auto record = records[key];
            printf("\tAddr: %p - [%s] %zd bytes - %s:%d\n", cast(void*)key, record.type.toStringz, record.size, record.file.toStringz, record.line);
        }
    }
}

private void printMemoryLeaks(){
    import std.stdio;
    import std.array;
    import std.algorithm.sorting : sort;

    writeln("----- Memory allocation information -----");
    writefln("Total amount of allocated memory that has not been released: %s bytes", totalAllocatedMemory);
    version(advProfiler) {
        foreach (key; records.byKey().array.sort) {
            auto record = records[key];
            writefln("\tAddr: 0x%X - [%s] %s bytes - %s:%s", key, record.type, record.size, record.file, record
                    .line);
        }
    }
}

shared static ~this(){
    import std.stdio : writeln;
    if (totalAllocatedMemory > 0) {
        writeln("WARNING! Possible memory leaks!");
        printMemoryLeaks();
    }
    version(advProfiler) {
        records.clear();
    }
}

import std.experimental.allocator : makeArray, _make = make, _expandArray = expandArray, _shrinkArray = shrinkArray,
    _dispose = dispose, _makeMultidimensionalArray = makeMultidimensionalArray,
    _disposeMultidimensionalArray = disposeMultidimensionalArray;
import std.traits;
import ddiv.core.memory.traits;

version(advProfiler) {

    /**
    Wraps std.experimental.allocator.make with 'T' being a class or struct

    Stores usefull information to profile allocations and deallocations
    */
    auto make(T, Allocator, A...)(auto ref Allocator alloc, auto ref A args, string file = __FILE__, int line = __LINE__)
    if (isAllocator!Allocator && !isArray!T) {
        if (memoryProfilerEnabled) {
            static if (is(T == class)) {
                auto size = __traits(classInstanceSize, T);
                addAllocatedMemory(size);
            } else {
                addAllocatedMemory(T.sizeof);
            }
        }
        auto ret = _make!(T, Allocator)(alloc, args);
        if (memoryProfilerEnabled) {
            static if (is(T == class)) {
                auto size = __traits(classInstanceSize, T);
            } else {
                auto size = T.sizeof;
            }
            void* ptr = cast(void*)ret;
            addRecord(ptr, T.stringof, size, file, line);
        }
        return ret;
    }

    /**
        Create an array `T[]` with `length` elements using `alloc`.
        The array is either default-initialized, filled with copies of `init`,
        or initialized with values fetched from `range`.

        Params:
        T = element type of the array being created
        alloc = the allocator used for getting memory
        length = Size on elements of the array

        Returns:
        The newly-created array, or `null` if either `length` was `0` or
        allocation failed.

        Throws:
        The first two overloads throw only if `alloc`'s primitives do. The
        overloads that involve copy initialization deallocate memory and propagate the
        exception if the copy operation throws.
    */
    T make(T, A)(auto ref A alloc, size_t length, string file = __FILE__, int line = __LINE__)
    if (isAllocator!A && isArray!T)
    in (length > 0, "Invalid size of dynamic array. Must greater that 0") {
        alias ArrayOf = ForeachType!T;
        auto ret = alloc.makeArray!ArrayOf(length);
        if (memoryProfilerEnabled) {
            auto size = ArrayOf.sizeof * ret.length;
            addAllocatedMemory(size);
            addRecord(ret.ptr, T.stringof, size, file, line);
        }
        return ret;
    }

    /**
        Create an array `T[]` with `length` elements using `alloc`.
        The array is either default-initialized, filled with copies of `init`,
        or initialized with values fetched from `range`.

        Params:
        T = element type of the array being created
        U = initializer value type
        alloc = the allocator used for getting memory
        length = Size on elements of the array
        initializer = element used for filling the array

        Returns:
        The newly-created array, or `null` if either `length` was `0` or
        allocation failed.

        Throws:
        The first two overloads throw only if `alloc`'s primitives do. The
        overloads that involve copy initialization deallocate memory and propagate the
        exception if the copy operation throws.
    */
    T make(T, U, A)(auto ref A alloc, size_t length, U initilizer, string file = __FILE__, int line = __LINE__)
    if (isAllocator!A && isArray!T && is(ForeachType!T == U))
    in (length > 0, "Invalid size of dynamic array. Must greater that 0") {

        alias ArrayOf = ForeachType!T;
        auto ret = alloc.makeArray!ArrayOf(length, initilizer);
        if (memoryProfilerEnabled) {
            auto size = ArrayOf.sizeof * ret.length;
            addAllocatedMemory(size);
            addRecord(ret.ptr, T.stringof, size, file, line);
        }
        return ret;
    }

    import std.range : isInputRange, isInfinite;
    /**
    Wraps std.experimental.allocator.expandArray

    Stores usefull information to profile allocations and deallocations
    */
    bool expandArray(T, A)(auto ref A alloc, ref T[] array, size_t delta, string file = __FILE__, int line = __LINE__)
    if (isAllocator!A) {
        if (memoryProfilerEnabled) {
            auto size = T.sizeof * array.length;
            subAllocatedMemory(size);
            deleteRecord(array.ptr);
        }
        auto ret = _expandArray(alloc, array, delta);
        if (memoryProfilerEnabled) {
            auto size = T.sizeof * array.length;
            addAllocatedMemory(size);
            addRecord(array.ptr, T[].stringof, size, file, line);
        }
        return ret;
    }

    /**
    Wraps std.experimental.allocator.expandArray

    Stores usefull information to profile allocations and deallocations
    */
    bool expandArray(T, A)(auto ref A alloc, ref T[] array, size_t delta, auto ref T init, string file = __FILE__, int line = __LINE__)
    if (isAllocator!A) {
        if (memoryProfilerEnabled) {
            auto size = T.sizeof * array.length;
            subAllocatedMemory(size);
            deleteRecord(array.ptr);
        }
        auto ret = _expandArray(alloc, array, delta, init);
        if (memoryProfilerEnabled) {
            auto size = T.sizeof * array.length;
            addAllocatedMemory(size);
            addRecord(array.ptr, T[].stringof, size, file, line);
        }
        return ret;
    }

    /**
    Wraps std.experimental.allocator.expandArray

    Stores usefull information to profile allocations and deallocations
    */
    bool expandArray(T, A, R)(auto ref A alloc, ref T[] array, R range, string file = __FILE__, int line = __LINE__)
    if (isAllocator!A && isInputRange!R) {
        if (memoryProfilerEnabled) {
            auto size = T.sizeof * array.length;
            subAllocatedMemory(size);
            deleteRecord(array.ptr);
        }
        auto ret = _expandArray(alloc, array, range);
        if (memoryProfilerEnabled) {
            auto size = T.sizeof * array.length;
            addAllocatedMemory(size);
            addRecord(array.ptr, T[].stringof, size, file, line);
        }
        return ret;
    }

    /**
    Wraps std.experimental.allocator.shrinkArray

    Stores usefull information to profile allocations and deallocations
    */
    bool shrinkArray(T, A)(auto ref A alloc, ref T[] array, size_t delta, string file = __FILE__, int line = __LINE__)
    if (isAllocator!A) {
        if (memoryProfilerEnabled) {
            auto size = T.sizeof * array.length;
            subAllocatedMemory(size);
            deleteRecord(array.ptr);
        }
        auto ret = _shrinkArray(alloc, array, delta);
        if (memoryProfilerEnabled) {
            auto size = T.sizeof * array.length;
            addAllocatedMemory(size);
            addRecord(array.ptr, T[].stringof, size, file, line);
        }
        return ret;
    }

    /**
    Wraps std.experimental.allocator.dispose

    Stores usefull information to profile allocations and deallocations
    */
    void dispose(A, T)(auto ref A alloc, auto ref T* p)
    if (isAllocator!A && !isArray!T) {
        if (memoryProfilerEnabled) {
            subAllocatedMemory(T.sizeof);
            void* ptr = cast(void*)p;
            deleteRecord(p);
        }
        _dispose(alloc, p);
    }

    /**
    Wraps std.experimental.allocator.dispose

    Stores usefull information to profile allocations and deallocations
    */
    void dispose(A, T)(auto ref A alloc, auto ref T p)
    if (isAllocator!A && (is(T == class) || is(T == interface))) {
        if (memoryProfilerEnabled) {
            auto size = __traits(classInstanceSize, T);
            subAllocatedMemory(size);
            void* ptr = cast(void*)p;
            deleteRecord(ptr);
        }
        _dispose(alloc, p);
    }

    /**
    Wraps std.experimental.allocator.dispose

    Stores usefull information to profile allocations and deallocations
    */
    void dispose(A, T)(auto ref A alloc, auto ref T[] array)
    if (isAllocator!A) {
        if (memoryProfilerEnabled) {
            auto size = T.sizeof * array.length;
            subAllocatedMemory(size);
            deleteRecord(array.ptr);
        }
        _dispose(alloc, array);
    }

    /+
    auto makeMultidimensionalArray(T, Allocator, size_t N)(auto ref Allocator alloc, size_t[N] lengths...) {
        return _makeMultidimensionalArray(alloc, lengths);
    }

    void disposeMultidimensionalArray(T, Allocator)(auto ref Allocator alloc, auto ref T[] array)
    {
        _disposeMultidimensionalArray(alloc, array);
    }
    +/
} else {

    /**
    Wraps std.experimental.allocator.make with 'T' being a class or struct

    Stores usefull information to profile allocations and deallocations
    */
    auto make(T, Allocator, A...)(auto ref Allocator alloc, auto ref A args)
    if (isAllocator!Allocator && !isArray!T) {
        if (memoryProfilerEnabled) {
            static if (is(T == class)) {
                auto size = __traits(classInstanceSize, T);
                addAllocatedMemory(size);
            } else {
                addAllocatedMemory(T.sizeof);
            }
        }
        auto ret = _make!(T, Allocator)(alloc, args);
        return ret;
    }

    /**
        Create an array `T[]` with `length` elements using `alloc`.
        The array is either default-initialized, filled with copies of `init`,
        or initialized with values fetched from `range`.

        Params:
        T = element type of the array being created
        alloc = the allocator used for getting memory
        length = Size on elements of the array

        Returns:
        The newly-created array, or `null` if either `length` was `0` or
        allocation failed.

        Throws:
        The first two overloads throw only if `alloc`'s primitives do. The
        overloads that involve copy initialization deallocate memory and propagate the
        exception if the copy operation throws.
    */
    T make(T, A)(auto ref A alloc, size_t length)
    if (isAllocator!A && isArray!T)
    in (length > 0, "Invalid size of dynamic array. Must greater that 0") {
        alias ArrayOf = ForeachType!T;
        auto ret = alloc.makeArray!ArrayOf(length);
        if (memoryProfilerEnabled) {
            auto size = ArrayOf.sizeof * ret.length;
            addAllocatedMemory(size);
        }
        return ret;
    }

    /**
        Create an array `T[]` with `length` elements using `alloc`.
        The array is either default-initialized, filled with copies of `init`,
        or initialized with values fetched from `range`.

        Params:
        T = element type of the array being created
        U = initializer value type
        alloc = the allocator used for getting memory
        length = Size on elements of the array
        initializer = element used for filling the array

        Returns:
        The newly-created array, or `null` if either `length` was `0` or
        allocation failed.

        Throws:
        The first two overloads throw only if `alloc`'s primitives do. The
        overloads that involve copy initialization deallocate memory and propagate the
        exception if the copy operation throws.
    */
    T make(T, U, A)(auto ref A alloc, size_t length, U initilizer)
    if (isAllocator!A && isArray!T && is(ForeachType!T == U))
    in (length > 0, "Invalid size of dynamic array. Must greater that 0") {

        alias ArrayOf = ForeachType!T;
        auto ret = alloc.makeArray!ArrayOf(length, initilizer);
        if (memoryProfilerEnabled) {
            auto size = ArrayOf.sizeof * ret.length;
            addAllocatedMemory(size);
        }
        return ret;
    }

    import std.range : isInputRange, isInfinite;
    /**
    Wraps std.experimental.allocator.expandArray

    Stores usefull information to profile allocations and deallocations
    */
    bool expandArray(T, A)(auto ref A alloc, ref T[] array, size_t delta)
    if (isAllocator!A){
        if (memoryProfilerEnabled) {
            auto size = T.sizeof * array.length;
            subAllocatedMemory(size);
        }
        auto ret = _expandArray(alloc, array, delta);
        if (memoryProfilerEnabled) {
            auto size = T.sizeof * array.length;
            addAllocatedMemory(size);
        }
        return ret;
    }

    /**
    Wraps std.experimental.allocator.expandArray

    Stores usefull information to profile allocations and deallocations
    */
    bool expandArray(T, A)(auto ref A alloc, ref T[] array, size_t delta, auto ref T init)
    if (isAllocator!A) {
        if (memoryProfilerEnabled) {
            auto size = T.sizeof * array.length;
            subAllocatedMemory(size);
        }
        auto ret = _expandArray(alloc, array, delta, init);
        if (memoryProfilerEnabled) {
            auto size = T.sizeof * array.length;
            addAllocatedMemory(size);
        }
        return ret;
    }

    /**
    Wraps std.experimental.allocator.expandArray

    Stores usefull information to profile allocations and deallocations
    */
    bool expandArray(T, A, R)(auto ref A alloc, ref T[] array, R range)
    if (isAllocator!A && isInputRange!R) {
        if (memoryProfilerEnabled) {
            auto size = T.sizeof * array.length;
            subAllocatedMemory(size);
        }
        auto ret = _expandArray(alloc, array, range);
        if (memoryProfilerEnabled) {
            auto size = T.sizeof * array.length;
            addAllocatedMemory(size);
        }
        return ret;
    }

    /**
    Wraps std.experimental.allocator.shrinkArray

    Stores usefull information to profile allocations and deallocations
    */
    bool shrinkArray(T, A)(auto ref A alloc, ref T[] array, size_t delta)
    if (isAllocator!A) {
        if (memoryProfilerEnabled) {
            auto size = T.sizeof * array.length;
            subAllocatedMemory(size);
        }
        auto ret = _shrinkArray(alloc, array, delta);
        if (memoryProfilerEnabled) {
            auto size = T.sizeof * array.length;
            addAllocatedMemory(size);
        }
        return ret;
    }

    /**
    Wraps std.experimental.allocator.dispose

    Stores usefull information to profile allocations and deallocations
    */
    void dispose(A, T)(auto ref A alloc, auto ref T* p)
    if (isAllocator!A && !isArray!T) {
        if (memoryProfilerEnabled) {
            subAllocatedMemory(T.sizeof);
            void* ptr = cast(void*)p;
        }
        _dispose(alloc, p);
    }

    /**
    Wraps std.experimental.allocator.dispose

    Stores usefull information to profile allocations and deallocations
    */
    void dispose(A, T)(auto ref A alloc, auto ref T p)
    if (isAllocator!A && (is(T == class) || is(T == interface))) {
        if (memoryProfilerEnabled) {
            auto size = __traits(classInstanceSize, T);
            subAllocatedMemory(size);
            void* ptr = cast(void*)p;
        }
        _dispose(alloc, p);
    }

    /**
    Wraps std.experimental.allocator.dispose

    Stores usefull information to profile allocations and deallocations
    */
    void dispose(A, T)(auto ref A alloc, auto ref T[] array)
    if (isAllocator!A) {
        if (memoryProfilerEnabled) {
            auto size = T.sizeof * array.length;
            subAllocatedMemory(size);
        }
        _dispose(alloc, array);
    }
}

@("@nogc Allocator profiled helpers")
@trusted @nogc unittest {
    import pijamas;
    import std.experimental.allocator.mallocator : Mallocator;

    enableMemoryProfiler();

    {
        auto array = Mallocator.instance.make!(int[])(10);
        scope (exit)
            Mallocator.instance.dispose(array);
        array[0] = 100;
        array[1] = 200;

        array.should.have.length(10);
        totalAllocatedMemory.should.be.equal(int.sizeof * array.length);


        Mallocator.instance.expandArray(array, 5);
        array.should.have.length(15);

        totalAllocatedMemory.should.be.equal(int.sizeof * array.length);

        Mallocator.instance.shrinkArray(array, 10).should.be.True();
        array.should.have.length(5);

        totalAllocatedMemory.should.be.equal(int.sizeof * array.length);
    }
    // scope(exit) deallocates the array
    totalAllocatedMemory.should.be.equal(0);

    {
        import std.array : staticArray;
        auto array = Mallocator.instance.make!(int[])(5, 333);
        scope (exit)
            Mallocator.instance.dispose(array);
        array[0] = 100;
        array[1] = 200;

        array.should.have.length(5);
        totalAllocatedMemory.should.be.equal(int.sizeof * array.length);
        array.should.be.equal([100, 200, 333, 333, 333].staticArray);

        Mallocator.instance.expandArray(array, 16, 666);
        totalAllocatedMemory.should.be.equal(int.sizeof * array.length);
        array.should.be.equal([100, 200, 333, 333, 333,
            666, 666, 666, 666, 666, 666, 666, 666,
            666, 666, 666, 666, 666, 666, 666, 666,
        ].staticArray);
        // printMemoryLog();
    }
    totalAllocatedMemory.should.be.equal(0);

    {
        struct S {
            int x, y;
        }

        auto s = Mallocator.instance.make!S();
        scope (exit)
            Mallocator.instance.dispose(s);

        s.x.should.be.equal(int.init);
        s.y.should.be.equal(int.init);
        totalAllocatedMemory.should.be.equal(s.sizeof);
    }
    totalAllocatedMemory.should.be.equal(0);

}

@("gc dependant Allocator profiled helpers")
@trusted unittest {
    import pijamas;
    import std.experimental.allocator.mallocator : Mallocator;

    enableMemoryProfiler();

     /+
    {
        auto gcArray = [1, 2, 3, 4, 5, 6];
        auto array = Mallocator.instance.make!(int[])(gcArray);
        scope (exit)
            Mallocator.instance.dispose(array);

        array.should.have.length(6);
        // totalAllocatedMemory.should.be.equal(int.sizeof * 6);
        array.should.be.equal(gcArray);
    }
    //totalAllocatedMemory.should.be.equal(0);
    +/

    {
        __gshared int dtorCalledTimes = 0;
        struct S {
            int x, y;

            this(int val) {
                x = val;
                y = val;
            }

            ~this() {
                dtorCalledTimes++;
            }
        }

        auto s = Mallocator.instance.make!S(123);
        scope (exit)
            dtorCalledTimes.should.be.equal(1);
        scope (exit)
            Mallocator.instance.dispose(s);


        s.x.should.be.equal(123);
        s.y.should.be.equal(123);
    }
    totalAllocatedMemory.should.be.equal(0);


    {
        class C
        {
            int x, y;

            this(int x, int y) @nogc
            {
                this.x = x;
                this.y = y;
            }
            ~this() @nogc {}
        }

        C c = Mallocator.instance.make!C(1, 200);
        scope (exit)
            Mallocator.instance.dispose(c);

        c.x.should.be.equal(1);
        c.y.should.be.equal(200);
    }
    totalAllocatedMemory.should.be.equal(0);

    {
        __gshared int cDtorCalledTimes = 0;
        class C2 {
            int x, y;

            this(int x, int y) {
                this.x = x;
                this.y = y;
            }

            ~this() {
                cDtorCalledTimes++;
            }
        }

        C2 c = Mallocator.instance.make!C2(1, 200);
        scope (exit)
            cDtorCalledTimes.should.be.equal(1);
        scope (exit)
            Mallocator.instance.dispose(c);

        printMemoryLog();
        c.x.should.be.equal(1);
        c.y.should.be.equal(200);
    }
    totalAllocatedMemory.should.be.equal(0);
}
