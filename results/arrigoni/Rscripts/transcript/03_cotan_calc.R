library(project.logger)
library(project.cotan)

cotan_obj <- readRDS("/data/lorenzo_delitala/data/project_files/arrigoni/objects/initialized.transcript.cotan.rds")

config_workflow(logging_level = 3L, 
  output_dir = "/data/lorenzo_delitala/data/project_files/arrigoni/logs", 
  file_name = "cotan_calc.transcripts.log")

cotan_obj <- prepare_to_coex(cotan_obj, cores = 40L, chunk_size = 512L)

cotan_obj <- calculate_coex(cotan_obj, return_pp_fract = TRUE, device_str = "cpu")

cotan_obj <- calculate_p_value (cotan_obj, cores = 40L, chunk_size = 512L)

cotan_obj <- calculate_gdi(
  cotan_obj,
  cores = 40L,
  stat_type = "S",
  chunk_size = 1024L,
  output_dir = "/data/lorenzo_delitala/data/project_files/arrigoni/objects", 
  file_name = "calculated.transcript.cotan.rds"
)

