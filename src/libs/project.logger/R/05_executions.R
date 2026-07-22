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
