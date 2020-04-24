module ddiv.core.process;

import core.thread.fiber;

/*
Pseudocode idea from DIV source :

main_loop (while !scheduler.isEmpty()):
  frame_start
  do {
    scheduler.execNextProcess();
  } while (scheduler.hasProcessToExecute();
  frame_end


frame_start:

1. elimina procesos muertos -> scheduler.deleteDeadProcess();
2. marca todos los procesos como no ejecutados -> scheduler.prepareAllProcess()

scheduler.execNextProcess():
  this.max = int.min;
  process = this.nextProcessToBeExecuted();

  if (process._frame >= 100) {
    process._frame -= 100;
    process.executed = true;
  } else {
    process.call();
  }

scheduler.nextProcessToBeExecuted():
  Process nextProcess;
  foreach(auto process : processes) {
    if (process.NoDormido
            && !process.executed
            && process.priorty > this.max) {
        nextProcess = process;
        max = nextProcess.priority
    }
  }


process.frame(int f = 100):
  this._frame += fM
  if (this._frame >= 100) {
    this._frame -= 100;
    this.executed = true;
  }


*/

/// Process based on Fibers
class Process : Fiber
{
private:
    uint _id = 0; // Process ID
    int _priority = 0; // Process priority
    int _return; // Return value

package:
    uint _frame = 0; /// Actual frame percent value
    bool _executed = 0; /// Has been totally (100%) executed on this frame ?

public:

    /// Creates a DDiv Process
    this()
    {
        this(0, 0);
    }

    package this(uint id, int priority = 0)
    {
        super(&run);
        this._id = id;
        this._priority = priority;
        scheduler.registerProcess(this);
    }

    /// Returns process Id
    @property uint id() const pure @nogc @safe
    {
        return this._id;
    }

    /// Return process priority
    @property int priority() const pure @nogc @safe
    {
        return this._priority;
    }

    /// Changes process priority
    @property void priority(int priority)
    {
        if (priority != this.priority) {
            this._priority = priority;
            scheduler.unregisterProcess(this);
            scheduler.registerProcess(this);
        }
    }

    /**
     * Stops the actual execution of this process.
     * Params:
     *  percent     = Percent of executed frame. By default its 100%
     *
     * Description:
     * This method it's called when the process yields the execution. The percent value, indicates how many work
     * has been completed. So, the default value of 100, indicates that has completed the 100% of the work for
     * this frame. A value of 400 (400%), indicates that the process has done 400% of the work, so it would be
     * executed again in 4 frames. A value of 50 (50%, indicates that the process has done only 50% of the work, and it
     * would be executed again on this frame.
     */
    final void frame(uint percent = 100)
    {
        this._frame += percent;
        if (this._frame >= 100) {
            this._frame -= 100;
            this._executed = true;
        }
        this.yield();
    }

    /// Returned value from the process when it ends
    @property final int returnValue()
    {
        return this._return;
    }

    /// Sets the returned value of the process when it ends.
    @property final void returnValue(int returnValue)
    {
        this._return = returnValue;
    }

    int opCmp(ref const Process s) const
    {
        return this.id - s.id;
    }

    override string toString() const
    {
        import std.conv : to;
        import ddiv.core.aux : baseName;
        return this.classinfo.baseName ~ "[" ~ to!string(this._id)
            ~ ", _executed=" ~ to!string(this._executed)
            ~ ", _frame=" ~ to!string(this._frame)
            ~ ", state=" ~ to!string(this.state)
            ~ "]";

    }

package:

    /// Changes the process Id
    @property void id(uint id)
    {
        this._id = id;
    }

protected:

    /// Code to be executed by the process
    abstract void run();

}

/// Process Scheduler inspired by DIV process scheduler
private struct Scheduler
{
private:
    import ddiv.core.heap : PriorityQueue;

    /// PriorityQueue (BinaryHeap) that stores the process ordered by his priority
    PriorityQueue!(int, Process) _processes;
    /// Associative array to the process by his Id
    Process[uint] _processesById;
    /// Actual priority level being executed
    int _actualPriority;
    /// Has all remaning processes executed on this frame ?
    bool _hasRemainingProcessesToExecute;


package:
    /// Register a process on the scheduler
    void registerProcess(Process process)
    {
        process.id = process.id == 0 ? this.generateNewId() : process.id;

        // TODO Handle when the pre-exising process.id is being reused by another process
        this._processes.insert(process.priority, process);
        this._processesById[process.id] = process;
    }

    /// Unregisters a process on the scheduler
    void unregisterProcess(Process process)
    {
        this._processes.remove(process.priority, process);
        this._processesById.remove(process.id);
    }

public:
    void prepareProcessesToBeExecuted()
    {
        foreach (pair; this._processes) {
            auto process = pair[1];
            if (process.state == Fiber.State.HOLD) {
                process._executed = false;
            }
        }
        this._hasRemainingProcessesToExecute = true;
    }

    /// Delete all dead processes
    void deleteDeadProcess()
    {
        foreach (pair; this._processes) {
            auto process = pair[1];
            if (/+process._state == dead || +/ process.state == Fiber.State.TERM) {
                this.unregisterProcess(process);
            }
        }
    }

    void executeNextProcess()
    {
        this._actualPriority = int.min;
        auto process = this.nextProcessToBeExecuted();
        if (process !is null ) {
            // Skips process with  _frame > 100 (this happens, for example, when frame(200) is called
            if (process._frame >= 100) {
                process._frame -= 100;
                process._executed = true;
            } else {
                process.call();
            }
        }
    }

