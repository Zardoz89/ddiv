/**
PriortyQueue build over a BinaryHeap
*/
module ddiv.container.priorityqueue;

import std.array;
import std.range: assumeSorted;
import std.typecons: Tuple;

/**
 * Templated Priority Queue
 * Usage:     PriorityQueue!(PRIORITY_TYPE, VALUE_TYPE, OPTIONAL_PREDICATE)
 * Based on https://forum.dlang.org/post/mdqxpypqvgzyzwfgmsoh@forum.dlang.org
*/
struct PriorityQueue(P, V, alias predicate = "a > b") {

    // To make the code a bit more readable
    alias PV = Tuple!(P, "priority", V, "value");

    /// Internal storage on a dynamic array
    PV[] _q;

    // Forward most function calls to the underlying array.
    alias _q this;

    /// Determine if the queue is empty
    bool empty() const pure @nogc @safe {
        return (_q.length == 0);
    }

    /// Needed so foreach can work
    PV front() pure @nogc @safe {
        return this._q.front;
    }

    /// Chop off the front of the array
    void popFront() @nogc @safe {
        this._q = this._q[1 .. $];
    }

    /// Insert a record via a template tuple
    void insert(ref PV rec) @trusted {
        // Empty queue?
        if (this.empty) {
            // just put the record into the queue
            this._q ~= rec;
            return;
        }

        // Assume the queue is already sorted according to PREDICATE
        auto a = assumeSorted!(predicate)(_q);

        // Find a slice containing records with priorities less than the insertion rec
        auto p = a.lowerBound(rec);
        const location = p.length;

        // Insert the record
        _q.insertInPlace(location, rec);
    }

    /// Inserts a record
    void insert(PV rec) @safe {
        this.insert(rec);
    }

    /// Insert a record via decomposed priority and value
    void insert(P priority, V value) @safe {
        PV rec = PV(priority, value);
        this.insert(rec);
    }

    /// Removes an entry of the heap
    void remove(PV rec) @trusted {
        import std.algorithm.mutation : remove;
        this._q = this._q.remove!(x => x == rec);
    }

    /// Removes an entry of the heap
    void remove(P priority, V value) @trusted
    {
        this.remove(PV(priority, value));
    }

    /**
     * Merge two Priority Queues, returning the merge.
     * The two queues must obviously be of the same type in Priority and Value, and predicate;
     */
    ref PriorityQueue!(P, V, predicate) merge(ref PriorityQueue!(P, V, predicate) qmerge) {

        // Make a copy of this PriorityQueue
        PriorityQueue!(P, V, predicate)* qreturn = new PriorityQueue!(P, V, predicate);
        qreturn._q = this._q.dup;

        // Add in all the elements of the merging queue
        foreach(rec; qmerge) {
            qreturn.insert(rec);
        }

        // Return the resulting merged queue
        return *qreturn;
    }

}

version(unittest) import beep;

@("PriorityQueue")
unittest {
    alias P = int;
    alias V = string;
    alias PQ = PriorityQueue!(P, V, "a < b");
    alias PV =  PQ.PV;
    PQ pq, pq2, pq3;

    import std.typecons: tuple;

    // Test basic insertion
    pq.insert(10, "HELLO10");
    pq.insert(11, "HELLO11");
    pq.insert(3, "HELLO3");
    pq.insert(31, "HELLO31");
    pq.insert(5, "HELLO5");
    pq.insert(10, "HELLO10-2");

    pq.length.expect!equal(6);

    foreach (const e; pq) {}    // iteration
    pq.empty.expect!false;          // shouldn't consume queue

    // Copy by value
    pq2 = pq;

    foreach (priority, value; pq) {
        pq.popFront();
    }

    // pq and pq2 should be independent
    pq2.empty.expect!false;
    pq.empty.expect!true;

    // Test merging
    pq3.insert(PV(12, "HELLO12"));
    pq3.insert(PV(17, "HELLO17"));
    pq3.insert(PV(7, "HELLO7"));

    pq = pq2.merge(pq3);

    pq.empty.expect!false;

    assert(pq.front == PV(3, "HELLO3"));
    pq.popFront;
    assert(pq.front == PV(5, "HELLO5"));
    pq.popFront;
    assert(pq.front == PV(7, "HELLO7"));
    pq.popFront;

    pq.length.expect!equal(6);

    // Removing
    pq.remove(PV(12, "HELLO12"));
    pq.length.expect!equal(5);
}

@("PriorityQueue 2")
unittest {
    debug(PriorityQueueTestStdout) {
        import std.stdio : writefln, writeln;
    }

    alias P = int;
    alias V = string;
    alias PQ = PriorityQueue!(P, V);
    alias PV =  PQ.PV;

    PQ pq, pq2, pq3;

    pq.insert(10, "HELLO10");
    pq.insert(11, "HELLO11");
    pq.insert(PV(3, "HELLO3"));
    pq.insert(5, "HELLO5");
    pq.insert(PV(12, "HELLO12"));
    pq.insert(PV(17, "HELLO17"));

    pq2.insert(PV(15, "HELLO15"));
    pq2.insert(PV(21, "HELLO21"));

    debug(PriorityQueueTestStdout) {
        writefln("\tPQ: %s \n\tPQ2: %s \n\tPQ3: %s", pq, pq2, pq3);
    }
    pq3 = pq.merge(pq2);

    debug(PriorityQueueTestStdout) {
        import std.algorithm : map;
        writeln(pq3.map!(x => x.priority));
    }
    int oldPriority = int.max;
    foreach(i, tuple; pq3) {
        debug(PriorityQueueTestStdout) {
            writefln("Pos: %s \t Priority: %s \tValue: %s \tLength: %s", i, tuple.priority, tuple.value, pq3.length);
        }
        (tuple.priority <= oldPriority).expect!true;
        oldPriority = tuple.priority;
        pq3.popFront();
    }
    pq3.empty.expect!true;
}

