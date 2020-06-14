module tests.ddiv.container.sparsemap_spec;

import pijamas;

import ddiv.container.sparsemap;

/// Helper class
class C
{
    int x, y;

    this(int x, int y) @safe
    {
        this.x = x;
        this.y = y;
    }

    override bool opEquals(Object o) const @safe {
        if (C rhs = cast(C)o) {
            return this.x == rhs.x && this.y == rhs.y;
        }
        return false;
    }

    override string toString() const @trusted
    {
        import std.conv : to;
        return "C(" ~ this.x.to!string ~ ", " ~ this.y.to!string ~ ")";
    }
}

/// Helper struct
struct S
{
    int x, y;
    
    bool opEquals(const S rhs) const @safe {
        return this.x == rhs.x && this.y == rhs.y;
    }
    bool opEquals(ref const S rhs) const @safe {
        return this.x == rhs.x && this.y == rhs.y;
    }

    string toString() const @trusted
    {
        import std.conv : to;
        return "S(" ~ this.x.to!string ~ ", " ~ this.y.to!string ~ ")";
    }
}

@("SparseMap Unsorted")
@safe unittest {

    // describe("Capacity, masKey and reserve"),
    {
        // given("A type T that is a valid SparseMap")
        alias RefMap = SparseMap!(C);
        alias ValMap = SparseMap!(S);

        // expect("the expect capacity and max value must be the intial")
        auto refMap = RefMap(16, 16);
        refMap.capacity.should.be.biggerOrEqualThan(16);
        refMap.maxKey.should.be.equal(16);
        
        auto valMap = ValMap(16, 16);
        valMap.capacity.should.be.biggerOrEqualThan(16);
        valMap.maxKey.should.be.equal(16);

        // when("If we call reserve")
        refMap.reserve(32);
        valMap.reserve(32);

        // then("the capacity is expanded")
        refMap.capacity.should.be.biggerOrEqualThan(32);
        valMap.capacity.should.be.biggerOrEqualThan(32);
    }

    // For the rest of tests, we make a alias to type less
    alias RefMap = SparseMap!(C);
    alias ValMap = SparseMap!(S);

    // describe("Using the default constructor, gives a empty map"),
    {
        // given("A instance of map")
        auto map = RefMap(16, 16);

        // expect("that is empty")
        map.empty.should.be.True;

        // and("toString only returns the object name")
        map.toString.should.be.equal( "SparseMap!(C, uint)()");
    }

    // describe("Inserting and searching unsigned integers"),
    {
        // given("A instance of map")
        auto map = RefMap(16, 16);

        // when("We insert some pairs of key, value")
        map.insert(10, new C(0, 0)).should.be.True;
        map[3] = new C(1, 2);
        map[0] = new C(123, 666);

        // then("It must not be empty")
        map.empty.should.be.False;
        map.length.should.be.equal(3);

        // and("when we search by key, returns it's position")
        map.search(10).should.be.equal(0);
        map.search(3).should.be.equal(1);
        map.search(0).should.be.equal(2);

        // and("when we search a not existing key, returns -1")
        map.search( 13).should.be.equal( -1); // Searching a not existing value

        // and("retriving a value by key, returns the value")
        map[10].should.be.equal(new C(0, 0));
        map[3].should.be.equal(new C(1, 2)); 
        map[0].should.be.equal(new C(123, 666));

        // and("retriving a no existent entry, returns null")
        map[13].should.not.exist;

        // and("when we try to use the \"in\" operator ")
        auto ptr = 3 in map;
        ptr.should.be.exist;
        ptr.x.should.be.equal(1);

        // and("using \"in\" operator a no existent entry, returns null")
        ptr = 13 in map;
        ptr.should.not.exist;

        // and("toString returns the object name and the values list")
        map.toString.should.be.equal( "SparseMap!(C, uint)(10 : C(0, 0), 3 : C(1, 2), 0 : C(123, 666))");
    }
    
    // describe("Inserting and searching a value over the max kay"),
    {
        // given("An instance of map")
        auto map = RefMap(16, 16);

        // when("We insert a value over max key")
        auto value = map.maxKey + 1;
        map.insert(value, new C(0, 0)).should.be.False;

        // then("the value musnt' be inserted")
        map.search(value).should.be.equal(-1); // Not found becasue isn't inserted
        map[value].should.not.exist;
        map.empty.should.be.True;
    }

    // describe("Removing an entry"),
    {
        // given("An instance of map")
        auto map = RefMap(16, 16);
        map[3] = new C(10, 20);
        map[5] = new C(12, 22);
        map[1] = new C(100,50);
        map[0] = new C(0,5);
        map.length.should.be.equal(4);

        // when("we remove an entry")
        map.remove(1).should.be.True;

        // then("the removed value disapers from the map")
        map.length.should.be.equal(3);
        map.search(1).should.be.equal(-1);

        // expect("when try to remove a not existent value, must return false")
        map.remove(13).should.be.False;
        map.length.should.be.equal(3);

        // when("we try to remove the last element")
        map.remove(0).should.be.True;

        // then("the removed value disapers from the map")
        map.length.should.be.equal(2);
        map.search(0).should.be.equal(-1);

        /+
        // FIX Seg fault when insert a value after removing values
        // when("we insert a new value")
        map[13] = new C(123, 123);

        // then()
        map.length.should.be.equal(3);
        map.search(13).should.not.be.equal(-1);
        +/
    }

    // describe("Inserting a entry with the same key of a previusly existing entry of the map")
    /+
    // TODO Check the seg fault
    {
        // given("An instance of map")
        auto map = RefMap(16, 16);
        map[3] = new C(10, 20);
        map[5] = new C(12, 22);
        map[1] = new C(100,50);
        map[0] = new C(0,5);
        map.length.should.be.equal(4);

        // when("we try to insert over an existing key")
        map.insert(3, new C(666, 666)).should.be.False;

        // then("it leep the map intact")
        map.length.should.be.equal(4);
        map[3].should.be.equal(new C(10, 20));
        // when("we try to replace it")
        map.insertOrReplace(3, new C(666, 666));
        
        // then("the entry it's replaced")
        map.length.should.be.equal(4);
        map[3].should.be.equal(new C(666, 666));
    }
    +/

    // describe("Obtaining the keys and values of this map, with a reference Value")
    {
        // given("A instance of map intialized with some values")
        auto map = RefMap(16, 16);
        map[10] = new C(0, 1);
        map[3] = new C(1, 2);
        map[0] = new C(123, 666);

        // expect("we get an array of the keys of the map")
        auto keys = map.keys;
        keys.should.be.equal([10, 3, 0]);

        // expect("we get an array of the values of the map")
        auto values = map.values();
        values.should.be.equal([new C(0, 1), new C(1, 2), new C(123, 666)]);

        // and("If try to modify a value, then it must be changed on the containter")
        values[0].x = 33;
        map[10].should.be.equal(new C(33, 1));
    }

    // describe("Obtaining the keys and values of this map, with not reference Value")
    {
        // given("A instance of map")
        auto map = ValMap(16, 16);
        map[10] = S(0, 1);
        map[3] = S(1, 2);
        map[0] = S(123, 666);

        // expect("we get an array of the keys of the map")
        auto keys = map.keys;
        keys.should.be.equal([10, 3, 0]);

        // expect("we get an array of the values of the map")
        auto values = map.values();
        values.should.be.equal([S(0, 1), S(1, 2), S(123, 666)]);
        
        // and("If try to modify a value, then it must be changed on the containter")
        values[0].x = 33;
        map[10].should.be.equal(S(33, 1));
    }
    
}

