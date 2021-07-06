/**
PriortyQueue build over a BinaryHeap
*/
module ddiv.container.priorityqueue;

import ddiv.core.memory;
import ddiv.core.exceptions;
import ddiv.container.common;
import ddiv.container.list;
import std.array;
import std.experimental.allocator.mallocator : Mallocator;
import std.range : assumeSorted;
import std.traits : isScalarType, isArray, hasIndirections;
import std.typecons : Tuple;

/**
 * Templated Priority Queue
 * Usage:     PriorityQueue!(PRIORITY_TYPE, VALUE_TYPE, OPTIONAL_PREDICATE)
 * Based on https://forum.dlang.org/post/mdqxpypqvgzyzwfgmsoh@forum.dlang.org
*/
struct PriorityQueue(P, V, alias predicate = "a > b", Allocator = Mallocator, bool supportGC = hasIndirections!V)
if (isAllocator!Allocator  && isScalarType!P) {

    // To make the code a bit more readable
    alias PV = Tuple!(P, "priority", V, "value");

    /// Internal storage on a dynamic array
    private SimpleList!(PV, Allocator, supportGC) list;

    import ddiv.core.memory.traits : isStatelessAllocator;

    static if (!isStatelessAllocator!Allocator)
    {
        /// No default construction if an allocator must be provided.
        this() @disable;

        /**
         * Use the given `allocator` for allocations.
         */
        this(Allocator allocator) @nogc @safe pure nothrow
        {
            this.list = SimpleList!(PV, Allocator, supportGC)(allocator);
        }
    }

    this(ref return PriorityQueue!(P, V, predicate, Allocator, supportGC) rhs)
    {
        this.list = SimpleList!(PV, Allocator, supportGC)(rhs.list);
    }

    ~this() @nogc @trusted {
        this.free();
    }

    void free() @nogc @trusted {
        this.list.free();
    }

    void reserve(size_t newCapacity) @trusted
    in (newCapacity > 0, "Invalid capacity. Must greater that 0") {
        this.list.reserve = newCapacity;
    }

    void expand(size_t delta) @nogc @trusted {
        this.list.expand(delta);
    }

    @property size_t capacity() const @nogc nothrow @safe {
        return this.list.capacity;
    }

    @property void capacity(size_t newCapacity) @trusted {
        this.reserve(newCapacity);
    }

    size_t opDollar() const @nogc nothrow @safe {
        return this.list.length;
    }

    alias length = opDollar;


    bool empty() const pure @nogc @safe {
        return this.list.empty;
    }

    void clear() @nogc nothrow {
        this.list.clear;
    }

    /// Needed so foreach can work
    auto ref PV front() pure @nogc @safe {
        if (this.empty) {
            throw new RangeError("PriotyQueue it's empty.");
        }
        return this.list.front;
    }

    alias top = front;

    /// Chop off the front of the array
    void popFront() @nogc nothrow {
        this.list.popFront;
    }

    /// Insert a value via a templated tuple
    void insert(ref PV value) @trusted {
        // Empty queue?
        if (this.empty) {
            this.list ~= value;
            return;
        }

        // Assume the queue is already sorted according to PREDICATE
        auto sortedRange = assumeSorted!(predicate)(this.list[]);

        // Find a slice containing records with priorities less than the insertion rec
        auto lowerBound = sortedRange.lowerBound(value);
        const location = lowerBound.length;
        this.list.insertInPlace(location, value);
    }

    /// ditto
    void insert(PV value) @safe {
        this.insert(value);
    }

    /// ditto
    void opOpAssign(string op)(PV value)
    if (op == "~") {
        this.insert(value);
    }

    /// Insert a record via decomposed priority and value
    void insert(P priority, V value) @safe {
        PV rec = PV(priority, value);
        this.insert(rec);
    }

    /// Removes an entry of the heap
    bool remove(PV value) @trusted {
        if (this.empty) {
            return false;
        }

        // Assume the queue is already sorted according to PREDICATE
        auto sortedRange = assumeSorted!(predicate)(this.list[]);
        // Obtains slices with previous, equal and rear respect to the element to find.
        auto slices = sortedRange.trisect(value);
        if (slices[1].empty) {
            return false;
        }
        assert (slices[1].length >= 1);
        const location = slices[0].length;
        assert (location <= this.length);
        this.list.remove(location);
        return true;
    }

    /// Removes an entry of the heap
    void remove(P priority, V value) @trusted {
        this.remove(PV(priority, value));
    }

    /// Returns a sorted range
    auto range(this This)() return @nogc nothrow @safe {
        return assumeSorted!(predicate)(this.list.range);
    }

    auto opSlice(this This)() @safe return {
        return this.list[];
    }

    auto opSlice(this This)(size_t start, size_t end) @safe @nogc return {
        return this.list[start..end];
    }

    auto ptr(this This)() return {
        return this.list.ptr;
    }

    /+
    /**
     * Merge two Priority Queues, returning the merge.
     * The two queues must obviously be of the same type in Priority and Value, and predicate;
     */
    ref PriorityQueue!(P, V, predicate) merge(ref PriorityQueue!(P, V, predicate) qmerge) {

        // Make a copy of this PriorityQueue
        PriorityQueue!(P, V, predicate)* qreturn = new PriorityQueue!(P, V, predicate);
        qreturn.elements = this.elements.dup;

        // Add in all the elements of the merging queue
        foreach (rec; qmerge) {
            qreturn.insert(rec);
        }

        // Return the resulting merged queue
        return *qreturn;
    }
    +/

    import std.format : FormatSpec;
    void toString(scope void delegate(const(char)[]) sink, FormatSpec!char fmt) const
    {
        this.list.toString(sink, fmt);
    }
}

