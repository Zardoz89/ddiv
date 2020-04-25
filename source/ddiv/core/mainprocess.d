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
        // Orphan, id 1, and max priorty
        super(0, 1, int.max);
    }

    /// Executes the main loop. Only finishs when all remaning processes has die or an exception is throw
    final void mainLoop()
    {
        do {
            this.frame();
        } while(!scheduler.empty);
    }

protected:
    final override void run()
    {
        this.returnValue(this.main(this._args));
    }

    abstract int main(string[] args);
    // TODO No usa un delegate, si no extender un método main y quitar el final de la clase, pero ponerselo a run

    final void frame()
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

private:
    string[] _args;
}



version(unittest) import beep;

@("MainProcess and MainLoop")
unittest {

    import std.stdio : writeln;

    class MyProcess : Process
    {
        int executeTimes = 0;
        this(uint fatherId)
        {
            super(fatherId);
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
            this.orphan.expect!true; // Main process is orphan always

            writeln("I'm main! ");
            auto myP = new MyProcess(this.id);
            writeln(this.toString);

            // Testing simple process hirearchy
            this.childrenIds.length.expect!equal(1);
            this.childrenIds.expect!contain(myP.id);
            myP.orphan.expect!false;
            myP.fatherId.expect!equal(this.id);
            myP.father.expect!equal(this);

            this.frame();
            writeln(myP);
            // myP becomes orphan and keeps runing a few frames more. It must not crash
            return 0;
        }
    }

    auto main = new Main([""]);

    scheduler.empty.expect!false; // Main process must be registered
    main.mainLoop();
    scheduler.empty.expect!true; // mainLoop ends when all process has been executed
}
