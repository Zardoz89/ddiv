module app;

import ddiv.core;

final class Main : MainProcess
{
    this(string[] args)
    {
        super( args);
    }

    override int main(string[] args)
    {
        import std.stdio : writeln;

        int i=0;
        do {
            //writeln("i: ", i);
            this.frame();
            i++;
        } while (i < 600);
        return 0;
    }
}

int main(string[] args)
{
    import ddiv.log;
    configLogger();
    
    auto main = new Main(args);
    return main.runGame();
}
