# ==============================================================================
# Custom Logging Library - Utilities & State (INTERNAL)
# ==============================================================================

# Hidden environment to store the indentation state
.log_state <- new.env(parent = emptyenv())
.log_state$depth <- 0

# --- Internal ANSI Color Helpers ---
.col_blue_bold   <- function(x) paste0("\033[1;34m", x, "\033[0m")
.col_green_bold  <- function(x) paste0("\033[1;32m", x, "\033[0m")
.col_red_bold    <- function(x) paste0("\033[1;31m", x, "\033[0m")
.col_yellow      <- function(x) paste0("\033[33m", x, "\033[0m")
.col_gray        <- function(x) paste0("\033[90m", x, "\033[0m")
.col_magenta     <- function(x) paste0("\033[35m", x, "\033[0m")
.col_cyan        <- function(x) paste0("\033[36m", x, "\033[0m")

# Generate standard tree indentation
.get_indent <- function() {
    if (.log_state$depth == 0) return("")
    if (getOption("COTAN.LogLevel", default = 1L) == 3L){
    colored_bar <- paste0(.col_blue_bold("┃"), "   ")
    paste0(rep(colored_bar, .log_state$depth), collapse = "")
    } else{
    colored_bar <- paste0(.col_blue_bold(" "), "   ")
    paste0(rep(colored_bar, .log_state$depth), collapse = "")
    }
    
}

# Generate base indentation (excluding the current depth level)
# Used for branching lines like ┣━━
.get_indent_base <- function() {
    if (.log_state$depth <= 1) return("")
    if (getOption("COTAN.LogLevel", default = 1L) == 3L){
    colored_bar <- paste0(.col_blue_bold("┃"), "   ")
    paste0(rep(colored_bar, .log_state$depth - 1), collapse = "")
    } else{
    colored_bar <- paste0(.col_blue_bold(" "), "   ")
    paste0(rep(colored_bar, .log_state$depth - 1), collapse = "")
    } 
}

#' Reset the logging state
#'
#' @description
#' Resets the internal indentation counter to zero. 
#' It is highly recommended to call this function at the very beginning 
#' of your main pipeline script to ensure a clean state, or after a manual interruption.
#'
#' @return No return value.
#' @export
reset_log_state <- function() {
    .log_state$depth <- 0
    invisible()
}