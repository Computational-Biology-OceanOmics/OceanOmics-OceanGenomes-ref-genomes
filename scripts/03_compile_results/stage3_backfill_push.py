#!/usr/bin/env python3
"""
Stage 3 backfill: download, parse and push gfastats, BUSCO, and merqury QV
for 13 OGs that have results in the bucket but not yet in the DB.

Usage:
    singularity exec $SING/psycopg2:0.1.sif python3 stage3_backfill_push.py ~/postgresql_details/oceanomics.cfg

Handles:
  - gfastats: *.3.curated.hap[12].*.summary.txt
  - BUSCO batch_summary (standard tab-delimited)
  - BUSCO short_summary.txt (OG88 narrative format)
  - merqury .qv files (combined multi-row or per-haplotype)
"""

import subprocess, sys, os, re, configparser, shutil
from pathlib import Path

# Find rclone — may not be on PATH inside singularity
RCLONE = shutil.which("rclone") or "/software/setonix/2025.08/software/linux-sles15-zen3/gcc-14.2.0/rclone-1.68.1-keh5njlsrwncnbkajieeatgbqtxdsc3s/bin/rclone"

# ── Config ──────────────────────────────────────────────────────────────────
BUCKET  = "pawsey0964:oceanomics-refassemblies"
TMPDIR  = Path("/scratch/pawsey0964/lhuet/stage3_backfill_tmp")
CFG     = sys.argv[1] if len(sys.argv) > 1 else str(Path.home() / "postgresql_details/oceanomics.cfg")

TMPDIR.mkdir(parents=True, exist_ok=True)

# ── OG manifest: (og_id, seq_date, version, bucket_dir) ────────────────────
OGS = [
    # hic1 — gfastats+busco+merqury all missing
    ("OG13",  "230212", "hic1", "OG13_v230212.hic1"),
    ("OG88",  "230728", "hic1", "OG88_v230728.hic1"),
    ("OG9",   "240206", "hic1", "OG9_v240206.hic1"),
    ("OG657", "250110", "hic1", "OG657_v250110.hic1"),
    ("OG683", "241025", "hic1", "OG683_v241025.hic1"),
    # hic1 — only dual merqury missing
    ("OG646", "240821", "hic1", "OG646_v240821.hic1"),
    ("OG863", "241004", "hic1", "OG863_v241004.hic1"),
    # hic2 — busco missing
    ("OG114", "240116", "hic2", "OG114_v240116.hic2"),
    ("OG665", "240501", "hic2", "OG665_v240501.hic2"),
    ("OG749", "250331", "hic2", "OG749_v250331.hic2"),
    ("OG785", "241004", "hic2", "OG785_v241004.hic2"),
    # hic2 — only dual merqury missing
    ("OG808", "240520", "hic2", "OG808_v240520.hic2"),
    # hic2 — everything missing
    ("OG820", "240502", "hic2", "OG820_v240502.hic2"),
]

# ── DB helpers ───────────────────────────────────────────────────────────────
def load_db_config(cfg_path):
    cfg = configparser.ConfigParser()
    cfg.read(cfg_path)
    return {k: cfg.get("postgres", k) for k in ("dbname","user","password","host","port")}

def get_conn():
    import psycopg2
    p = load_db_config(CFG)
    return psycopg2.connect(dbname=p["dbname"], user=p["user"],
                            password=p["password"], host=p["host"], port=int(p["port"]))

def pf(v):
    """Parse float, return None on failure."""
    try:
        s = str(v).strip().replace(",","").replace("%","")
        return float(s) if s and s.lower() != "nan" else None
    except (ValueError, TypeError):
        return None

def pi(v):
    """Parse int, return None on failure."""
    try:
        s = str(v).strip().replace(",","")
        return int(float(s)) if s and s.lower() != "nan" else None
    except (ValueError, TypeError):
        return None

# ── rclone helpers ───────────────────────────────────────────────────────────
def rclone_download(remote_path, local_dir):
    """Download a single file; return local path or None on failure."""
    fname = Path(remote_path).name
    local = Path(local_dir) / fname
    r = subprocess.run(
        [RCLONE, "copy", remote_path, str(local_dir)],
        capture_output=True, text=True
    )
    return local if local.exists() else None

