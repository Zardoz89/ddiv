/**
Implementation of a Map using a Sparse Set
*/
module ddiv.container.sparsemap;

import ddiv.container.common;

import std.array : insertInPlace;
import std.range : assumeSorted;

/// SparseMap sorting policy
enum SparseSortPolicy {
    None, /// SparseMap unserted
    ByKey, /// SparseMap ordered by Key
    ByValue /// SparseMap ordered by Value
}

/**
 * Templated naive Sparse Set using static arrays
 *
 * Params:
 *  Value = Stored value type
 *  capacity = Max number of elements to be stored
 *  Key = Key type. Must a unsigned integer type. By default is uint
 *  maxKey = Bigger numbert allow to be stored . By default is the same value that capacity
 *
 * Usage:     StaticSparseMap!(Value, capacity)()
 *
 * Based on https://www.geeksforgeeks.org/sparse-set/
 *
 * Total ram usage should be :
 * if Value is a Class or a ptr (T.sizeof + ptr.sizeof ) * 2^capacity + size_t.sizeof * 2^maxKey 
 * else (T.sizeof + Value.sizeof ) * 2^capacity + size_t.sizeof * 2^maxKey 
 *
 * Performance:
 *
 * | Opration| Big O |
 * | ------- | ----- |
 * | search  | O(1)  |
 * | insert  | O(1)  |
 * | remove  | O(1)  |
 * | clear   | O(1)  |
 * | iterate | O(n)  |
*/
struct SparseMap(Value, Key = uint, SparseSortPolicy _sparseSortPolicy = SparseSortPolicy.None,
    alias predicate = "a < b")
