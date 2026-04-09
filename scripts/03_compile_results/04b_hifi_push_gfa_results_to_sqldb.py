#!/usr/bin/env python3
# Push hifi-only (p_ctg / a_ctg) gfastats to the ref_genomes table at stage=0.
# singularity run $SING/psycopg2:0.1.sif python 04b_hifi_push_gfa_results_to_sqldb.py ~/postgresql_details/oceanomics.cfg

import psycopg2
import pandas as pd
import numpy as np
import configparser
import sys
from pathlib import Path


def load_db_config(config_file):
    if not Path(config_file).exists():
        raise FileNotFoundError(f"❌ Config file '{config_file}' does not exist.")
    config = configparser.ConfigParser()
    config.read(config_file)
    section = "postgres" if config.has_section("postgres") else "postgresql"
    if not config.has_section(section):
        raise ValueError("❌ Missing [postgres] section in config file.")
    params = {
        "dbname":   config.get(section, "dbname"),
        "user":     config.get(section, "user"),
        "password": config.get(section, "password"),
        "host":     config.get(section, "host"),
    }
    if config.has_option(section, "port"):
        params["port"] = config.getint(section, "port")
    return params


def parse_int(val):
    if val is None or (isinstance(val, float) and np.isnan(val)):
        return None
    s = str(val).strip().replace(",", "")
    return int(float(s)) if s and s.lower() != "nan" else None


def parse_float(val):
    if val is None or (isinstance(val, float) and np.isnan(val)):
        return None
    s = str(val).strip().replace(",", "").replace("%", "")
    return float(s) if s and s.lower() != "nan" else None


def parse_filename(fname):
    """
    Parse fields from a hifi gfastats filename. Handles multiple formats:
      OGxxx_vDDDDDD.hifi1.0.hifiasm.p_ctg.assembly_summary.txt       -> p_ctg
      OGxxx_vDDDDDD.hifi1.0.hifiasm.a_ctg.assembly.summary.txt       -> a_ctg
      OGxxx_vDDDDDD.hifi1.0.hifiasm.bp.hap1.p_ctg.assembly.summary.txt -> p_ctg
      OGxxx_vDDDDDD.hifi1.0.hifiasm.bp.hap2.p_ctg.assembly.summary.txt -> a_ctg
      OG855_240821.hifi1... (date without 'v' prefix)
      OG906_hifi1...       (no date — seq_date=None)
      OG90_bc2008_v240821.hifi1... (og_id=OG90_bc2008)
    """
    # Special case: OG906 — no date in filename
    if fname.startswith("OG906_hifi1"):
        haplotype = "p_ctg" if "p_ctg" in fname else ("a_ctg" if "a_ctg" in fname else None)
        return "OG906", "250212", "hifi1", 0, haplotype

    # Special case: OG90_bc2008 — barcode embedded in og_id
    if fname.startswith("OG90_bc2008"):
        haplotype = "p_ctg" if "p_ctg" in fname else ("a_ctg" if "a_ctg" in fname else None)
        return "OG90_bc2008", "240821", "hifi1", 0, haplotype

    parts = fname.split(".")
    first = parts[0].split("_")          # ["OGxxx", "vDDDDDD"] or ["OG855", "240821"]
    og_id    = first[0] if len(first) > 0 else None
    seq_date = first[1].lstrip("v") if len(first) > 1 else None
    version  = "hifi1"                   # stage 0 hifi assemblies are always hifi1
    stage    = parse_int(parts[2]) if len(parts) > 2 else None

    # Determine haplotype — handle bp.hap1/hap2 style
    if len(parts) > 4 and parts[4] == "bp":
        if len(parts) > 5 and parts[5] == "hap1":
            haplotype = "p_ctg"
        elif len(parts) > 5 and parts[5] == "hap2":
            haplotype = "a_ctg"
        else:
            haplotype = None  # bp.p_ctg — should have been filtered before reaching here
    else:
        haplotype = parts[4] if len(parts) > 4 else None

    return og_id, seq_date, version, stage, haplotype


