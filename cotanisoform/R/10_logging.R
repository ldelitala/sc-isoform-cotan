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
# ==============================================================================
# Output Sinks (Console and File Redirection)
# ==============================================================================

#' Dispatch log string to console and file connections
#'
#' Prints message to console (with ANSI escape colors, no timestamps) if LogLevel is met, 
#' and writes it with timestamps (if configured) and without colors to the active COTAN log file.
#'
#' @param msg Character. The styled message string.
#' @param logLevel Integer. Log level threshold. Default is 1L.
#' @return Invisible TRUE.
#' @noRd
.write_log <- function(msg, logLevel = 1L) {
    # Get current log file connection from options
    log_conn <- getOption("COTAN.LogFile")
    
    # Get current COTAN.LogLevel
    current_level <- getOption("COTAN.LogLevel", default = 1L)
    
    # 1. Handle console output (No timestamp, prints with colors)
    if (current_level >= logLevel) {
        # message() automatically appends a newline and outputs to stderr,
        # making it perfectly compatible with suppressMessages().
        message(msg)
    }
    
    # 2. Handle file output (Clean text + timestamp if configured)
    if (!is.null(log_conn)) {
        # Strip ANSI escape codes using regex
        clean_msg <- gsub("\033\\[[0-9;]*m", "", msg)
        
        # Prepend timestamp if configured
        time_pos <- .get_theme("time_position")
        time_fmt <- .get_theme("time_format")
        
        if (time_fmt != "") {
            timestamp_str <- sprintf("[%s] ", format(Sys.time(), time_fmt))
            
            if (time_pos == "before_indent") {
                file_msg <- paste0(timestamp_str, clean_msg)
            } else if (time_pos == "after_indent") {
                # Calculate indentation length from active stack
                stack <- .get_log_stack()
                visible_stack <- stack[stack <= current_level]
                indent_len <- length(visible_stack) * 4
                
                if (indent_len > 0 && nchar(clean_msg) >= indent_len) {
                    indent_str <- substr(clean_msg, 1, indent_len)
                    content_str <- substr(clean_msg, indent_len + 1, nchar(clean_msg))
                    file_msg <- paste0(indent_str, timestamp_str, content_str)
                } else {
                    file_msg <- paste0(timestamp_str, clean_msg)
                }
            } else {
                file_msg <- clean_msg
            }
        } else {
            file_msg <- clean_msg
        }
        
        # Append to the connection
        cat(file_msg, "\n", file = log_conn, sep = "")
    }
    
    invisible(TRUE)
}
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
# ==============================================================================
# Execution Block Logger APIs
# ==============================================================================

#' Handle the Start and End of an Execution Block
#'
#' Prints function execution start sequences with parameters or completion indicators 
#' in a tree-aligned layout.
#'
#' @param func_name Character. Name of the function/process.
#' @param ... Optional parameters passed to the function, printed as key-value pairs.
#' @param is_complete Boolean. If TRUE, logs completion; if FALSE, logs start. Default is FALSE.
#' @param level Integer. Log level threshold. Default is 1L.
#' @return Invisible TRUE.
#' @export
log_cotan_execution <- function(func_name, ..., is_complete = FALSE, level = 2L) {
    base_indent <- .get_indent_base()
    
    if (!is_complete) {
        # 1. Sostituisce l'ultimo livello dell'albero con la freccia verso il basso
        arrows_down <- paste0(.col_blue_bold(.get_theme("exec_arrow_down")), "   ")
        msg_exec <- .col_magenta(sprintf("%s %s", .get_theme("exec_start"), func_name))
        .write_log(paste0(base_indent, arrows_down, msg_exec), logLevel = level)
        
        # 2. Formatta e stampa i parametri (se presenti) nel varco appena aperto
        params <- list(...)
        if (length(params) > 0) {
            param_names <- names(params)
            if (is.null(param_names) || any(param_names == "")) {
                param_names[param_names == ""] <- "unnamed"
            }
            
            # Formattazione con colori separati per Chiave e Valore
            formatted_pairs <- vapply(seq_along(params), function(i) {
                val <- params[[i]]
                val_str <- if (is.null(val)) "NULL" else paste(as.character(val), collapse = ",")
                
                key_colored <- .col_gray(param_names[i])
                val_colored <- .col_cyan(val_str)
                
                sprintf("%s: %s", key_colored, val_colored)
            }, character(1))
            
            # Il simbolo bullet colorato di grigio come separatore
            sep_symbol <- .col_gray(sprintf(" %s ", .get_theme("bullet")))
            # Aggiunge 2 spazi per spingere l'indentazione più all'interno
            msg_params <- paste0("  ", .col_gray(paste0(.get_theme("bullet"), " ")), paste(formatted_pairs, collapse = sep_symbol))
            
            param_indent <- paste0(base_indent, "    ") 
            .write_log(paste0(param_indent, msg_params), logLevel = level)
        }
        
    } else {
        # 3. Sostituisce l'ultimo livello dell'albero con la freccia verso l'alto
        arrows_up <- paste0(.col_blue_bold(.get_theme("exec_arrow_up")), "   ")
        msg_done <- .col_magenta(.get_theme("exec_done"))
        .write_log(paste0(base_indent, arrows_up, msg_done), logLevel = level)
    }
}
# ==============================================================================
# Matrix Stats Logger APIs
# ==============================================================================