def rclone_ls(remote_dir):
    """List files (not dirs) in remote_dir. Returns list of filenames."""
    r = subprocess.run(
        [RCLONE, "lsf", remote_dir, "--files-only"],
        capture_output=True, text=True
    )
    return [l.strip() for l in r.stdout.splitlines() if l.strip()]

def rclone_download_dir(remote_dir, local_dir):
    """Download all files in remote_dir to local_dir."""
    Path(local_dir).mkdir(parents=True, exist_ok=True)
    subprocess.run([RCLONE, "copy", remote_dir, str(local_dir)],
                   capture_output=True, text=True)

# ── Haplotype detection from sample/filename strings ─────────────────────────
def detect_hap(s):
    """Return 'hap1', 'hap2', 'dual', or None."""
    s = str(s)
    if s.strip() == "Both":
        return "dual"
    if re.search(r'hap2', s, re.IGNORECASE):
        return "hap2"
    if re.search(r'hap1', s, re.IGNORECASE):
        return "hap1"
    return None

# ── GFASTATS PARSING ─────────────────────────────────────────────────────────
def parse_gfastats_file(path):
    """Parse a gfastats assembly summary txt. Returns dict of metrics."""
    kw = {}
    for line in Path(path).read_text().splitlines():
        parts = line.split("\t")
        if len(parts) < 2:
            continue
        key, val = parts[0].strip(), parts[-1].strip()
        kw[key] = val
    def g(k): return kw.get(k)
    num_scaffolds  = pi(g("# scaffolds"))
    scaffold_len   = pi(g("Total scaffold length"))
    scaffold_n50   = pi(g("Scaffold N50"))
    largest_scaf   = pi(g("Largest scaffold"))
    num_contigs    = pi(g("# contigs"))
    contig_n50     = pi(g("Contig N50"))
    gc_raw         = g("GC content")
    gc = pf(gc_raw.rstrip("%")) if gc_raw else None
    # gfastats reports GC as fraction (0.42) not percent — multiply if < 1
    if gc is not None and gc < 1:
        gc = round(gc * 100, 4)
    return {
        "num_contigs": num_contigs,
        "contig_n50": contig_n50,
        "contig_n50_size_mb": round(contig_n50 / 1e6, 4) if contig_n50 else None,
        "num_scaffolds": num_scaffolds,
        "scaffold_n50": scaffold_n50,
        "scaffold_n50_size_mb": round(scaffold_n50 / 1e6, 4) if scaffold_n50 else None,
        "largest_scaffold": largest_scaf,
        "largest_scaffold_size_mb": round(largest_scaf / 1e6, 4) if largest_scaf else None,
        "total_scaffold_length": scaffold_len,
        "total_scaffold_length_size_mb": round(scaffold_len / 1e6, 4) if scaffold_len else None,
        "gc_content_percent": gc,
    }

# ── BUSCO PARSING ─────────────────────────────────────────────────────────────
def parse_busco_batch_summary(path, og_id, seq_date, version):
    """
    Parse a BUSCO batch_summary.txt. Returns list of row dicts.
    Handles both column layouts (with/without 'Internal stop codon percent').
    Skips 'Run failed' rows.
    """
    rows = []
    lines = Path(path).read_text().splitlines()
    if not lines:
        return rows
    header = lines[0].split("\t")
    # Normalise header keys
    header = [h.strip() for h in header]
    has_isc = "Internal stop codon percent" in header

    for line in lines[1:]:
        fields = line.split("\t")
        if not fields or len(fields) < 8:
            continue
        row = dict(zip(header, fields))
        input_file = row.get("Input_file", "").strip()
        dataset    = row.get("Dataset", "").strip()
        if not dataset or "Run failed" in line or not input_file:
            continue

        hap = detect_hap(input_file)
        if not hap:
            continue

        isc = pf(row.get("Internal stop codon percent")) if has_isc else None

        rows.append({
            "og_id": og_id,
            "seq_date": seq_date,
            "version": version,
            "stage": 3,
            "haplotype": hap,
            "dataset": dataset,
            "complete": pf(row.get("Complete")),
            "single_copy": pf(row.get("Single")),
            "multi_copy": pf(row.get("Duplicated")),
            "fragmented": pf(row.get("Fragmented")),
            "missing": pf(row.get("Missing")),
            "n_markers": pi(row.get("n_markers")),
            "internal_stop_codon_percent": isc,
            "scaffold_n50_bus": pi(row.get("Scaffold N50")),
            "contigs_n50_bus": pi(row.get("Contigs N50")),
            "percent_gaps": pf(row.get("Percent gaps")),
            "number_of_scaffolds": pi(row.get("Number of scaffolds")),
        })
    return rows

