#!/bin/bash
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
script="${REPO_DIR}/scripts/04_backup_scripts"
csv_file="${REPO_DIR}/assets/samplesheet.csv"

# Loop through each line of the CSV
tail -n +2 "$csv_file" | while IFS=',' read -r sample hifi_dir hic_dir version date tolid taxid species; do
    # Pass sample, date, version to your job script
    sbatch "$script/full_assembly_backup.sh" "$sample" "$date" "$version"
    echo "Submitted: $sample $date $version"
done
