#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
script="${SCRIPT_DIR}"
csv_file="${REPO_DIR}/assets/samplesheet.csv"

# Loop through each line of the CSV
tail -n +2 "$csv_file" | while IFS=',' read -r sample hifi_dir hic_dir version date tolid taxid species; do
    # Pass sample, date, version to your job script
    sbatch "$script/full_assembly_backup.sh" "$sample" "$date" "$version"
    echo "Submitted: $sample $date $version"
done
