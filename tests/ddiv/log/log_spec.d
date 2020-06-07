/**
Test of logger
*/
module ddiv.log.log_spec;

import ddiv.log;

@("log")
unittest
{
    configLogger();

    log("Log");
    trace("Tracing");
    info("Info");
    warning("warn");
    error("error");
    critical("critical");
    //fatal("fatal");
}