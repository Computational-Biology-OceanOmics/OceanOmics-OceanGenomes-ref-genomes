#!/bin/bash

# Path to your sample sheet
SAMPLE_SHEET="/scratch/pawsey0964/lhuet/ref-gen/yahs/OceanOmics-OceanGenomes-ref-genomes/assets/samplesheet.csv"

# Path to the chromsyn.sh script
CHROMSYN_SCRIPT="/scratch/pawsey0964/lhuet/ref-gen/yahs/OceanOmics-OceanGenomes-ref-genomes/scripts/02_run_chromsyn/chromsyn.sh"

# Dry-run mode flag
DRY_RUN=false  # Set to true to test without submitting jobs

# Read the sample sheet, skipping the header row
tail -n +2 "$SAMPLE_SHEET" | while IFS=',' read -r sample hifi_dir hic_dir version date tolid taxid species; do

    echo "Processing sample: $sample, date: $date, version: $version"

    OUTPUT_DIR="/scratch/pawsey0964/lhuet/ref-gen/yahs/${sample}/09-chromsyn"
    echo "Creating directory: $OUTPUT_DIR"
    [[ "$DRY_RUN" == "false" ]] && mkdir -p "$OUTPUT_DIR"

    echo "Copying chromsyn.sh to: $OUTPUT_DIR"
    [[ "$DRY_RUN" == "false" ]] && cp "$CHROMSYN_SCRIPT" "$OUTPUT_DIR"

    echo "Navigating to: $OUTPUT_DIR"
    [[ "$DRY_RUN" == "false" ]] && cd "$OUTPUT_DIR" || exit

    echo "Submitting job: sbatch ./chromsyn.sh $sample $date $version"
    [[ "$DRY_RUN" == "false" ]] && sbatch ./chromsyn.sh "$sample" "$date" "$version"

    echo "Waiting 2 minutes before next submission..."
    sleep 120  # 5-minute delay

    echo "Returning to the original directory"
    [[ "$DRY_RUN" == "false" ]] && cd - > /dev/null

    echo "-----------------------------------------"

done
