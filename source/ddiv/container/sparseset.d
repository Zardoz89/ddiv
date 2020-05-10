/**
Implementation of Sparse Sets
*/
module ddiv.container.sparseset;

import ddiv.container.common;

/**
 * Templated naive Sparse Set using static arrays
 *
 * Params:
 *  T = Content type. Must a unsigned integer type
 *  capacity = Max number of elements to be stored
 *  maxValue = Bigger number allowed to be stored . By default is the same value that capacity
 *
 * Usage:     StaticSparseSet!(uint, capacity)() or StaticSparseSet!(uint, capacity, maxValue)()
 *
 * Based on https://www.geeksforgeeks.org/sparse-set/
 *
 * Total ram usage should be :
 * T.sizeof * 2^capacity + size_t * 2^maxValue ≃ T.sizeof * 2 * 2^n
 *
 * For example, for uint and maxValue=capacity= 2^22 -> 4*2^22 + 8*2^22= 48MiB
 *
 * Performance:
 *
 * | Opration| Big O |
 * | ------- | ---- |
 * | search  | O(1) |
 * | insert  | O(1) |
 * | remove  | O(1) |
 * | clear   | O(1) |
 * | iterate | O(n) |
 *
 * TODO Study the posibility of compressing sparse, using a HashSet, for huge big maxValue cases
*/
struct StaticSparseSet(T = uint, size_t _capacity, T _maxValue = _capacity)
if (__traits(isUnsigned, T))
{
    static assert(_capacity > 0 , "Invalid capacity. Must be a positive value");
    static assert(_maxValue > 0 , "Invalid maxValue. Must be a positive value");

    private size_t[_maxValue + 1] sparse; // sparse[val] returns a index of dense
    private T[_capacity] dense; // Here contains the values
    private size_t n = 0;

    private static enum _SparseSet_ = true; // Flag to help isSparseSet to identify as a SparseSet
    private static enum _StaticSparseSet_ = true; // Flag to help isSparseSet to identify as a StaticSparseSet

    this(this) @disable;

    import std.range : isInputRange , isInfinite, ElementType;
    import std.traits : isImplicitlyConvertible;

    /// Initializes the set using a input range
    this(R)(scope R init)
    if (!isInfinite!R && isInputRange!R && isImplicitlyConvertible!(ElementType!R, T))
    {
        foreach (val ; init) {
            this.insert(val);
        }
    }

    /**
     * Searchs a value on the sparse set
     *
     * Returns: Retuns the position of a value on the dense set, or -1 if the value isn't on the sparse set
     */
    size_t search(T value) const nothrow pure @nogc @safe
    {
        // Searched element must be in range
        if (value > _maxValue) {
            return -1;
        }

        // The first condition verifies that 'x' is within 'n' in this set and the second
        // condition tells us that it is present in the data structure.
        auto denseIndex = this.sparse[value];
        if (denseIndex < this.n && this.dense[denseIndex] == value) {
            return denseIndex;
        }

        return -1;
    }

    /// Inserts a new element into set
    void insert(T value) nothrow pure @nogc @safe
    {
        //  Corner cases, value must not be out of range, dense[] should not be full and value should not already be present
        if (value > _maxValue) {
            return ;
        }
        if (this.n >= _capacity) {
            return ;
        }
        if (this.search(value) != -1) {
            return ;
        }

        // Inserting into array-dense[] at index 'n'.
        this.dense[this.n]  = value;

        // Mapping it to sparse[] array.
        this.sparse[value] = this.n;

        // Increment count of elements in set
        this.n++;
    }

    /// Insert a range of values
    void insert(R)(scope R inputRange) nothrow pure @nogc @safe
    if (!isInfinite!R && isInputRange!R && isImplicitlyConvertible!(ElementType!R, T))
    {
        foreach (value ; inputRange) {
            this.insert(value);
        }
    }

    /**
	 * Removes the given item from the set. Note that changes the order of the elements
	 * Returns: false if the value was not present
	 */
    bool remove(T value) nothrow pure @nogc @safe
    {
        // If x is not present
        auto denseIndex = this.search(value);
        if (denseIndex == -1) {
            return false;
        }
        this.removeByIndex(denseIndex);
        return true;
    }

    /// Removes a set element by his position. Note that changes the order of the elements
    void removeByIndex(size_t denseIndex) nothrow pure @nogc @safe
    {
        if (denseIndex < this.n - 1) {
            const temp = this.dense[this.n-1];  // Take an element from end
            this.sparse[temp] = denseIndex; // Overwrite
            this.dense[denseIndex] = temp;  // Overwrite
        }
        // The last element replaces the "removed" element on the set

        // Since one element has been deleted, we decrement 'n' by 1.
        this.n--;
    }

    /// Cleans the SparseSet
    void clean() nothrow @nogc @safe
    {
        this.n = 0;
    }

    /// Index operator overload
    auto opIndex(size_t i)
    {
        import std.exception : enforce;
        import core.exception : RangeError;
        enforce!RangeError(i < this.n, "Indexing value outside of SparseSet bounds.");
        return this.dense[i];
    }

    /// Slice operator overload
    auto opSlice(this This)() @nogc
    {
        return this.dense[0..this.length];
    }

    /// ditto
    auto opSlice(this This)(size_t a, size_t b) const
    {
        import std.exception : enforce;
        import core.exception : RangeError;
        enforce!RangeError(a > 0, "Range violation.");
        enforce!RangeError(a <= b, "Range violation.");
        enforce!RangeError(b <= this.n, "Range violation. Indexing value outside of SparseSet bounds.");
        return this.dense[a..b];
    }

    /// Returns SparseSet capacity
    size_t capacity() const nothrow pure @nogc @safe
    {
        return _capacity;
    }

    /// Returns SparseSet max value allowed to be stored
    T maxValue () const nothrow pure @nogc @safe
    {
        return _maxValue;
    }

    /// Returns: the number of items in the sparse set
    pragma(inline, true)
    size_t length() const nothrow pure @nogc @safe @property
    {
        return this.n;
    }

    /// ditto
    alias opDollar = length;

    /// Determines if the sparse set is empty
    pragma(inline, true)
    bool empty() const nothrow pure @nogc @safe {
        return this.length == 0;
    }

    string toString() @safe const
    {
        import std.range : iota;
        string str = "SparseSet(";
        foreach( i ; this.n.iota) {
            import std.conv : to;
            str ~= this.dense[i].to!string;
            if (i != this.n - 1) {
                str ~= ", ";
            }
        }
        return str ~ ")";
    }
}

