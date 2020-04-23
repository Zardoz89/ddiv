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

