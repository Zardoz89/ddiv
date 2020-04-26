module ddiv.core.process;

import core.thread.fiber;
import ddiv.core.scheduler;

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

/// Posible states of a Process
enum ProcessState : ubyte {
    /// Actually running. By desing only a process can be running at same time
    RUNNING,
    /// Waiting to be executed by the scheduler
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

/// Process based on Fibers
class Process
{
private:
    Fiber _fiber;
    ProcessState _state = ProcessState.HOLD;
    uint _id = 0; // Process ID
    int _priority = 0; // Process priority
    int _return; // Return value
    uint _fatherId; // Father process Id. if is 0, it's orphan
    uint[] _childrenIds; // Chuildren process Ids

package:
    uint _frame = 0; /// Actual frame percent value
    bool _executed = 0; /// Has been totally (100%) executed on this frame ?

public:

    /// Creates a DDiv Process
    this(uint fatherId)
    {
        this(fatherId, 0, 0);
    }

    protected this(uint fatherId, uint id = 0, int priority = 0)
    {
        this._fiber = new Fiber(&runner);
        this._fatherId = fatherId;
        this._id = id;
        this._priority = priority;
        scheduler.registerProcess(this);
    }

    /// Returns process Id
    @property final uint id() const pure @nogc @safe
    {
        return this._id;
    }

    /// Process Id of father process
    @property final uint fatherId() const pure @nogc @safe
    {
        return this._fatherId;
    }

    /// Return father Process
    @property final auto father() @safe
    {
        return scheduler.getProcessById(this._fatherId);
    }

    /// Returns if this process is orphan
    @property final bool orphan() const pure @nogc @safe
    {
        return this._fatherId == 0;
    }

    /// Children processes ids
    @property final uint[] childrenIds() pure @nogc @safe
    {
        return this._childrenIds;
    }

    /// Children processes
    @property final auto childrens() @safe
    {
        return scheduler.getProcessById(this._childrenIds);
    }

    /// Return process priority
    @property final int priority() const pure @nogc @safe
    {
        return this._priority;
    }

    /// Changes process priority
    @property final void priority(int priority)
    {
        if (priority != this.priority) {
            scheduler.changeProcessPriority(this, this._priority, priority);
            this._priority = priority;
        }
    }

    @property final ProcessState state() const pure @nogc @safe
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
    @property final int returnValue()
    {
        return this._return;
    }

    int opCmp(ref const Process s) const
    {
        return this.id - s.id;
    }

    override string toString() const
    {
        import std.conv : to;
        import ddiv.core.aux : baseName;
        string str = this.classinfo.baseName ~ "[" ~ to!string(this._id)
            ~ ", _executed=" ~ to!string(this._executed)
            ~ ", _frame=" ~ to!string(this._frame)
            ~ ", state=" ~ to!string(this.state);
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

    /// Continua con la ejecución de este proceso
    final void call()
    {
        this._state = ProcessState.RUNNING;
        this._fiber.call();
    }

    /// Devuelve el estado de la fibra
    @property final Fiber.State fiberState()
    {
        return this._fiber.state;
    }

    /// Changes the process Id
    @property final void id(uint id) pure @nogc @safe
    {
        this._id = id;
    }

    /// Process Id of father process
    @property final void fatherId(uint fatherId) pure @nogc @safe
    {
        this._fatherId = fatherId;
    }
    /// Children process ids
    @property final void childrenIds(uint[] childrenIds) pure @nogc @safe
    {
        this._childrenIds = childrenIds;
    }

    @property final void state(ProcessState state) @safe
    {
        this._state = state;
    }

    /// Sets the returned value of the process when it ends.
    @property final void returnValue(int returnValue)
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


