module tests.ddiv.container.linkedmap_spec;

import pijamas;

import ddiv.container.linkedmap;

class C {
    int x, y;

    this(int x, int y) @safe {
        this.x = x;
        this.y = y;
    }

    override bool opEquals(Object o) const @safe {
        if (C rhs = cast(C) o) {
            return this.x == rhs.x && this.y == rhs.y;
        }
        return false;
    }

    override string toString() const @trusted {
        import std.conv : to;

        return "C(" ~ this.x.to!string ~ ", " ~ this.y.to!string ~ ")";
    }
}

struct S {
    int x, y;

    bool opEquals(const S rhs) const @safe {
        return this.x == rhs.x && this.y == rhs.y;
    }

    bool opEquals(ref const S rhs) const @safe {
        return this.x == rhs.x && this.y == rhs.y;
    }

    string toString() const @trusted {
        import std.conv : to;

        return "S(" ~ this.x.to!string ~ ", " ~ this.y.to!string ~ ")";
    }
}

@("LinkedMap sorted by insertion order")
unittest {

    // For the rest of tests, we make a alias to type less
    alias RefMap = LinkedMap!(uint, C);
    alias ValMap = LinkedMap!(uint, S);

    // describe("Using the default constructor, gives a empty map"),
    {
        // given("A instance of map")
        auto refMap = RefMap();
        auto valMap = ValMap();

        // expect("that is empty")
        refMap.length.should.be.equal(0);
        refMap.empty.should.be.True;
        valMap.length.should.be.equal(0);
        valMap.empty.should.be.True;

        // and("toString only returns the object name")
        refMap.toString.should.be.equal("LinkedMap!(uint, C)()");
        valMap.toString.should.be.equal("LinkedMap!(uint, S)()");
    }

    // describe("Inserting and searching unsigned integers"),
    {
        // given("A instance of map")
        auto map = RefMap();

        // when("We insert some pairs of key, value")
        map[10] = new C(0, 0);
        map[3] = new C(1, 2);
        map[0] = new C(123, 666);

        // then("It must not be empty")
        map.empty.should.be.False;
        map.length.should.be.equal(3);

        // and("Must contains the key")
        map.contains(10).should.be.True();
        (10 in map).should.exist;
        map.contains(3).should.be.True();
        map.contains(0).should.be.True();
        map.contains(22).should.not.be.True();
        auto keys = map.keys;
        keys.should.be.equal([10, 3, 0]);

        // and("when we try to get e value by key, returns the value")
        map[10].should.be.equal(new C(0, 0));
        map[3].should.be.equal(new C(1, 2));
        map[0].should.be.equal(new C(123, 666));

        // and("if we try to get a not exitent value, thorows")
        import ikod.containers.hashmap : KeyNotFound;

        should(() { map[22]; }).Throw!KeyNotFound;

        // and("toString returns the object name and the values list")
        map.toString.should.be.equal(
                "LinkedMap!(uint, C)(10 : C(0, 0), 3 : C(1, 2), 0 : C(123, 666))");
    }

    // describe("Overwrite a inserted value"),
    {
        // given("A instance of map with some initial values")
        auto map = RefMap();
        map[10] = new C(0, 0);
        map[3] = new C(1, 2);
        map[0] = new C(123, 666);

        // when("We insert a new value with a existing key")
        /*
        map[10] = new C(13, 31);

        // then("must replace the old value")
        map[10].should.be.equal(new C(13, 31));
        map.keys.should.be.equal([3, 0, 10]);
        */
    }
}

@("LinkedMap sorted by key")
unittest {

    // For the rest of tests, we make a alias to type less
    alias RefMap = LinkedMap!(uint, C, SortPolicy.ByKey);
    alias ValMap = LinkedMap!(uint, S, SortPolicy.ByKey);

    // describe("Using the default constructor, gives a empty map"),
    {
        // given("A instance of map")
        auto refMap = RefMap();
        auto valMap = ValMap();

        // expect("that is empty")
        refMap.length.should.be.equal(0);
        refMap.empty.should.be.True;
        valMap.length.should.be.equal(0);
        valMap.empty.should.be.True;

        // and("toString only returns the object name")
        refMap.toString.should.be.equal("LinkedMap!(uint, C)()");
        valMap.toString.should.be.equal("LinkedMap!(uint, S)()");
    }

    // describe("Inserting and searching unsigned integers"),
    {
        // given("A instance of map")
        auto map = RefMap();

        // when("We insert some pairs of key, value")
        map[10] = new C(0, 0);
        map[3] = new C(1, 2);
        map[0] = new C(123, 666);

        // then("It must not be empty")
        map.empty.should.be.False;
        map.length.should.be.equal(3);

        // and("Must contains the key")
        (10 in map).should.exist;
        map.contains(10).should.be.True();
        map.contains(3).should.be.True();
        map.contains(0).should.be.True();
        map.contains(2).should.be.False();
        auto keys = map.keys;
        keys.should.be.equal([0, 3, 10]);

        // and("when we try to get e value by key, returns the value")
        map[10].should.be.equal(new C(0, 0));
        map[3].should.be.equal(new C(1, 2));
        map[0].should.be.equal(new C(123, 666));

        // and("if we try to get a not exitent value, thorows")
        import ikod.containers.hashmap : KeyNotFound;

        should(() { map[22]; }).Throw!KeyNotFound;

        // and("toString returns the object name and the values list")
        map.toString.should.be.equal(
                "LinkedMap!(uint, C)(0 : C(123, 666), 3 : C(1, 2), 10 : C(0, 0))");
    }
}
