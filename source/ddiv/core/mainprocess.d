module ddiv.core.mainprocess;

import ddiv.core.process;

/// Initial process
class MainProcess : Process
{
    /**
     * Creates the initial process
     * @param args Arguments
     * @param mainFunction Code to be execute as main
     */
    this(string[] args)
    {
        this._args = args;
        super(1, int.max);
    }


protected:
    final override void run()
    {
        this.returnValue(this.main(this._args));
    }

    abstract int main(string[] args);
    // TODO No usa un delegate, si no extender un método main y quitar el final de la clase, pero ponerselo a run

private:
    string[] _args;
}

void mainLoop()
{
    do {
        frame();
    } while(!scheduler.empty);
}

void frame()
{
    // frame_start
    scheduler.deleteDeadProcess();
    scheduler.prepareProcessesToBeExecuted();

    // Execute processes
    do {
        scheduler.executeNextProcess();
    } while (scheduler.hasProcessesToExecute);

    // frame_end
}

unittest {

    import std.stdio : writeln;

    class MyProcess : Process
    {
        int executeTimes = 0;
        this()
        {
            super();
        }

        override void run()
        {
            for(int i = 0 ; i < 4; i++) {
                executeTimes++;
                writeln(executeTimes, "->", this.toString());
                this.frame();
            }
        }
    }

    final class Main : MainProcess
    {
        this(string[] args)
        {
            super(args);
        }

        override int main(string[] args)
        {
            writeln("I'm main! ");
            auto myP = new MyProcess();
            this.frame();
            writeln(myP);
            return 0;
        }
    }


    auto main = new Main([""]);
    writeln(main);

    assert(!scheduler.empty);
    mainLoop();
    assert(scheduler.empty);


    scheduler.reset();
    writeln("Ok");
}
