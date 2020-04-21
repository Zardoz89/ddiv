module ddiv.core.process;

import core.thread.fiber;

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

    @property uint framePercent() const pure @nogc @safe
    {
        return this._framePercent;
    }

    /// Return process priority
    @property int priority() const pure @nogc @safe
    {
        return this._priority;
    }

    /// Changes process priority
    @property void priority(int priority)
    {
        this._priority = priority;
        /// TODO Unregister and register again the process
    }

    final void frame(uint percent = 100)
    {
        this._framePercent = percent;
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

package:
    @property void id(uint id)
    {
        this._id = id;
    }

protected:

    /// Code to be executed by the process
    abstract void run();

private:
    uint _id = 0; // Process ID
    int _priority = 0; // Process priority
    uint _framePercent;
    int _return;

}

class MainProcess
{
    this(string[] args)
    {
        this.args = args;
    }

    final void frame(uint percent = 100)
    {
        this._framePercent = percent;
        scheduler.executeProcess();
    }
protected:
    string[] args;

    /// Code to be executed by the process
    abstract int main();

private:
    uint _framePercent;
}

private struct Scheduler
{
    import ddiv.core.heap : PriorityQueue;

    void registerProcess(Process process)
    {
        process.id = process.id == 0 ? this.generateNewId() : process.id;

        this._processes.insert(process.priority, process);
        this._processesSet[process.id] = true;
    }

    void executeProcess()
    {
        // TODO
        import std.algorithm.sorting : sort;
        //import std.stdio : writeln;

        //writeln(this._processesSet, " ", this._processes);
        foreach (pair; this._processes) {
            //writeln(pair[0], "->", pair[1]);
            auto process = pair[1];
            if (process.state != Fiber.State.TERM) {
                process.call();
            } else {
                // TODO unregister finished process
            }
        }
    }

    void unregisterProcess(Process process)
    {
        // TODO
    }

    bool allProcessesFinished()
    {
        // TODO
        return false;
    }

private:
    PriorityQueue!(int, Process) _processes;
    bool[uint] _processesSet;

    /// Generates a random process Id that isn't registered
    uint generateNewId()
    {
        import std.random : uniform;
        uint id;
        do {
            id = uniform(1, uint.max);
        } while ((id in _processesSet) !is null);
        return id;
    }
}

static Scheduler scheduler;

