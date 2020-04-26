/**
Process Scheduler
*/
module ddiv.core.scheduler;

import core.thread.fiber;
import ddiv.core.process;
import ddiv.core.aux;

/*
Pseudocode idea from DIV source :

main_loop (while !Scheduler.get().isEmpty()):
  frame_start
  do {
    Scheduler.get().execNextProcess();
  } while (Scheduler.get().hasProcessToExecute();
  frame_end


frame_start:

1. elimina procesos muertos -> Scheduler.get().deleteDeadProcess();
2. marca todos los procesos como no ejecutados -> Scheduler.get().prepareAllProcess()

Scheduler.get().execNextProcess():
  this.max = int.min;
  process = this.nextProcessToBeExecuted();

  if (process._frame >= 100) {
    process._frame -= 100;
    process.executed = true;
  } else {
    process.call();
  }

Scheduler.get().nextProcessToBeExecuted():
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


/// Process Scheduler inspired by DIV process scheduler
final class Scheduler
{
    mixin TlsSingleton!Scheduler;

private:
    import ddiv.container : PriorityQueue;

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
        if (process.fatherId != 0) {
            auto father = this._processesById[process.fatherId];
            auto childrens = father.childrenIds;
            childrens ~= process.id;
            father.childrenIds = childrens;
        }
    }

    /// Unregisters a process on the scheduler
    void unregisterProcess(Process process)
    {
        if (process.childrenIds.length > 0) {
            import std.algorithm : each;
            // change children father to the father of this process
            foreach(children ; process.childrens) {
                children.fatherId = process.fatherId;
            }
            // add this process childrens to the father childrens
            if (process.fatherId != 0) {
                auto father = this._processesById[process.fatherId];
                auto fatherChildrens = father.childrenIds;
                fatherChildrens ~= process.childrenIds;
                father.childrenIds = fatherChildrens;
                process.childrenIds = [];
            }
        }

        if (process.fatherId != 0) {
            // Remove process from father childrenIds
            import std.algorithm : remove;
            auto father = this._processesById[process.fatherId];
            auto childrens = father.childrenIds;
            father.childrenIds = childrens.remove!(id => id == process.id);
        }

        // Finally we remove the process from the priority queue and from the associative array
        this._processes.remove(process.priority, process);
        this._processesById.remove(process.id);
    }

    /// Updates the priority queue with a change of priority
    void changeProcessPriority(Process process, int oldPriority, int newPriority)
    {
        this._processes.remove(oldPriority, process);
        this._processes.insert(newPriority, process);
    }

public:
    /// Prepare all processes for the next frame
    void prepareProcessesToBeExecuted()
    {
        foreach (pair; this._processes) {
            auto process = pair[1];
            if (process.fiberState == Fiber.State.HOLD) {
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
            if (process.state == ProcessState.DEAD || process.fiberState == Fiber.State.TERM) {
                this.unregisterProcess(process);
            }
        }
    }

    void executeNextProcess()
    {
        debug(ShowProcessIds) {
            import std.stdio : writeln;
            import std.algorithm : map;
            writeln(this._processes.map!(p => p.value.id));
        }

        this._actualPriority = int.min;
        auto process = this.nextProcessToBeExecuted();
        if (process !is null && process.state == ProcessState.HOLD) {
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

    /// Return a process object by his id, or null if it not exists
    auto getProcessById(const uint id) pure @safe
    {
        return this._processesById.get(id, null);

    }

    /// Returns a range of process objects
    auto getProcessById(const uint[] ids) pure @safe
    {
        import std.algorithm : map;
        return ids.map!( id => this.getProcessById(id));
    }

    @property bool hasProcessesToExecute() pure @nogc @safe
    {
        return this._hasRemainingProcessesToExecute && !this.empty;
    }

    @property bool empty() pure @nogc @safe
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
            if (process.fiberState == Fiber.State.HOLD && !process._executed
                    && process.priority > this._actualPriority) {
                this._actualPriority = process.priority;
                return process;
            }
        }
        this._hasRemainingProcessesToExecute = false;
        return null;
    }
}

