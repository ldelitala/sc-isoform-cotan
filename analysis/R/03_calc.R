#!/usr/bin/env Rscript

# Step 03 — estimate the COTAN parameters, the gene co-expression and its
# p-values, then the GDI. This is the expensive step (tens of minutes to hours).
#
# The call arguments below are exactly the ones of the released drivers
# (03_cotan_calc.R for arrigoni, 02_calc.R for the ding runs); only the file
# names, directory, core count and chunk sizes come from the config.

initial_options <- commandArgs(trailingOnly = FALSE)
script_name <- sub("--file=", "", initial_options[grep("--file=", initial_options)])
script_dir <- if (length(script_name) > 0) dirname(normalizePath(script_name)) else "."
source(file.path(script_dir, "..", "lib", "common.R"))

cfg <- load_config()
p <- resolve_paths(cfg)

input <- in_file(p, object_path(p, "initialized"))
target <- out_file(p, object_path(p, "calculated"))

cores <- step_cfg(p, "calc", "cores", 1L)
chunk_size <- step_cfg(p, "calc", "chunk_size", 1024L)
gdi_chunk_size <- step_cfg(p, "calc", "gdi_chunk_size", chunk_size)
gdi_cores <- step_cfg(p, "calc", "gdi_cores", cores)

check_io(
  p,
  reads = c("initialized cotan" = input),
  writes = c("calculated cotan" = target)
)
step_log(p, log_name(p, "cotan_calc"))

log_info(sprintf("Loading cotan object: %s", input))
cotan_obj <- readRDS(input)

log_stat(sprintf("Cores: %d (GDI: %d) — chunk sizes: %d (GDI: %d)",
                 cores, gdi_cores, chunk_size, gdi_chunk_size))

cotan_obj <- prepare_to_coex(cotan_obj, cores = cores, chunk_size = chunk_size)

cotan_obj <- calculate_coex(cotan_obj, return_pp_fract = TRUE, device_str = "cpu")

cotan_obj <- calculate_p_value(cotan_obj, cores = cores, chunk_size = chunk_size)

cotan_obj <- calculate_gdi(
  cotan_obj,
  cores = gdi_cores,
  stat_type = "S",
  chunk_size = gdi_chunk_size,
  output_dir = dirname(target),
  file_name = basename(target)
)
