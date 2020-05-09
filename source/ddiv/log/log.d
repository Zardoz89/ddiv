module ddiv.log.log;

public import std.experimental.logger;

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
    multiLogger.insertLogger("console", new ConsoleLogger(consoleLogLevel));
    multiLogger.insertLogger("file", new FileLogger(outputFile, LogLevel.all));

    sharedLog = multiLogger;
}
