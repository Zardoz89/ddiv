module ddiv.core.abstractmainprocess;

import ddiv.core.process;
import ddiv.core.scheduler;
import ddiv.log;
import ddiv.sdl.sdlgraphics;

/// Base class of the initial process. Don't know anything about graphics stuff, etc
abstract class AbstractMainProcess : Process
{
    alias LibLoader = bool function();

    /**
     * Creates the initial process
     * @param args Arguments
     * @param libLoaders code to load third party libraries
     */
    this(string[] args, LibLoader[] libLoaders)
    {
        this._args = args;
        this._libLoaders = libLoaders;
        // Orphan, id 1, and max priorty
        super(0, 1, int.max);
    }

    /// Entry point to execute the game
    final int runGame() {
        if (!this.loadLibs()) {
            this.showAbortMessage();
            return -1;
        }
        if (!this.initLibs()) {
            this.showAbortMessage();
            return -1;
        }
        scope(exit) this.quitLibs();

        this.mainLoop();
        return this.returnValue;
    }

    /// Load third party libraries
    private bool loadLibs()
    {
        foreach (libLoader ; this._libLoaders) {
            if (!libLoader()) {
                return false;
            }
        }
        return true;
    }

    abstract bool initLibs();

    abstract void quitLibs();

    private void showAbortMessage()
    {
        critical("Aborting execution.");
    }


    package:
    /// Executes the main loop. Only finishs when all remaning processes are dead or an exception is throw
    final void mainLoop()
    {
        do {
            this.doFrame();
        } while(!Scheduler.get().empty);
    }

    protected:
    string[] _args;

    final override int run()
    {
        return this.main(this._args);
    }

    /// Method to extend with the game code
    abstract int main(string[] args);

    /// Execute a game frame
    final void doFrame()
    {
        this.frameStart();

        // Execute all processes in a game frame
        do {
            Scheduler.get().executeNextProcess();
        } while (Scheduler.get().hasProcessesToExecute);

        this.frameEnd();
    }

    void frameStart()
    {
        debug(ShowFrame) {
            trace("Frame start");
        }

        auto scheduler = Scheduler.get();
        scheduler.deleteDeadProcess();
        scheduler.prepareProcessesToBeExecuted();
    }

    void frameEnd()
    {
        debug(ShowFrame) {
            trace("Frame end");
        }
    }

    private:
    LibLoader[] _libLoaders; /// Libraries to be loaded
}
