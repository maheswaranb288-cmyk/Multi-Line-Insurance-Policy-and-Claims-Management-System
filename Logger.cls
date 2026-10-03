/**
 * Logger
 * -------------------------------------------------------------------------
 * Persistent logging to Apex_Log__c. System.debug() output is lost the moment
 * an async job ends; these rows survive so you can actually diagnose what a
 * Queueable or platform-event-driven flow did in production.
 *
 * Buffer, then flush() once at the end of a unit of work to stay bulk-safe.
 */
public with sharing class Logger {

    private static List<Apex_Log__c> buffer = new List<Apex_Log__c>();

    public static void info(String context, String message)  { add('INFO',  context, message, null); }
    public static void warn(String context, String message)  { add('WARN',  context, message, null); }
    public static void error(String context, String message, Exception ex) {
        add('ERROR', context, message, ex == null ? null : ex.getStackTraceString());
    }

    private static void add(String level, String context, String message, String stack) {
        buffer.add(new Apex_Log__c(
            Level__c       = level,
            Context__c     = context == null ? null : context.left(255),
            Message__c     = message,
            Stack_Trace__c = stack
        ));
    }

    /**
     * Persist buffered logs. Uses partial-success DML so a logging failure can
     * never roll back real business data.
     */
    public static void flush() {
        if (buffer.isEmpty()) {
            return;
        }
        try {
            Database.insert(buffer, false);
        } catch (Exception e) {
            // Never let logging throw.
            System.debug(LoggingLevel.ERROR, 'Logger.flush failed: ' + e.getMessage());
        } finally {
            buffer.clear();
        }
    }
}
