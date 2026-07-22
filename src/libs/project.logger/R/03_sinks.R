# ==============================================================================
# Output Sinks (Console and File Redirection)
# ==============================================================================

#' Dispatch log string to console and file connections
#'
#' Prints message to console (with ANSI escape colors, no timestamps) if LogLevel is met, 
#' and writes it with timestamps (if configured) and without colors to the active COTAN log file.
#'
#' @param msg Character. The styled message string.
#' @param logLevel Integer. Log level threshold. Default is 1L.
#' @return Invisible TRUE.
#' @noRd
.write_log <- function(msg, logLevel = 1L) {
    # Get current log file connection from options
    log_conn <- getOption("COTAN.LogFile")
    
    # Get current COTAN.LogLevel
    current_level <- getOption("COTAN.LogLevel", default = 1L)
    
    # 1. Handle console output (No timestamp, prints with colors)
    if (current_level >= logLevel) {
        # message() automatically appends a newline and outputs to stderr,
        # making it perfectly compatible with suppressMessages().
        message(msg)
    }
    
    # 2. Handle file output (Clean text + timestamp if configured)
    if (!is.null(log_conn)) {
        # Strip ANSI escape codes using regex
        clean_msg <- gsub("\033\\[[0-9;]*m", "", msg)
        
        # Prepend timestamp if configured
        time_pos <- .get_theme("time_position")
        time_fmt <- .get_theme("time_format")
        
        if (time_fmt != "") {
            timestamp_str <- sprintf("[%s] ", format(Sys.time(), time_fmt))
            
            if (time_pos == "before_indent") {
                file_msg <- paste0(timestamp_str, clean_msg)
            } else if (time_pos == "after_indent") {
                # Calculate indentation length from active stack
                stack <- .get_log_stack()
                visible_stack <- stack[stack <= current_level]
                indent_len <- length(visible_stack) * 4
                
                if (indent_len > 0 && nchar(clean_msg) >= indent_len) {
                    indent_str <- substr(clean_msg, 1, indent_len)
                    content_str <- substr(clean_msg, indent_len + 1, nchar(clean_msg))
                    file_msg <- paste0(indent_str, timestamp_str, content_str)
                } else {
                    file_msg <- paste0(timestamp_str, clean_msg)
                }
            } else {
                file_msg <- clean_msg
            }
        } else {
            file_msg <- clean_msg
        }
        
        # Append to the connection
        cat(file_msg, "\n", file = log_conn, sep = "")
    }
    
    invisible(TRUE)
}
