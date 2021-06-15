module ddiv.core.mainprocess;

import ddiv.core.process;
import ddiv.core.scheduler;
import ddiv.core.tostring;

/// Initial process
class MainProcess : Process {
    /**
     * Creates the initial process
     * @param args Arguments
     * @param mainFunction Code to be execute as main
     */
    this(string[] args) {
        this._args = args;
        Scheduler.get().reset(); // Work around
        // Orphan, id 1, and max priorty
        super(ORPHAN_FATHER_ID, ROOT_ID, int.max);
    }

    /// Executes the main loop. Only finishs when all remaning processes has die or an exception is throw
    final void mainLoop() {
        do {
            this.doFrame();
        }
        while (!Scheduler.get().empty);
    }

    /*
    override string toString()
    {
        import std.conv : to;
        return to!string([ __traits(allMembers, MainProcess) ]);
    }
    */

    mixin ToString!MainProcess;

protected:
    final override int run() {
        return this.main(this._args);
    }

    abstract int main(string[] args);
    // TODO No usa un delegate, si no extender un método main y quitar el final de la clase, pero ponerselo a run

    /// Execute a game frame
    final void doFrame() {
        // frame_start
        debug (ShowFrame) {
            import ddiv.log;

            trace("Frame start");
        }
        Scheduler.get().deleteDeadProcess();
        Scheduler.get().prepareProcessesToBeExecuted();

        // Execute processes
        do {
            Scheduler.get().executeNextProcess();
        }
        while (Scheduler.get().hasProcessesToExecute);

        debug (ShowFrame) {
            import ddiv.log;

            trace("Frame end");
        }
        // frame_end
    }

private:
    string[] _args;
}
