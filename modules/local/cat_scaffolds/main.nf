process CAT_SCAFFOLDS {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/fastqc:0.12.1--hdfd78af_0' :
        'biocontainers/fastqc:0.12.1--hdfd78af_0' }"

    input:
    tuple val(meta), path(scaffolds)
    val asmversion

    output:
    tuple val(meta), path("*_combined_scaffolds.fa"), emit: cat_file
    tuple val(meta), path("*hap1.scaffolds_1.fa")     , emit: hap1_scaffold
    tuple val(meta), path("*hap2.scaffolds_2.fa")     , emit: hap2_scaffold
    path  "scaffold_counts.txt"                       , emit: count_report
    path  "versions.yml"                           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}" 
    """
    # Function to rename scaffolds using sequential numbering (HAP1_SCAFFOLD_1, HAP2_SCAFFOLD_1, ...)
    # This format is compatible with agp-tpf-utils for single haplotype assemblies
    rename_scaffolds_sequential() {
        local input_file=\$1
        local output_file=\$2
        local start_num=\$3
        local hap_prefix=\$4

        echo "Renaming scaffolds in \$input_file starting from \${hap_prefix}SCAFFOLD_\${start_num}..."

        # awk counts headers itself and writes the count to <output>.count
        # This avoids a separate grep on the input file, preventing Lustre
        # read-consistency race conditions on HPC systems.
        awk -v start="\$start_num" -v hap_prefix="\$hap_prefix" -v count_file="\${output_file}.count" '
        BEGIN { counter = start }
        /^>/ {
            print ">" hap_prefix "SCAFFOLD_" counter
            counter++
            next
        }
        { print }
        END { print (counter - start) > count_file }
        ' "\$input_file" > "\$output_file"

        return \$?
    }

    echo "Starting CAT_SCAFFOLDS process for ${prefix}"
    echo "Using sequential HAP1_SCAFFOLD_N / HAP2_SCAFFOLD_N naming format for agp-tpf-utils compatibility"

    # Process Hap1 scaffolds with retry logic (start numbering from 1)
    # After awk runs we re-count the INPUT file to cross-check awk's count.
    # If they differ it means awk saw a partially-visible Lustre file; retry
    # with a longer sleep to let Lustre propagate the full file to this node.
    echo "Processing Hap1 scaffolds..."
    hap1_success=false
    for attempt in 1 2 3 4 5; do
        echo "Hap1 attempt \$attempt..."
        rm -f "${prefix}.hap1.scaffolds_1.fa" "${prefix}.hap1.scaffolds_1.fa.count"

        if rename_scaffolds_sequential "${prefix}.2.tiara.hap1_scaffolds.fa" "${prefix}.hap1.scaffolds_1.fa" 1 "HAP1_"; then
            if [ -s "${prefix}.hap1.scaffolds_1.fa" ] && [ -s "${prefix}.hap1.scaffolds_1.fa.count" ]; then
                hap1_renamed=\$(cat "${prefix}.hap1.scaffolds_1.fa.count")
                # Re-count input AFTER awk has read it (forces Lustre cache refresh)
                hap1_input=\$(grep -c '^>' "${prefix}.2.tiara.hap1_scaffolds.fa" || echo 0)
                first_header=\$(head -1 ${prefix}.hap1.scaffolds_1.fa)
                if [[ "\$first_header" == ">HAP1_SCAFFOLD_"* ]] && [ "\$hap1_renamed" -gt 0 ] && [ "\$hap1_renamed" -eq "\$hap1_input" ]; then
                    echo "SUCCESS: Hap1 - Renamed: \$hap1_renamed scaffolds (input: \$hap1_input)"
                    hap1_success=true
                    break
                else
                    echo "Hap1 validation failed on attempt \$attempt (awk: \$hap1_renamed, input: \$hap1_input, header: \$first_header) -- Lustre lag suspected, retrying..."
                fi
            else
                echo "Hap1 output file or count file is empty on attempt \$attempt, retrying..."
            fi
        else
            echo "Hap1 renaming command failed on attempt \$attempt, retrying..."
        fi

        sleep 30
    done

    if [ "\$hap1_success" = false ]; then
        echo "FATAL ERROR: Failed to rename Hap1 scaffolds after 5 attempts"
        echo "Input file size: \$(stat -c%s ${prefix}.2.tiara.hap1_scaffolds.fa 2>/dev/null || echo unknown)"
        head -5 "${prefix}.2.tiara.hap1_scaffolds.fa"
        exit 1
    fi

    echo "Hap1 renaming successful!"

    # Process Hap2 scaffolds with retry logic (start numbering from 1, independent of Hap1)
    echo "Processing Hap2 scaffolds..."
    hap2_success=false
    for attempt in 1 2 3 4 5; do
        echo "Hap2 attempt \$attempt..."
        rm -f "${prefix}.hap2.scaffolds_2.fa" "${prefix}.hap2.scaffolds_2.fa.count"

        if rename_scaffolds_sequential "${prefix}.2.tiara.hap2_scaffolds.fa" "${prefix}.hap2.scaffolds_2.fa" 1 "HAP2_"; then
            if [ -s "${prefix}.hap2.scaffolds_2.fa" ] && [ -s "${prefix}.hap2.scaffolds_2.fa.count" ]; then
                hap2_renamed=\$(cat "${prefix}.hap2.scaffolds_2.fa.count")
                # Re-count input AFTER awk has read it (forces Lustre cache refresh)
                hap2_input=\$(grep -c '^>' "${prefix}.2.tiara.hap2_scaffolds.fa" || echo 0)
                first_header=\$(head -1 ${prefix}.hap2.scaffolds_2.fa)
                if [[ "\$first_header" == ">HAP2_SCAFFOLD_"* ]] && [ "\$hap2_renamed" -gt 0 ] && [ "\$hap2_renamed" -eq "\$hap2_input" ]; then
                    echo "SUCCESS: Hap2 - Renamed: \$hap2_renamed scaffolds (input: \$hap2_input)"
                    hap2_success=true
                    break
                else
                    echo "Hap2 validation failed on attempt \$attempt (awk: \$hap2_renamed, input: \$hap2_input, header: \$first_header) -- Lustre lag suspected, retrying..."
                fi
            else
                echo "Hap2 output file or count file is empty on attempt \$attempt, retrying..."
            fi
        else
            echo "Hap2 renaming command failed on attempt \$attempt, retrying..."
        fi

        sleep 30
    done

    if [ "\$hap2_success" = false ]; then
        echo "FATAL ERROR: Failed to rename Hap2 scaffolds after 5 attempts"
        echo "Input file size: \$(stat -c%s ${prefix}.2.tiara.hap2_scaffolds.fa 2>/dev/null || echo unknown)"
        head -5 "${prefix}.2.tiara.hap2_scaffolds.fa"
        exit 1
    fi

    hap2_renamed=\$(cat "${prefix}.hap2.scaffolds_2.fa.count")
    echo "Hap2 renaming successful!"

    # Final validation: re-count output files (no input file reads needed)
    echo "Performing final validation..."
    hap1_final=\$(grep -c '^>' ${prefix}.hap1.scaffolds_1.fa || echo 0)
    hap2_final=\$(grep -c '^>' ${prefix}.hap2.scaffolds_2.fa || echo 0)

    if [ "\$hap1_renamed" -ne "\$hap1_final" ] || [ "\$hap2_renamed" -ne "\$hap2_final" ]; then
        echo "FATAL ERROR: Final count validation failed!"
        echo "Hap1 - awk count: \$hap1_renamed, grep count: \$hap1_final"
        echo "Hap2 - awk count: \$hap2_renamed, grep count: \$hap2_final"
        exit 1
    fi

    echo "All validations passed. Proceeding with concatenation..."

    # Concatenate hap1 and hap2 scaffolds
    cat ${prefix}.hap1.scaffolds_1.fa ${prefix}.hap2.scaffolds_2.fa > "${prefix}${asmversion}_combined_scaffolds.fa"

    # Count scaffolds in concatenated file
    cat_fa=\$(grep -c '^>' ${prefix}${asmversion}_combined_scaffolds.fa || echo 0)
    expected_total=\$((hap1_final + hap2_final))

    if [ "\$cat_fa" -ne "\$expected_total" ]; then
        echo "FATAL ERROR: Concatenated file count mismatch! Expected: \$expected_total, Actual: \$cat_fa"
        exit 1
    fi

    echo "Concatenation successful. Total scaffolds: \$cat_fa"
    
    # Display sample headers to verify naming
    echo "Sample scaffold headers from combined file:"
    grep '^>' ${prefix}${asmversion}_combined_scaffolds.fa | head -5 || true
    echo "..."
    grep '^>' ${prefix}${asmversion}_combined_scaffolds.fa | tail -5 || true

    # Write comprehensive count report
    cat <<-END_COUNTS > scaffold_counts.txt
	Haplotype 1 - Renamed : \$hap1_final
	Haplotype 2 - Renamed : \$hap2_final
	Combined Total        : \$cat_fa
	Expected Total        : \$expected_total
	Naming Format         : HAP1_SCAFFOLD_N / HAP2_SCAFFOLD_N (agp-tpf-utils compatible)
	Status                : SUCCESS
	END_COUNTS
    
    cat <<-END_VERSIONS > versions.yml
	"${task.process}":
	    bash: \$(bash --version | head -n1 | cut -d' ' -f4)
	END_VERSIONS

    echo "CAT_SCAFFOLDS process completed successfully!"
    """
}