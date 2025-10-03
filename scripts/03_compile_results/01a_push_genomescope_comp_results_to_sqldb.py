#!/usr/bin/env python3
# singularity run $SING/psycopg2:0.1.sif python 01a_push_genomescope_comp_results_to_sqldb.py ~/postgresql_details/oceanomics.cfg

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

# ---- tiny helper to parse numbers the way your code intended ----
def parse_num(val, int_like=False):
    s = str(val).strip().replace(",", "").replace("%", "")
    if s == "" or s.lower() == "nan":
        return None
    try:
        return int(s) if int_like else float(s)
    except ValueError:
        return None

# Config file path
config_file = sys.argv[1]

genomescope_compiled_path = "genomescope_compiled_results.tsv"

print(f"Importing data from {genomescope_compiled_path}")

genomescope = pd.read_csv(genomescope_compiled_path, sep="\t")

# Require 'sample' and create og_id exactly as you did
if 'sample' in genomescope.columns:
    genomescope['og_id'] = genomescope['sample'].astype(str).str.split('_').str[0]
else:
    raise ValueError("❌ 'sample' column not found in the input file.")

print("\n🔍 Final dataset summary:")
print(genomescope.describe())
# print(genomescope.columns)  # keep if you want

conn = None
cursor = None
try:
    db_params = load_db_config(config_file)
    conn = psycopg2.connect(**db_params)
    cursor = conn.cursor()

    row_count = 0

    for _, row in genomescope.iterrows():
        # Build params with minimal parsing (same fields you used)
        params = {
            "og_id": row["og_id"],
            "homozygosity": parse_num(row.get("homozygosity"), int_like=False), # FLOAT
            "heterozygosity": parse_num(row.get("heterozygosity"), int_like=False), # FLOAT
            "genomesize": parse_num(row.get("genomesize"), int_like=True), # BIGINT
            "repeatsize": parse_num(row.get("repeatsize"), int_like=True), # BIGINT
            "uniquesize": parse_num(row.get("uniquesize"), int_like=True), # BIGINT
            "modelfit": parse_num(row.get("modelfit"), int_like=False), # FLOAT
            "errorrate": parse_num(row.get("errorrate"), int_like=False), # FLOAT
        }

        upsert_query = """
        INSERT INTO raw_qc (
            og_id, homozygosity, heterozygosity, genomesize,
            repeatsize, uniquesize, modelfit, errorrate
        )
        VALUES (
            %(og_id)s, %(homozygosity)s, %(heterozygosity)s, %(genomesize)s,
            %(repeatsize)s, %(uniquesize)s, %(modelfit)s, %(errorrate)s
        )
        ON CONFLICT (og_id) DO UPDATE SET
            homozygosity = EXCLUDED.homozygosity,
            heterozygosity = EXCLUDED.heterozygosity,
            genomesize = EXCLUDED.genomesize,
            repeatsize = EXCLUDED.repeatsize,
            uniquesize = EXCLUDED.uniquesize,
            modelfit = EXCLUDED.modelfit,
            errorrate = EXCLUDED.errorrate;
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
