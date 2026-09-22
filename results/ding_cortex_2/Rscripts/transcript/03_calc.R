library(project.logger)
library(project.cotan)

cotan_obj <- readRDS("/data/lorenzo_delitala/data/project_files/ding/cortex_2/objects/initialized.transcript.cotan.rds")

config_workflow(logging_level = 3L, output_dir = "/data/lorenzo_delitala/data/project_files/ding/cortex_2/logs", file_name = "cotan_calc.transcript.log")

cotan_obj <- prepare_to_coex(cotan_obj, cores = 80L, chunk_size = 512L)

cotan_obj <- calculate_coex(cotan_obj, return_pp_fract = TRUE, device_str = "cpu")

cotan_obj <- calculate_p_value (cotan_obj, cores = 80L, chunk_size = 512L)

cotan_obj <- calculate_gdi(
  cotan_obj,
  cores = 80L,
  stat_type = "S",
#  rows_fraction = 1,
  chunk_size = 1024L,
  output_dir = "/data/lorenzo_delitala/data/project_files/ding/cortex_2/objects", 
  file_name = "calculated.transcript.cotan.rds"
)