@("PriorityQueue")
unittest {
    import pijamas;

    {
        alias P = int;
        alias V = string;
        alias PQ = PriorityQueue!(P, V, "a < b", Mallocator, false); // Top have always the lowest value
        alias PV = PQ.PV;
        PQ pq;

        pq.empty.should.be.True;
        should(() { pq.front; }).Throw!RangeError;

        import std.stdio;
        // Test basic insertion
        pq.insert(10, "HELLO10");
        pq.front.should.be.equal(PV(10, "HELLO10"));
        pq ~= PV(11, "HELLO11");
        pq.front.should.be.equal(PV(10, "HELLO10"));
        pq.insert(3, "HELLO3");
        pq.front.should.be.equal(PV(3, "HELLO3"));
        pq.insert(31, "HELLO31");
        pq.front.should.be.equal(PV(3, "HELLO3"));
        pq.insert(5, "HELLO5");
        pq.front.should.be.equal(PV(3, "HELLO3"));
        pq.insert(10, "HELLO10-2");
        pq.front.should.be.equal(PV(3, "HELLO3"));

        pq.empty.should.be.False;
        pq.length.should.be.equal(6);

        should(() { cast(void) pq.front; }).not.Throw!RangeError;

        foreach (const e; pq) {
        } // iteration
        pq.empty.should.be.False;

        foreach (const e; pq.range) {
        }
        pq.empty.should.be.False;

        pq.popFront;
        pq.front.should.be.equal(PV(5, "HELLO5"));
        pq.length.should.be.equal(5);

        pq.popFront;
        pq.front.should.be.equal(PV(10, "HELLO10"));

        pq.popFront;
        pq.front.should.be.equal(PV(10, "HELLO10-2"));

        pq.length.should.be.equal(3);

        pq.insert(3, "HELLO3");
        pq.length.should.be.equal(4);

        pq.remove(3, "HELLO23");
        pq.length.should.be.equal(4);


        pq.remove(10, "HELLO10-2");
        pq.length.should.be.equal(3);
        pq.front.should.be.equal(PV(3, "HELLO3"));
        pq.popFront;
        pq.front.should.be.equal(PV(11, "HELLO11"));
        pq.popFront;
        pq.front.should.be.equal(PV(31, "HELLO31"));
        pq.popFront;

        pq.empty.should.be.True;
        should(() { cast(void) pq.front; }).Throw!RangeError;

        pq.insert(123, "Hello");
        pq.insert(512, "Bye");

        PQ pq2 = pq;
        pq.clear;

        // pq and pq2 should be independent
        pq2.empty.should.be.False;
        pq.empty.should.be.True;
        /+
    // Test merging
    pq3.insert(PV(12, "HELLO12"));
    pq3.insert(PV(17, "HELLO17"));
    pq3.insert(PV(7, "HELLO7"));

    pq = pq2.merge(pq3);

    pq.should.not.be.empty;

    pq.front.should.be.equal(PV(3, "HELLO3"));
    pq.popFront;
    pq.front.should.be.equal(PV(5, "HELLO5"));
    pq.popFront;
    pq.front.should.be.equal(PV(7, "HELLO7"));
    pq.popFront;

    pq.should.have.length(6);

    // Removing
    pq.remove(PV(12, "HELLO12"));
    pq.should.have.length(5);
    +/
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

        alias P = int;
        alias PQ = PriorityQueue!(P, S, "a < b"); // Top have always the lowest value
        alias PV = PQ.PV;
        PQ pq;
        pq.reserve(32);
        pq.capacity.should.be.equal(32);
        pq.length.should.be.equal(0);
        pq.empty.should.be.True;

        pq ~= PV(10, S(10, 10));
        pq.length.should.be.equal(1);
        pq.empty.should.be.False;

        pq ~= PV(100, S(100, 10));
        pq ~= PV(100, S(100, 20));
        pq ~= PV(5, S(5, 0));

        pq.top.value.y = 512;
        pq.top.value.should.be.equal(S(5, 512));
    }

    debug (PriorityQueueTestStdout) {
        import std.stdio : writefln, writeln;

        alias P = int;
        alias V = string;
        alias PQ = PriorityQueue!(P, V);
        alias PV = PQ.PV;

        PQ pq, pq2, pq3;

        pq.insert(10, "HELLO10");
        pq.insert(11, "HELLO11");
        pq.insert(PV(3, "HELLO3"));
        pq.insert(5, "HELLO5");
        pq.insert(5, "HELLO5");
        pq.insert(PV(12, "HELLO12"));
        pq.insert(PV(17, "HELLO17"));

        pq2.insert(PV(15, "HELLO15"));
        pq2.insert(PV(21, "HELLO21"));

        writefln("\tPQ: %s \n\tPQ2: %s \n\tPQ3: %s", pq.toString, pq2.toString, pq3.toString);
        /+
        pq3 = pq.merge(pq2);

        debug (PriorityQueueTestStdout) {
            import std.algorithm : map;

            writeln(pq3.map!(x => x.priority));
        }
        int oldPriority = int.max;
        foreach (i, tuple; pq3) {
            debug (PriorityQueueTestStdout) {
                writefln("Pos: %s \t Priority: %s \tValue: %s \tLength: %s", i, tuple.priority, tuple.value, pq3
                        .length);
            }
            tuple.priority.should.not.be.biggerThan(oldPriority);
            oldPriority = tuple.priority;
            pq3.popFront();
        }
        pq3.should.be.empty;
        +/
    }
}

