module ddiv.core.memory.traits;
/**
BSD 3-Clause License

Copyright (c) 2017-2019, Atila Neves
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this
  list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice,
  this list of conditions and the following disclaimer in the documentation
  and/or other materials provided with the distribution.

* Neither the name of the copyright holder nor the names of its
  contributors may be used to endorse or promote products derived from
  this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

private void checkAllocator(T)() {
    import std.experimental.allocator: make, dispose;
    import std.traits: hasMember;

    static if(hasMember!(T, "instance")) {
        alias allocator = T.instance;
    } else {
        T allocator;
    }

    int* i = allocator.make!int;
    allocator.dispose(&i);
    void[] bytes = allocator.allocate(size_t.init);
    allocator.deallocate(bytes);
}

/// Checks if a type it's a valid Allocator
enum isAllocator(T) = is(typeof(checkAllocator!T));

@("isAllocator")
@safe @nogc pure unittest {
    import std.experimental.allocator.mallocator: Mallocator;

    static assert(isAllocator!Mallocator);
    static assert(!isAllocator!int);
}

/// Checks if an allocator stores state or not
template isStatelessAllocator(Allocator) if (isAllocator!Allocator)
{
    import std.experimental.allocator.common : stateSize;
    enum bool isStatelessAllocator = (stateSize!Allocator == 0);
}

@("isStatelessAllocator")
@safe @nogc pure unittest
{
    import std.experimental.allocator.mallocator : Mallocator;
    static assert(isStatelessAllocator!Mallocator);

    import std.experimental.allocator.building_blocks.stats_collector : StatsCollector, Options;
    import std.experimental.allocator.gc_allocator : GCAllocator;
    import std.experimental.allocator.building_blocks.free_list : FreeList;
    alias AllocatorWithState = StatsCollector!(GCAllocator, Options.bytesUsed);
    static assert(!isStatelessAllocator!AllocatorWithState);
}
