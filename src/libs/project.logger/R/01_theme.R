# ==============================================================================
# Theme & Layout Customization Module
# ==============================================================================

# Hidden environment for theme settings
.log_theme <- new.env(parent = emptyenv())

# Default theme settings
.log_theme$info_prefix     <- "❖ "
.log_theme$warn_prefix     <- "⚠️ [WARNING] "
.log_theme$error_prefix    <- "❌ [ERROR] "
.log_theme$stat_prefix     <- " » "
.log_theme$debug_prefix    <- " [DEBUG] "
.log_theme$branch_vertical <- "┃"
.log_theme$branch_space    <- " "
.log_theme$branch_start    <- "┏━━"
.log_theme$branch_end      <- "┗━━"
.log_theme$exec_start      <- "▶"
.log_theme$exec_done       <- "✔ Done."
.log_theme$exec_arrow_down <- "⇣"
.log_theme$exec_arrow_up   <- "⇡"
.log_theme$bullet          <- "◦"

# Timestamp settings
.log_theme$time_format     <- "%Y-%m-%d %H:%M:%S"
.log_theme$time_position   <- "before_indent"

#' Set or Modify Logging Theme Properties
#'
#' Customize prefix layouts, branch styles, execution markers, or time formats dynamically.
#'
#' @param ... Named theme property-value pairs (e.g., info_prefix = "INFO: ").
#' @return Invisible NULL.
#' @export
set_log_theme <- function(...) {
    args <- list(...)
    for (name in names(args)) {
        if (exists(name, envir = .log_theme)) {
            assign(name, args[[name]], envir = .log_theme)
        } else {
            warning(sprintf("Theme property '%s' is not recognized.", name))
        }
    }
    invisible()
}

#' Retrieve theme property value
#'
#' @param name Character. Property key name.
#' @return Character value or empty string.
#' @noRd
.get_theme <- function(name) {
    if (exists(name, envir = .log_theme)) {
        return(get(name, envir = .log_theme))
    }
    return("")
}
