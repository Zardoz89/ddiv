module ddiv.core.mainprocess;

import ddiv.core.process;

/// Initial process
final class MainProcess : Process
{
    /**
     * Creates the initial process
     * @param args Arguments
     * @param mainFunction Code to be execute as main
     */
    this(string[] args, int delegate(string[] args) mainFunction)
    {
        this._args = args;
        this._main = mainFunction;
        super(1, int.max);
    }

protected:
    override void run()
    {
        this.returnValue(this._main(this._args));
    }

private:
    string[] _args;
    int delegate(string[] args) _main;
}

void mainLoop()
{
    do {
        frame();
    } while(!scheduler.empty);
}

void frame()
{
    // frame_start
    scheduler.deleteDeadProcess();
    scheduler.prepareProcessesToBeExecuted();

    // Execute processes
    do {
        scheduler.executeNextProcess();
    } while (scheduler.hasProcessesToExecute);

    // frame_end
}
