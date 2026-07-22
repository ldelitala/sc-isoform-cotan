# ==============================================================================
# Core Logging Level APIs
# ==============================================================================

#' Log an Error Message
#'
#' Formats and prints an error message to console and file, optionally halting execution.
#'
#' @param msg Character. Error message.
#' @param stop_exec Boolean. If TRUE, calls stop() to halt execution. Default is FALSE.
#' @return Invisible TRUE or stops execution.
#' @export
log_error <- function(msg, stop_exec = FALSE) {
    indent <- .get_indent()
    msg_formatted <- .col_red_bold(paste0(.get_theme("error_prefix"), msg))
    .write_log(paste0(indent, msg_formatted), logLevel = 0L)
    if (stop_exec) stop(msg, call. = FALSE)
}

#' Log a Warning Message
#'
#' Formats and prints a warning message to console and file.
#'
#' @param msg Character. Warning message.
#' @param level Integer. Log level threshold. Default is 0L.
#' @return Invisible TRUE.
#' @export
log_warn <- function(msg, level = 0L) {
    indent <- .get_indent()
    msg_formatted <- .col_yellow(paste0(.get_theme("warn_prefix"), msg))
    .write_log(paste0(indent, msg_formatted), logLevel = level)
}

#' Log an Information Message
#'
#' Formats and prints an info message to console and file.
#'
#' @param msg Character. Information message.
#' @param level Integer. Log level threshold. Default is 2L.
#' @return Invisible TRUE.
#' @export
log_info <- function(msg, level = 2L) {
    indent <- .get_indent()
    msg_formatted <- .col_gray(paste0(.get_theme("info_prefix"), msg))
    .write_log(paste0(indent, msg_formatted), logLevel = level)
}

#' Log a Statistical Bullet Point
#'
#' Formats and prints a statistics summary bullet to console and file.
#'
#' @param msg Character. Statistics summary.
#' @param level Integer. Log level threshold. Default is 1L.
#' @return Invisible TRUE.
#' @export
log_stat <- function(msg, level = 1L) {
    indent <- .get_indent()
    msg_formatted <- .col_cyan(paste0(.get_theme("stat_prefix"), msg))
    .write_log(paste0(indent, msg_formatted), logLevel = level)
}

#' Log a Debug Message
#'
#' Formats and prints a debug message to console and file.
#'
#' @param msg Character. Debug message.
#' @param level Integer. Log level threshold. Default is 3L.
#' @return Invisible TRUE.
#' @export
log_debug <- function(msg, level = 3L) {
    indent <- .get_indent()
    msg_formatted <- .col_gray(paste0(.get_theme("debug_prefix"), msg))
    .write_log(paste0(indent, msg_formatted), logLevel = level)
}
