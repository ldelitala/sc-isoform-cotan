#' Generate a Fixed-Width Decorative Ribbon
#'
#' @description
#' Creates a string consisting of a message followed by a repeated character
#' ribbon, padding the total length to a specified width. This is used for
#' formatting log headers and visual separators in the console output.
#'
#' @param msg Character. The text message to be displayed.
#' @param char Character. The character used to draw the ribbon. Default is `"="`.
#' @param total_width Integer. The target total width of the string. Default is `80`.
#'
#' @return A character string of length `total_width` (or `nchar(msg)` if
#'   `msg` exceeds `total_width`).
#'
#' @examples
#' # Internal usage:
#' # add_ribbon("== [ STARTING PROCESS ] ", char = "=", total_width = 80)
#'
.add_ribbon <- function(msg, char = "=", total_width = 80) {
    return(sprintf("%s%s", msg, paste0(rep(char, max(0, total_width - nchar(msg))), collapse = "")))
}
