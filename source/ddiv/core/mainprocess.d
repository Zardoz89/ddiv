module ddiv.core.mainprocess;

import ddiv.core.process;
import ddiv.core.scheduler;

/// Initial process
class MainProcess : Process
{
    /**
     * Creates the initial process
     * @param args Arguments
     * @param mainFunction Code to be execute as main
     */
    this(string[] args)
    {
        this._args = args;
        // Orphan, id 1, and max priorty
        super(0, 1, int.max);
    }

    /// Executes the main loop. Only finishs when all remaning processes has die or an exception is throw
    final void mainLoop()
    {
        do {
            this.doFrame();
        } while(!scheduler.empty);
    }

protected:
    final override int run()
    {
        return this.main(this._args);
    }

    abstract int main(string[] args);
    // TODO No usa un delegate, si no extender un método main y quitar el final de la clase, pero ponerselo a run

    /// Execute a game frame
    final void doFrame()
    {
        // frame_start
        debug(ShowFrame) {
            import std.stdio : writeln;
            writeln("Frame start");
        }
        scheduler.deleteDeadProcess();
        scheduler.prepareProcessesToBeExecuted();

        // Execute processes
        do {
            scheduler.executeNextProcess();
        } while (scheduler.hasProcessesToExecute);

        debug(ShowFrame) {
            import std.stdio : writeln;
            writeln("Frame end");
        }
        // frame_end
    }

private:
    string[] _args;
}


