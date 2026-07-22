# ==============================================================================
# Header & Tree Boundary APIs
# ==============================================================================

#' Print a Formatted Header with Dynamic Clean Tree
#'
#' Prints structural header visual boundaries to frame pipeline phases. 
#' Manages the active indentation stack to align logs within tree branches.
#'
#' @param msg Character. The text message to display. Default is "".
#' @param is_complete Boolean. If TRUE, closes the block; if FALSE, opens it. Default is FALSE.
#' @param level Integer. Log level threshold. Default is 3L.
#' @return Invisible TRUE.
#' @export
log_header <- function(msg = "", is_complete = FALSE, level = 3L) {
    current_level <- getOption("COTAN.LogLevel", default = 1L)
    
    if (is_complete) {
        # Pop the last element off the stack
        .pop_log_level()
        
        # Only print the closing line if the header's level is visible
        if (current_level >= level) {
            indent <- .get_indent()
            msg_formatted <- .col_blue_bold(.get_theme("branch_end"))
            .write_log(paste0(indent, msg_formatted), logLevel = level)
        }
    } else {
        # Only print the starting line if the header's level is visible
        if (current_level >= level) {
            indent <- .get_indent()
            msg_formatted <- .col_blue_bold(sprintf("%s %s", .get_theme("branch_start"), toupper(msg)))
            .write_log(paste0(indent, msg_formatted), logLevel = level)
        }
        
        # Push the level onto the stack (always track it!)
        .push_log_level(level)
    }
}
