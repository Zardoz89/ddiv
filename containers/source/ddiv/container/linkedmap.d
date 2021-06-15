module ddiv.container.linkedmap;

import ddiv.container.common;
import ikod.containers.hashmap;

/// SparseMap sorting policy
enum SortPolicy {
    ByInsertionOrder, /// ordered by insertion order
    ByKey, /// Map ordered by Key
    ByValue /// Map ordered by Value
}

/**
 * Dicctionary that can return sorted ranges
 */
struct LinkedMap(Key, Value, SortPolicy sortPolicy = SortPolicy.ByInsertionOrder, alias predicate = "a < b") {
    private alias Map = HashMap!(Key, Value);
    private alias List = Key[];

    private Map map;
    private List list;

    /// No postblit operator. It's a container, and MUST NOT be copied
    this(this) @disable;

    ~this() @trusted nothrow {
        this.clear();
    }

    /**
	 * Removes all items from the map
	 */
    void clear() {
        this.map.clear;
        this.list.length = 0;
    }

    /**
	 * Supports `aa[key]` syntax.
	 */
    auto ref Value opIndex(this This)(const Key key) {
        return this.map[key];
    }

    /**
	 * Supports $(B aa[key] = value;) syntax.
	 */
    void opIndexAssign(Value value, const Key key)
    out {
        assert(this.map.length == this.list.length);
    }
    do {
        if (this.map.contains(key)) {
            import std.algorithm : remove;

            this.list.remove!((k) { return k == key; });
        }

        import std.array : insertInPlace;
        import std.range : assumeSorted;

        static if (sortPolicy == SortPolicy.ByKey) {
            if (this.list.length == 0) {
                this.list ~= key;
            } else {
                // Assume the queue is already sorted according to PREDICATE
                auto sortedKeys = assumeSorted!(predicate)(this.list);

                // Find a slice containing records with keys less that the inserted key
                const location = sortedKeys.lowerBound(key).length;

                // Insert the record
                this.list.insertInPlace(location, key);
            }

        } else static if (sortPolicy == SortPolicy.ByValue) {
            auto sortedValues = this.list
                .map!(k => this.map[k])
                .assumeSorted!(predicate);
            // Find a slice containing records with priorities less than the insertion rec
            const location = sortedValues.lowerBound(value).length;

            // Insert the record
            this.list.insertInPlace(location, key);
        } else {
            this.list ~= key;
        }
        this.map.getOrAdd(key, value);
    }

    /**
	 * Gets the value for the given key, or returns `defaultValue` if the given
	 * key is not present.
	 *
	 * Params:
	 *     key = the key to look up
	 *     value = the default value
	 * Returns: the value indexed by `key`, if present, or `defaultValue` otherwise.
	 */
    auto get(Key key, lazy Value defaultValue) {
        return this.map.get(key, defaultValue);
    }

    bool contains(K)(K k)
    {
        return this.map.contains(k);
    }

    /**
	 * Supports $(B key in aa) syntax.
	 *
	 * Returns: pointer to the value corresponding to the given key,
	 * or null if the key is not present in the HashMap.
	 */
    deprecated("very unsafe")
    const(Value)* opBinaryRight(string op)(const Key key) inout nothrow @trusted
    if (op == "in") {
        return key in this.map;
    }

    /**
	 * Removes the value associated with the given key
	 * Returns: true if a value was actually removed.
	 */
    bool remove(Key key) {
        const removed = this.map.remove(key);
        if (removed) {
            import std.algorithm : remove;

            this.list.remove!((k) { return k == key; });
        }
        return true;
    }

    /// Returns Map length
    size_t length() const nothrow pure @nogc @safe {
        return this.map.length;
    }

    /// Returns true if length == 0
    bool empty() const nothrow pure @nogc @safe {
        return this.length == 0;
    }

    /**
	 * Returns: a GC-allocated array filled with the keys contained in this map.
	 */
    immutable(Key)[] keys() const @trusted
    out (result) {
        assert(result.length == this.length);
    }
    do {
        return this.list.idup;
    }

    /// Returns: a input range filled with the keys contained in this map. If SortPolicy is ByKey, then returns a SortedRange
    auto byKeys() const @trusted {
        static if (sortPolicy == SortPolicy.ByKey) {
            import std.range : assumeSorted;

            return assumeSorted!(predicate)(this.list.idup);
        } else {
            return this.list.idup;
        }
    }

    /**
	 * Returns: a GC-allocated array containing the values contained in this map
	 */
    auto values() const @trusted
    out (result) {
        assert(result.length == this.length);
    }
    do {
        import std.array : array;

        return this.byValue.array;
    }

    /// Returns: a input range containing the values contained in this map. If SortPolicy is ByValue, then returns a SortedRange
    auto byValue() const @trusted {
        import std.algorithm : map;

        static if (sortPolicy == SortPolicy.ByValue) {
            import std.range : assumeSorted;

            return assumeSorted!(predicate)(this.list.map!(k => this.map[k]));
        } else {
            return this.list.map!(k => this.map[k]);
        }
    }

    /**
	 * Returns: a GC-allocated array of the kev/value pairs in this map.
	 * The element type of this array is a Voldemort struct with `key` and `value` fields.
	 */
    auto keyAndValues() const @trusted {
        import std.array : array;

        return this.byKeyValue.array;
    }

    /**
	 * Returns: a input forward range of the key/values pairs in this map.
	 * The element type of this range is a Voldemort struct with `key` and `value` fields.
	 */
    auto byKeyValue() const @trusted {
        import std.array : array;
        import std.algorithm : map;

        struct MapPair {
            immutable(Key) key;
            const Value value;
        }

        return this.list.map!(k => MapPair(k, this.map[k]));
    }

    string toString() @trusted const {
        import std.conv : to;
        import std.range : iota;

        auto str = "LinkedMap!(" ~ Key.stringof ~ ", " ~ Value.stringof ~ ")(";
        size_t i;
        foreach (pair; this.byKeyValue) { //this.keyAndValues()) {
            str ~= pair.key.to!string ~ " : " ~ pair.value.to!string;
            if (i < this.length - 1) {
                str ~= ", ";
            }
            i++;
        }

        return str ~ ")";
    }

    /+
	private enum RangeType
	{
		Key,
		Value,
		KeyAndValue
	}

	private struct MapRange(RangeType rangeType, RangeKey, RangeValue)
	{
		RangeKey keys;
		/*
		static if (rangeType == RangeType.Key || y == RangeType.KeyAndValue) {

		}
        */

		this(RangeKey keys)
		{
			this.keys = keys;
		}

		bool empty() const @safe nothrow @nogc
		{
			return this.keys.emp
		}
	}
	+/
}
