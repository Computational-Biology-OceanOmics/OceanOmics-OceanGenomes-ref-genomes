#!/bin/bash
script=/scratch/pawsey0964/lhuet/refgenomes
csv_file="backup.csv"

# Loop through each line of the CSV
tail -n +2 "$csv_file" | while IFS=',' read -r OG date version; do
    # Submit the backup script, passing OG and asm_version as arguments
    sbatch $script/full_assembly_backup.sh "$OG" "$date" "$version"
    echo $OG $date $version
done