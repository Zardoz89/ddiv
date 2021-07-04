/**
PriortyQueue build over a BinaryHeap
*/
module ddiv.container.priorityqueue;

import ddiv.core.memory;
import ddiv.core.exceptions;
import ddiv.container.common;
import std.array;
import std.experimental.allocator.mallocator : Mallocator;
import std.range : assumeSorted;
import std.traits : isScalarType;
import std.typecons : Tuple;

/**
 * Templated Priority Queue
 * Usage:     PriorityQueue!(PRIORITY_TYPE, VALUE_TYPE, OPTIONAL_PREDICATE)
 * Based on https://forum.dlang.org/post/mdqxpypqvgzyzwfgmsoh@forum.dlang.org
*/
struct PriorityQueue(P, V, alias predicate = "a > b", Allocator = Mallocator)
if (isAllocator!Allocator  && isScalarType!P /*&& !is(V == class)*/) {

    // To make the code a bit more readable
    alias PV = Tuple!(P, "priority", V, "value");

    /// Internal storage on a dynamic array
    private PV[] elements = void;
    private size_t arrayLength = 0;

    // Gets the struct constructor
    mixin StructAllocator!Allocator;

    this(ref return scope PriorityQueue rhs) @disable;

    ~this() @nogc @trusted scope {
        this.free();
    }

    void free() @nogc @trusted scope {
        if (!(this.elements is null)) {

            /*
            static if ((is(V == struct) || is(V == union)) && __traits(hasMember, V, "__xdtor")) {
                foreach (ref element; elements[0 .. this.length]) {
                    element.__xdtor();
                }
            }
            */

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
            this.elements = allocator.make!(PV[])(newCapacity);
        } else {
            if (newCapacity > this.capacity) {
                allocator.expandArray!PV(this.elements, newCapacity - this.capacity);
            } else {
                allocator.shrinkArray!PV(this.elements, this.capacity - newCapacity);
            }
        }
    }

    void expand(size_t delta) @nogc @trusted {
        if (this.elements is null) {
            this.elements = allocator.make!(PV[])(delta);
        } else {
            allocator.expandArray!PV(this.elements, delta);
        }
    }

    size_t capacity() const @nogc nothrow @safe {
        return this.elements.length;
    }

    size_t opDollar() const @nogc nothrow @safe {
        return this.arrayLength;
    }

    alias length = opDollar;


    /// Determine if the queue is empty
    bool empty() const pure @nogc @safe {
        return this.elements is null || this.length == 0;
    }

    void clear() @nogc nothrow {
        if (!this.empty) {
            /*
            static if ((is(T == struct) || is(T == union))
                    && __traits(hasMember, T, "__xdtor")) {
                foreach (ref element; elements[0 .. this.length]) {
                    element.__xdtor();
                }
            }
            */
            this.arrayLength = 0;
        }
    }

    /// Needed so foreach can work
    auto ref PV front() pure @nogc @safe {
        if (this.empty) {
            throw new RangeError("PriotyQueue it's empty.");
        }
        return this.elements.front;
    }

    alias top = front;

    /// Chop off the front of the array
    void popFront() @nogc @safe {
        if (!this.empty) {
            /*
            static if ((is(T == struct) || is(T == union))
                    && __traits(hasMember, T, "__xdtor")) {
                this.elements[0].__xdtor();
            }
            */
            foreach (i; 0 .. this.arrayLength - 1) {
                this.elements[i] = this.elements[i + 1];
            }
            this.arrayLength--;
        }
    }

    /// Insert a record via a template tuple
    void insert(ref PV value) @trusted {
        // Empty queue?
        if (this.empty) {
            if (this.elements is null) {
                this.reserve(32);
            }
            if (this.arrayLength >= this.capacity) {
                this.reserve(growCapacity(this.capacity));
            }

            // just put the record into the queue
            this.elements[0] = value;
            this.arrayLength++;
            return;
        }

        // Assume the queue is already sorted according to PREDICATE
        auto a = assumeSorted!(predicate)(this.elements[0 .. this.length]);

        // Find a slice containing records with priorities less than the insertion rec
        auto p = a.lowerBound(value);
        const location = p.length;
        //writeln("-> ", p, " -- ", value, " l:", location);
        this.insertInPlace(location, value);

    }

    /// ditto
    void insert(PV rec) @safe {
        this.insert(rec);
    }

    void opOpAssign(string op)(PV rec) nothrow
    if (op == "~") {
        this.insert(rec);
    }

    /// Insert a record via decomposed priority and value
    void insert(P priority, V value) @safe {
        PV rec = PV(priority, value);
        this.insert(rec);
    }

    /// Moves to the right, the items of the internal list and inserts the new value
    private void insertInPlace(size_t location, ref PV value)
    in (location <= arrayLength)
    {
        if (this.elements is null) {
            this.reserve(32);
        }
        if (this.arrayLength >= this.capacity) {
            this.reserve(growCapacity(this.capacity));
        }

        if (location < this.arrayLength) {
            foreach_reverse (i; location..this.arrayLength) {
                this.elements[i+1] = this.elements[i];
            }
        }
        this.elements[location] = value;
        this.arrayLength++;
    }

    // TODO Testear remove
    /// Removes an entry of the heap
    void remove(PV value) @trusted {

        // Assume the queue is already sorted according to PREDICATE
        auto a = assumeSorted!(predicate)(this.elements[0 .. this.length]);
        // Obtains slices with previous, equal and rear respect to the element to find.
        auto slices = a.trisect(value);
        if (slices[1].empty) {
            return;
        }
        assert (slices[1].length == 1);
        const startLocation = slices[0].length;

        // Moves rear elements to the left
        foreach (i; startLocation .. this.arrayLength - 1) {
            this.elements[i] = this.elements[i+1];
        }
        this.arrayLength--;
    }

    /// Removes an entry of the heap
    void remove(P priority, V value) @trusted {
        this.remove(PV(priority, value));
    }

    /// Returns a forward range
    auto range(this This)() return @nogc nothrow @safe {
        static struct Range {
            private This* self;
            private size_t frontIndex;
            private size_t backIndex;

            Range save() {
                return this;
            }

            auto front() {
                return self.elements[frontIndex];
            }

            void popFront() @nogc {
                ++frontIndex;
            }

            auto back() {
                return self.elements[backIndex];
            }

            void popBack() @nogc {
                ++backIndex;
            }

            bool empty() const @nogc {
                return frontIndex >= backIndex;
            }

            size_t length() const @nogc {
                return frontIndex - backIndex;
            }

            alias opDollar = length;

            ref inout(PV) opIndex(size_t index) inout @nogc @safe {
                if (self.empty || index > self.length) {
                    throw new RangeError("Indexing out of bounds.");
                }
                return self.elements[index];
            }
        }

        import std.range.primitives : isForwardRange, isBidirectionalRange, isRandomAccessRange;

        static assert(isForwardRange!Range);
        static assert(isBidirectionalRange!Range);
        static assert(isRandomAccessRange!Range);

        return assumeSorted!(predicate)(Range(() @trusted { return &this; }(), 0, this.length));
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

    string toString() const
    {
        if (this.empty) {
            return "[]";
        }
        import std.conv : to;
        return this.elements[0..this.length].to!string;
    }
}

@("PriorityQueue")
unittest {
    import pijamas;

    {
        alias P = int;
        alias V = string;
        alias PQ = PriorityQueue!(P, V, "a < b"); // Top have always the lowest value
        alias PV = PQ.PV;
        PQ pq;

        pq.empty.should.be.True;
        should(() { pq.front; }).Throw!RangeError;

        import std.typecons : tuple;

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

        pq.length.should.be.equal(6);
        pq.empty.should.be.False;

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


        /+
    // Copy by value
    pq2 = pq;

    foreach (priority, value; pq) {
        pq.popFront();
    }

    // pq and pq2 should be independent
    pq2.should.not.be.empty;
    pq.should.be.empty;

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

