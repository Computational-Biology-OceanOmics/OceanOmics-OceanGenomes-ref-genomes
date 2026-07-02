#!/usr/bin/env python3
"""
Query the sequencing table for all HiC runs for each OG in the samplesheet,
then write rclone copy commands to a shell script for execution on the host.

Previous runs = all Hi-C run_ids in the DB that are NOT in --current-runs.
Files are copied from:
    s3:oceanomics/OceanGenomes/illumina-hic/<run_id>/<og_id>/
into the hic_dir for each OG (as specified in the samplesheet).

Run inside the psycopg2 Singularity container:
    singularity run $SING/psycopg2:0.1.sif python stage_previous_hic.py \
        ~/postgresql_details/oceanomics.cfg samplesheet.csv \
        --current-runs NOVA_260603_TW2 \
        --cmd-output /tmp/prev_hic_cmds.sh
"""

import argparse
import configparser
import csv
import sys
from collections import defaultdict
from pathlib import Path

HIC_BUCKET = "s3:oceanomics/OceanGenomes/illumina-hic"


def load_db_config(config_file):
    path = Path(config_file).expanduser()
    cfg = configparser.ConfigParser()
    cfg.read(path)
    p = dict(cfg["postgres"])
    return {k: (int(v) if k == "port" else v) for k, v in p.items()}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("postgres_cfg")
    parser.add_argument("samplesheet")
    parser.add_argument("--current-runs", default="",
                        help="Comma-separated run IDs for the current batch (will be skipped)")
    parser.add_argument("--cmd-output", default=None,
                        help="Path to write the generated rclone commands shell script")
    args = parser.parse_args()

    current_runs = {r.strip() for r in args.current_runs.split(",") if r.strip()}

    # Load samplesheet: og_id -> hic_dir
    og_hic_dirs = {}
    with open(args.samplesheet) as f:
        for row in csv.DictReader(f):
            og = (row.get("sample") or "").strip()
            hic_dir = (row.get("hic_dir") or "").strip()
            if og and hic_dir:
                og_hic_dirs[og] = hic_dir

    if not og_hic_dirs:
        print("No samples found in samplesheet", file=sys.stderr)
        sys.exit(0)

    og_ids = sorted(og_hic_dirs.keys())
    print(f"Checking previous HiC runs for {len(og_ids)} OG(s): {', '.join(og_ids)}")
    if current_runs:
        print(f"  Current runs (skipping): {', '.join(sorted(current_runs))}")

    import psycopg2
    db_params = load_db_config(args.postgres_cfg)
    conn = psycopg2.connect(**db_params)
    cur = conn.cursor()

    cur.execute(
        """
        SELECT og_id, run_id, hic_library_tube_id
        FROM sequencing
        WHERE og_id = ANY(%s)
          AND technology = 'Hi-C'
          AND (run_id ILIKE 'NOVA_%%' OR run_id ILIKE 'NEXT_%%')
        ORDER BY og_id, seq_date
        """,
        (og_ids,),
    )
    rows = cur.fetchall()
    conn.close()

    og_runs = defaultdict(list)
    for og_id, run_id, tube_id in rows:
        og_runs[og_id].append((run_id, tube_id))

    cmds = []
    staged_summary = []

    for og_id in og_ids:
        hic_dir = og_hic_dirs[og_id]
        all_runs = og_runs.get(og_id, [])
        all_run_ids = [r for r, _ in all_runs]
        prev_runs = [(r, t) for r, t in all_runs if r not in current_runs]
        prev_run_ids = [r for r, _ in prev_runs]

        if not all_runs:
            print(f"  {og_id}: no HiC records in sequencing table")
            continue

        print(f"  {og_id}: {len(all_runs)} HiC run(s) in DB: {', '.join(all_run_ids)}")

        if not prev_runs:
            print(f"    no previous runs to stage")
            continue

        print(f"    staging {len(prev_runs)} previous run(s): {', '.join(prev_run_ids)}")
        staged_summary.append(f"{og_id}: {', '.join(prev_run_ids)}")

        for run_id, tube_id in prev_runs:
            src = f"{HIC_BUCKET}/{run_id}/{og_id}/"
            # Namespace by run_id: NovaSeq reuses lane/sample-index naming
            # across runs, so files from different runs can share a basename.
            # Staging them into one flat directory would silently overwrite
            # an earlier run's reads with a later one's.
            dst = f"{hic_dir}/{run_id}/"
            cmds.append(f"mkdir -p '{hic_dir}/{run_id}'")
            cmds.append(
                f"echo '  [{og_id}] Copying previous run {run_id} (tube: {tube_id}) "
                f"from {src}'"
            )
            # Guard: skip gracefully if the S3 path doesn't exist yet
            cmds.append(
                f"if rclone ls '{src}' --max-depth 1 >/dev/null 2>&1; then"
            )
            cmds.append(f"  rclone copy '{src}' '{dst}' --no-traverse")
            cmds.append(
                f"else"
            )
            cmds.append(
                f"  echo '  WARNING: {src} not found on S3 — skipping (run not yet backed up?)'"
            )
            cmds.append(f"fi")

    if not cmds:
        print("\nNo previous HiC runs to stage.")
    else:
        print(f"\n{len(staged_summary)} OG(s) have previous runs: {'; '.join(staged_summary)}")

    if args.cmd_output:
        with open(args.cmd_output, "w") as f:
            f.write("#!/bin/bash\n")
            f.write("set -euo pipefail\n")
            f.write(f"# Previous HiC staging for OGs: {', '.join(og_ids)}\n")
            f.write(f"# Current runs excluded: {', '.join(sorted(current_runs))}\n\n")
            for cmd in cmds:
                f.write(cmd + "\n")
            if cmds:
                f.write("\necho 'Previous HiC staging complete.'\n")
            else:
                f.write("echo 'No previous HiC runs to stage.'\n")
        print(f"Commands written to: {args.cmd_output}")
    elif cmds:
        print("\nCommands (dry-run — no --cmd-output specified):")
        for cmd in cmds:
            print(f"  {cmd}")


if __name__ == "__main__":
    main()