/// Returns true if T is a SparseSet
enum bool isSparseSet(T) =
    __traits(compiles, () {
        static assert(T._SparseSet_);
    });

/// Returns true if T is a StaticSparseSet
enum bool isStaticSparseSet(T) =
    isSparseSet!T &&
    __traits(compiles, () {
        T t;
        static assert(T._StaticSparseSet_);
    });


private import stdx.allocator.mallocator : Mallocator;

/**
 * Templated naive Sparse Set using stdx Allocator arrays
 *
 * Params:
 *  T = Content type. Must a unsigned integer type
 *
 * Usage:     DynamicSparseSet!uint(capacity, maxValue) or DynamicSparseSet!uint(allocator, capacity, maxValue)
 *
 * Based on https://www.geeksforgeeks.org/sparse-set/
 *
 * Total ram usage should be :
 * T.sizeof * (2^maxValue + 2^capacity) ≃ T.sizeof * 2 * 2^n
 *
 * For example, for uint and maxValue=capacity= 2^22 -> 4*2*2^20= 32MiB
 *
 * Performance:
 *
 * | Opration| Big O |
 * | ------- | ---- |
 * | search  | O(1) |
 * | insert  | O(1) |
 * | remove  | O(1) |
 * | clear   | O(1) |
 * | iterate | O(capacity) |
 *
 * TODO Study the posibility of compressing sparse, using a HashSet, for huge big maxValue cases
*/
struct DynamicSparseSet(T = uint, Allocator = Mallocator)
if (__traits(isUnsigned, T))
{
    private size_t[] sparse; // sparse[value] returns a index of dense
    private T[] dense; // Here contains the values
    private size_t n = 0;
    private T _maxValue = 0;
    private size_t _capacity = 0;

    private static enum _SparseSet_ = true; // Flag to help isSparseSet to identify as a SparseSet
    private static enum _DynamicSparseSet_ = true; // Flag to help isSparseSet to identify as a DynamicSparseSet

    private import stdx.allocator.common : stateSize;

    this(this) @disable;

    /// No default constructor, as is necesary to give initial capacity and maxValue
    this() @disable;

    static if (stateSize!Allocator != 0) // Ie, Allocator isn't void or a empty struct/unio ?
    {
        private Allocator allocator;

        /// Creates a SparseSet with a initial capacity and max value
        this(Allocator allocator, size_t _capacity, T _maxValue)
        in
        {
            assert(allocator !is null, "Allocator must not be null");
            assert(maxValue > 0, "Max value must be a positive value");
            assert(capacity > 0, "Capacity must be a positive value");
        }
        do
        {
            this.allocator = allocator;
            this.n = 0;
            this.maxValue(_maxValue);
            this.reserve(nextPower2(_capacity));
        }

        /// Initializes the set using a input range
        this(R)(Allocator allocator, size_t _capacity, T _maxValue, scope R init)
        if (!isInfinite!R && isInputRange!R && isImplicitlyConvertible!(ElementType!R, T))
        {
            this(allocator, _capacity, _maxValue);
            foreach (val ; init) {
                this.insert(val);
            }
        }


    } else {
        private alias allocator = Allocator.instance;

        /// Creates a SparseSet with a initial capacity and max value
        this(size_t _capacity, T _maxValue)
        in
        {
            assert(_maxValue > 0, "Max value must be a positive value");
            assert(_capacity > 0, "Capacity must be a positive value");
        }
        do
        {
            this.n = 0;
            this.maxValue(_maxValue);
            this.reserve(nextPower2(_capacity));
        }

        /// Initializes the set using a input range
        this(R)(size_t _capacity, T _maxValue, scope R init)
        if (!isInfinite!R && isInputRange!R && isImplicitlyConvertible!(ElementType!R, T))
        {
            this(_capacity, _maxValue);
            foreach (val ; init) {
                this.insert(val);
            }
        }
    }

    ~this()
    {
        allocator.deallocate(this.sparse);
        allocator.deallocate(this.dense);
    }

    /// Expands the capacity of the sparse set to the new capcity. Round up's to a power of 2
    void reserve(size_t newCapacity)
    {
        if (this.dense.length >= newCapacity || this._capacity >= newCapacity) {
            return;
        }
        this._capacity = newCapacity;
        if (this.dense.ptr is null) {
            this.dense = cast(typeof(this.dense)) this.allocator.allocate(T.sizeof * this._capacity);
        } else {
            void[] denseVoid = cast(void[]) this.dense;
            allocator.reallocate(denseVoid, T.sizeof * this._capacity);
            this.dense = cast(typeof(this.dense)) denseVoid;
        }
    }

    /**
     * Changes the max value to a new value
     *
     * Params:
     *  newMaxValue = A positive value, bigger that the previous max value
     */
    void maxValue(T newMaxValue)
    {
        if (this.sparse.length >= newMaxValue || this._maxValue >= newMaxValue) {
            return;
        }
        this._maxValue = newMaxValue;
        if (this.sparse.ptr is null) {
            this.sparse = cast(typeof(this.sparse)) this.allocator.allocate(size_t.sizeof * this._maxValue);
        } else {
            void[] sparseVoid = cast(void[]) this.sparse;
            allocator.reallocate(sparseVoid, size_t.sizeof * this._maxValue);
            this.sparse = cast(typeof(this.sparse)) sparseVoid;
        }
    }

    /**
     * Searchs a value on the sparse set
     *
     * Returns: Retuns the position of a value on the dense set, or -1 if the value isn't on the sparse set
     */
    size_t search(T value) const nothrow pure @nogc @safe
    {
        // Searched element must be in range
        if (value > this._maxValue) {
            return -1;
        }

        // The first condition verifies that 'value' is within 'n' in this set and the second
        // condition tells us that it is present in the data structure.
        auto denseIndex = this.sparse[value];
        if (denseIndex < this.n && this.dense[denseIndex] == value) {
            return denseIndex;
        }

        return -1;
    }

    /// Inserts a new element into set
    void insert(T value) nothrow
    {
        //  Corner cases, value must not be out of range, dense[] should not be full and value should not already be present
        if (value > this._maxValue) {
            return ;
        }
        if (this.search(value) != -1) {
            return ;
        }
        // Auto expand dense if we reach the max capacity
        if (this.n >= this._capacity) {
            this.reserve(growCapacity(this._capacity)); // grows by ~1.5 times
        }

        // Inserting into array-dense[] at index 'n'.
        this.dense[this.n]  = value;

        // Mapping it to sparse[] array.
        this.sparse[value] = this.n;

        // Increment count of elements in set
        this.n++;
    }


    import std.range : isInputRange , isInfinite, ElementType;
    import std.traits : isImplicitlyConvertible;

    /// Insert a range of values
    void insert(R)(scope R inputRange) nothrow
    if (!isInfinite!R && isInputRange!R && isImplicitlyConvertible!(ElementType!R, T))
    {
        foreach (value ; inputRange) {
            this.insert(value);
        }
    }

    /**
	 * Removes the given item from the set. Note that changes the order of the elements
	 * Returns: false if the value was not present
	 */
    bool remove(T value) nothrow pure @nogc @safe
    {
        // If x is not present
        auto denseIndex = this.search(value);
        if (denseIndex == -1) {
            return false;
        }
        this.removeByIndex(denseIndex);
        return true;
    }

    /// Removes a set element by his position. Note that changes the order of the elements
    void removeByIndex(size_t index) nothrow pure @nogc @safe
    {
        if (index < this.n - 1) {
            T temp = this.dense[this.n-1];  // Take an element from end
            this.dense[index] = temp;  // Overwrite.
            this.sparse[temp] = index; // Overwrite.
        }

        // Since one element has been deleted, we decrement 'n' by 1.
        this.n--;
    }

    /// Cleans the SparseSet
    void clean() nothrow @nogc @safe
    {
        this.n = 0;
    }

    /// Index operator overload
    auto opIndex(size_t i) const
    {
        import std.exception : enforce;
        import core.exception : RangeError;
        enforce!RangeError(i < this.n, "Indexing value outside of SparseSet bounds.");
        return this.dense[i];
    }

    /// Slice operator overload
    auto opSlice(this This)() const @nogc
    {
        return this.dense[0..this.length];
    }

    /// ditto
    auto opSlice(this This)(size_t a, size_t b) const
    {
        import std.exception : enforce;
        import core.exception : RangeError;
        enforce!RangeError(a > 0, "Range violation.");
        enforce!RangeError(a <= b, "Range violation.");
        enforce!RangeError(b <= this.n, "Range violation. Indexing value outside of SparseSet bounds.");
        return this.dense[a..b];
    }

    /// Returns SparseSet capacity
    size_t capacity() const nothrow pure @nogc @safe
    {
        return this._capacity;
    }

    /// Returns SparseSet max value allowed to be stored
    T maxValue () const nothrow pure @nogc @safe
    {
        return this._maxValue;
    }

    /// Returns: the number of items in the sparse set
    pragma(inline, true)
    size_t length() const nothrow pure @nogc @safe @property
    {
        return this.n;
    }

    /// ditto
    alias opDollar = length;

    /// Determines if the sparse set is empty
    pragma(inline, true)
    bool empty() const nothrow pure @nogc @safe {
        return this.length == 0;
    }

    string toString() @safe const
    {
        import std.range : iota;
        string str = "SparseSet(";
        foreach( i ; this.n.iota) {
            import std.conv : to;
            str ~= this.dense[i].to!string;
            if (i != this.n - 1) {
                str ~= ", ";
            }
        }
        return str ~ ")";
    }
}

