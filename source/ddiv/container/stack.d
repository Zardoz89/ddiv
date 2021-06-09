module ddiv.container.stack;

import ddiv.core.mallocator;

/**
 Simple NoGC stack that usess malloc/realloc.
 
 Only can contain scalar values (int, float, etc...)
 */
struct SimpleStack(T) 
if (__traits(isScalar, T)) 
{
    private T[] elements = void;
    private size_t arrayLength = 0;

    @disable this();

    this(size_t capacity) @nogc @trusted
    {
        this.elements = Mallocator.make!(T[])(capacity);
    }

    ~this() @nogc @trusted
    {
        Mallocator.dispose(this.elements);
    }

    void reserve(size_t newCapacity) @nogc @trusted
    {
        this.elements = Mallocator.resizeArray(this.elements, newCapacity);
    }

    void expand(size_t capacityIncrease) @nogc @trusted
    {
        this.elements = Mallocator.expandArray(this.elements, capacityIncrease);
    }

    size_t capacity() @nogc @safe
    {
        return this.elements.length;
    }

    size_t length() @nogc @safe
    {
        return this.arrayLength;
    }

    bool empty() @nogc @safe
    {
        return this.arrayLength == 0;
    }

    void push(T value) @nogc @safe
    {
        if (this.arrayLength >= this.capacity) {
            this.expand(this.capacity); // Old classic double the space
        }
        this.elements[this.arrayLength++] = value;
    }

    T top() @nogc @safe
    {
        if (this.empty) {
            return T.init;
        }
        return this.elements[this.arrayLength - 1];
    }

    T pop() @nogc @safe
    {
        if (this.empty) {
            return T.init;
        }
        T value = this.top();
        this.arrayLength--;
        return value;
    }

    bool contains(T value) @nogc @safe
    {
        if (this.empty) {
            return false;
        }
        import std.algorithm.searching : canFind;
        return canFind(this.elements[0..this.length], value);
    }

    void clear() @nogc @safe
    {
        this.arrayLength = 0;
    }
}

@("SimpleStack")
@safe
unittest {
    import pijamas;

    auto s = SimpleStack!int(16);
    s.capacity.should.be.equal(16);
    s.length.should.be.equal(0);
    s.empty.should.be.True();

    s.top.should.be.equal(int.init);
    s.contains(123).should.be.False();

    s.push(100);
    s.top.should.be.equal(100);
    s.length.should.be.equal(1);
    s.empty.should.be.False();
    s.contains(100).should.be.True();
    s.contains(123).should.be.False();
    s.pop.should.be.equal(100);
    s.empty.should.be.True();

    // Stress test
    foreach(i ; 0 .. 10_240) {
        s.push(i);
    }
    s.length.should.be.equal(10_240);
    s.capacity.should.be.biggerOrEqualThan(10_240);
    s.top.should.be.equal(10_240 - 1);
    s.contains(10_200).should.be.True();

    s.clear();
    s.length.should.be.equal(0);
    s.capacity.should.be.biggerOrEqualThan(10_240);
}