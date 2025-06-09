#!/bin/bash

# Path to your sample sheet
SAMPLE_SHEET="/scratch/pawsey0964/lhuet/refgenomes/OceanOmics-OceanGenomes-ref-genomes/assets/samplesheet.csv"

# Path to the chromsyn.sh script
CHROMSYN_SCRIPT="/scratch/pawsey0964/lhuet/refgenomes/OceanOmics-OceanGenomes-ref-genomes/scripts/02_run_chromsyn/chromsyn.sh"

# Dry-run mode flag
DRY_RUN=false  # Set to true to test without submitting jobs

# Read the sample sheet, skipping the header row
tail -n +2 "$SAMPLE_SHEET" | while IFS=',' read -r sample hifi_dir hic_dir version date tolid taxid species; do

    echo "Processing sample: $sample, date: $date"

    # Define the output directory
    OUTPUT_DIR="/scratch/pawsey0964/lhuet/refgenomes/${sample}/09-chromsyn"

    # Print the output directory creation step
    echo "Creating directory: $OUTPUT_DIR"
    if [[ "$DRY_RUN" == "false" ]]; then
        mkdir -p "$OUTPUT_DIR"
    fi

    # Print the script copy step
    echo "Copying chromsyn.sh to: $OUTPUT_DIR"
    if [[ "$DRY_RUN" == "false" ]]; then
        cp "$CHROMSYN_SCRIPT" "$OUTPUT_DIR"
    fi

    # Print the navigation step
    echo "Navigating to: $OUTPUT_DIR"
    if [[ "$DRY_RUN" == "false" ]]; then
        cd "$OUTPUT_DIR" || exit
    fi

    # Print the sbatch submission command
    echo "Would submit: sbatch ./chromsyn.sh $sample $date"
    if [[ "$DRY_RUN" == "false" ]]; then
        sbatch ./chromsyn.sh "$sample" "$date"
    fi

    # Move back to the original directory (for dry-run mode)
    echo "Returning to the original directory"
    if [[ "$DRY_RUN" == "false" ]]; then
        cd - > /dev/null
    fi

    echo "-----------------------------------------"

done