    /// Removes all processes on the scheduler
    void reset()
    {
        this._processes.length = 0;
        this._processesById.clear;
    }

    @property bool hasProcessesToExecute()
    {
        return this._hasRemainingProcessesToExecute && !this.empty;
    }

    @property bool empty()
    {
        return this._processes.empty();
    }

private:
    /// Generates a random process Id that isn't registered
    uint generateNewId()
    {
        import std.random : uniform;
        uint id;
        // TODO Contemplate what happens when the number of total processes are near int.max
        do {
            id = uniform(1, uint.max);
        } while ((id in _processesById) !is null);
        return id;
    }

    Process nextProcessToBeExecuted()
    {
        foreach (pair; this._processes) {
            auto process = pair[1];
            if (process.state == Fiber.State.HOLD && !process._executed && process.priority > this._actualPriority) {
                this._actualPriority = process.priority;
                return process;
            }
        }
        this._hasRemainingProcessesToExecute = false;
        return null;
    }
}

static Scheduler scheduler;

version(unittest) import beep;

@("Scheduler and process with frame(100)")
unittest {

    import std.stdio : writeln;
    import std.conv : to;

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

    int frames = 0;
    auto p = new MyProcess();
    assert(p.id != 0);
    assert(p.executeTimes == 0); // Zero executions before the scheduler begins to do his job

    for (int i = 1; i <= 6; i++) {
        scheduler.prepareProcessesToBeExecuted();
        scheduler.deleteDeadProcess();
        if (p.state == Fiber.State.HOLD) {
            assert(!scheduler.empty); // Must not delete the only process
            assert(scheduler.hasProcessesToExecute()); // The process is ready to be executed
        } else {
            assert(scheduler.empty); // Except when the process has been finished
            assert(!scheduler.hasProcessesToExecute());
        }

        do {
            scheduler.executeNextProcess();
        } while (scheduler.hasProcessesToExecute);
        writeln("frame=", frames);
        if (p.state == Fiber.State.HOLD) {
            assert(p._executed);
            assert(!scheduler.hasProcessesToExecute()); // The process has been executed
            assert(p.executeTimes == i, "Expected " ~ to!string(i) ~ " but obtained " ~ to!string(p.executeTimes));
        }
        frames++;
    }

    // Verify that terminated processes are deleted
    assert(scheduler.empty);

    scheduler.reset();
}

@("Scheduler and process with frame(400)")
unittest {

    import std.stdio : writeln;
    import std.conv : to;
    import std.math : ceil;

    class MyProcess400 : Process
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
                this.frame(400);
            }
        }
    }

    int frames = 0;
    auto p = new MyProcess400();
    assert(p.id != 0);
    assert(p.executeTimes == 0); // Zero executions before the scheduler begins to do his job

    for (int i = 1; i <= 18; i++) {
        scheduler.prepareProcessesToBeExecuted();
        scheduler.deleteDeadProcess();
        if (p.state == Fiber.State.HOLD) {
            assert(!scheduler.empty); // Must not delete the only process
            assert(scheduler.hasProcessesToExecute()); // The process is ready to be executed
        } else {
            assert(scheduler.empty); // Except when the process has been finished
            assert(!scheduler.hasProcessesToExecute());
        }

        do {
            scheduler.executeNextProcess();
        } while (scheduler.hasProcessesToExecute);
        writeln("frame=", frames);
        if (p.state == Fiber.State.HOLD) {
            assert(p._executed);
            assert(!scheduler.hasProcessesToExecute()); // The process has been executed
            assert(p.executeTimes == ceil(i/4.0),
                    "Expected " ~ to!string(ceil(i/4.0)) ~ " but obtained " ~ to!string(p.executeTimes));
        }
        frames++;
    }

    // Verify that terminated processes are deleted
    assert(scheduler.empty);

    scheduler.reset();
}

@("Scheduler and process with frame(50)")
unittest {

    import std.stdio : writeln;
    import std.conv : to;
    import std.math : ceil;

    class MyProcess50 : Process
    {
        int executeTimes = 0;
        this()
        {
            super();
        }

        override void run()
        {
            for(int i = 0 ; i < 6; i++) {
                executeTimes++;
                writeln(executeTimes, "->", this.toString());
                this.frame(50);
            }
        }
    }

    int frames = 0;
    auto p = new MyProcess50();
    assert(p.id != 0);
    assert(p.executeTimes == 0); // Zero executions before the scheduler begins to do his job

    for (int i = 1; i <= 6; i++) {
        scheduler.prepareProcessesToBeExecuted();
        scheduler.deleteDeadProcess();
        if (p.state == Fiber.State.HOLD) {
            assert(!scheduler.empty); // Must not delete the only process
            assert(scheduler.hasProcessesToExecute()); // The process is ready to be executed
        } else {
            assert(scheduler.empty); // Except when the process has been finished
            assert(!scheduler.hasProcessesToExecute());
        }

        do {
            scheduler.executeNextProcess();
        } while (scheduler.hasProcessesToExecute);
        writeln("frame=", frames);
        if (p.state == Fiber.State.HOLD) {
            assert(p._executed);
            assert(!scheduler.hasProcessesToExecute()); // The process has been executed
            assert(p.executeTimes == i*2, "Expected " ~ to!string(i*2) ~ " but obtained " ~ to!string(p.executeTimes));
        }
        frames++;
    }

    // Verify that terminated processes are deleted
    assert(scheduler.empty);

    scheduler.reset();
}

