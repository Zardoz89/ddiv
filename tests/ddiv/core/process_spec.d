/**
Integration tests of Process and Scheduler 
*/
module ddiv.core.process_spec;

import core.thread.fiber;

import ddiv.core.process;
import ddiv.core.process_test_helper;
import ddiv.core.scheduler;

import pijamas;

@("Scheduling many process")
unittest {
    
    // describe("Creating a process, must initialized and don't autoexecute alone")
    {
        // given("Creating a process")
        auto p = new MyProcess!(100, 6)(0);

        // expect("must have some initial values")
        p.id.should.not.be.equal(0);
        p.state.should.be.equal(ProcessState.HOLD);
        p.fiberState.should.be.equal(Fiber.State.HOLD);

        // and("must not run the process itself")
        p.executeTimes.should.be.equal(0);

        // when("we execute an single iteration of the schdeuler")
        executeSchedulerNframes(1);

        // then("The process must has been executed one time and there isn't anymore process to execute on this frame")
        Scheduler.get().empty.should.be.False; // Must not delete the only process
        p.state.should.be.equal(ProcessState.HOLD);
        p.fiberState.should.be.equal(Fiber.State.HOLD);
        p._executed.should.be.True;
        Scheduler.get().hasProcessesToExecute().should.be.False; // The process has been executed
        p.executeTimes.should.be.equal(1);

        // when("we run enought scheduler iterations")
        executeSchedulerNframes(10);
        
        // then("the process must has been ended and removed from the schduler")
        Scheduler.get().empty.should.be.True; //  The process has been removed from the scheduler
        Scheduler.get().hasProcessesToExecute().should.be.False; // And so, there isn't any process to be executed
        p.state.should.be.equal(ProcessState.DEAD);
        p.fiberState.should.be.equal(Fiber.State.TERM);
        p.executeTimes.should.be.equal(6);
    }

    // describe("Yielding with frame > 100 must skip scheduler frames/iterations")
    {
        // given("Creating a process")
        auto p = new MyProcess!(400, 6)(0);

        // when("we execute an single iteration of the schdeuler")
        executeSchedulerNframes(1);

        // then("The process must has been executed one time and there isn't anymore process to execute on this frame")
        Scheduler.get().empty.should.be.False; // Must not delete the only process
        p.state.should.be.equal(ProcessState.HOLD);
        p.fiberState.should.be.equal(Fiber.State.HOLD);
        p._executed.should.be.True;
        Scheduler.get().hasProcessesToExecute().should.be.False; // The process has been executed
        p.executeTimes.should.be.equal(1);

        // expect("we execute again a single iteration of the scheduler, the process skips it four times")
        executeSchedulerNframes(1);
        p.executeTimes.should.be.equal(1);
        executeSchedulerNframes(1);
        p.executeTimes.should.be.equal(1);
        executeSchedulerNframes(1);
        p.executeTimes.should.be.equal(1);
        executeSchedulerNframes(1);
        p.executeTimes.should.be.equal(2);

        // when("we run enought scheduler iterations")
        executeSchedulerNframes(50);
        
        // then("the process must has been ended and removed from the schduler")
        Scheduler.get().empty.should.be.True; // The process has been removed from the scheduler
        p.state.should.be.equal(ProcessState.DEAD);
        p.fiberState.should.be.equal(Fiber.State.TERM);
        p.executeTimes.should.be.equal(6);
    }

    // describe("Yielding with frame < 100 must execute many times on a single frames/iterations")
    {
        // given("Creating a process")
        auto p = new MyProcess!(50, 6)(0);

        // when("we execute an single iteration of the schdeuler")
        executeSchedulerNframes(1);

        // then("The process must has been executed and there isn't anymore process to execute on this frame")
        Scheduler.get().empty.should.be.False; // Must not delete the only process
        p.state.should.be.equal(ProcessState.HOLD);
        p.fiberState.should.be.equal(Fiber.State.HOLD);
        p._executed.should.be.True;
        Scheduler.get().hasProcessesToExecute().should.be.False; // The process has been executed

        // and("The process must been execute more that a time")
        p.executeTimes.should.be.equal(2);

        // when("we run enought scheduler iterations")
        executeSchedulerNframes(50);
        
        // then("the process must has been ended and removed from the schduler")
        Scheduler.get().empty.should.be.True; // The process has been removed from the scheduler
        p.state.should.be.equal(ProcessState.DEAD);
        p.fiberState.should.be.equal(Fiber.State.TERM);
        p.executeTimes.should.be.equal(6);
    }
}

