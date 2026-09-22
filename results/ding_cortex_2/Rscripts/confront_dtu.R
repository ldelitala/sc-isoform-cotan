library(dplyr)
library(readr)
library(project.logger)

config_workflow(
  logging_level = 3L, 
  output_dir = "/data/lorenzo_delitala/data/project_files/ding/cortex_2/logs", 
  file_name = "compare_dtu.log"
)

log_header("Compare DTU candidates")

log_info("Loading DTU candidate files...")
file1_path <- "/data/lorenzo_delitala/data/project_files/ding/cortex_2/dtu_candidates.transcript_cluster.csv" 
file2_path <- "/data/lorenzo_delitala/data/project_files/ding/cortex_2/dtu_candidates.gene_cluster.csv"

dtu_1 <- read_csv(file1_path, show_col_types = FALSE)
dtu_2 <- read_csv(file2_path, show_col_types = FALSE)

log_info("Defining helper function to create order-independent DTU IDs...")
create_dtu_id <- function(df) {
  df %>%
    rowwise() %>%
    mutate(
      Tr_min = min(Transcript_A, Transcript_B),
      Tr_max = max(Transcript_A, Transcript_B),
      DTU_ID = paste(Gene_ID, Tr_min, Tr_max, sep = "___")
    ) %>%
    ungroup()
}

log_info("Applying unique IDs to both datasets...")
dtu_1_id <- create_dtu_id(dtu_1)
dtu_2_id <- create_dtu_id(dtu_2)

log_info("Identifying shared and exclusive DTU events...")
join_cols <- "DTU_ID"
if ("Gene_ID" %in% colnames(dtu_1_id)) join_cols <- c(join_cols, "Gene_ID")
if ("Gene_Name" %in% colnames(dtu_1_id)) join_cols <- c(join_cols, "Gene_Name")

shared_dtus <- inner_join(
  dtu_1_id, 
  dtu_2_id,
  by = join_cols,
  suffix = c("_file1", "_file2")
)

exclusive_file1 <- anti_join(dtu_1_id, dtu_2_id, by = "DTU_ID")
exclusive_file2 <- anti_join(dtu_2_id, dtu_1_id, by = "DTU_ID")

log_stat(sprintf("Total candidates in File 1: %d", nrow(dtu_1)))
log_stat(sprintf("Total candidates in File 2: %d", nrow(dtu_2)))
log_stat(sprintf("SHARED DTU events: %d", nrow(shared_dtus)))
log_stat(sprintf("EXCLUSIVE DTU events in File 1: %d", nrow(exclusive_file1)))
log_stat(sprintf("EXCLUSIVE DTU events in File 2: %d", nrow(exclusive_file2)))

if (nrow(shared_dtus) > 0) {
  log_info("Calculating COEX differences for shared events...")
  shared_dtus <- shared_dtus %>%
    mutate(
      COEX_Diff = abs(COEX_Score_file1 - COEX_Score_file2)
    ) %>%
    arrange(desc(COEX_Diff))
  
  log_stat(sprintf("Mean COEX_Score difference for shared events: %.4f", mean(shared_dtus$COEX_Diff, na.rm = TRUE)))
}

output_dir <- dirname(file1_path)
log_info(sprintf("Saving results to directory: %s", output_dir))

write_csv(shared_dtus, file.path(output_dir, "dtu_shared.csv"))
write_csv(exclusive_file1, file.path(output_dir, "dtu_exclusive_file1.csv"))
write_csv(exclusive_file2, file.path(output_dir, "dtu_exclusive_file2.csv"))

log_header(is_complete = TRUE)