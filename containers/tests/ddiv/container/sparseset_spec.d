module ddiv.container.sparseset_spec;

import pijamas;

import ddiv.container.sparseset;

@("StaticSparseSet")
@safe unittest {
    // describe("Init the set"),
    {
        // given("A type T that is a valid StaticSparseSet")
        alias Set = StaticSparseSet!(uint, 16);

        // expect("capacity and max value is the incated by the type")
        auto set = Set();
        set.capacity.should.be.equal(16);
        set.maxValue.should.be.equal(16);
    }

    // For the rest of tests, we make a alias to type less
    alias Set = StaticSparseSet!(uint, 16);

    // describe("Using the default constructor, gives a empty set"),
    {
        // given("A instance of set")
        auto set = Set();

        // expect("that is empty")
        set.empty.should.be.True;

        // and("toString only returns the object name")
        set.toString.should.be.equal( "SparseSet()");
    }

    // describe("Inserting and searching unsigned integers"),
    {
        // given("A instance of set")
        auto set = Set();

        // when("We insert some values")
        set.insert( 10);
        set.insert( 3);
        set.insert( 0);

        // then("It must not be empty")
        set.empty.should.be.False;
        set.length.should.be.equal(3);

        // and("when we search these values, returns it's position")
        set.search( 10).should.be.equal( 0);
        set.search( 3).should.be.equal( 1);
        set.search( 0).should.be.equal( 2);

        // and("when we search a not existing value, returns -1")
        set.search( 13).should.be.equal( -1); // Searching a not existing value

        // and("toString returns the object name and the values list")
        set.toString.should.be.equal( "SparseSet(10, 3, 0)");

        // when("we insert a range of values")
        import std.range : iota;
        set.insert(iota(11, 14));

        // then("the values of the range are inserted")
        set.search(11).should.be.equal(3);
        set.search(13).should.be.equal(5);
    }

    // describe("Inserting and searching a value over the max value"),
    {
        // given("A instance of set")
        auto set = Set();

        // when("We insert a value over max value")
        auto value = set.maxValue + 1;
        set.insert(value);

        // then("the value musnt' be inserted")
        set.search(value).should.be.equal( -1); // Not found becasue isn't inserted
        set.empty.should.be.True;
    }

    // describe("Inserting more values that the fixed capacity allows"),
    {
        // given("A instance of set")
        auto set = StaticSparseSet!(uint, 16, 32)();

        // when("we insert more values that the capacity allows")
        import std.range : iota, array;
        set.insert(iota(0, 30));

        // then("Only the first N values, where N < capacity, are inserted")
        set.length.should.be.equal(set.capacity);
        set[].should.be.equal(iota(0, set.capacity).array);
    }

    // describe("Intialize with an array of values"),
    {
        // given("A instance of set intialized with an array")
        auto set = Set([10, 9, 8]);

        // expect("the set contains the values used on intializacion")
        set.length.should.be.equal(3);
        set.search(10).should.be.equal(0);
        set.search(9).should.be.equal(1);
        set.search(8).should.be.equal(2);

        // when("we initialize with a range")
        import std.range : iota;
        set = Set(iota(0, 3));

        // then("the set contains the values of the range")
        set.length.should.be.equal(3);
        set.search(0).should.be.equal(0);
        set.search(1).should.be.equal(1);
        set.search(2).should.be.equal(2);
    }

    // describe("Slice operations")
    {
        // given("A instance of set intialized some values")
        const values = [14, 13, 12, 11, 15];
        auto set = Set(values);

        // when("we to use [] to create a slice")
        auto slice1 = set[];

        // then("the slice contains the values of the whole set")
        slice1.should.be.equal(values);

        // when("we to use [a..b] to create a slice")
        auto slice2 = set[1..$];

        // then("the slice contains only the values on the range")
        slice2.should.be.equal(values[1..$]);
    }

    // describe("A set must be a Set. Can't be repeated values stored")
    {
        // given("A empty Set")
        auto set = Set();

        // when("we insert values that are repeated")
        set.insert(13);
        set.insert(13);
        set.insert(2);
        set.insert(3);
        set.insert(2);
        set.insert(3);

        // then("the values must be unique")
        set[].should.be.equal([13, 2, 3]);

        // when("we initialize a Set with repeated values")
        set = Set([3, 5, 5, 3, 14, 14]);

        // then("the values must be unique")
        set[].should.be.equal([3, 5, 14]);
    }

    // describe("Removing values from a Set")
    {
        // given("A initialized Set")
        auto set = Set([5, 2, 0, 14]);

        // expect("removing a existin value, returns true")
        set.remove(2).should.be.True;

        // and("the removed values can't be find")
        set.search(2).should.be.equal(-1);
        set[].should.be.equal([ 5, 14, 0]);

        // expect("removing a non existent value, returns false")
        set.remove( 6).should.be.False;
    }

    // describe("foreach not consumes the set")
    {
        // given("A initialized Set")
        const values = [5, 2, 0, 14];
        auto set = Set(values);

        // when("we do a foreach on it")
        uint[] tmp;
        foreach (val ; set) {
            tmp ~= val;
        }

        // then("the set isn't consumed")
        set.empty.should.be.False;
        set[].should.be.equal(values);
        tmp.should.be.equal(values);
    }
}

/+
@("SparseSet union and intersection")
unittest {

    alias SSet = StaticSparseSet!(uint, 16);

    // describe("An union of sets")
    {
        // given("Two static sets with some initial values")
        auto set1 = SSet([ 4, 2, 14]);
        auto set2 = SSet([ 1, 4, 2, 3, 5, 4, 10]);

        // when("we do the union of both sets")
        auto unionSet = setUnion!SSet(set1, set2);

        // then("the union set must have values of both sets")
        unionSet[].should.be.equal([4, 2, 14, 1, 3, 5, 10]);
    }

    // describe("An intersection of sets")
    {
        // given("Two static sets with some initial values")
        auto set1 = SSet([ 4, 2, 14]);
        auto set2 = SSet([ 1, 4, 2, 3, 5, 4, 10]);

        // when("we do the intersection of both sets")
        auto intersectionSet = intersection!SSet(set1, set2);

        // then("the union set must have values of both sets")
        intersectionSet[].should.be.equal([4, 2, 14]);
    }

    // describe("Passing by reference a Set")
    {
        // given("A not empty sets")
        auto sset = SSet([ 1, 4, 2, 3, 5, 4, 10]);

        // expect("we can pass a reference to the set")
        void func(T)(scope ref T s)
            if (T == StaticSparseSet)
        {
            s[].should.be.equal([1, 4 ,2 ,3, 5, 10]);
        }
        func(sset);
    }
}
+/
