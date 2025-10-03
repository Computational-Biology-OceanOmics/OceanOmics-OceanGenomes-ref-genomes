#!/usr/bin/env python3
# singularity run $SING/psycopg2:0.1.sif python 03a_push_busco_results_to_sqldb.py ~/postgresql_details/oceanomics.cfg
import psycopg2
import pandas as pd
import numpy as np  # Required for handling infinity values
import configparser
import sys
from pathlib import Path  # ✅ you used Path but didn't import it

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
BUSCO_compiled_path = "BUSCO_compiled_results.tsv"

print(f"Importing data from {BUSCO_compiled_path}")
busco = pd.read_csv(BUSCO_compiled_path, sep="\t")

# -------------------------------
# Derive og_id, seq_date, stage, haplotype
# -------------------------------
if 'sample' not in busco.columns:
    raise ValueError("❌ 'sample' column not found in the input file.")

samp = busco['sample'].astype(str)
busco['og_id']     = samp.apply(lambda x: safe_us_part(x, 0, dot_idx=0))
busco['seq_date']  = samp.apply(lambda x: (safe_us_part(x, 1, dot_idx=0) or "").lstrip('v') or None)
busco['stage']     = samp.apply(lambda x: parse_int(safe_dot_part(x, 2)))
busco['haplotype'] = samp.apply(lambda x: safe_us_part(x, 0, dot_idx=4))

# Optional: keep your side-effect of saving the split file
output_file = "BUSCO_compiled_results_split.tsv"
busco.to_csv(output_file, sep="\t", index=False)
print("File successfully processed! New columns added.")

print("\n🔍 Final dataset summary:")
print(busco.describe())

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

    for _, row in busco.iterrows():
        params = {
            "og_id": row.get("og_id"),
            "seq_date": row.get("seq_date"),
            "stage": parse_int(row.get("stage")),  # INTEGER
            "haplotype": row.get("haplotype"),
            "dataset": row.get("dataset"),
            "complete": parse_float(row.get("complete")),
            "single_copy": parse_float(row.get("single_copy")),
            "multi_copy": parse_float(row.get("multi_copy")),
            "fragmented": parse_float(row.get("fragmented")),
            "missing": parse_float(row.get("missing")),
            "n_markers": parse_int(row.get("n_markers")),
            "internal_stop_codon_percent": parse_float(row.get("internal_stop_codon_percent")),
            "scaffold_n50_bus": parse_int(row.get("scaffold_n50_bus")),
            "contigs_n50_bus": parse_int(row.get("contigs_n50_bus")),
            "percent_gaps": parse_float(row.get("percent_gaps")),
            "number_of_scaffolds": parse_int(row.get("number_of_scaffolds")),
        }

        upsert_query = """
        INSERT INTO ref_genomes (
            og_id, seq_date, stage, haplotype, dataset, complete, single_copy, multi_copy, fragmented,
            missing, n_markers, internal_stop_codon_percent, scaffold_n50_bus, contigs_n50_bus, percent_gaps, number_of_scaffolds
        )
        VALUES (
            %(og_id)s, %(seq_date)s, %(stage)s, %(haplotype)s, %(dataset)s, %(complete)s, %(single_copy)s, %(multi_copy)s, %(fragmented)s,
            %(missing)s, %(n_markers)s, %(internal_stop_codon_percent)s, %(scaffold_n50_bus)s, %(contigs_n50_bus)s, %(percent_gaps)s, %(number_of_scaffolds)s
        )
        ON CONFLICT (og_id, seq_date, stage, haplotype) DO UPDATE SET
            dataset = EXCLUDED.dataset,
            complete = EXCLUDED.complete,
            single_copy = EXCLUDED.single_copy,
            multi_copy = EXCLUDED.multi_copy,
            fragmented = EXCLUDED.fragmented,
            missing = EXCLUDED.missing,
            n_markers = EXCLUDED.n_markers,
            internal_stop_codon_percent = EXCLUDED.internal_stop_codon_percent,
            scaffold_n50_bus = EXCLUDED.scaffold_n50_bus,
            contigs_n50_bus = EXCLUDED.contigs_n50_bus,
            percent_gaps = EXCLUDED.percent_gaps,
            number_of_scaffolds = EXCLUDED.number_of_scaffolds;
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
