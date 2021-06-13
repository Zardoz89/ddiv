/**
Auxiliar functions and helpers
*/
module ddiv.core.aux;

import std.traits;

/// Marks a class attribute to no be displayed on toString
enum NoString;

/** Generates an auto toString method displaying all field values for a class */
template ToString(T)
if (isAggregateType!T)
{
    override string toString() {
        import std.conv : to;
        import std.string : chomp;

        string toString = this.classinfo.baseName ~ "(";
        enum fieldNames = fieldNames!T;
        auto noStringAttribute = false;
        static foreach(fieldName ; fieldNames) {
            noStringAttribute = false;
            foreach(attribute; __traits(getAttributes, __traits(getMember, this, fieldName))) {
                static if(is(attribute == NoString)) {
                    noStringAttribute = true;
                    break;
                }
            }
            if (!noStringAttribute) {
                toString ~= fieldName ~ "=" ~ to!string(__traits(getMember, this, fieldName)) ~ ", ";
            }
        }   
        return toString.chomp(", ") ~ ")";
    }
}

@("ToString mixin")
unittest {
    class Point {
        private int x, y;
        @NoString
        int u;

        mixin ToString!Point;
    }

    class Point3D : Point {
        int z;
        
        mixin ToString!Point3D;
    }

    Point p = new Point();
    p.x = 3;
    p.y = 9;
    p.u = -1;
    p.toString().should.match(`Point\(x=3, y=9\)`);

    p = new Point3D();
    p.x = 10;
    p.y = 20;
    p.u = -1;
    p.toString().should.match(`Point3D\(z=0, x=10, y=20\)`);

    auto p3d = new Point3D();
    p3d.x = 1;
    p3d.y = 2;
    p3d.z = 3;
    p3d.u = -1;
    p3d.toString().should.match(`Point3D\(z=3, x=1, y=2\)`);

    struct S {
        int x;
        int y;
    }
    class Z {
        string dragon;
        S ball;
        
        mixin ToString!Z;
    }
    Z z = new Z();
    z.dragon = "Goku";
    z.ball.x = 123;
    z.toString().should.match(`Z\(dragon=Goku, ball=S\(123, 0\)\)`);
}

/// Returns an array of strings with the field names of a Class 
string[] fieldNames(T)() pure 
if (isAggregateType!T)  {
    import std.meta : AliasSeq;

    enum fields = FieldNameTuple!(T);
    alias types = Fields!T;
    string[] names;
    static foreach (i, fieldName; fields) {
        if (!(isAggregateType!(types[i])) || __traits(isPOD, types[i])) {  // only basic type and POD for now
            names ~= fieldName;
        }
    }
    static foreach (baseClass; BaseClassesTuple!T) {
        static if (!is(baseClass == Object)) {
            names ~= fieldNames!baseClass;
        }
    }
    return names;
}

/**
 * Return the classname of a class without the wholly qualified name
 *
 * Returns: foo.bar.x.y.MyDerivedClass --> MyDerivedClass
 *
 * Source: https://forum.dlang.org/post/phyvgqjbppmmifaewshh@forum.dlang.org
 */
string baseName(const ClassInfo classinfo) pure {
    import std.algorithm : countUntil;
    import std.range : retro;

    const qualifiedName = classinfo.name;

    size_t dotIndex = qualifiedName.retro.countUntil('.');

    if (dotIndex < 0) {
        return qualifiedName;
    }

    return qualifiedName[$ - dotIndex .. $];
}

/// Returns true if a class have the default constructor and is accesible.
enum HasDefaultCtor(T) = __traits(compiles, new T());

/**
 * Implements the TLS fast thread safe singleton
 * Source: http://p0nce.github.io/d-idioms/#Leveraging-TLS-for-a-fast-thread-safe-singleton
 */
mixin template Singleton()
{
    private alias ThisType = typeof(this);
    static assert(is(ThisType == class), "This mixin only works with classes.");
    static assert(HasDefaultCtor!ThisType, "This function relies on the class having a default constructor.");

    private static bool instantiated_;
    private __gshared ThisType instance_;
    public static ThisType get() @trusted
    {
        if (!instantiated_) {
            synchronized (ThisType.classinfo) {
                if (!instance_) {
                    instance_ = new ThisType();
                }
                instantiated_ = true;
            }
        }
        return instance_;
    }
}

/**
 * Implements a singleton over TLS . Unsafe for multi-thread usage.
 */
mixin template TlsSingleton()
{
    private alias ThisType = typeof(this);
    static assert(is(ThisType == class), "This mixin only works with classes.");
    static assert(HasDefaultCtor!ThisType, "This function relies on the class having a default constructor.");

    private static ThisType instance_;
    public static ThisType get() @trusted
    {
        if (!instance_) {
            instance_ = new ThisType();
        }
        return instance_;
    }
}


version(unittest) {
    import pijamas;

    // This two test classes can't be declared inside of unittest block
    class MySingleton
    {
        private this() {}
        int x;
        mixin Singleton;
    }

    class MyLocalSingleton
    {
        private this() {}
        int x;
        mixin TlsSingleton;
    }
}

@("Singleton templates")
unittest {

    auto single = MySingleton.get();
    single.x = 3;
    single.x.should.be.equal(3);
    MySingleton.get().x.should.be.equal(3);
    MySingleton.get().should.be.equal(single);

    auto tls = MyLocalSingleton.get();
    tls.x = 42;
    tls.x.should.be.equal(42);
    MyLocalSingleton.get().x.should.be.equal(42);
    MyLocalSingleton.get().should.be.equal(tls);

    import core.thread.osthread : Thread;

    new Thread({
        MySingleton.get().x = 333;
        single.x.should.be.equal(333);
        MySingleton.get().should.be.equal(single);

        auto tls2 = MyLocalSingleton.get();
        tls2.x = 666;
        tls2.x.should.be.equal(666);
        MyLocalSingleton.get().x.should.be.equal(666);
        // tls is a diferent instance
        (MyLocalSingleton.get() != tls).should.be.True;
        tls.x.should.be.equal(42);
    }).start();

}

