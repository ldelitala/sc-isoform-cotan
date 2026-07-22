# ==============================================================================
# Custom Logging Library - Helpers & Formats
# ==============================================================================

#' Print a formatted header with dynamic clean tree
#' @export
log_header <- function(msg, is_complete = FALSE, level = 3L) {
    
    if(getOption("COTAN.LogLevel", default = 1L) == level){
    if (is_complete) {
        .log_state$depth <- max(0, .log_state$depth - 1)
        indent <- .get_indent()
        msg_formatted <- .col_blue_bold("┗━━")
        COTAN::logThis(paste0(indent, msg_formatted), logLevel = level)
    } else {
        indent <- .get_indent()
        msg_formatted <- .col_blue_bold(sprintf("┏━━ %s", toupper(msg)))
        COTAN::logThis(paste0(indent, msg_formatted), logLevel = level)
        .log_state$depth <- .log_state$depth + 1
    }}
}

#' Handle the start and end of a COTAN execution with native output tracking
#' @export
log_cotan_execution <- function(func_name, ..., is_complete = FALSE, level = 1L) {
    base_indent <- .get_indent_base()
    
    if (!is_complete) {
        # 1. Sostituisce l'ultimo livello dell'albero con la freccia verso il basso
        arrows_down <- paste0(.col_blue_bold("⇣"), "   ")
        msg_exec <- .col_magenta(sprintf("▶ %s", func_name))
        COTAN::logThis(paste0(base_indent, arrows_down, msg_exec), logLevel = level)
        
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
            
            # Il simbolo ◦ colorato di grigio come separatore
            sep_symbol <- .col_gray(" ◦ ")
            # Aggiunge 2 spazi per spingere l'indentazione più all'interno
            msg_params <- paste0("  ", .col_gray("◦ "), paste(formatted_pairs, collapse = sep_symbol))
            
            param_indent <- paste0(base_indent, "    ") 
            COTAN::logThis(paste0(param_indent, msg_params), logLevel = level)
        }
        
    } else {
        # 3. Sostituisce l'ultimo livello dell'albero con la freccia verso l'alto
        arrows_up <- paste0(.col_blue_bold("⇡"), "   ")
        msg_done <- .col_magenta("✔ Done.")
        COTAN::logThis(paste0(base_indent, arrows_up, msg_done), logLevel = level)
    }
}

#' Log Matrix Filtering Statistics
#' @export
log_matrix_stats <- function(cells_before, cells_after = NULL, features_before = NULL, features_after = NULL, level = 1L) {
    fmt <- function(number) format(number, big.mark = ",", scientific = FALSE, trim = TRUE)
    
    print_matrix_line <- function(msg) {
        indent <- .get_indent()
        COTAN::logThis(paste0(indent, msg), logLevel = level)
    }

    # Helper colori esclusivi per la Matrice: Verde "opaco" per le etichette, "acceso" per i totali
    .col_green_dim  <- function(x) paste0("\033[32m", x, "\033[0m")    # Verde standard
    .col_green_bold <- function(x) paste0("\033[1;32m", x, "\033[0m")  # Verde brillante
    
    showing_variation <- (!is.null(cells_before) && !is.null(cells_after)) ||
                         (!is.null(features_before) && !is.null(features_after))

    if (is.null(features_before)) features_before <- 0
    if (is.null(features_after)) features_after <- features_before
    if (is.null(cells_before)) cells_before <- 0
    if (is.null(cells_after)) cells_after <- cells_before

    # 1. FUNZIONE DI CENTRATURA PER LE ETICHETTE
    center_str <- function(text, width) {
        pad <- max(0, width - nchar(text))
        left <- floor(pad / 2)
        right <- ceiling(pad / 2)
        paste0(strrep(" ", left), text, strrep(" ", right))
    }

    # 2. LOGICA DI ALLINEAMENTO MILLIMETRICO PER I NUMERI (Colonna da 14 caratteri)
    fmt_normal <- function(x) {
        core <- paste0(fmt(x), "  ")
        pad <- max(0, 14 - nchar(core))
        paste0(strrep(" ", pad), core)
    }

    fmt_delta <- function(before, after) {
        diff <- before - after
        if (diff == 0) {
            core <- paste0(fmt(0), "  ") # Zero pulito
        } else if (diff > 0) {
            core <- paste0("▼ ", fmt(diff), " ▼")
        } else {
            core <- paste0("▲ ", fmt(abs(diff)), " ▲")
        }
        pad <- max(0, 14 - nchar(core))
        paste0(strrep(" ", pad), core)
    }

    # 3. STRUTTURA PARENTESI (Grigie)
    b_tl <- .col_gray("  ⎡ ")
    b_tr <- .col_gray(" ⎤")
    b_ml <- .col_gray("  ⎢ ")
    b_mr <- .col_gray(" ⎥")
    b_bl <- .col_gray("  ⎣ ")
    b_br <- .col_gray(" ⎦")
    
    sep <- "   " # Spazio centrale rigido

    if (showing_variation) {
        log_info("Matrix variation:", level = level)
        
        lbl_f <- center_str("Features", 14)
        lbl_c <- center_str("Cells", 14)
        
        old_f <- fmt_normal(features_before)
        old_c <- fmt_normal(cells_before)
        
        del_f <- fmt_delta(features_before, features_after)
        del_c <- fmt_delta(cells_before, cells_after)
        
        new_f <- fmt_normal(features_after)
        new_c <- fmt_normal(cells_after)
        
        # Colorazione: Verde Dim (Top), Grigio (Old), Giallo (Delta), Verde Bold (New)
        line1 <- paste0(b_tl, .col_green_dim(lbl_c), sep, .col_green_dim(lbl_f), b_tr)
        line2 <- paste0(b_ml, .col_gray(old_c), sep, .col_gray(old_f), b_mr)
        line3 <- paste0(b_ml, .col_yellow(del_c), sep, .col_yellow(del_f), b_mr)
        line4 <- paste0(b_bl, .col_green_bold(new_c), sep, .col_green_bold(new_f), b_br)
        
        print_matrix_line(line1)
        print_matrix_line(line2)
        print_matrix_line(line3)
        print_matrix_line(line4)
        
    } else {
        log_info("Matrix snapshot:", level = level)
        
        lbl_f <- center_str("Features", 14)
        lbl_c <- center_str("Cells", 14)
        
        old_f <- fmt_normal(features_before)
        old_c <- fmt_normal(cells_before)
        
        line1 <- paste0(b_tl, .col_green_dim(lbl_c), sep, .col_green_dim(lbl_f), b_tr)
        line2 <- paste0(b_bl, .col_green_bold(old_c), sep, .col_green_bold(old_f), b_br)
        
        print_matrix_line(line1)
        print_matrix_line(line2)
    }
}

#' Log Estimator Statistics
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