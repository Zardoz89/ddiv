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
        this.call();
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

    final void frame(uint percent = 100)
    {
        this._frame += percent;
        if (this._frame >= 100) {
            this._frame -= 100;
            this._executed = true;
        }
        this.yield();
    }

    @property final int returnValue()
    {
        return this._return;
    }

    @property final void returnValue(int returnValue)
    {
        this._return = returnValue;
    }

    int opCmp(ref const Process s) const
    {
        return this.priority - s.priority;
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
    @property void id(uint id)
    {
        this._id = id;
    }

    uint _frame = 0;;
    bool _executed = 0;

protected:

    /// Code to be executed by the process
    abstract void run();

private:
    uint _id = 0; // Process ID
    int _priority = 0; // Process priority
    int _return;

}

/// Process Scheduler inspired by DIV process scheduler
private struct Scheduler
{
    import ddiv.core.heap : PriorityQueue;

    /// Register a process on the scheduler
    void registerProcess(Process process)
    {
        process.id = process.id == 0 ? this.generateNewId() : process.id;

        // TODO Handle when the pre-exising process.id is being reused by another process
        this._processes.insert(process.priority, process);
        this._processesSet[process.id] = true;
    }

    /// Unregisters a process on the scheduler
    void unregisterProcess(Process process)
    {
        this._processes.remove(process.priority, process);
        this._processesSet.remove(process.id);
    }

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

    @property bool hasProcessesToExecute()
    {
        return this._hasRemainingProcessesToExecute && !this.empty;
    }

    @property bool empty()
    {
        return this._processes.empty();
    }

private:
    PriorityQueue!(int, Process) _processes;
    bool[uint] _processesSet;
    int _actualPriority;
    bool _hasRemainingProcessesToExecute;

    /// Generates a random process Id that isn't registered
    uint generateNewId()
    {
        import std.random : uniform;
        uint id;
        // TODO Contemplate what happens when the number of total processes are near int.max
        do {
            id = uniform(1, uint.max);
        } while ((id in _processesSet) !is null);
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
    assert(p.executeTimes == 1); // At least execute before the first frame()

    for (int i = 2; i <= 10; i++) {
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

    writeln("Scheduler basic operation OK");
}

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
    assert(p.executeTimes == 1); // At least execute before the first frame()

    for (int i = 2; i <= 20; i++) {
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
            assert(p.executeTimes == ceil(i/4.0), "Expected " ~ to!string(ceil(i/4.0)) ~ " but obtained " ~ to!string(p.executeTimes));
        }
        frames++;
    }

    // Verify that terminated processes are deleted
    assert(scheduler.empty);

    writeln("Scheduler frame(400) OK");
}

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
    assert(p.executeTimes == 1); // At least execute before the first frame()

    for (int i = 1; i <= 10; i++) {
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

    writeln("Scheduler frame(50) OK");
}

