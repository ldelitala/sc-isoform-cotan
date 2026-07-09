source("/data/lorenzo_delitala/src/pipeline/bin/tmp_carica.R")


cotan_obj <- clean_cotan_data(cotan_obj)

# 1. Prepare for COEX calculation (Estimating Lambda and Dispersion via Solver)
# Adjust the 'cores' parameter based on your available hardware
cotan_obj <- prepare_to_coex(cotan_obj, cores = 22L, maxIterations = 100L, chunkSize = 1024L)

# 2. Calculate the genes' COEX matrix
# Set deviceStr to "cpu" if you do not have a CUDA-enabled GPU available
cotan_obj <- calculate_coex(
    cotan_obj,
    actOnCells = FALSE,
    optimizeForSpeed = TRUE,
    deviceStr = "cpu"
)

# 3. Calculate GDI, store it within the object, and save the final object to disk
cotan_obj <- calculate_and_store_gdi(
    cotan_obj,
    out_dir = cotan_output_dir,
    cores = 16L,
    statType = "S"
)

# Optional: Print out the final dimensions of the object slots to verify successful execution
cat("\nFinal COTAN Object Dimensions:\n")
print(COTAN::getDims(cotan_obj))