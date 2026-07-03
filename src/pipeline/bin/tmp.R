source("/data/lorenzo_delitala/src/pipeline/bin/tmp_carica.R")
source("/data/lorenzo_delitala/src/pipeline/bin/lib_utils.R")
source("/data/lorenzo_delitala/src/pipeline/bin/lib_COTAN_config.R")

config_cotan_workflow(output_dir = "/data/lorenzo_delitala/cotan_results",
  log_file_name = "cotan_pipeline.log"
)

filtered_seurat_obj <- filter_mt_transcripts(seurat_obj, mt_transcripts_list)

cotan_obj <- initialize_cotan_from_seurat(filtered_seurat_obj, geo = "arrigoni2023", condition="prova")