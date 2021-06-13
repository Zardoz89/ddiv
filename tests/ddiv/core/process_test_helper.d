/**
Helper class and functions for integration tests 
*/
module ddiv.core.process_test_helper;

import ddiv.core.process;
import ddiv.core.scheduler;

import pijamas;

/// Executes N iterations or frames of the schduler
void executeSchedulerNframes(uint totalFrames)
{
    for (uint frame = 0; frame < totalFrames; frame++) {
        prepareSchedulerFrame();

        executeAllProcessesForThisFrame();

        debug(ProcessTestStdout) {
            import std.stdio : writeln;
            try {
                writeln("frame=", frame);
            } catch (Exception ex) {}
        }
    }
}

private void prepareSchedulerFrame()
{
    Scheduler.get().prepareProcessesToBeExecuted();
    Scheduler.get().deleteDeadProcess();
}

private void executeAllProcessesForThisFrame()
{
    do {
        Scheduler.get().executeNextProcess();
    } while (Scheduler.get().hasProcessesToExecute);
}

/// Test process
class MyProcess(uint percent = 100, uint times) : Process
{
    int executeTimes = 0;
    this(uint fatherId)
    {
        super(fatherId);
    }

    override int run()
    {
        for(uint i = 0 ; i < times; i++) {
            debug(ProcessTestStdout) {
                import std.stdio : writeln;
                try {
                    writeln(executeTimes, "->", this.toString());
                } catch (Exception ex) {}
            }
            executeTimes++;
            // The process state must be RUNNING when it's running
            this.state.should.be.equal(ProcessState.RUNNING);
            this.frame(percent);
        }
        return 0;
    }
}
