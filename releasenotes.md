# OceanOmics-OceanGenomes-ref-genomes v2.0.0

## New Assembly Modes

The pipeline now supports four modes via `--assembly_mode`:

| Mode | Input | Description |
|------|-------|-------------|
| `hifi_hic` (default) | HiFi + Hi-C reads | Full dual-haplotype assembly |
| `hifi_only` | HiFi reads only | Primary + alternate contigs, no scaffolding |
| Precomputed dual-hap | `hap1_assembly` + `hap2_assembly` in samplesheet | Skip Hifiasm, run full dual-hap pipeline |
| Precomputed single-hap | `primary_assembly` in samplesheet | Skip Hifiasm, run single-hap pipeline |

## Improvements

- **Decontamination** — Tiara now removes bacteria and archaea contigs (previously prokarya/mito/plastid only)
- **Scaffold renaming** — `RENAME_SCAFFOLDS` rebuilt with retry logic and output validation matching `CAT_SCAFFOLDS`
- **Resource allocation** — `FCS_FCSGX` in single-hap mode now runs on the `highmem` queue (512 GB); fixes OOM exit 137
- **Backup scripts** — `full_assembly_backup.sh` now supports `hifi_hic`, `single_hap`, and `dual_hap` modes
- **Samplesheet generation** — `create_samplesheet_from_config.py` outputs `primary_assembly`, `hap1_assembly`, `hap2_assembly` columns; paths auto-populated where directories exist

## Bug Fixes

- Fixed zero-coverage gaps bedgraph not replacing `0` with `200` (sed end-of-line anchor escape)
- Fixed `GFASTATS` output publishing to wrong directory in single-haplotype mode
