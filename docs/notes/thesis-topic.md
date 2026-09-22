# Isoform-aware COTAN
## can we recover differential transcript usage (DTU) from scRNA-seq? 

### Short intro 

[[COTAN]] models single-cell data using [[Contingency Tables|contingency tables]] that focus on the presence/absence (zeros) of gene reads rather than [[Log-normalized counts|log-normalized counts]]. This avoids [[Imputation|imputation]] and [[Log-scaling|log-scaling]], handles [[UMI droplet sparsity]] natively, and yields a robust [[Co-expression Matrix|gene–gene co-expression (coex) matrix]], a [[Differential Expression Analysis|DEA test]] for enrichment, and the [[Global Differentiation Index|Global Differentiation Index]] (gdi) for [[Homogeneity check|homogeneity checks]]. Benchmarks show fewer false positives in DEA and stronger marker recovery—especially for low-expression genes—than [[Seurat]]/[[Scanpy]]/[[Monocle]]. These traits make COTAN a good candidate to probe [[Isoform|isoform]] switches ([[DTU - Differential Transcript Usage|DTU]]), where mutually exclusive transcript usage within a gene is subtle and sparse. 

[^1]Many genes can produce multiple slightly different proteins; these comes from different transcripts/isoforms produced by the same gene. DTU asks whether the proportions of those isoforms change between conditions, cell types, or along a trajectory—even if the gene’s total expression doesn’t change. That makes DTU different from standard differential expression (DE), which looks at gene-level totals.

In [[single-cell RNA-seq (scRNA-seq)|single-cell RNA-seq]], DTU is challenging because data are sparse and often [[3-biased sequencing|3′-biased]] (droplet assays capture only transcript ends). Practical strategies include: [^2](i) [[Pseudo-bulk per cell type|pseudo-bulk per cell type]]/state, (ii) modelling transcript proportions or exon/junction usage, and (iii) validating with orthogonal evidence (motifs, known switches, or long-read data when available). 

For the thesis, we’ll quantify transcripts, then test whether COTAN-style independence/exclusivity signals at the transcript level recover DTU events robustly. 

### Expanded idea & plan 
#### Goal
Build an isoform-level scRNA-seq workflow, run COTAN at transcript resolution, and test whether COTAN’s independence/association statistics can recover within-gene exclusivity patterns indicative of DTU. Compare against standard DTU baselines  and quantify when this works (and when it doesn’t). 
#### Why COTAN helps here 
COTAN estimates co-activation/exclusivity from 2×2 tables while explicitly modelling cell library size and zero probabilities, reducing spurious correlations that plague sparse data.  
Its DEA and [[correlation tests]] deliver well-calibrated [[p-values]], with empirically lower false positives under challenging splits and better [[ROC curves]] for marker detection; performance is notably strong for low-abundance genes—exactly the regime many isoforms live in.  
The [[Global Differentiation Index|gdi]] can flag heterogeneous cell mixes; running transcript-level COTAN within gdi-uniform clusters reduces confounding.  
#### Data strategy
[^3]* Test [[Pseudo-alignment|pseudo aligners]] on 3’ 10x data (did they get enough information?) 
* Get [[Full-length sequencing|full-length scRNA-seq]] (e.g., SMART-seq/SMART-seq2) for isoform resolution and test COTAN on them 
* Use datasets with known cell types so you can [[Pseudo-bulk analysis per cell type|pseudo-bulk per cluster]] for DTU baselines.  
#### Methods
##### Transcript quantification. 
* Build a cell × transcript matrix;
* apply strict [[Quality Control in scRNA-seq|QC]] to filter ultra-rare isoforms and cells with poor coverage;
##### Transcript-level COTAN. 
* Treat transcripts as features;
* compute the coex matrix among transcripts; 
* convert to p-values using the [[large-m approximation]] supplied by COTAN;
* Within each gene, examine transcript-pair coex: strong negative association across cells hints at mutual exclusivity/DTU;
* Compute DEA for transcripts across clusters (one-vs-rest) to find cluster-biased isoforms. 
* Use gdi on the same subset to verify cluster homogeneity before calling DTU, following the paper’s guidance on thresholds/upper-tail behavior.  
#### Baselines & benchmarking. 
* Run standard DTU on matched pseudo-bulks  as the reference. 
##### Metrics: 
* Per-gene: overlap/precision-recall of DTU-positive genes (COTAN vs. baseline). 
* Within-gene transcript pairs: rank enrichment of negatively associated pairs. 

##### Others?? 
Interpretation & visualization. 
For top DTU candidates, show transcript proportion shifts across clusters, coex heatmaps, and DEA volcanoes. 
Summarize biological plausibility with pathway/marker context. 

[1] Galfre, Silvia Giulia, et al. "COTAN: scRNA-seq data analysis based on gene co-expression." NAR genomics and bioinformatics 3.3 (2021): lqab072. 

[2] Matilde I. Conte, Azahara Fuentes-Trillo, Cecilia Domínguez Conde, “Opportunities and tradeoffs in single-cell transcriptomic technologies”, Trends in Genetics, Volume 40, Issue 1, 2024, Pages 83-93, ISSN 0168-9525,https://doi.org/10.1016/j.tig.2023.10.003. 

[3] Joglekar, A., Foord, C., Jarroux, J., Pollard, S., & Tilgner, H. U. (2023). From words to complete phrases: insight into single-cell isoforms using short and long reads. Transcription, 14(3–5), 92–104.https://doi.org/10.1080/21541264.2023.2213514 

[4] Draper BJ, Dunning MJ and James DC. Selecting differential splicing methods: Practical considerations for short-read RNA sequencing F1000Research 2025, 14:47https://doi.org/10.12688/f1000research.155223.2 

 

[^1]: Da capire meglio

[^2]: devo capire esattamente queste strategie proposte

[^3]: altra roba tutta da capire