def parse_busco_short_summary(path, og_id, seq_date, version, hap):
    """
    Parse a BUSCO short_summary.txt (narrative format, e.g. OG88).
    Returns a single row dict or None.
    Note: Scaffold/Contig N50 are in MB (approximate).
    """
    text = Path(path).read_text()

    # Parse summary line: C:98.9%[S:98.2%,D:0.7%],F:0.4%,M:0.7%,n:3640
    m = re.search(r'C:([\d.]+)%\[S:([\d.]+)%,D:([\d.]+)%\],F:([\d.]+)%,M:([\d.]+)%,n:(\d+)', text)
    if not m:
        return None
    complete, single, dup, frag, miss, n_markers = m.groups()

    # Assembly statistics block
    num_scaf = None; pct_gaps = None; scaf_n50_mb = None; cont_n50_mb = None
    for line in text.splitlines():
        line = line.strip()
        if re.match(r'^\d+\s+Number of scaffolds', line):
            num_scaf = pi(line.split()[0])
        elif re.search(r'Percent gaps', line):
            m2 = re.search(r'([\d.]+)%', line)
            if m2: pct_gaps = pf(m2.group(1))
        elif re.search(r'Scaffold N50', line):
            m2 = re.search(r'([\d.]+)\s*MB', line, re.IGNORECASE)
            if m2: scaf_n50_mb = int(float(m2.group(1)) * 1e6)
        elif re.search(r'Contigs N50', line):
            m2 = re.search(r'([\d.]+)\s*MB', line, re.IGNORECASE)
            if m2: cont_n50_mb = int(float(m2.group(1)) * 1e6)

    # Dataset from lineage line
    m3 = re.search(r'lineage dataset is: (\S+)', text)
    dataset = m3.group(1).rstrip(')').rstrip(',') if m3 else "actinopterygii_odb10"

    return {
        "og_id": og_id,
        "seq_date": seq_date,
        "version": version,
        "stage": 3,
        "haplotype": hap,
        "dataset": dataset,
        "complete": pf(complete),
        "single_copy": pf(single),
        "multi_copy": pf(dup),
        "fragmented": pf(frag),
        "missing": pf(miss),
        "n_markers": pi(n_markers),
        "internal_stop_codon_percent": None,  # not in short_summary
        "scaffold_n50_bus": scaf_n50_mb,  # approximate (MB-rounded)
        "contigs_n50_bus": cont_n50_mb,   # approximate
        "percent_gaps": pct_gaps,
        "number_of_scaffolds": num_scaf,
    }

# ── MERQURY PARSING ───────────────────────────────────────────────────────────
def parse_merqury_qv_file(path, og_id, seq_date, version):
    """
    Parse a merqury .qv file (5-column: sample, unique_kmers, total_kmers, qv, error).
    Returns list of row dicts (one per haplotype row found).
    """
    rows = []
    for line in Path(path).read_text().splitlines():
        fields = line.strip().split("\t")
        if len(fields) < 4:
            continue
        sample = fields[0].strip()
        hap = detect_hap(sample)
        if not hap:
            continue
        rows.append({
            "og_id": og_id,
            "seq_date": seq_date,
            "version": version,
            "stage": 3,
            "haplotype": hap,
            "unique_k_mers_assembly": pi(fields[1]),
            "k_mers_total": pi(fields[2]),
            "qv": pf(fields[3]),
            "error": pf(fields[4]) if len(fields) > 4 else None,
        })
    return rows

