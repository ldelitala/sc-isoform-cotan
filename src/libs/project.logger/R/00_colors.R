# ==============================================================================
# Internal ANSI Color Helpers
# ==============================================================================

#' Wrap text in blue bold ANSI escape code
#' @param x Character string.
#' @noRd
.col_blue_bold   <- function(x) paste0("\033[1;34m", x, "\033[0m")

#' Wrap text in green bold ANSI escape code
#' @param x Character string.
#' @noRd
.col_green_bold  <- function(x) paste0("\033[1;32m", x, "\033[0m")

#' Wrap text in green dim ANSI escape code
#' @param x Character string.
#' @noRd
.col_green_dim   <- function(x) paste0("\033[32m", x, "\033[0m")

#' Wrap text in red bold ANSI escape code
#' @param x Character string.
#' @noRd
.col_red_bold    <- function(x) paste0("\033[1;31m", x, "\033[0m")

#' Wrap text in yellow ANSI escape code
#' @param x Character string.
#' @noRd
.col_yellow      <- function(x) paste0("\033[33m", x, "\033[0m")

#' Wrap text in gray ANSI escape code
#' @param x Character string.
#' @noRd
.col_gray        <- function(x) paste0("\033[90m", x, "\033[0m")

#' Wrap text in magenta ANSI escape code
#' @param x Character string.
#' @noRd
.col_magenta     <- function(x) paste0("\033[35m", x, "\033[0m")

#' Wrap text in cyan ANSI escape code
#' @param x Character string.
#' @noRd
.col_cyan        <- function(x) paste0("\033[36m", x, "\033[0m")

# --- New Custom Colors for Premium Themes ---

#' Wrap text in 256-color orange dim ANSI escape code
#' @param x Character string.
#' @noRd
.col_orange_dim  <- function(x) paste0("\033[38;5;172m", x, "\033[0m")

#' Wrap text in 256-color orange bold ANSI escape code
#' @param x Character string.
#' @noRd
.col_orange_bold <- function(x) paste0("\033[1;38;5;208m", x, "\033[0m")

#' Wrap text in magenta bold ANSI escape code
#' @param x Character string.
#' @noRd
.col_magenta_bold <- function(x) paste0("\033[1;35m", x, "\033[0m")

#' Wrap text in cyan bold ANSI escape code
#' @param x Character string.
#' @noRd
.col_cyan_bold   <- function(x) paste0("\033[1;36m", x, "\033[0m")
