/**
Integration tests of Process, Scheduler and MainProcess
*/
module ddiv.core.tests;

@("Scheduler and process with frame(100)")
unittest {
    import beep;

    import core.thread.fiber;

    import ddiv.core.process;
    import ddiv.core.scheduler;

    debug(ProcessTestStdout) {
        import std.stdio : writeln;
    }

    class MyProcess : Process
    {
        int executeTimes = 0;
        this(uint fatherId)
        {
            super(fatherId);
        }

        override int run()
        {
            for(int i = 0 ; i < 4; i++) {
                executeTimes++;
                debug(ProcessTestStdout) {
                    writeln(executeTimes, "->", this.toString());
                }
                this.state.expect!equal(ProcessState.RUNNING);
                this.frame();
            }
            return 0;
        }
    }

    int frames = 0;
    auto p = new MyProcess(0);
    (p.id != 0).expect!true;
    p.executeTimes.expect!equal(0); // Zero executions before the Scheduler.get() begins to do his job
    p.state.expect!equal(ProcessState.HOLD);

    for (int i = 1; i <= 6; i++) {
        Scheduler.get().prepareProcessesToBeExecuted();
        Scheduler.get().deleteDeadProcess();
        if (p.fiberState == Fiber.State.HOLD) {
            Scheduler.get().empty.expect!false; // Must not delete the only process
            Scheduler.get().hasProcessesToExecute().expect!true; // The process is ready to be executed
        } else {
            Scheduler.get().empty.expect!true; //  Except when the process has been finished
            Scheduler.get().hasProcessesToExecute().expect!false;
        }

        do {
            Scheduler.get().executeNextProcess();
        } while (Scheduler.get().hasProcessesToExecute);

        debug(ProcessTestStdout) {
            writeln("frame=", frames);
        }

        if (p.fiberState == Fiber.State.HOLD) {
            p._executed.expect!true;
            Scheduler.get().hasProcessesToExecute().expect!false; // The process has been executed
            p.executeTimes.expect!equal(i);
        }
        frames++;
    }

    // Verify that terminated processes are deleted
    Scheduler.get().empty.expect!true;

    p.state.expect!equal(ProcessState.DEAD); // And the process must be dead

    Scheduler.get().reset();
}

@("Scheduler and process with frame(400)")
unittest {
    import beep;

    import core.thread.fiber;

    import ddiv.core.process;
    import ddiv.core.scheduler;

    debug(ProcessTestStdout) {
        import std.stdio : writeln;
    }
    import std.math : ceil;

    class MyProcess400 : Process
    {
        int executeTimes = 0;
        this(uint fatherId)
        {
            super(fatherId);
        }

        override int run()
        {
            for(int i = 0 ; i < 4; i++) {
                executeTimes++;
                debug(ProcessTestStdout) {
                    writeln(executeTimes, "->", this.toString());
                }
                this.frame(400);
            }
            return 0;
        }
    }

    int frames = 0;
    auto p = new MyProcess400(0);
    (p.id != 0).expect!true;
    p.executeTimes.expect!equal(0); // Zero executions before the Scheduler.get() begins to do his job

    for (int i = 1; i <= 18; i++) {
        Scheduler.get().prepareProcessesToBeExecuted();
        Scheduler.get().deleteDeadProcess();
        if (p.fiberState == Fiber.State.HOLD) {
            Scheduler.get().empty.expect!false; // Must not delete the only process
            Scheduler.get().hasProcessesToExecute().expect!true; // The process is ready to be executed
        } else {
            Scheduler.get().empty.expect!true; //  Except when the process has been finished
            Scheduler.get().hasProcessesToExecute().expect!false;
        }

        do {
            Scheduler.get().executeNextProcess();
        } while (Scheduler.get().hasProcessesToExecute);

        debug(ProcessTestStdout) {
            writeln("frame=", frames);
        }

        if (p.fiberState == Fiber.State.HOLD) {
            p._executed.expect!true;
            Scheduler.get().hasProcessesToExecute().expect!false; // The process has been executed
            p.executeTimes.expect!equal(ceil(i/4.0));
        }
        frames++;
    }

    // Verify that terminated processes are deleted
    Scheduler.get().empty.expect!true;

    Scheduler.get().reset();
}

@("Scheduler and process with frame(50)")
unittest {
    import beep;

    import core.thread.fiber;

    import ddiv.core.process;
    import ddiv.core.scheduler;

    debug(ProcessTestStdout) {
        import std.stdio : writeln;
    }

    class MyProcess50 : Process
    {
        int executeTimes = 0;
        this(uint fatherId)
        {
            super(fatherId);
        }

        override int run()
        {
            for(int i = 0 ; i < 6; i++) {
                executeTimes++;
                debug(ProcessTestStdout) {
                    writeln(executeTimes, "->", this.toString());
                }
                this.frame(50);
            }
            return 0;
        }
    }

    int frames = 0;
    auto p = new MyProcess50(0);
    (p.id != 0).expect!true;
    p.executeTimes.expect!equal(0); // Zero executions before the Scheduler.get() begins to do his job

    for (int i = 1; i <= 6; i++) {
        Scheduler.get().prepareProcessesToBeExecuted();
        Scheduler.get().deleteDeadProcess();
        if (p.fiberState == Fiber.State.HOLD) {
            Scheduler.get().empty.expect!false; // Must not delete the only process
            Scheduler.get().hasProcessesToExecute().expect!true; // The process is ready to be executed
        } else {
            Scheduler.get().empty.expect!true; //  Except when the process has been finished
            Scheduler.get().hasProcessesToExecute().expect!false;
        }

        do {
            Scheduler.get().executeNextProcess();
        } while (Scheduler.get().hasProcessesToExecute);

        debug(ProcessTestStdout) {
            writeln("frame=", frames);
        }

        if (p.fiberState == Fiber.State.HOLD) {
            p._executed.expect!true;
            Scheduler.get().hasProcessesToExecute().expect!false; // The process has been executed
            p.executeTimes.expect!equal(i*2);
        }
        frames++;
    }

    // Verify that terminated processes are deleted
    Scheduler.get().empty.expect!true;

    Scheduler.get().reset();
}


@("MainProcess and MainLoop - Simple")
unittest {
    import beep;

    import ddiv.core.process;
    import ddiv.core.scheduler;
    import ddiv.core.mainprocess;

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

    Scheduler.get().empty.expect!false; // Main process must be registered
    main.mainLoop();
    Scheduler.get().empty.expect!true; // mainLoop ends when all process has been executed
}

@("MainProcess and MainLoop - Complex hirearchy")
unittest {
    import beep;

    import ddiv.core.process;
    import ddiv.core.scheduler;
    import ddiv.core.mainprocess;

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

    Scheduler.get().empty.expect!false; // Main process must be registered
    main.mainLoop();
    Scheduler.get().empty.expect!true; // mainLoop ends when all process has been executed
}


