module ddiv.log.log;

public import std.experimental.logger;
import logger;

/**
 * Configures the engine logger, reaplacing the default sharedLog by a multiLogger to stdout and to a file
 * Params:
 *  outputFile : Output file of the file logger. By default is "ddiv.log"
 *  consoleLogLevel : Console (stdout) log level. By default is LogLevel.info
 */
void configLogger(string outputFile = "ddiv.log", LogLevel consoleLogLevel = LogLevel.info) {
    auto multiLogger = new MultiLogger();
    multiLogger.insertLogger("console", new ConsoleLogger(consoleLogLevel));

    import std.stdio : File;

    auto file = File(outputFile, "w");

    multiLogger.insertLogger("file", new ExtendedFileLogger(file, LogLevel.all,
            new ConfigurableLogPattern(simplePattern)));

    sharedLog = multiLogger;
}
