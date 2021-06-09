/*
MIT License:

Copyright 2021 Luis Panadero Guardeño

Permission is hereby granted, free of charge, to any person obtaining a copy of
 this software and associated documentation files (the "Software"), to deal in 
 the Software without restriction, including without limitation the rights to 
 use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies 
 of the Software, and to permit persons to whom the Software is furnished to do
  so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all 
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE 
SOFTWARE.
*/
module ddiv.core.mallocator;
/** 
 * Auxiliar code to allocate/deallocate using classic Malloc/Free on a safe way on Dlang.
 */

import std.traits;

import core.memory : malloc = pureMalloc, free = pureFree, realloc = pureRealloc;
import core.stdc.string : memcpy, memset;
import core.exception: onOutOfMemoryError;

private struct AllocationRecord
{
    string type;
    size_t size;
}

private shared size_t totalAllocatedMemory = 0;
private __gshared bool memoryProfilerEnabled = false;
private __gshared AllocationRecord[size_t] records;

void addRecord(void* p, string type, size_t size)
{
    records[cast(size_t)p] = AllocationRecord(type, size);
}
void deleteRecord(void* p)
{
    records.remove(cast(size_t)p);
}

private void addAllocatedMemory(size_t size) nothrow @nogc
{
    import core.atomic : atomicOp;
    atomicOp!"+="(totalAllocatedMemory, size);
}

private void subAllocatedMemory(size_t size) nothrow @nogc
{
    import core.atomic : atomicOp;
    atomicOp!"-="(totalAllocatedMemory, size);
}


/**
 * Returns current amount of allocated memory in bytes. This is 0 at program start, and should be 0 at program end
 */
public size_t allocatedMemory()
{
    return totalAllocatedMemory;
}

/// Enables/Disables memopry profiling
public void enableMemoryProfiler(bool toggle)
{
    memoryProfilerEnabled = toggle;
}


/// Helper to handle allocations using Malloc, Realloc, Free, etc...
struct Mallocator
{
    /**
     Creates a new instance of `T`

     Params:
        args = Arguments uses to construct `T`
    */
    static T make(T, Args...)(Args args) @trusted
    if (is(T == class))
    {
        auto size = __traits(classInstanceSize, T);
        void* ptr = malloc(size);
        if (ptr is null) {
            onOutOfMemoryError();
        }
        auto memory = ptr[0..size];
        addAllocatedMemory(size);
        import std.conv : emplace;
        return emplace!(T, Args)(memory, args);  
    }

    /**
     Creates a new instance of `T`

     Params:
        args = Arguments uses to construct `T`
    */
    static T* make(T)() @nogc @trusted nothrow
    if (is(T == struct) && __traits(isPOD, T))
    {
        T* ptr = cast(T*) malloc(T.sizeof);
        if (ptr is null) {
            onOutOfMemoryError();
        }
        __gshared immutable T init = T.init;
        memcpy(ptr, &init, T.sizeof);
        addAllocatedMemory(T.sizeof);
        return ptr;
    }
    
    /**
     Creates a new instance of `T`

     Params:
        args = Arguments uses to construct `T`
    */
    static T* make(T, Args...)(auto ref Args args) @trusted
    if (is(T == struct) && !__traits(isPOD, T))
    {
        T* ptr = cast(T*) malloc(T.sizeof);
        if (ptr is null) {
            onOutOfMemoryError();
        }
        import std.conv : emplace;
        emplace(ptr, args);
        addAllocatedMemory(T.sizeof);
        return ptr;
    }

    /**
     Creates a new array 'T'

     Params:
        length = Size on elements of the array
    */
    static T make(T)(size_t length) @nogc @trusted nothrow
    if (isArray!T)
    in (length > 0, "Invalid size of dynamic array. Must greater that 0")
    {
        import std.traits : ForeachType;
        alias ArrayOf = ForeachType!T;
        return makeArray!ArrayOf(length);
    }

    static T make(T, U)(size_t length, U initilizer) @nogc @trusted nothrow
    if (isArray!T && is(ForeachType!T == U))
    in (length > 0, "Invalid size of dynamic array. Must greater that 0")
    {
        import std.traits : ForeachType;
        alias ArrayOf = ForeachType!T;
        return makeArray!ArrayOf(length, initilizer);
    }

    static T make(T)(T array) @nogc @trusted nothrow
    if (isArray!T)
    {
        import std.traits : ForeachType;
        alias ArrayOf = ForeachType!T;
        return makeArray!ArrayOf(array);
    }

