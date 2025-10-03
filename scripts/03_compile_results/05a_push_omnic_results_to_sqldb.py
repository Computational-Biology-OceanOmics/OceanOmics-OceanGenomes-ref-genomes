#!/usr/bin/env python3
# singularity run $SING/psycopg2:0.1.sif python 05a_push_omnic_results_to_sqldb.py ~/postgresql_details/oceanomics.cfg
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

def safe_us_part(s, us_idx):
    parts = s.split("_")
    return parts[us_idx] if len(parts) > us_idx else None

# -------------------------------
# Args & input
# -------------------------------
config_file = sys.argv[1]

# File containing Omni-C stats data (tab-delimited)
omnic_path = "final_omnic_stats_report.txt"  # adjust if needed

print(f"Importing data from {omnic_path}")
omnic = pd.read_csv(omnic_path, sep="\t")

# -------------------------------
# Derive og_id, seq_date, stage, haplotype
# -------------------------------
if 'sample' not in omnic.columns:
    raise ValueError("❌ 'sample' column not found in the input file.")

samp = omnic['sample'].astype(str)

# og_id and seq_date from sample like 'OG863_v250331'
omnic['og_id'] = samp.apply(lambda x: safe_us_part(x, 0))
omnic['seq_date'] = samp.apply(lambda x: (safe_us_part(x, 1) or "").lstrip('v') or None)

# stage: map strings to ints per your note (0 pre-curation, 2 post)
if 'stage' in omnic.columns:
    omnic['stage'] = omnic['stage'].replace({'04-scaffolding': '0', '05-decontamination': '2'})
    omnic['stage'] = omnic['stage'].apply(parse_int)
else:
    raise ValueError("❌ 'stage' column could not be found in input file (required).")

# haplotype: USE COLUMN IF PRESENT; only fallback to parsing if missing
if 'haplotype' in omnic.columns:
    omnic['haplotype'] = omnic['haplotype'].astype(str).str.strip()
else:
    # fallback (not used for your file, but harmless)
    omnic['haplotype'] = None

# Optional: save a split file
output_file = "omnic_compiled_results_split.tsv"
omnic.to_csv(output_file, sep="\t", index=False)
print("File successfully processed! New columns added.")

print("\n🔍 Final dataset summary:")
print(omnic.describe())

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

    for _, row in omnic.iterrows():
        params = {
            "og_id": row.get("og_id"),                 # TEXT
            "seq_date": row.get("seq_date"),           # TEXT/DATE
            "stage": parse_int(row.get("stage")),      # INT
            "haplotype": row.get("haplotype"),         # TEXT ('hap1','hap2','dual', etc.)
            "total": parse_int(row.get("total")),                                      # BIGINT
            "total_unmapped": parse_int(row.get("total_unmapped")),                    # BIGINT
            "total_single_sided_mapped": parse_int(row.get("total_single_sided_mapped")),  # BIGINT
            "total_mapped": parse_int(row.get("total_mapped")),                        # BIGINT
            "total_dups": parse_int(row.get("total_dups")),                            # BIGINT
            "total_nodups": parse_int(row.get("total_nodups")),                        # BIGINT
            "cis": parse_int(row.get("cis")),                                          # BIGINT
            "trans": parse_int(row.get("trans")),                                      # BIGINT
        }

        upsert_query = """
        INSERT INTO ref_genomes (
            og_id, seq_date, stage, haplotype, total, total_unmapped, total_single_sided_mapped, total_mapped,
            total_dups, total_nodups, cis, trans
        )
        VALUES (
            %(og_id)s, %(seq_date)s, %(stage)s, %(haplotype)s, %(total)s, %(total_unmapped)s, %(total_single_sided_mapped)s, %(total_mapped)s,
            %(total_dups)s, %(total_nodups)s, %(cis)s, %(trans)s
        )
        ON CONFLICT (og_id, seq_date, stage, haplotype) DO UPDATE SET
            total = EXCLUDED.total,
            total_unmapped = EXCLUDED.total_unmapped,
            total_single_sided_mapped = EXCLUDED.total_single_sided_mapped,
            total_mapped = EXCLUDED.total_mapped,
            total_dups = EXCLUDED.total_dups,
            total_nodups = EXCLUDED.total_nodups,
            cis = EXCLUDED.cis,
            trans = EXCLUDED.trans;
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
