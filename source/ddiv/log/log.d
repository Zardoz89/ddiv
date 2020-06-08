module ddiv.log.log;

public import std.experimental.logger;
import ddiv.log.patternfilelogger;

/**
 * Configures the engine logger, reaplacing the default sharedLog by a multiLogger to stdout and to a file
 * Params:
 *  outputFile : Output file of the file logger. By default is "ddiv.log"
 *  consoleLogLevel : Console (stdout) log level. By default is LogLevel.info
 */
void configLogger(string outputFile = "ddiv.log", LogLevel consoleLogLevel = LogLevel.info)
{
    import ddiv.log.consolelogger;

    auto multiLogger = new MultiLogger();
    multiLogger.insertLogger("console", new ConsoleLogger(consoleLogLevel, simplePattern));
    multiLogger.insertLogger("file", new PatternFileLogger(outputFile, LogLevel.all, simplePattern));

    sharedLog = multiLogger;
}
