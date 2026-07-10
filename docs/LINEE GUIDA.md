### ISOFORM-AWARE COTAN NEXTFLOW PIPELINE ARCHITECTURE

---

#### 1. GLOBAL WORKFLOW DAG (Directed Acyclic Graph)

```text
[nf-core/scrnaseq] --> (Seurat/SCE Output)
                          |
                          v
[ Process 1: Ingestion & QC ] ---------> (Checkpoint: .rds & QC Plots)
                          |
                          v
[ Process 2: Model Calibration ] ------> (Checkpoint: .rds & Nu/Dispersion Plots)
                          |
                          v
[ Process 3: COEX Calculation ] -------> (Checkpoint: .rds [Heavy])
                          |
                          v
[ Process 4: GDI & Clustering ] -------> (Checkpoint: .rds & UMAP/GDI Plots)
                          |
                          v
[ Process 5: DTU Analysis ] -----------> (Final: CSVs, Heatmaps, SCE Object)

```

---

#### 2. NEXTFLOW CONFIGURATION (`nextflow.config`)

Define these parameters to ensure pipeline flexibility and reproducibility.

**Hardware & Execution**

* `params.cotan_cores` = `1` (Maps to `cores` arguments in COTAN functions)


* `params.use_gpu` = `false` (Maps to `optimizeForSpeed`)


* `params.device` = `"cuda"` (Maps to `deviceStr`, falls back to CPU if unavailable)



**Data & Annotation**

* `params.transcript_prefix` = `'^ENST'` (Regex for feature subsetting)
* `params.mt_prefix` = `'^MT-'` (Regex for mitochondrial fraction)



**Filtering Thresholds**

* `params.mt_max_pct` = `5.0` (Maximum allowable mitochondrial percentage)
* `params.cells_cutoff` = `0.003` (Minimum cell expression frequency, default `0.003`)


* `params.genes_cutoff` = `0.002` (Minimum transcript expression frequency, default `0.002`)



**Clustering & Evaluation**

* `params.gdi_threshold` = `1.4` (Strictness for Uniform Transcript property)


* `params.dtu_pval_adj` = `0.05` (Significance threshold for Differential Transcript Usage)

---

#### 3. PROCESS SPECIFICATIONS & R SCRIPT BOUNDARIES

##### PROCESS 1: Ingestion & QC (`01_ingest_qc.R`)

* **Inputs:** `nf-core/scrnaseq` transcript count matrix.
* **Operations:**
1. Subset rows using `params.transcript_prefix`.
2. Initialize object: `obj <- COTAN(raw = count_matrix)`.


3. Calculate MT percentage (`params.mt_prefix`) and filter cells > `params.mt_max_pct`.


4. Remove completely empty droplets.


* **Outputs (`publishDir`):**
* `cotan_qc.rds` (Lightweight checkpoint).
* `qc_mt_plot.pdf` (Output of `mitochondrialPercentagePlot()`).





##### PROCESS 2: Model Calibration (`02_calibrate.R`)

* **Inputs:** `cotan_qc.rds`
* **Operations:**
1. Iterative sparsity filtering: `clean(obj, cellsCutoff = params.cells_cutoff, genesCutoff = params.genes_cutoff)`.


2. Linear estimators: `estimateLambdaLinear()` and `estimateNuLinear()`.


3. Bisection solvers: `estimateDispersionNuBisection(cores = params.cotan_cores)`.




* **Outputs (`publishDir`):**
* `cotan_calibrated.rds` (Ready for COEX).
* `clean_plots.pdf` (Output of `cleanPlots()` including PCA and UDE plots).





##### PROCESS 3: COEX Calculation (`03_calc_coex.R`)

* **Inputs:** `cotan_calibrated.rds`
* **Resource Allocation:** Maximize CPUs/GPUs.
* **Operations:**
1. Calculate expected and observed contingency tables.
2. Generate COEX matrix: `calculateCoex(optimizeForSpeed = params.use_gpu, deviceStr = params.device)`.




* **Outputs (`publishDir`):**
* `cotan_coex.rds` (Heavy checkpoint containing `genesCoex`).





##### PROCESS 4: GDI & Clustering (`04_cluster.R`)

* **Inputs:** `cotan_coex.rds`
* **Operations:**
1. Calculate GDI: `calculateGDI()` and `storeGDI()`.


2. Uniform clustering: `cellsUniformClustering(GDIThreshold = params.gdi_threshold)`.


3. *(Optional)* Merge clusters: `mergeUniformCellsClusters()`.




* **Outputs (`publishDir`):**
* `cotan_clustered.rds`.
* `gdi_distribution.pdf` (Output of `GDIPlot()`).


* `umap_clusters.pdf` (Output of `cellsUMAPPlot()`).





##### PROCESS 5: DTU Exclusivity Analysis (`05_dtu_extract.R`)

* **Inputs:** `cotan_clustered.rds`
* **Operations:**
1. Calculate cluster markers/enrichment: `DEAOnClusters()`.


2. Extract transcript-to-transcript COEX values for transcripts sharing the same parent gene.
3. Identify pairs with significant negative COEX coefficients (mutual exclusivity).
4. Format interoperability output: `convertToSingleCellExperiment()`.




* **Outputs (`publishDir`):**
* `dtu_candidates.csv` (Tabular results containing Gene, Transcript A, Transcript B, COEX score, P-value).
* `cluster_markers.csv` (Output of `findClustersMarkers()`).


* `dtu_heatmap.pdf` (Output of `clustersMarkersHeatmapPlot()` applied to DTU candidates).


* `cotan_final.rds` (Complete COTAN object).
* `cotan_sce.rds` (SingleCellExperiment object for cross-tool compatibility).