# ==============================================================================
# Custom Logging Library - Core Functions
# ==============================================================================

#' Log an error message
#' @export
log_error <- function(msg, stop_exec = FALSE) {
    indent <- .get_indent()
    msg_formatted <- .col_red_bold(sprintf("❌ [ERROR] %s", msg))
    COTAN::logThis(paste0(indent, msg_formatted), logLevel = 0L)
    if (stop_exec) stop(msg, call. = FALSE)
}

#' Log a warning message
#' @export
log_warn <- function(msg, level = 0L) {
    indent <- .get_indent()
    msg_formatted <- .col_yellow(sprintf("⚠️ [WARNING] %s", msg))
    COTAN::logThis(paste0(indent, msg_formatted), logLevel = level)
}

#' Log an information message
#' @export
log_info <- function(msg, level = 2L) {
    indent <- .get_indent()
    msg_formatted <- .col_gray(sprintf("❖ %s", msg))
    COTAN::logThis(paste0(indent, msg_formatted), logLevel = level)
}

#' Log a statistical bullet point
#' @export
log_stat <- function(msg, level = 1L) {
    indent <- .get_indent()
    msg_formatted <- .col_cyan(sprintf(" » %s", msg))
    COTAN::logThis(paste0(indent, msg_formatted), logLevel = level)
}

#' Log a debug message
#' @export
log_debug <- function(msg, level = 3L) {
    indent <- .get_indent()
    msg_formatted <- .col_gray(sprintf(" [DEBUG] %s", msg))
    COTAN::logThis(paste0(indent, msg_formatted), logLevel = level)
}