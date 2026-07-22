base_dir <- "runs/arrigoni2023/geo_metadata/"

# La tua lista di file
tsv_files <- c(
  "A549"       = paste0(base_dir, "GSE243665_A549_barcodes.tsv"),
  "CCL-185-IG" = paste0(base_dir, "GSE243665_CCL-185-IG_barcodes.tsv"),
  "CRL5868"    = paste0(base_dir, "GSE243665_CRL5868_barcodes.tsv.gz"),
  "DV90"       = paste0(base_dir, "GSE243665_DV90_barcodes.tsv.gz"),
  "HCC78"      = paste0(base_dir, "GSE243665_HCC78_barcodes.tsv.gz"),
  "HTB178"     = paste0(base_dir, "GSE243665_HTB178_barcodes.tsv.gz"),
  "PBMCs"      = paste0(base_dir, "GSE243665_PBMCs_barcodes.tsv.gz"),
  "PC9"        = paste0(base_dir, "GSE243665_PC9_barcodes.tsv.gz")
)

# 1. Inizializza un vettore vuoto per raccogliere i barcode
all_barcodes <- c()

# 2. Itera su ogni file della lista
for (cell_line in names(tsv_files)) {
  file_path <- tsv_files[[cell_line]]
  
  
  if (!file.exists(file_path)) {
    warning(sprintf("Attenzione: il file non esiste e verrà saltato -> %s", file_path))
    next
  }
  
  # Legge il file (gestisce in automatico anche i .gz)
  # Assumiamo header = FALSE (tipico dei file barcode generati da Cell Ranger)
  data <- read.table(file_path, header = FALSE, stringsAsFactors = FALSE)
  
  # Estrae la prima colonna (i barcode)
  barcodes <- data[[1]]
  
  # Aggiunge i barcode al vettore complessivo
  all_barcodes <- c(all_barcodes, barcodes)
}

# 3. Rimuove eventuali barcode duplicati 
# (Utile nel caso remoto in cui due linee cellulari abbiano barcode sovrapposti)
unique_barcodes <- unique(all_barcodes)

# 4. Salva il risultato in un nuovo file TSV unico
output_file <- paste0(base_dir, "GSE243665_combined_QC_barcodes.tsv")

write.table(unique_barcodes, file = output_file, 
            sep = "\t", quote = FALSE, row.names = FALSE, col.names = FALSE)

# Stampa un riepilogo