    /**
     Disposes a instance of `T` created previsuly with Mallocator.

     If the instances stored on array, are a struct or a class, and have a destructor, calls to his destructor.
     */
    static void dispose(T)(ref T array) @trusted
    if (isArray!T)
    {
        alias ArrayOf = PointerTarget!(typeof(array.ptr));
        static if (!isPointer!ArrayOf) {
            // Calls the destructors of each instanced stored on the array
            static if (__traits(hasMember, ArrayOf, "__xdtor")) {
                foreach (ref ArrayOf t; array) {
                    t.__xdtor();
                }
            } else static if (__traits(hasMember, ArrayOf, "__dtor")) {
                foreach (ArrayOf t; array) {
                    t.__dtor();
                }
            }
        }
        size_t size = ArrayOf.sizeof * array.length;
        free(cast(void*) array.ptr);
        subAllocatedMemory(size);
    }

    /**
     Disposes a instance of `T` created previsuly with Mallocator.

     If `T` is a a class, and have a destructor, calls to his destructor.
     */
    static void dispose(T)(T object) @trusted
    if (is(T == class))
    {
        static if (__traits(hasMember, T, "__xdtor")) {
            object.__xdtor();
        } else static if (__traits(hasMember, T, "__dtor")) {
            object.__dtor();
        }
        auto size = __traits(classInstanceSize, T);
        subAllocatedMemory(size);
        free(cast(void*) object);
    }

    /**
     Disposes a instance of `T` created previsuly with Mallocator.

     If `T` is a struct or a class, and have a destructor, calls to his destructor.
     */
    static void dispose(T)(T object) @trusted
    if (!isArray!T && !is(T == class))
    {
        static if (__traits(hasMember, T, "__xdtor")) {
            object.__xdtor();
        } else static if (__traits(hasMember, T, "__dtor")) {
            object.__dtor();
        }
        static if (isPointer!T) {
            alias PtrOf = PointerTarget!T;
            subAllocatedMemory(PtrOf.sizeof);
        } else {
            subAllocatedMemory(T.sizeof);
        }
        free(cast(void*) object);
    }

    /**
     Creates a dynamic array
 
     Params:
        length = Length of the array
     Returns: The dynamic array
     */
    private static T[] makeArray(T)(size_t length) nothrow @nogc
    in (length > 0, "Invalid size of dynamic array. Must greater that 0")
    {
        void* ptr = malloc(T.sizeof * length);
        if (ptr is null) {
            onOutOfMemoryError();
        }
        T[] ret = (cast(T*) ptr)[0 .. length];
        addAllocatedMemory(T.sizeof * length);

        static if (__traits(isPOD, T)) {
            __gshared immutable T init = T.init;

            foreach (i; 0 .. ret.length) {
                memcpy(&ret[i], &init, T.sizeof);
            }
        } else {
            import std.conv;

            foreach (i; 0 .. ret.length) {
                emplace(&ret[i]);
            }
        }
        return ret;
    }

    /**
     Creates a dynamic array with a preinitialized value
 
     Params:
        length = Length of the array
        initializer = Initial value for each array entry
     Returns: The dynamic array
     */
    private static T[] makeArray(T)(size_t length, T initializer) nothrow @nogc
    {
        void* ptr = malloc(T.sizeof * length);
        if (ptr is null) {
            onOutOfMemoryError();
        }
        T[] ret = (cast(T*) ptr)[0 .. length];
        addAllocatedMemory(T.sizeof * length);
        
        foreach (ref v; ret) {
            v = initializer;
        }
        return ret;
    }
    
    /**
     Creates a dynamic array that it's a copy of a previous arrat
 
     Params:
        length = Length of the array
        array = Array to copy
     Returns: The dynamic array
     */
    private static T[] makeArray(T)(T[] array) nothrow @nogc
    {
        void* ptr = malloc(T.sizeof * array.length);
        if (ptr is null) {
            onOutOfMemoryError();
        }
        T[] ret = (cast(T*) ptr)[0 .. array.length];
        addAllocatedMemory(T.sizeof * array.length);
        foreach (i, ref v; ret) {
            v = array[i];
        }
        return ret;
    }

