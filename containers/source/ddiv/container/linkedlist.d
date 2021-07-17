module ddiv.container.linkedlist;

import ddiv.core.memory;
import ddiv.core.exceptions;
import ddiv.container.common;
import std.experimental.allocator.mallocator : Mallocator;
import std.traits : isScalarType, hasIndirections;

/**
 Simple NoGC linked list that uses std.experimental.allocator

 Only can contain scalar
 */
class LinkedList(T, Allocator = Mallocator/+, bool supportGC = hasIndirections!T+/)
if (isAllocator!Allocator && isScalarType!T) {

    private struct Node(T) {
        T value;
        Node!T* prev = void;
        Node!T* next = void;
    }
    private Node!T* _start = void;
    private Node!T* _end = void;
    private size_t _length = 0;

    // Gets the struct constructor
    mixin StructAllocator!Allocator;

/+
    this(ref return typeof(this) rhs)
    {
        allocator = rhs.allocator;
        if (!rhs.empty) {
            foreach (element; rhs.range) {
                this.insertBack(element);
            }
        }
    }
    +/

    ~this() @nogc @trusted {
        this.clear();
    }

    void clear() @nogc @trusted {
        while(this._start !is null) {
            auto ptr = this._start;
            this._start = ptr.next;
            disposeNode(ptr);
        }
        this._end = null;
        this._length = 0;
        assert(this._start is null);
    }

    private void disposeNode(Node!T* node) @nogc @trusted {
        static if ((is(T == struct) || is(T == union)) && __traits(hasMember, T, "__xdtor")) {
            node.__xdtor();
        }
        /+
        static if (supportGC) {
            import core.memory : GC;

            GC.removeRange(node.value);
        }
        +/
        allocator.dispose(node);
    }

    size_t opDollar() const @nogc nothrow @safe {
        return this._length;
    }

    alias length = opDollar;
    alias capacity = opDollar;

    bool empty() @property const @nogc nothrow @safe pure {
        return this._length == 0;
    }

    /// O(1)
    void insertBack(T value) @nogc nothrow @trusted {
        auto node = allocator.make!(Node!T)();
        node.value = value;
        if (this._end is null) {
            this._start = node;
            this._end = node;
        } else {
            this._end.next = node;
            node.prev = this._end;
            this._end = node;
        }
            this._length++;
    }

    // O(1)
    void insertFront(T value) @nogc nothrow @trusted {
        auto node = allocator.make!(Node!T)();
        node.value = value;
        if (this._start is null) {
            this._start = node;
            this._end = node;
        } else {
            this._start.prev = node;
            node.next = this._start;
            this._start = node;
        }
        this._length++;
    }

    /// O(1)
    auto ref T back() @property pure const @nogc @safe {
        if (this.empty) {
            throw new RangeError("LinkedList it's empty.");
        }
        return this._end.value;
    }

    auto ref T moveBack() @nogc @safe {
        T result = this.back;
        this.popBack;
        return result;
    }

    /// O(1)
    auto ref T front() @property pure const @nogc @safe {
        if (this.empty) {
            throw new RangeError("LinkedList it's empty.");
        }
        return this._start.value;
    }

    auto ref T moveFront() @nogc @safe {
        T result = this.front;
        this.popFront();
        return result;
    }

    /// O(1)
    void popBack() @nogc nothrow @trusted {
        if (!this.empty) {
            auto ptr = this._end;
            this._end = ptr.prev;
            this._end.next = null;
            disposeNode(ptr);
            this._length--;
        }
    }

    /// O(1)
    void popFront() @nogc nothrow @trusted {
        if (!this.empty) {
            auto ptr = this._start;
            this._start = ptr.next;
            this._start.prev = null;
            disposeNode(ptr);
            this._length--;
        }
    }

    /// O(N)
    void remove(size_t index) @trusted @nogc nothrow
    in (this.empty || index <= this._length)
    {
        if (this.empty) {
            return;
        }

        if (index == 0) {
            this.popFront;
        } else if (index == this._length) {
            this.popBack;
        } else {
            auto cursor = this._start;
            for (size_t i= 0; i < index && i < this._length; i++) {
                cursor = cast(Node!T*) cursor.next;
            }
            cursor.prev.next = cursor.next;
            cursor.next.prev = cursor.prev;
            disposeNode(cursor);
            this._length--;
        }
    }

    /// O(N) (linear search)
    bool removeValue(T value) @nogc @trusted
    {
        auto nodeTuple = this.findTuple(value);
        if (nodeTuple[1] is null) {
            return false;
        }
        auto index = nodeTuple[0];
        if (index == 0) {
            this.popFront;
            return true;
        } else if (index == this._length) {
            this.popBack;
            return true;
        }

        auto node = nodeTuple[1];
        node.prev.next = node.next;
        node.next.prev = node.prev;
        disposeNode(node);
        this._length--;
        return true;
    }

    import std.typecons : Nullable, Tuple, tuple;

    /// O(N) (linear search)
    Nullable!size_t find(T value) @nogc @trusted
    {
        auto nodeTuple = this.findTuple(value);
        if (nodeTuple[1] is null) {
            return Nullable!size_t();
        }
        return Nullable!size_t(nodeTuple[0]);
    }

    private Tuple!(size_t, Node!T*) findTuple(ref T value) @trusted
    {
        if (this.empty) {
            return tuple(cast(size_t)0, cast(Node!T*)null);
        }

        auto cursor = this._start;
        bool found = false;
        size_t i = 0;
        for (; !found && i < this._length; i++) {
            if (cursor.value == value) {
                found = true;
                break;
            }
            cursor = cast(Node!T*) cursor.next;
        }
        if (found) {
            return tuple(i, cursor);
        }
        return tuple(cast(size_t)0, cast(Node!T*)null);
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

    /// $(BIGOH N) inserts in place
    void insertInPlace(size_t location, T value) @nogc @trusted
    in (location <= this._length)
    {
        if (this.empty || location > this._length) {
            throw new RangeError("Inserting value, out of bounds.");
        }
        if (location == this._length) {
            this.insertBack(value);
            return;
        }
        if (location == 0) {
            this.insertFront(value);
            return;
        }

        auto node = allocator.make!(Node!T)();
        node.value = value;
        auto cursor = this._start;
        for (size_t i= 0; i< location && i < this._length; i++) {
            cursor = cast(Node!T*) cursor.next;
        }
        node.next = cursor;
        node.prev = cursor.prev;
        cursor.prev.next = node;
        cursor.prev = node;
        this._length++;

    }

    private Node!T* getNodeByPosition(size_t index) const @nogc @trusted {
        if (this.empty || index > this.length) {
            throw new RangeError("Indexing out of bounds.");
        }
        auto cursor = cast(Node!T*) this._start;
        for (size_t i= 0; i< index && i < this._length; i++) {
            cursor = cursor.next;
        }
        return cursor;
    }

    static if (__traits(isScalar, T)) {
        inout(T) opIndex(size_t index) inout @nogc @trusted {
            return this.getNodeByPosition(index).value;
        }
    } else {
        ref inout(T) opIndex(size_t index) return inout @nogc @trusted {
            return this.getNodeByPosition(index).value;
        }
    }

    static struct LinkedListRange(T) {
        private Node!T* _start = void;
        private Node!T* _end = void;
        private size_t _length = 0;

        typeof(this) save() {
            return this;
        }

        auto front() @nogc @trusted {
            if (this.empty) {
                throw new RangeError("Range it's empty.");
            }
            return this._start.value;
        }

        void popFront() @nogc @trusted nothrow{
            if (!this.empty) {
                auto ptr = this._start;
                this._start = ptr.next;
                this._length--;
            }
        }

        auto back() @nogc @trusted {
            if (this.empty) {
                throw new RangeError("Range it's empty.");
            }
            return this._end.value;
        }

        void popBack() @nogc @trusted nothrow {
            if (!this.empty) {
                auto ptr = this._end;
                this._end = ptr.prev;
                this._length--;
            }
        }

        bool empty() pure const @nogc {
            return this._length == 0;
        }

        size_t length() pure const @nogc {
            return this._length;
        }

        alias opDollar = length;

        private Node!T* getNodeByPosition(size_t index) const @nogc @trusted {
            if (this.empty || index > this.length) {
                throw new RangeError("Indexing out of bounds.");
            }
            auto cursor = cast(Node!T*) this._start;
            for (size_t i= 0; i< index && i < this._length; i++) {
                cursor = cursor.next;
            }
            return cursor;
        }

        static if (__traits(isScalar, T)) {
            inout(T) opIndex(size_t index) inout @nogc @trusted {
                return this.getNodeByPosition(index).value;
            }
        }  else {
            ref inout(T) opIndex(size_t index) return inout @nogc @trusted {
                return this.getNodeByPosition(index).value;
            }
        }
    }
    import std.range.primitives : isForwardRange, isBidirectionalRange, isRandomAccessRange;

    static assert(isForwardRange!(LinkedListRange!T));
    static assert(isBidirectionalRange!(LinkedListRange!T));
    static assert(isRandomAccessRange!(LinkedListRange!T));

    /// Returns a bidirectional/randomAccess range
    auto opSlice() return @nogc nothrow @safe {
        return LinkedListRange!T(this._start, this._end, this._length);
    }

    /// ditto
    alias range = opSlice;

    /// ditto
    auto opSlice(this This)(size_t start, size_t end) return @nogc @safe {
        if (end < start) {
            throw new RangeError(
                    "Slicing with invalid range. Start must be equal or less that end.");
        }
        if (end > this.length) {
            throw new RangeError("Slicing out of bounds of SimpleList.");
        }
        return LinkedListRange!T(this.getNodeByPosition(start), this.getNodeByPosition(end), end - start);
    }

    import std.format : FormatSpec;
    void toString(scope void delegate(const(char)[]) sink, FormatSpec!char fmt) @trusted
    {
        import std.range : put;
        if (this.empty) {
            put(sink, "[]");
            return;
        }
        put(sink, "[");
        import std.format : formatValue;

        size_t index = 0;

        foreach(ref element; this.range() ) {
            formatValue(sink, element, fmt);
            if (index < this.length) {
                put(sink, ", ");
            }
            index++;
        }
        put(sink, "]");
    }
}

import std.range.primitives : isInputRange, isBidirectionalRange;
static assert (isInputRange!(LinkedList!int));
// static assert (isBidirectionalRange!(LinkedList!int));

@("LinkedList with scalar and simple structs @nogc")
@nogc @safe unittest {
    import pijamas;
    {
        scope auto ll = new LinkedList!int();
        ll.length.should.be.equal(0);
        ll.empty.should.be.True;

        /+
        this instances aren't never deallocated, becasue some bug of DMD with anonymus functions
        should(() {
            auto ll = LinkedList!int();
            ll.back;
        }).Throw!RangeError;
        should(() {
            auto ll = LinkedList!int();
            ll.front;
        }).Throw!RangeError;
        should(() {
            auto ll = LinkedList!int();
            cast(void) ll[123];
        }).Throw!RangeError;
        +/

        ll.insertFront(33);
        ll.length.should.be.equal(1);
        ll.empty.should.be.False;

        ll.insertBack(123);
        ll.insertFront(512);
        ll.length.should.be.equal(3);

        ll.front.should.be.equal(512);
        ll.back.should.be.equal(123);

        ll.popFront;
        ll.length.should.be.equal(2);
        ll.front.should.be.equal(33);
        ll.back.should.be.equal(123);

        ll.popBack;
        ll.length.should.be.equal(1);
        ll.front.should.be.equal(33);
        ll.back.should.be.equal(33);
    }

    {
        // Stress test
        scope auto ll = new LinkedList!int();
        import std.range : iota;

        ll ~= iota(0, 10_240);
        ll.length.should.be.equal(10_240);
        ll.front.should.be.equal(0);
        ll.back.should.be.equal(10_240 - 1);

        ll.insertInPlace(100, -512);
        ll.length.should.be.equal(10_241);
        ll[100].should.be.equal(-512);
        ll.remove(33);
        ll.length.should.be.equal(10_240);
        ll[33].should.be.equal(34);
        ll.removeValue(512).should.be.True;
        ll.length.should.be.equal(10_239);
        ll.removeValue(-123_456).should.be.False;

        ll.find(-123_456).isNull.should.be.True;
        auto f = ll.find(1_024);
        f.isNull.should.be.False;
        f.get.should.be.equal(1_023);

        import std.algorithm;
        ll.range.filter!(x => x % 2 == 0).sum.should.be.equal(26208256);
    }

/+
    {
        struct S {
            int x;
            long y;

            bool opEquals()(auto ref const S rhs) const @nogc @safe pure nothrow {
                return this.x == rhs.x && this.y == rhs.y;
            }
        }

        auto ll = LinkedList!S();
        ll.length.should.be.equal(0);
        ll.empty.should.be.True;

        /+
        this instances aren't never deallocated, becasue some bug of DMD with anonymus functions
        should(() {
            auto ll = LinkedList!S();
            ll.back;
        }).Throw!RangeError;
        should(() {
            auto ll = LinkedList!S();
            ll.front;
        }).Throw!RangeError;
        should(() {
            auto ll = LinkedList!S();
            cast(void) ll[123];
        }).Throw!RangeError;
        +/

        ll ~= S(10);
        ll.back.should.be.equal(S(10));
        ll.front.should.be.equal(S(10));
        ll.length.should.be.equal(1);
        ll.empty.should.be.False;

        ll.popBack;
        ll.empty.should.be.True;

        // Stress test
        import std.range : iota, array;

        foreach (i; 0 .. 128) {
            ll ~= S(i);
        }
        ll.length.should.be.equal(128);
        ll.back.should.be.equal(S(127));
        ll.front.should.be.equal(S(0));

        ll[0].x = 123;
        ll.front.should.be.equal(S(123));

        ll.find(S(1_024)).isNull.should.be.True;
        auto f = ll.find(S(120));
        f.isNull.should.be.False;
        f.get.should.be.equal(120);
    }
    +/
}

/+
@("LinkedList with class with destructor")
unittest {
    import pijamas;

    class C {
        int x;

        this(int x) @nogc nothrow {
            this.x = x;
        }
    }

    auto ll = LinkedList!C();
    foreach (i; 0 .. 32) {
        ll ~= new C(i);
    }
    ll.front.should.be.equal(ll[0]);
    ll.clear();
    ll.empty.should.be.True;

}
+/

@("LinkedList with scalar")
@safe unittest {
    import pijamas;

    {
        scope auto ll = new LinkedList!int();

        should(() {
            ll.back;
        }).Throw!RangeError;
        should(() {
            ll.front;
        }).Throw!RangeError;
        should(() {
            cast(void) ll[123];
        }).Throw!RangeError;

        import std.range : iota, array;

        ll ~= iota(0, 10_240);
        //ll[].should.be.equal(iota(0, 10_240).array);
        //ll[0 .. 100].should.be.equal(iota(0, 100).array);
        //ll[1_000 .. $].should.be.equal(iota(1_000, 10_240).array);

        should(() {
            cast(void) ll[-1 .. 100];
        }).Throw!RangeError;
        should(() {
            cast(void) ll[200 .. 100];
        }).Throw!RangeError;
        should(() {
            cast(void) ll[10 .. 20_000];
        }).Throw!RangeError;

        import std.algorithm.searching : canFind;

        ll.range.canFind(512).should.be.True;
    }

    {
        scope auto ll = new LinkedList!int();
        import std.range : iota, array;

        ll ~= iota(0, 512);
        import std.algorithm;
        ll.range.array.filter!(x => x % 2 == 0).sum.should.be.equal(65_280);
    }
}
