module ddiv.log.consolelogger;

import std.experimental.logger;

/// Extends FileLogger to log only to stdout and colorize log level
class ConsoleLogger : FileLogger
{
    import std.concurrency : Tid;
    import std.datetime.systime : SysTime;
    import std.format : formattedWrite;

    this(const LogLevel lv = LogLevel.all)
    {
        import std.stdio : stdout;
        super(stdout, lv);
    }

    /* This method overrides the base class method in order to log to a file
    without requiring heap allocated memory. Additionally, the `FileLogger`
    local mutex is logged to serialize the log calls.
    */
    override protected void beginLogMsg(string file, int line, string funcName,
    string prettyFuncName, string moduleName, LogLevel logLevel,
    Tid threadId, SysTime timestamp, Logger logger)
    @safe
    {
        import std.string : lastIndexOf;
        ptrdiff_t fnIdx = file.lastIndexOf('/') + 1;
        ptrdiff_t funIdx = funcName.lastIndexOf('.') + 1;

        auto lt = this.file_.lockingTextWriter();
        systimeToISOString(lt, timestamp);

        colorizeLogLevel(lt, logLevel);
        formattedWrite(lt, " %s:%u:%s ", file[fnIdx .. $], line, funcName[funIdx .. $]);
    }

    private void colorizeLogLevel(Writer)(auto ref Writer lt, LogLevel logLevel) @safe
    {
        import std.conv : to;
        auto logLevelStr = logLevel.to!string;

        switch (logLevel) {

            case LogLevel.all:
            formattedWrite(lt, " [\033[1;37;40m%s\033[0m]     ", logLevelStr);
            break;

            case LogLevel.trace:
            formattedWrite(lt, " [\033[1;37;40m%s\033[0m]   ", logLevelStr);
            break;

            case LogLevel.info:
            formattedWrite(lt, " [\033[1;32;40m%s\033[0m]    ", logLevelStr);
            break;

            case LogLevel.warning:
            formattedWrite(lt, " [\033[1;33;40m%s\033[0m] ", logLevelStr);
            break;

            case LogLevel.error:
            formattedWrite(lt, " [\033[1;31;40m%s\033[0m]   ", logLevelStr);
            break;

            case LogLevel.critical:
            formattedWrite(lt, " [\033[1;37;41m%s\033[0m]", logLevelStr);
            break;

            case LogLevel.fatal:
            formattedWrite(lt, " [\033[1;25;37;41m%s\033[0m]   ", logLevelStr);
            break;

            default:
            formattedWrite(lt, " [\033[1;37;40m%s\033[0m]     ", logLevelStr);
        }
    }
}
