module ddiv.log.patternfilelogger;

import std.experimental.logger;
import std.stdio;

private enum PatternToken = '%';

/// Default formating pattern - 2020-06-08T17:50:25.673 [info] __FILE__:__LINE__:__FUNC_NAME__
enum string defaultPattern = "%d [%p] %F:%L:%M ";
/// A simple pattern -  020-06-08T17:50:25.673 info     :
enum string simplePattern = "%d %-8p: ";

/**
 * Extends FileLogger to support configurable format
 *
 * The pattern it's a subset of log4j pattern layout format:
 * | Conversion Character | Effect |
 * | -------------------- | -----: |
 * | c | Module name (category on log4j parlance) |
 * | d | Used to output the date of the logging event. Actually only outputs on ISO format |
 * | F | Used to output the file name where the logging request was issued. |
 * | L | Used to output the line number from where the logging request was issued. | 
 * | M | Used to output the function or method name where the logging request was issued. |
 * | p | Used to output the priority of the logging event. |
 * | t | Used to output the thread that generated the logging event. |
 */
class PatternFileLogger : FileLogger
{
    import std.concurrency : Tid;
    import std.datetime.systime : SysTime;
    import std.format : formattedWrite;

    /** A constructor for the `FileLogger` Logger.
    Params:
      fn = The filename of the output file of the `FileLogger`. If that
      file can not be opened for writting an exception will be thrown.
      lv = The `LogLevel` for the `FileLogger`. By default the
      pattern = A string with the format pattern preceding the logging message
    Example:
    -------------
    auto l1 = new FileLogger("logFile");
    auto l2 = new FileLogger("logFile", LogLevel.fatal);
    auto l3 = new FileLogger("logFile", LogLevel.fatal, CreateFolder.yes);
    -------------
    */
    this(const string fn, const LogLevel lv = LogLevel.all, const string pattern = defaultPattern) @safe
    {
         this(fn, lv, pattern, CreateFolder.yes);
    }

    /** A constructor for the `FileLogger` Logger that takes a reference to
    a `File`.
    The `File` passed must be open for all the log call to the
    `FileLogger`. If the `File` gets closed, using the `FileLogger`
    for logging will result in undefined behaviour.
    Params:
      fn = The file used for logging.
      lv = The `LogLevel` for the `FileLogger`. By default the
      `LogLevel` for `FileLogger` is `LogLevel.all`.
      createFileNameFolder = if yes and fn contains a folder name, this
      folder will be created.
      pattern = A string with the format pattern preceding the logging message
    Example:
    -------------
    auto file = File("logFile.log", "w");
    auto l1 = new FileLogger(file);
    auto l2 = new FileLogger(file, LogLevel.fatal);
    -------------
    */
    this(const string fn, const LogLevel lv, const string pattern, CreateFolder createFileNameFolder) @safe
    {
        super(fn, lv, createFileNameFolder);
        this.pattern = pattern;
    }

    /** A constructor for the `FileLogger` Logger that takes a reference to
    a `File`.
    The `File` passed must be open for all the log call to the
    `FileLogger`. If the `File` gets closed, using the `FileLogger`
    for logging will result in undefined behaviour.
    Params:
      file = The file used for logging.
      lv = The `LogLevel` for the `FileLogger`. By default the
      `LogLevel` for `FileLogger` is `LogLevel.all`.
      pattern = A string with the format pattern preceding the logging message
    Example:
    -------------
    auto file = File("logFile.log", "w");
    auto l1 = new FileLogger(file);
    auto l2 = new FileLogger(file, LogLevel.fatal);
    -------------
    */
    this(File file, const LogLevel lv = LogLevel.all, const string pattern = defaultPattern) @safe
    {
        super(file, lv);
        this.pattern = pattern;
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
        import std.uni : byCodePoint;
        this.parsePattern(lt, pattern.byCodePoint, file[fnIdx .. $], line, funcName[funIdx .. $], prettyFuncName,
            moduleName, logLevel, threadId, timestamp);
    }

    import std.range : isOutputRange, isInputRange;