if (__traits(isUnsigned, Key))
{
    private size_t[] sparse; // sparse[val] returns a index of dense
    private Key[] dense; // Contains the Keys
    private Value[] storage; // Contains the Value
    private Key _maxKey = 0;

    /// No postblit operator. It's a container, and MUST NOT be copied
    this(this) @disable;
    
    /// No default constructor, as is necesary to give initial capacity and maxValue
    this() @disable;

    /// Creates a SparseSet with a initial capacity and max value
    this(size_t _capacity, Key _maxKey = Key.max)
    in
    {
        assert(_maxKey > 0, "Max value must be a positive value");
        assert(_capacity > 0, "Capacity must be a positive value");
    }
    do
    {
        this.maxKey(_maxKey);
        this.reserve(nextPower2(_capacity));
    }
    
    ~this() @trusted
    {
        this.dense.length = 0;
        this.storage.length = 0;
        this.sparse.length = 0;
    }

    debug {
        /// debug print internal state
        void debugPrint(string prefix = "") @trusted
        {
            import std.stdio : writeln, stderr;
            try {
                stderr.writeln(prefix ~ "maxKey: ", this._maxKey);
                stderr.writeln(prefix ~ "sparse : ", this.sparse);
                stderr.writeln(prefix ~ "dense : ", this.dense);
                stderr.writeln(prefix ~ "storage : ", this.storage);
            } catch (Exception ex) {}
        }
    }

    /// Expands the capacity of the sparse set to the new capcity. Round up's to a power of 2
    void reserve(size_t newCapacity) @trusted
    {
        if (this.dense.capacity >= newCapacity) {
            return;
        }

        this.dense.reserve(newCapacity);
        this.storage.reserve(newCapacity);
    }

    /**
     * Changes the max value to a new value
     *
     * Params:
     *  newMaxKey = A positive value, bigger that the previous max key
     */
    void maxKey(Key newMaxKey) @trusted
    out
    {
        assert(this.sparse.length == this._maxKey, "Invalid sparse lenght");
    }
    do
    {
        if (this.sparse.length >= newMaxKey || this._maxKey >= newMaxKey) {
            return;
        }

        /*
        import std.range : repeat;
        import std.array : array;
        size_t oldLength = this.sparse.length;
        this.sparse ~= (-1).repeat!size_t(newMaxKey - oldLength).array;
        */
        this.sparse.length = newMaxKey;
        this._maxKey = newMaxKey;
    }

    /**
     * Returns: Retuns the position of a key, or -1 if the value isn't on the sparse set
     */
    size_t search(const Key key) const nothrow pure @nogc @safe
    {
        // Searched element must be in range
        if (key > _maxKey) {
            return -1;
        }

        // The first condition verifies that 'x' is within 'n' in this set and the second
        // condition tells us that it is present in the data structure.
        auto denseIndex = this.sparse[key];
        if (denseIndex < this.length && this.dense[denseIndex] == key) {
            return denseIndex;
        }

        return -1;
    }

    /// Supports `auto val = aa[key]` syntax
    auto ref Value opIndex(this This)(const Key key)
    {
        size_t index = this.search(key);
        if (index != -1) {
            return this.storage[index];
        }
        import std.traits : isPointer;
        static if ( is(Value : Object) || isPointer!(Value)) {
            return null;
        } else {
            return Value.init;
        }
    }

    /// Inserts a new element into set
    bool insert(Value)(const Key key, auto ref Value value) @safe
    {
        //  Corner cases, value must not be out of range, dense[] should not be full and value should not already be present
        if (key > this._maxKey) {
            return false;
        }
        if (this.search(key) != -1) {
            return false;
        }
        // Auto expand if we reach the max capacity
        if (this.length >= this.capacity) {
            this.reserve(growCapacity(this.capacity)); // grows by ~1.5 times
        }

        static if (_sparseSortPolicy == SparseSortPolicy.None) {
            // Inserting into array-dense[] at index 'n'. Ie, puts at the end of the array
            this.dense ~= key;
            this.storage ~= value;

            // Mapping it to sparse[] array.
            this.sparse[key] = this.dense.length - 1;
        } else static if (_sparseSortPolicy == SparseSortPolicy.ByKey) {

            if (this.length == 0) {
                this.dense ~= key;
                this.storage ~= value;
                
                // Mapping it to sparse[] array.
                this.sparse[key] = 0;
            } else {
                // Assume that dense is already sorted according to PREDICATE
                auto sortedDense = assumeSorted!(predicate)(this.dense[]);

                // Find a slice containing records with priorities less than the insertion rec
                auto lowerBound = sortedDense.lowerBound(key);
                const denseIndex = lowerBound.length;

                // Insert the record
                this.dense.insertInPlace(denseIndex, key);
                this.storage.insertInPlace(denseIndex, value);
                this.updateSparsePositions(denseIndex);
                
                // Mapping it to sparse[] array.
                this.sparse[key] = denseIndex;
            }
        } else { // if ByValue

            if (this.length == 0) {
                this.dense ~= key;
                this.storage ~= value;
                
                // Mapping it to sparse[] array.
                this.sparse[key] = 0;
            } else {
                // Assume that dense is already sorted according to PREDICATE
                auto sortedStorage = assumeSorted!(predicate)(this.storage[]);

                // Find a slice containing records with priorities less than the insertion rec
                auto lowerBound = sortedStorage.lowerBound(value);
                const denseIndex = lowerBound.length;

                // Insert the record
                this.dense.insertInPlace(denseIndex, key);
                this.storage.insertInPlace(denseIndex, value);
                this.updateSparsePositions(denseIndex);
                
                // Mapping it to sparse[] array.
                this.sparse[key] = denseIndex;
            }
        }
        return true;
    }

    /// Upated sparse pointers to the displaced dense values
    private void updateSparsePositions(string op = "++")(size_t denseIndex)
    {
        for (size_t p = 0; p < this.sparse.length ; p++)
        {
            if (this.sparse[p] >= denseIndex) {
                static if (op == "++") {
                    this.sparse[p]++;
                } else {
                    this.sparse[p]--;
                }
            }
        }
    }
    
    /// Supports `aa[key] = value;` syntax.
    void opIndexAssign(Value)(auto ref Value value, const Key key)
    {
        this.insert(key, value);
    }

    /**
	 * Removes the given item from the set. 
     * Note that changes the order of the elements if SparseSortPolicy is None.
     * 
	 * Returns: false if the value was not present
	 */
    bool remove(const Key key) nothrow pure @safe
    {
        if (this.length == 0) {
            return false;
        }

        // If x is not present
        auto denseIndex = this.search(key);
        if (denseIndex == -1) {
            return false;
        }

        static if (_sparseSortPolicy == SparseSortPolicy.None) {
            if (denseIndex < this.length - 1) { // If isn't the last element
                const temp = this.dense[$-1];  // Take an element from end
                this.sparse[temp] = denseIndex; // Overwrite
                this.dense[denseIndex] = temp;  // Overwrite

                this.storage[denseIndex] = this.storage[$-1]; // We move the reference of the last element to the deleted value
                import std.traits : isPointer;
                static if ( is(Value : Object) || isPointer!(Value)) {
                    this.storage[$-1] = null;
                }
            }
            // We remove the last element that has been moved
            this.dense.length--;
            this.storage.length--;

        } else {
            //this.sparse[this.dense[denseIndex]] = -1; // mark as invalid
            this.dense = this.dense[0..denseIndex] ~ this.dense[denseIndex+1..$];
            this.storage = this.storage[0..denseIndex] ~ this.storage[denseIndex+1..$];

            this.updateSparsePositions!("--")(denseIndex);
        } 

        return true;
    }

    /**
	 * Supports $(B key in aa) syntax.
	 *
	 * Returns: pointer to the value corresponding to the given key,
	 * or null if the key is not present in the HashMap.
	 */
	inout(Value)* opBinaryRight(string op)(const Key key) inout nothrow @trusted
        if (op == "in")
	{
        auto denseIndex = this.search(key);
        if (denseIndex == -1) {
            return null;
        }
        return &(cast(inout) this.storage[denseIndex]);
	}

    /**
	 * Returns: a GC-allocated array filled with the keys contained in this map.
	 */
	auto keys(this This)() const
	{
		return this.dense[0..this.length].idup;
	}

    /**
	 * Returns: a GC-allocated array containing the values contained in this map.
	 */
	auto ref values(this This)()
    {
		return this.storage[0..this.length];
    }

    /// Cleans the SparseSet
    void clean() nothrow @safe
    {
        this.dense.length = 0;
        this.storage.length = 0;
    }

    /// Returns SparseMap capacity
    size_t capacity() const nothrow pure @safe
    {
        return this.dense.capacity;
    }

    /// Returns SparseMap max key allowed to be stored
    Key maxKey () const nothrow pure @nogc @safe
    {
        return this._maxKey;
    }

    /// Returns: the number of items in the sparse map
    pragma(inline, true)
    size_t length() const nothrow pure @nogc @safe @property
    {
        return this.dense.length;
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
        import std.conv : to;
        import std.range : iota;
        string str = "SparseMap!(" ~ Value.stringof ~ ", " ~ Key.stringof ~ ")";
        
        str ~= "(";
        foreach( i ; this.dense.length.iota) {
            str ~= this.dense[i].to!string;
            static if(!is(Value == void)) {
                str ~= " : " ~ this.storage[i].to!string;
            }
            if (i != this.length - 1) {
                str ~= ", ";
            }
        }
        return str ~ ")";
    }
}