#' Log Matrix Filtering Statistics
#'
#' Prints structured, aligned bracket tables showing cell and feature variations 
#' before and after filtering operations.
#'
#' @param cells_before Integer. Number of cells before filtering.
#' @param cells_after Integer. Number of cells after filtering. Default is NULL.
#' @param features_before Integer. Number of features before filtering. Default is NULL.
#' @param features_after Integer. Number of features after filtering. Default is NULL.
#' @param level Integer. Log level threshold. Default is 1L.
#' @return Invisible NULL.
#' @export
log_matrix_stats <- function(cells_before, cells_after = NULL, features_before = NULL, features_after = NULL, level = 1L) {
    # Helper to format numbers with thousands separator
    fmt_num <- function(x) {
        format(as.numeric(x), big.mark = ",", scientific = FALSE, trim = TRUE)
    }
    
    # Helper to center text in a column of a given width
    center_text <- function(text, width = 14) {
        pad <- max(0, width - nchar(text))
        left <- floor(pad / 2)
        right <- ceiling(pad / 2)
        paste0(strrep(" ", left), text, strrep(" ", right))
    }
    
    # Helper to construct delta string (difference indicator)
    get_delta_str <- function(before, after) {
        diff <- before - after
        if (diff == 0) {
            return("0")
        } else if (diff > 0) {
            return(sprintf("▼ %s ▼", fmt_num(diff)))
        } else {
            return(sprintf("▲ %s ▲", fmt_num(abs(diff))))
        }
    }
    
    # Check if we should display the variation or just a snapshot
    showing_variation <- (!is.null(cells_before) && !is.null(cells_after)) ||
                         (!is.null(features_before) && !is.null(features_after))

    # Fill in defaults if arguments are missing/NULL
    if (is.null(features_before)) features_before <- 0
    if (is.null(features_after)) features_after <- features_before
    if (is.null(cells_before)) cells_before <- 0
    if (is.null(cells_after)) cells_after <- cells_before

    # Define alignment variables
    col_width    <- 14
    lbl_cells    <- center_text("Cells", col_width)
    lbl_features <- center_text("Features", col_width)
    
    old_cells    <- center_text(fmt_num(cells_before), col_width)
    old_features <- center_text(fmt_num(features_before), col_width)

    # Gray bracket components
    b_tl <- .col_gray("  ⎡ ")
    b_tr <- .col_gray(" ⎤")
    b_ml <- .col_gray("  ⎢ ")
    b_mr <- .col_gray(" ⎥")
    b_bl <- .col_gray("  ⎣ ")
    b_br <- .col_gray(" ⎦")
    
    sep  <- "   " # Fixed spacer between columns
    
    # Write a formatted matrix line with tree indentation
    print_matrix_line <- function(line) {
        indent <- .get_indent()
        .write_log(paste0(indent, line), logLevel = level)
    }

    if (showing_variation) {
        log_info("Matrix variation:", level = level)
        
        delta_cells    <- center_text(get_delta_str(cells_before, cells_after), col_width)
        delta_features <- center_text(get_delta_str(features_before, features_after), col_width)
        
        new_cells      <- center_text(fmt_num(cells_after), col_width)
        new_features   <- center_text(fmt_num(features_after), col_width)
        
        # Color scheme: Orange dim (top), Gray (old), Magenta bold (delta), Orange bold (new)
        line1 <- paste0(b_tl, .col_orange_dim(lbl_cells), sep, .col_orange_dim(lbl_features), b_tr)
        line2 <- paste0(b_ml, .col_gray(old_cells), sep, .col_gray(old_features), b_mr)
        line3 <- paste0(b_ml, .col_yellow(delta_cells), sep, .col_yellow(delta_features), b_mr)
        line4 <- paste0(b_bl, .col_orange_bold(new_cells), sep, .col_orange_bold(new_features), b_br)
        
        print_matrix_line(line1)
        print_matrix_line(line2)
        print_matrix_line(line3)
        print_matrix_line(line4)
        
    } else {
        log_info("Matrix snapshot:", level = level)
        
        # Color scheme: Orange dim (top), Orange bold (snapshot values)
        line1 <- paste0(b_tl, .col_orange_dim(lbl_cells), sep, .col_orange_dim(lbl_features), b_tr)
        line2 <- paste0(b_bl, .col_orange_bold(old_cells), sep, .col_orange_bold(old_features), b_br)
        
        print_matrix_line(line1)
        print_matrix_line(line2)
    }
    
    invisible(NULL)
}
# ==============================================================================
# Estimator Stats Logger APIs
# ==============================================================================

