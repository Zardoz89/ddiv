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

/**
 * Implements the TLS fast thread safe singleton
 * Source: http://p0nce.github.io/d-idioms/#Leveraging-TLS-for-a-fast-thread-safe-singleton
 */
mixin template Singleton(T)
{
    mixin("
        private static bool instantiated_;
        private __gshared T instance_;

        public static T get() @trusted
        {
            if (!instantiated_) {
                synchronized (T.classinfo) {
                    if (!instance_) {
                        instance_ = new T();
                    }
                    instantiated_ = true;
                }
            }
            return instance_;
        }
    ");
}

/**
 * Implements a singleton over TLS . Unsafe for multi-thread usage.
 */
mixin template TlsSingleton(T)
{
    mixin("
        private static T instance_;

        public static T get() @trusted
        {
            if (!instance_) {
                instance_ = new T();
            }
            return instance_;
        }
    ");
}


version(unittest) {
    import beep;

    // This two test classes can't be declared inside of unittest block
    class MySingleton
    {
        private this() {}
        int x;
        mixin Singleton!MySingleton;
    }

    class MyLocalSingleton
    {
        private this() {}
        int x;
        mixin TlsSingleton!MyLocalSingleton;
    }
}

@("Singleton templates")
unittest {

    auto single = MySingleton.get();
    single.x = 3;
    single.x.expect!equal(3);
    MySingleton.get().x.expect!equal(3);
    MySingleton.get().expect!equal(single);

    auto tls = MyLocalSingleton.get();
    tls.x = 42;
    tls.x.expect!equal(42);
    MyLocalSingleton.get().x.expect!equal(42);
    MyLocalSingleton.get().expect!equal(tls);

    import core.thread.osthread : Thread;

    new Thread({
        MySingleton.get().x = 333;
        single.x.expect!equal(333);
        MySingleton.get().expect!equal(single);

        auto tls2 = MyLocalSingleton.get();
        tls2.x = 666;
        tls2.x.expect!equal(666);
        MyLocalSingleton.get().x.expect!equal(666);
        // tls is a diferent instance
        (MyLocalSingleton.get() != tls).expect!true;
        tls.x.expect!equal(42);
    }).start();


}

