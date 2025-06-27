#!/bin/bash
script=/scratch/pawsey0964/lhuet/hifi-only/OceanOmics-OceanGenomes-ref-genomes/scripts/04_backup_scripts
csv_file="/scratch/pawsey0964/lhuet/hifi-only/OceanOmics-OceanGenomes-ref-genomes/assets/samplesheet.csv"

# Loop through each line of the CSV
tail -n +2 "$csv_file" | while IFS=',' read -r sample hifi_dir version date tolid taxid species; do
    # Pass sample, date, version to your job script
    sbatch "$script/hifi_only_assembly_backup.sh" "$sample" "$date" "$version"
    echo "Submitted: $sample $date $version"
done
