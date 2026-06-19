#!/usr/bin/env python3

# apply_cheat_index.py
# Helper script to backup original maps and apply the transcript-identity cheat to a Piscem/Salmon index

import os
import sys
import shutil
import argparse

def main():
    parser = argparse.ArgumentParser(description="Apply transcript-identity cheat to simpleaf index")
    parser.add_argument("--index", required=True, help="Path to built simpleaf index (e.g. references/indices/GRCm38_simpleaf)")
    parser.add_argument("--dataset", required=True, help="Dataset folder name for metadata backups (e.g. manno2021)")
    
    args = parser.parse_args()
    index_path = args.index
    dataset = args.dataset
    
    t2g_name = "t2g_3col.tsv"
    gene_map_name = "gene_id_to_name.tsv"
    
    if not os.path.exists(index_path):
        print(f"Error: Index path '{index_path}' does not exist.")
        sys.exit(1)
        
    # Find all copies of t2g_3col.tsv and gene_id_to_name.tsv recursively
    t2g_files_found = []
    gene_map_files_found = []
    
    for root, dirs, files in os.walk(index_path):
        if t2g_name in files:
            t2g_files_found.append(os.path.join(root, t2g_name))
        if gene_map_name in files:
            gene_map_files_found.append(os.path.join(root, gene_map_name))
            
    if not t2g_files_found:
        print(f"Error: Could not locate '{t2g_name}' anywhere inside '{index_path}'. Is it a valid simpleaf index?")
        sys.exit(1)
        
    # Setup metadata backup folder
    metadata_backup_dir = os.path.join("metadata", f"{dataset}_simpleaf")
    os.makedirs(metadata_backup_dir, exist_ok=True)
    
    original_t2g_backup = os.path.join(metadata_backup_dir, f"original_{t2g_name}")
    original_gene_map_backup = os.path.join(metadata_backup_dir, f"original_{gene_map_name}")
    
    # Locate an uncheated source file if backup doesn't exist
    uncheated_source = None
    for f in t2g_files_found:
        try:
            with open(f, "r") as fin:
                first_line = fin.readline().strip().split("\t")
                if len(first_line) >= 2 and first_line[0] != first_line[1]:
                    uncheated_source = f
                    break
        except Exception:
            pass
            
    # 1. Back up original t2g and gene_id_to_name files if not already done
    if not os.path.exists(original_t2g_backup):
        if uncheated_source is None:
            uncheated_source = t2g_files_found[0]
            print("Warning: No uncheated source file found for backup. Backing up the first found file.")
        print(f"Backing up original reference maps to '{metadata_backup_dir}'...")
        shutil.copy2(uncheated_source, original_t2g_backup)
        if gene_map_files_found:
            shutil.copy2(gene_map_files_found[0], original_gene_map_backup)
    else:
        print(f"Backup files already exist in '{metadata_backup_dir}'. Re-running from original source.")
        
    # 2. Overwrite all t2g_3col.tsv copies with identity matrix (transcripts map to themselves, keeping splicing status)
    print("Modifying all t2g_3col.tsv copies (preserving splicing status)...")
    
    for t2g_file in t2g_files_found:
        temp_t2g_file = t2g_file + ".tmp"
        try:
            with open(original_t2g_backup, "r") as fin, open(temp_t2g_file, "w") as fout:
                for line in fin:
                    parts = line.strip().split("\t")
                    if len(parts) >= 3:
                        tx_id = parts[0]
                        status = parts[2]
                        fout.write(f"{tx_id}\t{tx_id}\t{status}\n")
                    elif len(parts) == 2:
                        tx_id = parts[0]
                        fout.write(f"{tx_id}\t{tx_id}\n")
                    else:
                        fout.write(line)
            os.replace(temp_t2g_file, t2g_file)
            print(f"Success: Overwrote '{t2g_file}'")
        except Exception as e:
            print(f"Error modifying '{t2g_file}': {e}")
            if os.path.exists(temp_t2g_file):
                os.remove(temp_t2g_file)
            sys.exit(1)
        
    # 3. Delete all gene_id_to_name.tsv files from the index directories
    if gene_map_files_found:
        for gene_map_file in gene_map_files_found:
            print(f"Deleting '{gene_map_file}' to skip symbol mapping...")
            os.remove(gene_map_file)
        print("Success: All symbol mapping files removed.")
    else:
        print("Symbol mapping files already removed. Skipping deletion.")
        
    print("\nCustomized index is ready!")
    print(f"Backup files saved in: {metadata_backup_dir}/")
    sys.exit(0)

if __name__ == "__main__":
    main()