#' Log Estimator Statistics
#'
#' Computes distribution summaries (mean, median, sd, min, max) of a numeric vector 
#' and prints them in structured logs.
#'
#' @param estimator_values Numeric vector. Values of the estimator to summarize.
#' @param estimator_name Character. Name of the estimator.
#' @param level Integer. Log level threshold. Default is 1L.
#' @return Invisible TRUE.
#' @export
log_estimator_stats <- function(estimator_values, estimator_name, level = 1L) {
    mean_val <- mean(estimator_values, na.rm = TRUE)
    std_val <- stats::sd(estimator_values, na.rm = TRUE)
    med_val <- stats::median(estimator_values, na.rm = TRUE)
    min_val <- min(estimator_values, na.rm = TRUE)
    max_val <- max(estimator_values, na.rm = TRUE)

    log_info(sprintf("%s distribution:", estimator_name), level = level)
    log_stat(sprintf("avg: %.3f | med: %.3f | sd: %.3f", mean_val, med_val, std_val), level = level)
    log_stat(sprintf("min: %.3f | max: %.3f", min_val, max_val), level = level)
}
# ==============================================================================
# Workflow Configuration APIs
# ==============================================================================

#' Generate a unique log file path to prevent overwriting
#'
#' @param dir_path Character. The directory path where the log will be stored.
#' @param base_filename Character. The target log file name.
#'
#' @return Character. A unique path for the log file.
#' @keywords internal
#' @noRd
.generate_unique_log_path <- function(dir_path, base_filename) {
  base_name <- tools::file_path_sans_ext(base_filename)
  ext <- tools::file_ext(base_filename)
  if (ext != "") ext <- paste0(".", ext)
  
  log_path <- file.path(dir_path, base_filename)
  counter <- 1
  
  while (file.exists(log_path)) {
    new_log_name <- sprintf("%s_%d%s", base_name, counter, ext)
    log_path <- file.path(dir_path, new_log_name)
    counter <- counter + 1
  }
  
  return(log_path)
}

#' Configure the COTAN workflow with Log Rotation
#'
#' @param output_dir Character. Directory where logs and outputs will be saved. Default is ".".
#' @param file_name Character. Name of the log file. Default is "cotan_pipeline.log".
#' @param parallel Boolean. Enable parallel processing. Default is TRUE.
#' @param logging_level Integer. Logging verbosity level (0-3). Default is 2L.
#'
#' @return The normalized path to the output directory.
#'
#' @export
config_workflow <- function(
  output_dir = ".",
  file_name = "cotan_pipeline.log",
  parallel = TRUE,
  logging_level = 2L
) {
  reset_log_state()

  options(error = function() {
    reset_log_state()
    cat("\n") # Spazio pulito prima della traccia dell'errore
    traceback()
  })

  COTAN::setLoggingLevel(logging_level)

  log_header("Configuring Workflow")

  log_info("Preparing file path...")

  data_dir <- normalizePath(output_dir, mustWork = FALSE)
  dir.create(data_dir, recursive = TRUE, showWarnings = FALSE)

  log_path <- .generate_unique_log_path(data_dir, file_name)

  log_cotan_execution("setLoggingFile()", logFileName = log_path)
  COTAN::setLoggingFile(log_path)
  log_cotan_execution("setLoggingFile()", is_complete = TRUE)

  log_info("Setting up conflict resolution (zeallot)...")
  suppressMessages(conflicted::conflict_prefer("%<-%", "zeallot"))

  log_info("Setting up parallel processing...")
  options(parallelly.fork.enable = parallel)

  log_stat(sprintf("Logging level set to: %d", logging_level))
  log_stat(sprintf("Logging path set to: %s", log_path))

  log_header("Configuring Workflow", is_complete = TRUE)

  return(data_dir)
}