config_file = sys.argv[1]
input_file  = sys.argv[2] if len(sys.argv) > 2 else "hifi_gfastats_report.txt"

print(f"Importing data from {input_file}")
gfa = pd.read_csv(input_file, sep="\t")

gfa[["og_id", "seq_date", "version", "stage", "haplotype"]] = gfa["filename"].apply(
    lambda x: pd.Series(parse_filename(str(x)))
)

print("\n🔍 Parsed rows:")
print(gfa[["filename", "og_id", "seq_date", "version", "stage", "haplotype"]].to_string(index=False))

conn = cursor = None
try:
    conn   = psycopg2.connect(**load_db_config(config_file))
    cursor = conn.cursor()

    upsert_query = """
    INSERT INTO ref_genomes (
        og_id, seq_date, version, stage, haplotype,
        num_contigs, contig_n50, contig_n50_size_mb,
        num_scaffolds, scaffold_n50, scaffold_n50_size_mb,
        largest_scaffold, largest_scaffold_size_mb,
        total_scaffold_length, total_scaffold_length_size_mb,
        gc_content_percent
    )
    VALUES (
        %(og_id)s, %(seq_date)s, %(version)s, %(stage)s, %(haplotype)s,
        %(num_contigs)s, %(contig_n50)s, %(contig_n50_size_mb)s,
        %(num_scaffolds)s, %(scaffold_n50)s, %(scaffold_n50_size_mb)s,
        %(largest_scaffold)s, %(largest_scaffold_size_mb)s,
        %(total_scaffold_length)s, %(total_scaffold_length_size_mb)s,
        %(gc_content_percent)s
    )
    ON CONFLICT (og_id, seq_date, stage, haplotype, version) DO UPDATE SET
        num_contigs                  = EXCLUDED.num_contigs,
        contig_n50                   = EXCLUDED.contig_n50,
        contig_n50_size_mb           = EXCLUDED.contig_n50_size_mb,
        num_scaffolds                = EXCLUDED.num_scaffolds,
        scaffold_n50                 = EXCLUDED.scaffold_n50,
        scaffold_n50_size_mb         = EXCLUDED.scaffold_n50_size_mb,
        largest_scaffold             = EXCLUDED.largest_scaffold,
        largest_scaffold_size_mb     = EXCLUDED.largest_scaffold_size_mb,
        total_scaffold_length        = EXCLUDED.total_scaffold_length,
        total_scaffold_length_size_mb = EXCLUDED.total_scaffold_length_size_mb,
        gc_content_percent           = EXCLUDED.gc_content_percent;
    """

    for i, row in gfa.iterrows():
        params = {
            "og_id":     row.get("og_id"),
            "seq_date":  row.get("seq_date"),
            "version":   row.get("version"),
            "stage":     parse_int(row.get("stage")),
            "haplotype": row.get("haplotype"),
            "num_contigs":                    parse_int(row.get("num_contigs")),
            "contig_n50":                     parse_int(row.get("contig_n50")),
            "contig_n50_size_mb":             parse_float(row.get("contig_n50_size_mb")),
            "num_scaffolds":                  parse_int(row.get("num_scaffolds")),
            "scaffold_n50":                   parse_int(row.get("scaffold_n50")),
            "scaffold_n50_size_mb":           parse_float(row.get("scaffold_n50_size_mb")),
            "largest_scaffold":               parse_int(row.get("largest_scaffold")),
            "largest_scaffold_size_mb":       parse_float(row.get("largest_scaffold_size_mb")),
            "total_scaffold_length":          parse_int(row.get("total_scaffold_length")),
            "total_scaffold_length_size_mb":  parse_float(row.get("total_scaffold_length_size_mb")),
            "gc_content_percent":             parse_float(row.get("gc_content_percent")),
        }
        cursor.execute(upsert_query, params)
        conn.commit()
        print(f"✅ Upserted: {params['og_id']} {params['seq_date']} version={params['version']} stage={params['stage']} haplotype={params['haplotype']}")

except Exception as e:
    if conn:
        conn.rollback()
    print(f"❌ Error: {e}")
finally:
    if cursor: cursor.close()
    if conn:   conn.close()
