/**
Auxiliar functions and helpers
*/
module ddiv.core.aux;

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

    const qualName = classinfo.name;

    size_t dotIndex = qualName.retro.countUntil('.');

    if (dotIndex < 0) {
        return qualName;
    }

    return qualName[$ - dotIndex .. $];
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