/// Returns true if T is a DynamicSparseSet
enum bool isDynamicSparseSet(T) =
    isSparseSet!T &&
    __traits(compiles, () {
        static assert(T._DynamicSparseSet_);
    });


/// Creates a new SparseSet that is a intersection of this set and another set
auto intersection(T)(scope const ref T lhs, scope const ref T rhs) @nogc
if (isSparseSet!T && !isDynamicSparseSet!T)
{
    // Create result set
    auto result = T();

    if (lhs.n < rhs.n) {
        // If this set is smaller, search every element of this set in 's'. If found, add it to result
        foreach (value ; lhs[]) {
            if (rhs.search(value)) {
                result.insert(value);
            }
        }
    } else {
        foreach (value ; rhs[]) {
            // Search every element of 's' in this set. If found, add it to result
            if (lhs.search(value)) {
                result.insert(value);
            }
        }
    }
    return result;
}

/**
 * Creates a new SparseSet that is the union of this set with another set
 *
 *  Time Complexity O(n1+n2)
 */
auto setUnion(T)(scope const ref T lhs, scope const ref T rhs) @nogc
if (isSparseSet!T && !isDynamicSparseSet!T)
{
    // Create result set that contains all the values of this set
    auto result = T(lhs[]);

    // And now, we add the values of the other set
    foreach (value ; rhs[]) {
        result.insert(value);
    }
    return result;
}