    /**
     * Generates a string representation of the log level
     * Params:
     *  file = The log level to format to string
     *  truncate = Max number of characters allowed on result string
     */
    protected string logLevelToString(const LogLevel logLevel, size_t truncate) @trusted
    {
        import std.conv : to;
        string str = logLevel.to!string;
        if (str.length > truncate) {
            str.length = truncate;
        }
        return str;
    }

    private void parsePattern(OutputRange, InputRange)(OutputRange outputRange, InputRange patternRange, string file,
        int line, string funcName, string prettyFuncName, string moduleName, LogLevel logLevel, Tid threadId, 
        SysTime timestamp ) @trusted
    if (isOutputRange!(OutputRange, char) && isInputRange!(InputRange))
    {
        // Outputs anything before finding the '%' format special character
        while(!patternRange.empty && patternRange.front != PatternToken) {
            outputRange.put(patternRange.front);
            patternRange.popFront;
        }
        if (patternRange.empty) {
            return;
        }
        patternRange.popFront; // And consumes the '%'

        auto modifier = this.formatModifier!(InputRange)(patternRange);

        // Value stores the output string
        string value;
        if (patternRange.front == '%') { // The sequence %% outputs a single percent sign. 
            outputRange.put('%');
            patternRange.popFront;
        } else if (patternRange.front == 'c') { // Module name (category on log4j parlance)
            value = moduleName;
            patternRange.popFront;
        } else if (patternRange.front == 'd') { // Date on ISO format
            outputRange.systimeToISOString(timestamp);
            patternRange.popFront;
        } else if (patternRange.front == 'p') { // priority of log level
            value = this.logLevelToString(logLevel, modifier[1]);
            patternRange.popFront;
        } else if (patternRange.front == 'F') { // Filename
            value = file;
            patternRange.popFront;
        } else if (patternRange.front == 'L') { // Lines
            import std.conv : to;
            value = line.to!string;
            patternRange.popFront;
        } else if (patternRange.front == 'M') { // Function/Method where the logging was issued
            value = funcName;
            patternRange.popFront;
        } else if (patternRange.front == 't') { // name of the thread that generated the logging event.
            import std.conv : to;
            value = threadId.to!string;
            patternRange.popFront;
        }
        // unsuported formats are we simply ignored

        if (value.length > 0) {
            outputRange.writeWithModifier(value, modifier[0], modifier[1]);
        }

        // Iterate for the next pattern token
        if (!patternRange.empty) {
            this.parsePattern(outputRange, patternRange, file, line, funcName, prettyFuncName, moduleName, 
                logLevel, threadId, timestamp);
        }
    }

    private auto formatModifier(InputRange)(ref InputRange patternRange)
        if (isInputRange!(InputRange))
    {
        import std.ascii : isDigit;
        import std.typecons : Tuple, tuple;
        Tuple!(int, size_t) modifier = tuple(0, size_t.max);

        // Get the padding modifier
        if (patternRange.front == '+' || patternRange.front == '-' || patternRange.front.isDigit) {
            import std.conv : parse;
            try {
                modifier[0] = patternRange.parse!int;
            } catch (std.conv.ConvException ex) {
                // Silently we ignore it
            }
        }
        // Get the truncate modifier
        if (patternRange.front == '.') {
            patternRange.popFront; // Consume the '.' separator
            if (patternRange.front.isDigit) {
                import std.conv : parse;
                try {
                    modifier[1] = patternRange.parse!size_t;
                } catch (std.conv.ConvException ex) {
                    // Silently we ignore it
                }
            }
        }
        return modifier;
    }

    protected string pattern;
}

import std.range : isOutputRange;

// writes to the output the value with the padding and truncation
private void writeWithModifier(OutputRange)(OutputRange outputRange, string value, int padding, size_t truncate)
    if (isOutputRange!(OutputRange, char))
{
    if (padding > 0) {
        // left padd
        padding -= value.length;
        while(padding > 0) {
            outputRange.put(' ');
            padding--;
        }
    }
    import std.format : formattedWrite;
    if (truncate != size_t.max && truncate < value.length) {
        outputRange.formattedWrite("%s", value[0..truncate]);
    } else {
        outputRange.formattedWrite("%s", value);
    }
    if (padding < 0) {
        // right padd
        padding += value.length;
        while(padding < 0) {
            outputRange.put(' ');
            padding++;
        }
    }
}

