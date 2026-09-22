library(dplyr)
library(readr)

t2g <- read_tsv(
  "/data/lorenzo_delitala/data/genomes/GRCm39/gene_index/index/t2g_3col.tsv", 
  col_names = c("transcript_id", "gene_id", "extra")
)

gene2name <- read_tsv(
  "/data/lorenzo_delitala/data/genomes/GRCm39/gene_index/index/gene_id_to_name.tsv", 
  col_names = c("gene_id", "gene_name")
)

t2gene_name <- t2g %>%
  left_join(gene2name, by = "gene_id") %>%
  select(transcript_id, gene_name) %>%
  distinct()

write_tsv(
  t2gene_name, 
  "/data/lorenzo_delitala/data/project_files/ding/cortex_2/objects/t2gene_name.tsv", 
  col_names = FALSE
)