# ── DB UPSERTS ───────────────────────────────────────────────────────────────
def upsert_gfastats(cur, og_id, seq_date, stage, hap, version, m):
    cur.execute("""
        INSERT INTO ref_genomes (
            og_id, seq_date, stage, haplotype, version,
            num_contigs, contig_n50, contig_n50_size_mb,
            num_scaffolds, scaffold_n50, scaffold_n50_size_mb,
            largest_scaffold, largest_scaffold_size_mb,
            total_scaffold_length, total_scaffold_length_size_mb,
            gc_content_percent
        ) VALUES (
            %(og_id)s, %(seq_date)s, %(stage)s, %(haplotype)s, %(version)s,
            %(num_contigs)s, %(contig_n50)s, %(contig_n50_size_mb)s,
            %(num_scaffolds)s, %(scaffold_n50)s, %(scaffold_n50_size_mb)s,
            %(largest_scaffold)s, %(largest_scaffold_size_mb)s,
            %(total_scaffold_length)s, %(total_scaffold_length_size_mb)s,
            %(gc_content_percent)s
        )
        ON CONFLICT (og_id, seq_date, stage, haplotype, version) DO UPDATE SET
            num_contigs               = EXCLUDED.num_contigs,
            contig_n50                = EXCLUDED.contig_n50,
            contig_n50_size_mb        = EXCLUDED.contig_n50_size_mb,
            num_scaffolds             = EXCLUDED.num_scaffolds,
            scaffold_n50              = EXCLUDED.scaffold_n50,
            scaffold_n50_size_mb      = EXCLUDED.scaffold_n50_size_mb,
            largest_scaffold          = EXCLUDED.largest_scaffold,
            largest_scaffold_size_mb  = EXCLUDED.largest_scaffold_size_mb,
            total_scaffold_length     = EXCLUDED.total_scaffold_length,
            total_scaffold_length_size_mb = EXCLUDED.total_scaffold_length_size_mb,
            gc_content_percent        = EXCLUDED.gc_content_percent
    """, {"og_id": og_id, "seq_date": seq_date, "stage": stage,
          "haplotype": hap, "version": version, **m})

def upsert_busco(cur, row):
    cur.execute("""
        INSERT INTO ref_genomes (
            og_id, seq_date, stage, haplotype, version,
            dataset, complete, single_copy, multi_copy, fragmented, missing,
            n_markers, internal_stop_codon_percent,
            scaffold_n50_bus, contigs_n50_bus, percent_gaps, number_of_scaffolds
        ) VALUES (
            %(og_id)s, %(seq_date)s, %(stage)s, %(haplotype)s, %(version)s,
            %(dataset)s, %(complete)s, %(single_copy)s, %(multi_copy)s,
            %(fragmented)s, %(missing)s, %(n_markers)s, %(internal_stop_codon_percent)s,
            %(scaffold_n50_bus)s, %(contigs_n50_bus)s, %(percent_gaps)s, %(number_of_scaffolds)s
        )
        ON CONFLICT (og_id, seq_date, stage, haplotype, version) DO UPDATE SET
            dataset                    = EXCLUDED.dataset,
            complete                   = EXCLUDED.complete,
            single_copy                = EXCLUDED.single_copy,
            multi_copy                 = EXCLUDED.multi_copy,
            fragmented                 = EXCLUDED.fragmented,
            missing                    = EXCLUDED.missing,
            n_markers                  = EXCLUDED.n_markers,
            internal_stop_codon_percent = EXCLUDED.internal_stop_codon_percent,
            scaffold_n50_bus           = EXCLUDED.scaffold_n50_bus,
            contigs_n50_bus            = EXCLUDED.contigs_n50_bus,
            percent_gaps               = EXCLUDED.percent_gaps,
            number_of_scaffolds        = EXCLUDED.number_of_scaffolds
    """, row)

def upsert_merqury(cur, row):
    cur.execute("""
        INSERT INTO ref_genomes (
            og_id, seq_date, stage, haplotype, version,
            unique_k_mers_assembly, k_mers_total, qv, error
        ) VALUES (
            %(og_id)s, %(seq_date)s, %(stage)s, %(haplotype)s, %(version)s,
            %(unique_k_mers_assembly)s, %(k_mers_total)s, %(qv)s, %(error)s
        )
        ON CONFLICT (og_id, seq_date, stage, haplotype, version) DO UPDATE SET
            unique_k_mers_assembly = EXCLUDED.unique_k_mers_assembly,
            k_mers_total           = EXCLUDED.k_mers_total,
            qv                     = EXCLUDED.qv,
            error                  = EXCLUDED.error
    """, row)

