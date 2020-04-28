/**
Process signal handling
*/
module ddiv.core.signals;

import ddiv.core.process;
import ddiv.core.scheduler;


/// Signals to send to a process
enum Signal : ubyte {
    /// kills a process. It wouldn't be executed on this frame, and removed on the next frame
    KILL,
    /// Sleeps a process
    SLEEP,
    /// Freezes a process (like sleeps, but graphics components keeps being displayed)
    FREEZE,
    /// Wakeup a process
    WAKEUP,
    /// Kill a whole process hierarchy
    KILL_TREE,
    /// Sleeps a whole process hierarchy
    SLEEP_TREE,
    /// Freezes a whole process hierarchy
    FREEZE_TREE,
    /// Wakeup a whole process hierarchy
    WAKEUP_TREE
}

void signal(uint id, Signal signal_)
{
    auto p = Scheduler.get().getProcessById(id);
    signal(p, signal_);
}

void signal(Process p, Signal signal_)
{
    // We can signal no exising processes or a dead process
    if (p is null || p.state == ProcessState.DEAD) {
        return;
    }

    void signalTree(Process p, Signal signal_)
    {
        foreach (child ; p.childrens) {
            if (child is null) {
                continue;
            }
            signal(child.id, signal_);
        }
    }

    final switch (signal_) {
        case Signal.KILL:
            p.state = ProcessState.DEAD;
            break;

        case Signal.SLEEP:
            p.state = ProcessState.SLEEP;
            break;

        case Signal.FREEZE:
            p.state = ProcessState.FREEZE;
            break;

        case Signal.WAKEUP:
            p.state = ProcessState.HOLD;
            break;

        case Signal.KILL_TREE:
            p.state = ProcessState.DEAD;
            signalTree(p, signal_);
            break;

        case Signal.SLEEP_TREE:
            p.state = ProcessState.SLEEP;
            signalTree(p, signal_);
            break;

        case Signal.FREEZE_TREE:
            p.state = ProcessState.FREEZE;
            signalTree(p, signal_);
            break;

        case Signal.WAKEUP_TREE:
            p.state = ProcessState.HOLD;
            signalTree(p, signal_);
            break;
    }
}

@("Signal processes - signal directly to a process")
unittest {
    import beep;

    class MyProcess : Process {
        this(uint fatherId) {
            super(fatherId);
        }

        override int run() {
            return 0;
        }
    }

    auto p = new MyProcess(0);
    p.state.expect!equal(ProcessState.HOLD);
    signal(p, Signal.SLEEP);
    p.state.expect!equal(ProcessState.SLEEP);
    signal(p, Signal.FREEZE);
    p.state.expect!equal(ProcessState.FREEZE);
    signal(p, Signal.WAKEUP);
    p.state.expect!equal(ProcessState.HOLD);
    signal(p, Signal.KILL);
    p.state.expect!equal(ProcessState.DEAD);

    // Signaling a dead process, must not change his state from dead. Ie, forbiden necromancy
    signal(p, Signal.SLEEP);
    p.state.expect!equal(ProcessState.DEAD);
    signal(p, Signal.FREEZE);
    p.state.expect!equal(ProcessState.DEAD);
    signal(p, Signal.WAKEUP);
    p.state.expect!equal(ProcessState.DEAD);
}

@("Signal processes - process hierarchy")
unittest {
    import beep;
    import std.algorithm : each;

    class MyProcess : Process {
        this(uint fatherId) {
            super(fatherId);
        }

        override int run() {
            return 0;
        }
    }

    auto root = new MyProcess(0);
    auto lvl1 = [new MyProcess(root.id), new MyProcess(root.id), new MyProcess(root.id)];
    auto lvl2 = [new MyProcess(lvl1[0].id), new MyProcess(lvl1[0].id), new MyProcess(lvl1[0].id)];
    /*
                        Root
                /                       \                 \
           lvl1[0]                   lvl1[1]            lvl1[2]
        /         \         \
    lvl2[0]     lvl2[1]    lvl2[2]
    */

    // Signals that ignores hierarchy
    root.state.expect!equal(ProcessState.HOLD);

    signal(root.id, Signal.SLEEP);
    lvl1.each!(c => c.state.expect!equal(ProcessState.HOLD));
    root.state.expect!equal(ProcessState.SLEEP);

    signal(root.id, Signal.FREEZE);
    lvl1.each!(c => c.state.expect!equal(ProcessState.HOLD));
    root.state.expect!equal(ProcessState.FREEZE);

    signal(root.id, Signal.WAKEUP);
    lvl1.each!(c => c.state.expect!equal(ProcessState.HOLD));
    root.state.expect!equal(ProcessState.HOLD);

    // Signals that travels the hierarchy
    signal(root, Signal.SLEEP_TREE);
    lvl1.each!(c => c.state.expect!equal(ProcessState.SLEEP));
    lvl2.each!(c => c.state.expect!equal(ProcessState.SLEEP));
    root.state.expect!equal(ProcessState.SLEEP);

    signal(root, Signal.FREEZE_TREE);
    lvl1.each!(c => c.state.expect!equal(ProcessState.FREEZE));
    lvl2.each!(c => c.state.expect!equal(ProcessState.FREEZE));
    root.state.expect!equal(ProcessState.FREEZE);

    signal(root, Signal.WAKEUP_TREE);
    lvl1.each!(c => c.state.expect!equal(ProcessState.HOLD));
    lvl2.each!(c => c.state.expect!equal(ProcessState.HOLD));
    root.state.expect!equal(ProcessState.HOLD);

    signal(lvl1[0], Signal.SLEEP_TREE);
    root.state.expect!equal(ProcessState.HOLD);
    lvl1[1..$].each!(c => c.state.expect!equal(ProcessState.HOLD));
    lvl2.each!(c => c.state.expect!equal(ProcessState.SLEEP));
    lvl1[0].state.expect!equal(ProcessState.SLEEP);

    signal(lvl1[1], Signal.FREEZE_TREE);
    root.state.expect!equal(ProcessState.HOLD);
    lvl1[0].state.expect!equal(ProcessState.SLEEP);
    lvl1[1].state.expect!equal(ProcessState.FREEZE);
    lvl1[2].state.expect!equal(ProcessState.HOLD);
    lvl2.each!(c => c.state.expect!equal(ProcessState.SLEEP));

    // Signaling a direct signal to a father, don't affect childrens
    signal(lvl1[0], Signal.WAKEUP);
    root.state.expect!equal(ProcessState.HOLD);
    lvl1[0].state.expect!equal(ProcessState.HOLD);
    lvl2.each!(c => c.state.expect!equal(ProcessState.SLEEP));

    // Killing a tree
    signal(lvl1[0], Signal.KILL_TREE);
    root.state.expect!equal(ProcessState.HOLD);
    lvl1[0].state.expect!equal(ProcessState.DEAD);
    lvl2.each!(c => c.state.expect!equal(ProcessState.DEAD));

    // Signaling a dead process, must not change his state from dead. Ie, forbiden necromancy
    signal(root, Signal.WAKEUP_TREE);
    root.state.expect!equal(ProcessState.HOLD);
    lvl1[0].state.expect!equal(ProcessState.DEAD);
    lvl1[1..$].each!(c => c.state.expect!equal(ProcessState.HOLD));
    lvl2.each!(c => c.state.expect!equal(ProcessState.DEAD));
}


