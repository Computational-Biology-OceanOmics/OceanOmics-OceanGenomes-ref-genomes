#!/usr/bin/env python3
# singularity run $SING/psycopg2:0.1.sif python 04a_push_gfa_results_to_sqldb.py ~/postgresql_details/oceanomics.cfg
import psycopg2
import pandas as pd
import numpy as np  # Required for handling infinity values
import configparser
import sys
from pathlib import Path  # ✅ needed for load_db_config

# -------------------------------
# Load DB credentials from .cfg
# -------------------------------
def load_db_config(config_file):
    if not Path(config_file).exists():
        raise FileNotFoundError(f"❌ Config file '{config_file}' does not exist.")
    config = configparser.ConfigParser()
    config.read(config_file)
    if not config.has_section('postgres'):
        raise ValueError("❌ Missing [postgres] section in config file.")
    required_keys = ['dbname', 'user', 'password', 'host', 'port']
    for key in required_keys:
        if not config.has_option('postgres', key):
            raise ValueError(f"❌ Missing '{key}' in [postgres] section of config file.")
    return {
        'dbname': config.get('postgres', 'dbname'),
        'user': config.get('postgres', 'user'),
        'password': config.get('postgres', 'password'),
        'host': config.get('postgres', 'host'),
        'port': config.getint('postgres', 'port')
    }

# --- tiny helpers (just enough to be safe) ---
def parse_int(val):
    if val is None or (isinstance(val, float) and np.isnan(val)):
        return None
    s = str(val).strip().replace(",", "")
    if s == "" or s.lower() == "nan":
        return None
    try:
        return int(float(s))
    except ValueError:
        return None

def parse_float(val):
    if val is None or (isinstance(val, float) and np.isnan(val)):
        return None
    s = str(val).strip().replace(",", "").replace("%", "")
    if s == "" or s.lower() == "nan":
        return None
    try:
        return float(s)
    except ValueError:
        return None

def safe_dot_part(s, idx):
    parts = s.split(".")
    return parts[idx] if len(parts) > idx else None

def safe_us_part(s, us_idx, dot_idx=0):
    base = safe_dot_part(s, dot_idx) or ""
    us = base.split("_")
    return us[us_idx] if len(us) > us_idx else None

# -------------------------------
# Args & input
# -------------------------------
config_file = sys.argv[1]

# File containing gfastats data (tab-delimited)
gfa_compiled_path = "final_gfastats_report.txt"  # adjust if needed

print(f"Importing data from {gfa_compiled_path}")
gfa = pd.read_csv(gfa_compiled_path, sep="\t")

# -------------------------------
# Derive og_id, seq_date, stage, haplotype from 'filename'
# -------------------------------
if 'filename' not in gfa.columns:
    raise ValueError("❌ 'filename' column not found in the input file.")

fname = gfa['filename'].astype(str)
gfa['og_id']     = fname.apply(lambda x: safe_us_part(x, 0, dot_idx=0))
gfa['seq_date']  = fname.apply(lambda x: (safe_us_part(x, 1, dot_idx=0) or "").lstrip('v') or None)
gfa['stage']     = fname.apply(lambda x: parse_int(safe_dot_part(x, 2)))
gfa['haplotype'] = fname.apply(lambda x: safe_us_part(x, 0, dot_idx=4))  # may be None for haploid assemblies

# Optional: save split file
output_file = "gfa_compiled_results_split.tsv"
gfa.to_csv(output_file, sep="\t", index=False)
print("File successfully processed! New columns added.")

print("\n🔍 Final dataset summary:")
print(gfa.describe())

# -------------------------------
# DB upsert
# -------------------------------
conn = None
cursor = None
try:
    db_params = load_db_config(config_file)
    conn = psycopg2.connect(**db_params)
    cursor = conn.cursor()

    row_count = 0

    for _, row in gfa.iterrows():
        params = {
            "og_id": row.get("og_id"),                      # TEXT
            "seq_date": row.get("seq_date"),                # TEXT/DATE
            "stage": parse_int(row.get("stage")),           # INT
            "haplotype": row.get("haplotype"),              # TEXT (can be None)
            "num_contigs": parse_int(row.get("num_contigs")),                              # INT
            "contig_n50": parse_int(row.get("contig_n50")),                                # BIGINT
            "contig_n50_size_mb": parse_float(row.get("contig_n50_size_mb")),              # FLOAT
            "num_scaffolds": parse_int(row.get("num_scaffolds")),                          # INT
            "scaffold_n50": parse_int(row.get("scaffold_n50")),                            # BIGINT
            "scaffold_n50_size_mb": parse_float(row.get("scaffold_n50_size_mb")),          # FLOAT
            "largest_scaffold": parse_int(row.get("largest_scaffold")),                    # BIGINT
            "largest_scaffold_size_mb": parse_float(row.get("largest_scaffold_size_mb")),  # FLOAT
            "total_scaffold_length": parse_int(row.get("total_scaffold_length")),          # BIGINT
            "total_scaffold_length_size_mb": parse_float(row.get("total_scaffold_length_size_mb")),  # FLOAT
            "gc_content_percent": parse_float(row.get("gc_content_percent")),              # FLOAT
        }

        upsert_query = """
        INSERT INTO ref_genomes (
            og_id, seq_date, stage, haplotype, num_contigs, contig_n50, contig_n50_size_mb, num_scaffolds,
            scaffold_n50, scaffold_n50_size_mb, largest_scaffold, largest_scaffold_size_mb, total_scaffold_length, total_scaffold_length_size_mb, gc_content_percent
        )
        VALUES (
            %(og_id)s, %(seq_date)s, %(stage)s, %(haplotype)s, %(num_contigs)s, %(contig_n50)s, %(contig_n50_size_mb)s, %(num_scaffolds)s,
            %(scaffold_n50)s, %(scaffold_n50_size_mb)s, %(largest_scaffold)s, %(largest_scaffold_size_mb)s, %(total_scaffold_length)s, %(total_scaffold_length_size_mb)s, %(gc_content_percent)s
        )
        ON CONFLICT (og_id, seq_date, stage, haplotype) DO UPDATE SET
            num_contigs = EXCLUDED.num_contigs,
            contig_n50 = EXCLUDED.contig_n50,
            contig_n50_size_mb = EXCLUDED.contig_n50_size_mb,
            num_scaffolds = EXCLUDED.num_scaffolds,
            scaffold_n50 = EXCLUDED.scaffold_n50,
            scaffold_n50_size_mb = EXCLUDED.scaffold_n50_size_mb,
            largest_scaffold = EXCLUDED.largest_scaffold,
            largest_scaffold_size_mb = EXCLUDED.largest_scaffold_size_mb,
            total_scaffold_length = EXCLUDED.total_scaffold_length,
            total_scaffold_length_size_mb = EXCLUDED.total_scaffold_length_size_mb,
            gc_content_percent = EXCLUDED.gc_content_percent;
        """

        cursor.execute(upsert_query, params)
        row_count += 1
        conn.commit()
        print(f"✅ Successfully processed {row_count} rows!")

except Exception as e:
    if conn:
        conn.rollback()
    print(f"❌ Error: {e}")

finally:
    if cursor:
        cursor.close()
    if conn:
        conn.close()
