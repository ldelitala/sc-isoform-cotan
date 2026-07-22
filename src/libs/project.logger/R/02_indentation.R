# ==============================================================================
# Indentation & Alignment Generator Functions
# ==============================================================================

# Generate standard tree indentation based on visible stack elements
.get_indent <- function() {
    stack <- .get_log_stack()
    if (length(stack) == 0) return("")
    
    current_level <- getOption("COTAN.LogLevel", default = 1L)
    
    # Only draw lines for headers at or below the current output level
    visible_stack <- stack[stack <= current_level]
    if (length(visible_stack) == 0) return("")
    
    indent_parts <- vapply(visible_stack, function(lvl) {
        if (current_level >= 3L) {
            paste0(.col_blue_bold(.get_theme("branch_vertical")), "   ")
        } else {
            paste0(.col_blue_bold(.get_theme("branch_space")), "   ")
        }
    }, character(1))
    
    paste0(indent_parts, collapse = "")
}

# Generate base indentation (excluding the last visible depth level)
# Used for branching lines like ┣━━ or ⇣
.get_indent_base <- function() {
    stack <- .get_log_stack()
    if (length(stack) == 0) return("")
    
    current_level <- getOption("COTAN.LogLevel", default = 1L)
    
    # Filter for visible stack elements
    visible_stack <- stack[stack <= current_level]
    
    # Drop the last visible element to get the base prefix
    if (length(visible_stack) <= 1) return("")
    visible_stack <- visible_stack[-length(visible_stack)]
    
    indent_parts <- vapply(visible_stack, function(lvl) {
        if (current_level >= 3L) {
            paste0(.col_blue_bold(.get_theme("branch_vertical")), "   ")
        } else {
            paste0(.col_blue_bold(.get_theme("branch_space")), "   ")
        }
    }, character(1))
    
    paste0(indent_parts, collapse = "")
}
