# Custom Logging Library - Ribbon & Bracket Style

# ==============================================================================
# PRIVATE HELPERS (Not exported, internal use only)
# ==============================================================================

# Generates a fixed-width decorative ribbon
make_ribbon <- function(msg, char = "=", total_width = 80) {
    # Calculate space occupied by "== [ " + msg + " ] "
    base_len <- nchar(msg) + 7
    pad_len <- max(0, total_width - base_len)
    paste0(rep(char, pad_len), collapse = "")
}

# ==============================================================================
# EXPORTED FUNCTIONS
# ==============================================================================

# --- LEVEL 0 (MUST) ---

#' Log an error message
#'
#' Prints a formatted error message using the COTAN logging function.
#'
#' @param msg Character. The error message to log.
#' @param stop_exec Logical. If `TRUE`, terminates execution with `stop()`. Default `FALSE`.
#' @return No return value (called for side effects).
#' @export
log_error <- function(msg, stop_exec = FALSE) {
    COTAN::logThis(sprintf("❌ [ERROR] %s", msg), logLevel = 0L)
    if (stop_exec) {
        stop(msg, call. = FALSE)
    }
}

#' Log a warning message
#'
#' Prints a formatted warning message.
#'
#' @param msg Character. The warning message to log.
#' @param level Integer. Logging level for COTAN. Default `0L`.
#' @return No return value.
#' @export
log_warn <- function(msg, level = 0L) {
    COTAN::logThis(sprintf("⚠️ [WARNING] %s", msg), logLevel = level)
}

# --- LEVEL 1 (HEADER) ---

#' Print a formatted header
#'
#' Useful for separating important sections in the log. Headers can be
#' start-of-section or completion messages.
#'
#' @param msg Character. The text of the header.
#' @param is_complete Logical. If `TRUE`, prints a completion footer with
#'   different characters. Default `FALSE`.
#' @param level Integer. Logging level for COTAN. Default `1L`.
#' @return No return value.
#' @export
log_header <- function(msg, is_complete = FALSE, level = 1L) {
    if (is_complete) {
        ribbon <- make_ribbon(msg, char = "-")
        COTAN::logThis(sprintf("-- [ %s ] %s\n\n", msg, ribbon), logLevel = level)
    } else {
        msg_up <- toupper(msg)
        ribbon <- make_ribbon(msg_up, char = "=")
        COTAN::logThis(sprintf("== [ %s ] %s\n", msg_up, ribbon), logLevel = level)
    }
}

# --- LEVEL 2 (INFO) ---

#' Log an information message
#'
#' @param msg Character. The information message.
#' @param level Integer. Logging level for COTAN. Default `2L`.
#' @return No return value.
#' @export
log_info <- function(msg, level = 2L) {
    COTAN::logThis(sprintf("> %s", msg), logLevel = level)
}

#' Log a statistical bullet point
#'
#' @param msg Character. The message to log as a bullet point.
#' @param level Integer. Logging level for COTAN. Default `2L`.
#' @return No return value.
#' @export
log_stat <- function(msg, level = 2L) {
    COTAN::logThis(sprintf("  * %s", msg), logLevel = level)
}

#' Handle the start and end of a function execution
#'
#' Logs a formatted start or end message for a COTAN function.
#'
#' @param func_name Character. The name of the function.
#' @param is_complete Logical. If `TRUE`, prints a completion footer with
#'   different characters. Default `FALSE`.
#' @param level Integer. Logging level for COTAN. Default `2L`.
#' @return No return value.
#' @export
log_cotan_execution <- function(func_name, is_complete = FALSE, level = 2L) {
    msg_base <- sprintf(".:: Executing %s ::.", func_name)

    if (!is_complete) {
        COTAN::logThis(msg_base, logLevel = level)
    } else {
        dots <- paste0(rep(".", nchar(msg_base)), collapse = "")
        COTAN::logThis(paste0(dots, "\n"), logLevel = level)
    }
}

# --- LEVEL 3 (DEBUG) ---

#' Log a debug message
#'
#' @param msg Character. The debug message.
#' @param level Integer. Logging level for COTAN. Default `3L`.
#' @return No return value.
#' @export
log_debug <- function(msg, level = 3L) {
    COTAN::logThis(sprintf("  [DEBUG] %s", msg), logLevel = level)
}