@("SparseMap Sorted ByKey")
@safe unittest {

    // describe("Capacity, masKey and reserve"),
    {
        // given("A type T that is a valid SparseMap")
        alias RefMap = SparseMap!(C, uint, SparseSortPolicy.ByKey);
        alias ValMap = SparseMap!(S, uint, SparseSortPolicy.ByKey);

        // expect("the expect capacity and max value is the incated by the type")
        auto refMap = RefMap(16, 16);
        refMap.capacity.should.be.biggerOrEqualThan(16);
        refMap.maxKey.should.be.equal(16);
        
        auto valMap = ValMap(16, 16);
        valMap.capacity.should.be.biggerOrEqualThan(16);
        valMap.maxKey.should.be.equal(16);
        
        // when("If we call reserve")
        refMap.reserve(32);
        valMap.reserve(32);

        // then("the capacity is expanded")
        refMap.capacity.should.be.biggerOrEqualThan(32);
        valMap.capacity.should.be.biggerOrEqualThan(32);
    }
    
    // For the rest of tests, we make a alias to type less
    alias RefMap = SparseMap!(C, uint, SparseSortPolicy.ByKey);
    alias ValMap = SparseMap!(S, uint, SparseSortPolicy.ByKey);

    // describe("Using the default constructor, gives a empty map"),
    {
        // given("A instance of map")
        auto map = RefMap(16, 16);

        // expect("that is empty")
        map.empty.should.be.True;

        // and("toString only returns the object name")
        map.toString.should.be.equal( "SparseMap!(C, uint)()");
    }

    // describe("Inserting and searching unsigned integers"),
    {
        // given("A instance of map")
        auto map = RefMap(16, 16);

        // when("We insert some pairs of key, value")
        map.insert(10, new C(0, 0));
        map[3] = new C(1, 2);
        map[0] = new C(123, 666);

        // then("It must not be empty")
        map.empty.should.be.False;
        map.length.should.be.equal(3);

        // and("when we search by key, returns it's position")
        map.search(10).should.be.equal(2);
        map.search(3).should.be.equal(1);
        map.search(0).should.be.equal(0);

        // and("when we search a not existing key, returns -1")
        map.search( 13).should.be.equal( -1); // Searching a not existing value

        // and("retriving a value by key, returns the value")
        map[10].should.be.equal(new C(0, 0));
        map[3].should.be.equal(new C(1, 2)); 
        map[0].should.be.equal(new C(123, 666));

        // and("retriving a no existent entry, returns null")
        map[13].should.not.exist;

        // and("when we try to use the \"in\" operator ")
        auto ptr = 3 in map;
        ptr.should.be.exist;
        ptr.x.should.be.equal(1);

        // and("using \"in\" operator a no existent entry, returns null")
        ptr = 13 in map;
        ptr.should.not.exist;

        // and("toString returns the object name and the values list")
        map.toString.should.be.equal( "SparseMap!(C, uint)(0 : C(123, 666), 3 : C(1, 2), 10 : C(0, 0))");
    }
    
    // describe("Inserting and searching a value over the max kay"),
    {
        // given("A instance of map")
        auto map = RefMap(16, 16);

        // when("We insert a value over max key")
        auto value = map.maxKey + 1;
        map.insert(value, new C(0, 0)).should.be.False;

        // then("the value musnt' be inserted")
        map.search(value).should.be.equal(-1); // Not found becasue isn't inserted
        map[value].should.not.exist;
        map.empty.should.be.True;
    }

    // describe("Removing an entry"),
    {
        // given("An instance of map")
        auto map = RefMap(16, 16);
        map[3] = new C(10, 20);
        map[5] = new C(12, 22);
        map[1] = new C(100,50);
        map[0] = new C(0,5);
        map.length.should.be.equal(4);
        map.search(1).should.be.equal(1);

        // when("we remove an entry")
        map.remove(1).should.be.True;

        // then("the removed valued disapers from the map")
        map.length.should.be.equal(3);
        map.search(1).should.be.equal(-1);

        // expect("when try to remove a not existent value, must return false")
        map.remove(13).should.be.False;
        map.length.should.be.equal(3);
    }

    // describe("Obtaining the keys and values of this map, with a reference Value")
    {
        // given("An instance of map")
        auto map = RefMap(16, 16);
        map[3] = new C(1, 2);
        map[10] = new C(0, 0);
        map[0] = new C(123, 666);
        map[1] = new C(100,50);

        // expect("we get an array of the keys of the map sorted")
        map.keys.should.be.equal([0, 1, 3, 10]);
        map.keys.should.be.sorted;

        // expect("we get an array of the values of the map, sorted by keys")
        auto values = map.values();
        values.should.be.equal([new C(123, 666), new C(100, 50), new C(1, 2), new C(0, 0)]);
        values[0].x = 33;
        map[0].should.be.equal(new C(33, 666));

        // when("we remove an element")
        map.remove(3);

        // then("the key and values order is preserved")
        map.keys.should.be.equal([0, 1, 10]);
        map.keys.should.be.sorted;
        map.values().should.be.equal([new C(33, 666), new C(100, 50), new C(0, 0)]);
    }

    // describe("Obtaining the keys and values of this map, with not reference Value")
    {
        // given("A instance of map")
        auto map = ValMap(16, 16);
        map[0] = S(123, 666);
        map[10] = S(0, 0);
        map[3] = S(1, 2);

        // expect("we get an array of the keys of the map sorted")
        auto keys = map.keys;
        keys.should.be.equal([0, 3, 10]);
        keys.should.be.sorted;

        // expect("we get an array of the values of the map, sorted by keys")
        auto values = map.values();
        values.should.be.equal([S(123, 666), S(1, 2), S(0, 0)]);
        
        // and("If try to modify a value, then it must be changed on the containter")
        values[0].x = 33;
        map[10].should.be.equal(S(0, 0));
    }
    
}

