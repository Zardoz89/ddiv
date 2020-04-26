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
            this.doFrame();
        } while(!scheduler.empty);
    }

protected:
    final override int run()
    {
        return this.main(this._args);
    }

    abstract int main(string[] args);
    // TODO No usa un delegate, si no extender un método main y quitar el final de la clase, pero ponerselo a run

    /// Execute a game frame
    final void doFrame()
    {
        // frame_start
        debug(ShowFrame) {
            import std.stdio : writeln;
            writeln("Frame start");
        }
        scheduler.deleteDeadProcess();
        scheduler.prepareProcessesToBeExecuted();

        // Execute processes
        do {
            scheduler.executeNextProcess();
        } while (scheduler.hasProcessesToExecute);

        debug(ShowFrame) {
            import std.stdio : writeln;
            writeln("Frame end");
        }
        // frame_end
    }

private:
    string[] _args;
}



version(unittest) import beep;

@("MainProcess and MainLoop - Simple")
unittest {
    debug(MainProcessTestStdout) {
        import std.stdio : writeln;
    }

    class MyProcess : Process
    {
        this(uint fatherId)
        {
            super(fatherId);
        }

        override int run()
        {
            for(int i = 0 ; i < 4; i++) {
                debug(MainProcessTestStdout) {
                    writeln(i, "->", this.toString());
                }
                this.frame();
            }
            return 0;
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

            debug(MainProcessTestStdout) {
                writeln("I'm main! ");
            }
            auto myP = new MyProcess(this.id);

            debug(MainProcessTestStdout) {
                writeln(this.toString);
            }

            // Testing simple process hirearchy
            this.childrenIds.length.expect!equal(1);
            this.childrenIds.expect!contain(myP.id);
            myP.orphan.expect!false;
            myP.fatherId.expect!equal(this.id);
            myP.father.expect!equal(this);

            this.frame();

            debug(MainProcessTestStdout) {
                writeln(myP);
            }
            // myP becomes orphan and keeps runing a few frames more. It must not crash
            return 0;
        }
    }

    auto main = new Main([""]);

    scheduler.empty.expect!false; // Main process must be registered
    main.mainLoop();
    scheduler.empty.expect!true; // mainLoop ends when all process has been executed
}

@("MainProcess and MainLoop - Complex hirearchy")
unittest {
    debug(MainProcessTestStdout) {
        import std.stdio : writeln;
    }

    class MyProcess : Process
    {
        int times;
        int createChildrens;
        this(uint fatherId, int times, int createChildrens)
        {
            super(fatherId);
            this.times = times;
            this.createChildrens = createChildrens;
        }

        override int run()
        {
            import std.random : dice;

            for (int i = 0; i < this.createChildrens; i++) {
                auto child = new MyProcess(this.id, times, cast(int) dice(0.5, 0.3, 0.2));
            }

            bool wasOrphan = false;
            for (int i = 0 ; i < this.times; i++) {
                debug(MainProcessTestStdout) {
                    writeln(i, "->", this.toString());
                }
                this.frame();
                debug(MainProcessTestStdout) {
                    if (this.orphan && !wasOrphan) {
                        wasOrphan = true;
                        writeln("Process id ", this.id, " has been orphaned");
                    }
                }
            }
            return 0;
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

            debug(MainProcessTestStdout) {
                writeln("I'm main! ");
            }
            auto myP = new MyProcess(this.id, 6, 4);
            debug(MainProcessTestStdout) {
                writeln(this.toString);
            }

            // Testing simple process hirearchy
            this.childrenIds.length.expect!equal(1);
            this.childrenIds.expect!contain(myP.id);
            myP.orphan.expect!false;
            myP.fatherId.expect!equal(this.id);
            myP.father.expect!equal(this);
            myP.childrenIds.length.expect!equal(0); // Frame hasn't happend yet, so myP hasm't been executed yet

            this.frame();
            debug(MainProcessTestStdout) {
                writeln(myP);
            }
            myP.childrenIds.length.expect!equal(4);

            for (int i = 0 ; i < 4; i++) {
                this.frame();
                debug(MainProcessTestStdout) {
                    writeln(myP);
                }
            }
            // myP becomes orphan and keeps runing a few frames more. It must not crash
            return 0;
        }
    }

    auto main = new Main([""]);

    scheduler.empty.expect!false; // Main process must be registered
    main.mainLoop();
    scheduler.empty.expect!true; // mainLoop ends when all process has been executed
}


