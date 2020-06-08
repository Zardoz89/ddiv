module ddiv.log.consolelogger;

import std.experimental.logger;
import ddiv.log.patternfilelogger;

/// Extends PatternFileLogger to log only to stdout and colorize log level
class ConsoleLogger : PatternFileLogger
{
    import std.concurrency : Tid;
    import std.datetime.systime : SysTime;
    import std.format : formattedWrite;

    this(const LogLevel lv = LogLevel.all, const string pattern = defaultPattern)
    @trusted
    {
        import std.stdio : stdout;
        super(stdout, lv, pattern);
    }
    /**
     * Generates a string representation of the log level
     * Params:
     *  file = The log level to format to string
     *  truncate = Max number of characters allowed on result string
     */
    override protected string logLevelToString(const LogLevel logLevel, size_t truncate) @trusted
    {
        import std.conv : to;
        string str = logLevel.to!string;
        if (str.length > truncate) {
            str.length = truncate;
        }
        import std.format : format;
        switch (logLevel) {

            case LogLevel.all:
            str = format!"\033[1;37;40m%s\033[0m"(str);
            break;

            case LogLevel.trace:
            str = format!"\033[1;37;40m%s\033[0m"(str);
            break;

            case LogLevel.info:
            str = format!"\033[1;32;40m%s\033[0m"(str);
            break;

            case LogLevel.warning:
            str = format!"\033[1;33;40m%s\033[0m"(str);
            break;

            case LogLevel.error:
            str = format!"\033[1;31;40m%s\033[0m"(str);
            break;

            case LogLevel.critical:
            str = format!"\033[1;37;40m%s\033[0m"(str);
            break;

            case LogLevel.fatal:
            str = format!"\033[1:25;37;41m%s\033[0m"(str);
            break;

            default:
            str = format!"\033[1;37;40m%s\033[0m"(str);
        }
        return str;
    }
}
