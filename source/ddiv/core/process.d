/**
Process implemented over Fibers
*/
module ddiv.core.process;

import core.thread.fiber;
import ddiv.core.scheduler;

/// Id of a process
alias ProcessId = uint;

/// Posible states of a Process
enum ProcessState : ubyte {
    /// Actually running. By desing only a process can be running at same time
    RUNNING,
    /// Waiting to be executed by the Scheduler.get()
    HOLD,
    /// This process has finished of executing and will be deleted on the next frame
    DEAD,
    /// This process is sleeping and need to be wakeup before running
    SLEEP,
    /**
     * This process is freeze and need to be wakeup before running. If have any graphical component associated,
     * it will be displayed
     */
    FREEZE
}

/// Process based on Fibers, following the processes of DIV lang
class Process
{
private:
    Fiber _fiber;
    ProcessState _state = ProcessState.HOLD;
    ProcessId _id = 0; // Process ID
    int _priority = 0; // Process priority
    int _return; // Return value
    ProcessId _fatherId; // Father process Id. if is 0, it's orphan
    ProcessId[] _childrenIds; // Chuildren process Ids

package:
    uint _frame = 0; /// Actual frame percent value
    bool _executed = 0; /// Has been totally (100%) executed on this frame ?

public:

    /// Creates a DDiv Process
    this(ProcessId fatherId)
    {
        this(fatherId, 0, 0);
    }

    protected this(uint fatherId, uint id = 0, int priority = 0)
    {
        this._fiber = new Fiber(&runner);
        this._fatherId = fatherId;
        this._id = id;
        this._priority = priority;
        Scheduler.get().registerProcess(this);
    }

    /// Returns process Id
    final inout(ProcessId) id() inout const pure @nogc @safe nothrow
    {
        return this._id;
    }

    /// Process Id of father process
    final inout(ProcessId) fatherId() inout const pure @nogc @safe nothrow
    {
        return this._fatherId;
    }

    /// Return father Process
    final auto father() inout @safe
    {
        return Scheduler.get().getProcessById(this._fatherId);
    }

    /// Returns if this process is orphan
    final bool orphan() const pure @nogc @safe nothrow
    {
        return this._fatherId == 0;
    }

    /// Children processes ids
    final inout(ProcessId[]) childrenIds() inout pure @nogc @safe nothrow
    {
        return this._childrenIds;
    }

    /// Children processes
    final auto childrens() inout @safe
    {
        return Scheduler.get().getProcessById(this._childrenIds);
    }

    /// Return process priority
    final inout(int) priority() inout const pure @nogc @safe nothrow
    {
        return this._priority;
    }

    /// Changes process priority
    final void priority(int priority)
    {
        if (priority != this.priority) {
            Scheduler.get().changeProcessPriority(this, this._priority, priority);
            this._priority = priority;
        }
    }

    /// Returns ptocess state
    final ProcessState state() const pure @nogc @safe nothrow
    {
        return this._state;
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
        this._state = ProcessState.HOLD;
        this._fiber.yield();
    }

    /// Returned value from the process when it ends
    final int returnValue() const pure nothrow @safe
    {
        return this._return;
    }

    /// Comparation operator
    int opCmp(ref const Process other) const pure nothrow @safe
    {
        return this._id - other._id;
    }

    /// Equals operator (check for equality).
    bool opEquals()(auto ref const Process other) const pure nothrow @safe
    {
        return this._id == this._id;
    }

    override string toString() const pure
    {
        import std.conv : to;
        import ddiv.core.aux : baseName;
        string str = this.classinfo.baseName ~ "[" ~ to!string(this._id)
            ~ ", _executed=" ~ to!string(this._executed)
            ~ ", _frame=" ~ to!string(this._frame)
            ~ ", state=" ~ to!string(this.state);
            //~ ", fstate=" ~ to!string(this._fiber.state);
        if (this.orphan) {
            str ~= ", orphan";
        } else {
            str ~= ", fatherId=" ~ to!string(this._fatherId);
        }
        str ~= ", childrenIds=" ~ to!string(this._childrenIds)
            ~ "]";
        return str;
    }

package:

    /// Contine con la ejecución de este proceso
    final void call()
    {
        this._state = ProcessState.RUNNING;
        this._fiber.call();
    }

    /// Devuelve el estado de la fibra
    final Fiber.State fiberState()
    {
        return this._fiber.state;
    }

    /// Changes the process Id
    final void id(ProcessId id) pure @nogc @safe
    {
        this._id = id;
    }

    /// Process Id of father process
    final void fatherId(ProcessId fatherId) pure @nogc @safe
    {
        this._fatherId = fatherId;
    }
    /// Children process ids
    final void childrenIds(ProcessId[] childrenIds) pure @nogc @safe
    {
        this._childrenIds = childrenIds;
    }

    final void state(ProcessState state) @safe
    {
        this._state = state;
    }

    /// Sets the returned value of the process when it ends.
    final void returnValue(int returnValue)
    {
        this._return = returnValue;
    }

protected:

    /// Code to be executed by the process
    abstract int run();

private:

    /// Wrapper around run() to assign the returned value
    final void runner()
    {
        scope(exit) {
            this._state = ProcessState.DEAD;
        }
        this.returnValue(this.run());
    }

}