    /**
     Resizes a dynamic array.
 
     Params:
        array = dynamic array to be resized
        length = New length of the array
     Returns: The resized dynamic array
     */
    static T[] resizeArray(T)(T[] array, size_t newLength) nothrow @nogc
    {
        T[] ret;
        scope(success) subAllocatedMemory(array.length * T.sizeof);

        if (newLength > array.length) {
            void* ptr = realloc(array.ptr, T.sizeof * newLength);
            if (ptr is null) {
                onOutOfMemoryError();
            }
            ret = (cast(T*) ptr)[0 .. newLength];
            static if (__traits(isPOD, T)) {
                __gshared immutable T init = T.init;

                foreach (i; array.length .. ret.length) {
                    memcpy(&ret[i], &init, T.sizeof);
                }
            } else {
                static import std.conv;

                foreach (i; array.length .. ret.length) {
                    std.conv.emplace(&ret[i]);
                }
            }
        } else {
            static if (__traits(hasMember, T, "__xdtor")) {
                foreach (i; newLength .. array.length) {
                    array[i].__xdtor();
                }

            } else static if (__traits(hasMember, T, "__dtor")) {
                foreach (i; newLength .. array.length) {
                    array[i].__dtor();
                }
            }
            void* ptr = realloc(array.ptr, T.sizeof * newLength);
            if (ptr is null) {
                onOutOfMemoryError();
            }
            ret = (cast(T*) ptr)[0 .. newLength];
        }
        addAllocatedMemory(T.sizeof * newLength);
        return ret;
    }

    /** 
     Expands a dynamic array

     Params:
        length = Increases the array length by this value
     Returns: The dynamic array expanded. The new lenght its the old lenght plus the value of the argument
     */
    static T[] expandArray(T)(T[] array, size_t length) nothrow @nogc
    {
        size_t newLength = array.length + length;
        return resizeArray!T(array, newLength);
    }

}

@("Mallocator")
unittest {
    import pijamas;

    {
        auto array = Mallocator.make!(int[])(10);
        scope(exit) Mallocator.dispose(array);
        array[0] = 100;
        array[1] = 200;

        array.should.have.length(10);
        allocatedMemory.should.be.equal(int.sizeof * 10);

        array = Mallocator.expandArray(array, 5);
        array.should.have.length(15);
        
        allocatedMemory.should.be.equal(int.sizeof * 15);

        array = Mallocator.resizeArray(array, 5);
        array.should.have.length(5);
        
        allocatedMemory.should.be.equal(int.sizeof * 5);
    }
    // scope(exit) disposes the array
    allocatedMemory.should.be.equal(0);

    {
        auto array = Mallocator.make!(int[])(5, 333);
        scope(exit) Mallocator.dispose(array);
        array[0] = 100;
        array[1] = 200;

        array.should.have.length(5);
        allocatedMemory.should.be.equal(int.sizeof * 5);
        array.should.be.equal([100, 200, 333, 333, 333]);
    }
    allocatedMemory.should.be.equal(0);

    {
        auto gcArray = [1, 2, 3, 4, 5, 6];
        auto array = Mallocator.make!(int[])(gcArray);
        scope(exit) Mallocator.dispose(array);

        array.should.have.length(6);
        allocatedMemory.should.be.equal(int.sizeof * 6);
        array.should.be.equal(gcArray);
    }
    allocatedMemory.should.be.equal(0);

    {
        __gshared int dtorCalledTimes = 0;
        struct S {
            int x, y;

            ~this() {
                dtorCalledTimes++;
            }
        }

        auto array = Mallocator.make!(S[])(4);
        scope(exit) dtorCalledTimes.should.be.equal(4);
        scope(exit) Mallocator.dispose(array);

        array.should.have.length(4);
        allocatedMemory.should.be.equal(S.sizeof * 4);
    }
    allocatedMemory.should.be.equal(0);

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

        auto s = Mallocator.make!S(123);
        scope(exit) dtorCalledTimes.should.be.equal(1);
        scope(exit) Mallocator.dispose(s);

        s.x.should.be.equal(123);
        s.y.should.be.equal(123);
    }
    allocatedMemory.should.be.equal(0);

    {
        __gshared int dtorCalledTimes = 0;
        class C {
            int x, y;

            this(int x, int y) {
                this.x = x;
                this.y = y;
            }

            ~this() {
                dtorCalledTimes++;
            }
        }

        C c = Mallocator.make!C(1, 200);
        scope(exit) dtorCalledTimes.should.be.equal(1);
        scope(exit) Mallocator.dispose(c);

        c.x.should.be.equal(1);
        c.y.should.be.equal(200);
    }
    allocatedMemory.should.be.equal(0);
}
