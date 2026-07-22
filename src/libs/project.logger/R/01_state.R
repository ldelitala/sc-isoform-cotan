# ==============================================================================
# Internal State Management (Hidden Environment)
# ==============================================================================

# Hidden environment to store the log indentation stack
.log_state <- new.env(parent = emptyenv())
.log_state$depth_stack <- integer(0)

#' Reset the Logging State
#'
#' Resets the internal depth stack to empty. Call this at the start of pipeline workflows
#' or inside error handling exits to restore normal root indentation.
#'
#' @return Invisible NULL.
#' @export
reset_log_state <- function() {
    .log_state$depth_stack <- integer(0)
    invisible()
}

#' Push log level onto the depth stack
#' @param level Integer. Log level threshold of the opened block.
#' @noRd
.push_log_level <- function(level) {
    .log_state$depth_stack <- c(.log_state$depth_stack, as.integer(level))
    invisible()
}

#' Pop the last log level off the depth stack
#' @noRd
.pop_log_level <- function() {
    stack <- .log_state$depth_stack
    if (length(stack) > 0) {
        .log_state$depth_stack <- stack[-length(stack)]
    }
    invisible()
}

#' Retrieve the active log depth stack
#' @return Integer vector.
#' @noRd
.get_log_stack <- function() {
    return(.log_state$depth_stack)
}
