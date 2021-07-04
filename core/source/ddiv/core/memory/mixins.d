module ddiv.core.memory.mixins;

import ddiv.core.memory.traits;

/// Helper mixin to build containers using Allocators
mixin template AllocatorState(Allocator)
if (isAllocator!Allocator) {
    import ddiv.core.memory.traits : isStatelessAllocator;

    static if (isStatelessAllocator!Allocator) {
        alias allocator = Allocator.instance;
    } else {
        Allocator allocator;
    }
}

/// Helper mixin to create to use an allocator with a Struct
mixin template StructAllocator(Allocator)
if (isAllocator!Allocator) {
    import ddiv.core.memory.traits : isStatelessAllocator;

    mixin AllocatorState!Allocator;

    static if (!isStatelessAllocator!Allocator)
    {
        /// No default construction if an allocator must be provided.
        this() @disable;

        /**
         * Use the given `allocator` for allocations.
         */
        this(Allocator allocator) @nogc @safe pure nothrow
        {
            this.allocator = allocator;
        }
    }
}

@("alloactor helper mixings")
@nogc unittest
{
    import std.experimental.allocator.mallocator : Mallocator;

    struct S(Allocator) {
        mixin StructAllocator!Allocator;
    }

    assert (__traits(compiles, () {
        S!Mallocator s = S!Mallocator();
    }));
    assert (__traits(hasMember, S!Mallocator, "allocator"));

    import std.experimental.allocator.building_blocks.stats_collector : StatsCollector, Options;
    import std.experimental.allocator.gc_allocator : GCAllocator;
    import std.experimental.allocator.building_blocks.free_list : FreeList;
    alias StateAllocator = StatsCollector!(GCAllocator, Options.bytesUsed);

    assert (!__traits(compiles, () {
        S!StateAllocator s = S!StateAllocator();
    }));
    assert (__traits(compiles, () {
        StateAllocator alloc;
        S!StateAllocator s = S!StateAllocator(alloc);
    }));

    StateAllocator alloc;
    S!StateAllocator s = S!StateAllocator(alloc);
    assert (__traits(hasMember, s, "allocator"));
}
