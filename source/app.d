import std.stdio;

import ddiv.core.process;


class MyProcess : Process
{
    this()
    {
        super();
    }

    override void run()
    {
        writeln("I'm running! ", this.id);
        this.frame();
        for(int i = 0 ; i < 3; i++) {
            writeln("And again! ", this.id);
            this.frame();
        }
    }
}

class Main : MainProcess{
    this(string[] args)
    {
        super(args);
    }

    override int main()
    {
        writeln("Main", this.args);
        auto p = new MyProcess();
        auto q = new MyProcess();
        for(int i = 0 ; i < 10 ; i++) {
            writeln("i=", i);
            this.frame();
        }
        return 0;
    }
}

int main(string[] args)
{
    auto main = new Main(args);

    return main.main();
}
