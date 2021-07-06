module ddiv.core.tostring;

import std.traits;

/// Marks a class attribute to no be displayed on toString
enum NoString;

/** Generates an auto toString method displaying all field values for a class */
template ToString(T)
if (isAggregateType!T) {
    override string toString() {
        import std.conv : to;
        import std.string : chomp;

        string toString = this.classinfo.baseName ~ "(";
        enum fieldNames = fieldNames!T;
        auto noStringAttribute = false;
        static foreach (fieldName; fieldNames) {
            noStringAttribute = false;
            foreach (attribute; __traits(getAttributes, __traits(getMember, this, fieldName))) {
                static if (is(attribute == NoString)) {
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
    import pijamas;

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

/+
/** Generates an auto toString, with sink parameter, method displaying all field values for a class */
template ToStringSink(T)
if (isAggregateType!T) {
    void toString(scope void delegate(const(char)[]) sink) const {
        import std.range : put;
        import std.conv : to;
        import std.string : chomp;

        put(sink, this.classinfo.baseName);
        put(sink, "(");
        enum fieldNames = fieldNames!T;
        auto noStringAttribute = false;
        static foreach (fieldName; fieldNames) {
            noStringAttribute = false;
            foreach (attribute; __traits(getAttributes, __traits(getMember, this, fieldName))) {
                static if (is(attribute == NoString)) {
                    noStringAttribute = true;
                    break;
                }
            }
            if (!noStringAttribute) {
                put(sink, fieldName);
                put(sink, "=");
                put(sink,  to!string(__traits(getMember, this, fieldName)));
                put(sink, ", ");
                //toString ~= fieldName ~ "=" ~ to!string(__traits(getMember, this, fieldName)) ~ ", ";
            }
        }
        put(sink, ")");
    }
}

@("ToStringSink mixin")
unittest {
    import pijamas;
    import std.conv : to;

    class Point {
        private int x, y;
        @NoString
        int u;

        mixin ToStringSink!Point;
    }

    class Point3D : Point {
        int z;

        mixin ToStringSink!Point3D;
    }

    Point p = new Point();
    p.x = 3;
    p.y = 9;
    p.u = -1;
    p.to!string.should.match(`Point\(x=3, y=9\)`);

    p = new Point3D();
    p.x = 10;
    p.y = 20;
    p.u = -1;
    p.to!string.should.match(`Point3D\(z=0, x=10, y=20\)`);

    auto p3d = new Point3D();
    p3d.x = 1;
    p3d.y = 2;
    p3d.z = 3;
    p3d.u = -1;
    p3d.to!string.should.match(`Point3D\(z=3, x=1, y=2\)`);

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
    z.to!string.should.match(`Z\(dragon=Goku, ball=S\(123, 0\)\)`);
}
+/

/// Returns an array of strings with the field names of a Class
string[] fieldNames(T)() pure
if (isAggregateType!T) {
    import std.meta : AliasSeq;

    enum fields = FieldNameTuple!(T);
    alias types = Fields!T;
    string[] names;
    static foreach (i, fieldName; fields) {
        if (!(isAggregateType!(types[i])) || __traits(isPOD, types[i])) { // only basic type and POD for now
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