@("SparseMap Sorted ByValue")
@safe unittest {

    // describe("Capacity, masKey and reserve"),
    {
        // given("A type T that is a valid SparseMap")
        alias RefMap = SparseMap!(C, uint, SparseSortPolicy.ByValue, "a.x < b.x");
        alias ValMap = SparseMap!(S, uint, SparseSortPolicy.ByValue, "a.x < b.x");

        // expect("the expect capacity and max value is the incated by the type")
        auto refMap = RefMap(16, 16);
        refMap.capacity.should.be.biggerOrEqualThan(16);
        refMap.maxKey.should.be.equal(16);
        
        auto valMap = ValMap(16, 16);
        valMap.capacity.should.be.biggerOrEqualThan(16);
        valMap.maxKey.should.be.equal(16);
        
        // when("If we call reserve")
        refMap.reserve(32);
        valMap.reserve(32);

        // then("the capacity is expanded")
        refMap.capacity.should.be.biggerOrEqualThan(32);
        valMap.capacity.should.be.biggerOrEqualThan(32);
    }
    
    // For the rest of tests, we make a alias to type less
    alias RefMap = SparseMap!(C, uint, SparseSortPolicy.ByValue, "a.x < b.x");
    alias ValMap = SparseMap!(S, uint, SparseSortPolicy.ByValue, "a.x < b.x");

    // describe("Using the constructor, gives a empty map"),
    {
        // given("A instance of map")
        auto map = RefMap(16, 16);

        // expect("that is empty")
        map.empty.should.be.True;

        // and("toString only returns the object name")
        map.toString.should.be.equal( "SparseMap!(C, uint)()");
    }

    // describe("Inserting and searching unsigned integers"),
    {
        // given("An instance of map")
        auto map = RefMap(16, 16);

        // when("We insert some pairs of key, value")
        map[0] = new C(1, 2);
        map.insert(10, new C(0, 0)).should.be.True;
        map[3] = new C(123, 666);

        // then("It must not be empty")
        map.empty.should.be.False;
        map.length.should.be.equal(3);

        // and("when we search by key, returns it's position")
        map.search(10).should.be.equal(0); // C.x = 0
        map.search(0).should.be.equal(1);  // C.x = 1
        map.search(3).should.be.equal(2);  // C.x = 123

        // and("when we search a not existing key, returns -1")
        map.search( 13).should.be.equal( -1); // Searching a not existing value

        // and("retriving a value by key, returns the value")
        map[10].should.be.equal(new C(0, 0));
        map[0].should.be.equal(new C(1, 2)); 
        map[3].should.be.equal(new C(123, 666));

        // and("retriving a no existent entry, returns null")
        map[13].should.not.exist;

        // and("when we try to use the \"in\" operator ")
        auto ptr = 3 in map;
        ptr.should.be.exist;
        ptr.x.should.be.equal(123);

        // and("using \"in\" operator a no existent entry, returns null")
        ptr = 13 in map;
        ptr.should.not.exist;

        // and("toString returns the object name and the values list")
        map.toString.should.be.equal( "SparseMap!(C, uint)(10 : C(0, 0), 0 : C(1, 2), 3 : C(123, 666))");
    }
    
    // describe("Inserting and searching a value over the max kay"),
    {
        // given("An instance of map")
        auto map = RefMap(16, 16);

        // when("We insert a value over max key")
        auto value = map.maxKey + 1;
        map.insert(value, new C(0, 0)).should.be.False;

        // then("the value musnt' be inserted")
        map.search(value).should.be.equal(-1); // Not found becasue isn't inserted
        map[value].should.not.exist;
        map.empty.should.be.True;
    }

    // describe("Removing an entry"),
    {
        // given("An instance of map")
        auto map = RefMap(16, 16);
        map[3] = new C(10, 20);
        map[5] = new C(12, 22);
        map[1] = new C(100,50);
        map[0] = new C(0,5);
        map.length.should.be.equal(4);
        map.search(1).should.be.equal(3);

        // when("we remove an entry")
        map.remove(1).should.be.True;

        // then("the removed valued disapers from the map")
        map.length.should.be.equal(3);
        map.search(1).should.be.equal(-1);

        // expect("when try to remove a not existent value, must return false")
        map.remove(13).should.be.False;
        map.length.should.be.equal(3);
    }

    // describe("Obtaining the keys and values of this map, with a reference Value")
    {
        // given("An instance of map intialized with some values")
        auto map = RefMap(16, 16);
        map[10] = new C(0, 1);
        map[0] = new C(123, 666);
        map[3] = new C(1, 2);

        // expect("we get an array of the keys of the map, sorted by the values")
        map.keys.should.be.equal([10, 3, 0]);

        // expect("we get an array of the values of the map")
        auto values = map.values();
        values.should.be.equal([new C(0, 1), new C(1, 2), new C(123, 666)]);

        // and("If try to modify a value, then it must be changed on the containter")
        values[0].x = 33;
        map[10].should.be.equal(new C(33, 1));

        // when("we remove an element")
        map.remove(3);

        // then("the key and values order is preserved")
        map.keys.should.be.equal([10, 0]);
        map.values().should.be.equal([new C(33, 1), new C(123, 666)]);
    }

    // describe("Obtaining the keys and values of this map, with not reference Value")
    {
        // given("A instance of map")
        auto map = ValMap(16, 16);
        map[3] = S(1, 2);
        map[10] = S(0, 1);
        map[0] = S(123, 666);

        // expect("we get an array of the keys of the map")
        auto keys = map.keys;
        keys.should.be.equal([10, 3, 0]);

        // expect("we get an array of the values of the map, sorted")
        auto values = map.values();
        values.should.be.equal([S(0, 1), S(1, 2), S(123, 666)]);
        
        // and("If try to modify a value, then it must be changed on the containter")
        values[0].x = 33;
        map[10].should.be.equal(S(33, 1));
    }
}    
