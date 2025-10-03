#!/usr/bin/env python3
# singularity run $SING/psycopg2:0.1.sif python 0a_push_hifiadapt_results_to_sqldb.py ~/postgresql_details/oceanomics.cfg
import sys
from pathlib import Path
import configparser
import pandas as pd
import numpy as np
import psycopg2
from psycopg2.extras import execute_values

def load_db_config(config_file: str) -> dict:
    p = Path(config_file)
    if not p.exists():
        raise FileNotFoundError(f"❌ Config file '{config_file}' does not exist.")
    cfg = configparser.ConfigParser()
    cfg.read(config_file)
    if 'postgres' not in cfg:
        raise ValueError("❌ Missing [postgres] section in config file.")
    required = ['dbname', 'user', 'password', 'host', 'port']
    missing = [k for k in required if not cfg.has_option('postgres', k)]
    if missing:
        raise ValueError(f"❌ Missing keys in [postgres]: {missing}")
    return {
        'dbname': cfg.get('postgres', 'dbname'),
        'user': cfg.get('postgres', 'user'),
        'password': cfg.get('postgres', 'password'),
        'host': cfg.get('postgres', 'host'),
        'port': cfg.getint('postgres', 'port')
    }

def clean_hifiadapt(df: pd.DataFrame) -> pd.DataFrame:
    if 'sample' in df.columns and 'og_id' not in df.columns:
        df = df.rename(columns={'sample': 'og_id'})
    required_cols = {'og_id', 'contam_reads'}
    missing = required_cols - set(df.columns)
    if missing:
        raise ValueError(f"❌ Input file missing required columns: {sorted(missing)}")

    # Normalise types and nulls
    df = df.replace([np.inf, -np.inf], np.nan)
    df['og_id'] = df['og_id'].astype(str)
    df['contam_reads'] = pd.to_numeric(df['contam_reads'], errors='coerce')  # -> float or NaN
    # psycopg2 wants None for NULL
    df['contam_reads'] = df['contam_reads'].where(pd.notna(df['contam_reads']), None)
    return df[['og_id', 'contam_reads']]

def main():
    if len(sys.argv) < 2:
        sys.exit("Usage: 0a_push_hifiadapt_results_to_sqldb.py /path/to/oceanomics.cfg")
    config_file = sys.argv[1]
    tsv = "hifiadaptorfilt_stats_summary.tsv"

    print(f"Importing data from {tsv}")
    df = pd.read_csv(tsv, sep="\t")
    df = clean_hifiadapt(df)

    print("\n🔍 Dataset summary:")
    # include='all' so non-numeric columns are summarised too
    print(df.describe(include='all'))
    print(df.columns.tolist())

    rows = list(df.itertuples(index=False, name=None))
    if not rows:
        print("No rows to upsert. Exiting.")
        return

    upsert_sql = """
        INSERT INTO raw_qc (og_id, contam_reads)
        VALUES %s
        ON CONFLICT (og_id) DO UPDATE
        SET contam_reads = EXCLUDED.contam_reads;
    """

    conn = None
    try:
        db_params = load_db_config(config_file)
        conn = psycopg2.connect(**db_params)
        with conn, conn.cursor() as cur:
            # Ensure unique index exists (safe if already present)
            cur.execute("CREATE UNIQUE INDEX IF NOT EXISTS raw_qc_og_id_uq ON raw_qc(og_id);")
            execute_values(cur, upsert_sql, rows, page_size=10_000)
        print(f"✅ Successfully upserted {len(rows)} rows into raw_qc.")
    except Exception as e:
        if conn:
            conn.rollback()
        print(f"❌ Error during upsert: {e}")
        raise
    finally:
        if conn:
            conn.close()

if __name__ == "__main__":
    main()