# ── MAIN ─────────────────────────────────────────────────────────────────────
def main():
    conn = get_conn()
    cur  = conn.cursor()
    total_gfa = total_bus = total_mer = 0

    for og_id, seq_date, version, bucket_dir in OGS:
        print(f"\n{'='*60}")
        print(f"  {og_id}  seq={seq_date}  ver={version}")
        print(f"{'='*60}")

        og_tmp = TMPDIR / og_id
        gfa_tmp = og_tmp / "gfastats"
        bus_tmp = og_tmp / "busco"
        mer_tmp = og_tmp / "merqury"

        remote_base = f"{BUCKET}/{og_id}/{bucket_dir}"

        # ── Download (skip if already downloaded) ────────────────────────────
        if not gfa_tmp.exists() or not any(gfa_tmp.iterdir() if gfa_tmp.exists() else []):
            print("  Downloading gfastats, busco, merqury...")
            rclone_download_dir(f"{remote_base}/gfastats", str(gfa_tmp))
            rclone_download_dir(f"{remote_base}/busco",    str(bus_tmp))
            rclone_download_dir(f"{remote_base}/merqury",  str(mer_tmp))
        else:
            print("  Using cached downloads.")

        # ── GFASTATS ─────────────────────────────────────────────────────────
        gfa_files = list(gfa_tmp.glob("*3.curated*hap*.*.txt")) if gfa_tmp.exists() else []
        if not gfa_files:
            # Also try .summary.txt style
            gfa_files = list(gfa_tmp.glob("*3.curated*.summary.txt")) if gfa_tmp.exists() else []
        for gfa_f in gfa_files:
            hap = detect_hap(gfa_f.name)
            if not hap or hap == "dual":
                continue
            metrics = parse_gfastats_file(gfa_f)
            upsert_gfastats(cur, og_id, seq_date, 3, hap, version, metrics)
            conn.commit()
            print(f"  ✅ gfastats {hap}: n50={metrics['scaffold_n50']}")
            total_gfa += 1

        # ── BUSCO ────────────────────────────────────────────────────────────
        busco_rows = []

        # Try batch_summary files first (prefer `-busco.batch_summary.txt` then `3.curated.batch_summary.txt`)
        batch_files = (list(bus_tmp.glob("*-busco.batch_summary.txt")) +
                       list(bus_tmp.glob("*3.curated.batch_summary.txt"))) if bus_tmp.exists() else []
        for bf in batch_files:
            rows = parse_busco_batch_summary(bf, og_id, seq_date, version)
            busco_rows.extend(rows)

        # Fallback: short_summary.txt (e.g. OG88)
        if not busco_rows and bus_tmp.exists():
            for sf in bus_tmp.glob("*3.curated.*_short_summary.txt"):
                hap = detect_hap(sf.name)
                if not hap or hap == "dual":
                    continue
                row = parse_busco_short_summary(sf, og_id, seq_date, version, hap)
                if row:
                    busco_rows.append(row)

        for row in busco_rows:
            upsert_busco(cur, row)
            conn.commit()
            print(f"  ✅ busco {row['haplotype']}: complete={row['complete']}%")
            total_bus += 1

        # ── MERQURY ──────────────────────────────────────────────────────────
        mer_rows = []

        # Look in subdirectories too (some OGs store .qv in named subdirs)
        qv_files = list(mer_tmp.rglob("*3.curated*.qv")) if mer_tmp.exists() else []
        # Exclude .completeness.stats, only want plain .qv files
        qv_files = [f for f in qv_files if not f.name.endswith(".completeness.stats")]

        for qf in qv_files:
            rows = parse_merqury_qv_file(qf, og_id, seq_date, version)
            mer_rows.extend(rows)

        # Deduplicate by haplotype (take last seen — later files override)
        seen_hap = {}
        for row in mer_rows:
            seen_hap[row["haplotype"]] = row
        for row in seen_hap.values():
            upsert_merqury(cur, row)
            conn.commit()
            print(f"  ✅ merqury {row['haplotype']}: qv={row['qv']}")
            total_mer += 1

    cur.close()
    conn.close()
    print(f"\n{'='*60}")
    print(f"  DONE: {total_gfa} gfastats, {total_bus} BUSCO, {total_mer} merqury rows pushed")
    print(f"{'='*60}")

if __name__ == "__main__":
    main()
