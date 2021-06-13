/**
Integration tests of Process, Scheduler and MainProcess
*/
module ddiv.core.mainprocess_spec;

import core.thread.fiber;

import ddiv.core.process;
import ddiv.core.process_test_helper;
import ddiv.core.scheduler;
import ddiv.core.mainprocess;

import pijamas;

@("MainProcess and MainLoop - Simple")
unittest {
    final class Main : MainProcess
    {
        this(string[] args)
        {
            super(args);
        }

        override int main(string[] args)
        {
            this.orphan.should.be.True; // Main process is orphan always

            debug(ProcessTestStdout) {
                import std.stdio : writeln;
                writeln("I'm main! ");
            }
            auto myP = new MyProcess!(100, 4)(this.id);

            debug(ProcessTestStdout) {
                import std.stdio : writeln;
                try {
                    writeln(this.toString);
                } catch (Exception ex) {}
            }

            // Testing simple process hirearchy
            this.childrenIds.should.have.length(1);
            this.childrenIds.should.include(myP.id);
            myP.orphan.should.be.False;
            myP.fatherId.should.be.equal(this.id);
            myP.father.should.be.equal(this);

            this.frame();

            debug(ProcessTestStdout) {
                import std.stdio : writeln;
                try {
                    writeln(myP);
                } catch (Exception ex) {}
            }
            // myP becomes orphan and keeps runing a few frames more. It must not crash
            return 0;
        }
    }

    // describe("Executing the main process with a simple process hierarchy")
    {
        // given("A main process that spawns a single simple process")
        auto main = new Main([""]);

        // expect("before calling the main loop, only the main process is registered on the scheduler")
        Scheduler.get().empty.should.be.False; // Main process must be registered

        // when("we launch the main loop")
        main.mainLoop();

        // then("mainLoop ends when all the process has been executed")
        Scheduler.get().empty.should.be.True;
    }
}

@("MainProcess and MainLoop - Complex hirearchy")
unittest {
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
                debug(ProcessTestStdout) {
                    import std.stdio : writeln;
                    try {
                        writeln(i, "->", this.toString());
                    } catch (Exception ex) {}
                }
                this.frame();
                debug(ProcessTestStdout) {
                    import std.stdio : writeln;
                    try {
                        if (this.orphan && !wasOrphan) {
                            wasOrphan = true;
                            writeln("Process id ", this.id, " has been orphaned");
                        }
                    } catch (Exception ex) {}
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
            this.orphan.should.be.True; // Main process is orphan always

            debug(ProcessTestStdout) {
                import std.stdio : writeln;
                try {
                    writeln("I'm main! ");
                } catch (Exception ex) {}
            }
            auto myP = new MyProcess(this.id, 6, 4);
            debug(ProcessTestStdout) {
                import std.stdio : writeln;
                try {
                    writeln(this.toString);
                } catch (Exception ex) {}
            }

            // Testing simple process hirearchy
            this.childrenIds.should.have.length(1);
            this.childrenIds.should.include(myP.id);
            myP.orphan.should.be.False;
            myP.fatherId.should.be.equal(this.id);
            myP.father.should.be.equal(this);
            myP.childrenIds.should.have.length(0); // Frame hasn't happend yet, so myP hasn't been executed yet

            this.frame();
            debug(MainProcessTestStdout) {
                writeln(myP);
            }
            // myP should has been execute a single time, so must have spawn his childrens
            myP.childrenIds.should.have.length(4);

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

    // describe("Executing the main process with a comple process hierarchy")
    {
        // given("A main process that spawns a single simple process")
        auto main = new Main([""]);

        // expect("before calling the main loop, only the main process is registered on the scheduler")
        Scheduler.get().empty.should.be.False; // Main process must be registered

        // when("we launch the main loop")
        main.mainLoop();

        // then("mainLoop ends when all the process has been executed")
        Scheduler.get().empty.should.be.True;
    }
}
