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
