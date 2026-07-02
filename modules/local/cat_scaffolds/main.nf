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
    tuple val(meta2), path(hap1_gfastats), path(hap2_gfastats)  // dependency: ensures gfastats completed before this task runs

    output:
    tuple val(meta), path("*_combined_scaffolds.fa"), emit: cat_file
    tuple val(meta), path("*hap1.scaffolds_1.fa")     , emit: hap1_scaffold
    tuple val(meta), path("*hap2.scaffolds_2.fa")     , emit: hap2_scaffold
    tuple val(meta), path("scaffold_counts.txt")       , emit: count_report
    path  "versions.yml"                           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}" 
    """
    # Rename scaffold headers while preserving the original scaffold suffix.
    # Example: >scaffold_42 -> >HAP1_SCAFFOLD_42
    rename_scaffolds() {
        local input_file=\$1
        local output_file=\$2
        local replacement_prefix=\$3

        echo "Renaming scaffolds in \$input_file using prefix \$replacement_prefix..."
        awk -v replacement_prefix="\$replacement_prefix" '
        /^>/ {
            sub(/^>scaffold/, ">" replacement_prefix)
            print
            next
        }
        { print }
        ' "\$input_file" > "\$output_file"
    }

    validate_counts() {
        local original_count=\$1
        local renamed_count=\$2
        local file_description=\$3

        if [ "\$original_count" -eq "\$renamed_count" ]; then
            echo "SUCCESS: \$file_description - Original: \$original_count, Renamed: \$renamed_count"
            return 0
        else
            echo "ERROR: \$file_description - Count mismatch! Original: \$original_count, Renamed: \$renamed_count"
            return 1
        fi
    }

    echo "Starting CAT_SCAFFOLDS process for ${prefix}"
    echo "Using prefix-preserving scaffold renaming: scaffold_N -> HAP1_SCAFFOLD_N / HAP2_SCAFFOLD_N"

    echo "Counting original scaffolds..."
    hap1_original=\$(grep -c '^>' "${prefix}.2.tiara.hap1_scaffolds.fa")
    hap2_original=\$(grep -c '^>' "${prefix}.2.tiara.hap2_scaffolds.fa")

    echo "Original counts - Hap1: \$hap1_original, Hap2: \$hap2_original"

    # Process Hap1 scaffolds with retry logic
    echo "Processing Hap1 scaffolds..."
    hap1_success=false
    for attempt in 1 2 3; do
        echo "Hap1 attempt \$attempt"
        rm -f "${prefix}.hap1.scaffolds_1.fa"

        if rename_scaffolds "${prefix}.2.tiara.hap1_scaffolds.fa" "${prefix}.hap1.scaffolds_1.fa" "HAP1_SCAFFOLD"; then
            if [ -s "${prefix}.hap1.scaffolds_1.fa" ]; then
                hap1_renamed=\$(grep -c '^>' "${prefix}.hap1.scaffolds_1.fa")
                first_header=\$(head -1 "${prefix}.hap1.scaffolds_1.fa")
                if [[ "\$first_header" == ">HAP1_SCAFFOLD_"* ]]; then
                    if validate_counts "\$hap1_original" "\$hap1_renamed" "Hap1"; then
                        echo "Hap1 renaming successful"
                        hap1_success=true
                        break
                    else
                        echo "Hap1 count validation failed, retrying..."
                        rm -f "${prefix}.hap1.scaffolds_1.fa"
                    fi
                else
                    echo "Hap1 header format incorrect (\$first_header), retrying..."
                    rm -f "${prefix}.hap1.scaffolds_1.fa"
                fi
            else
                echo "Hap1 output file is empty, retrying..."
            fi
        else
            echo "Hap1 renaming command failed, retrying..."
        fi

        sleep 2
    done

    if [ "\$hap1_success" = false ]; then
        echo "FATAL ERROR: Failed to rename Hap1 scaffolds after 3 attempts"
        head -5 "${prefix}.2.tiara.hap1_scaffolds.fa"
        exit 1
    fi

    # Process Hap2 scaffolds with retry logic
    echo "Processing Hap2 scaffolds..."
    hap2_success=false
    for attempt in 1 2 3; do
        echo "Hap2 attempt \$attempt"
        rm -f "${prefix}.hap2.scaffolds_2.fa"

        if rename_scaffolds "${prefix}.2.tiara.hap2_scaffolds.fa" "${prefix}.hap2.scaffolds_2.fa" "HAP2_SCAFFOLD"; then
            if [ -s "${prefix}.hap2.scaffolds_2.fa" ]; then
                hap2_renamed=\$(grep -c '^>' "${prefix}.hap2.scaffolds_2.fa")
                first_header=\$(head -1 "${prefix}.hap2.scaffolds_2.fa")
                if [[ "\$first_header" == ">HAP2_SCAFFOLD_"* ]]; then
                    if validate_counts "\$hap2_original" "\$hap2_renamed" "Hap2"; then
                        echo "Hap2 renaming successful"
                        hap2_success=true
                        break
                    else
                        echo "Hap2 count validation failed, retrying..."
                        rm -f "${prefix}.hap2.scaffolds_2.fa"
                    fi
                else
                    echo "Hap2 header format incorrect (\$first_header), retrying..."
                    rm -f "${prefix}.hap2.scaffolds_2.fa"
                fi
            else
                echo "Hap2 output file is empty, retrying..."
            fi
        else
            echo "Hap2 renaming command failed, retrying..."
        fi

        sleep 2
    done

    if [ "\$hap2_success" = false ]; then
        echo "FATAL ERROR: Failed to rename Hap2 scaffolds after 3 attempts"
        head -5 "${prefix}.2.tiara.hap2_scaffolds.fa"
        exit 1
    fi

    echo "Performing final validation..."
    hap1_final=\$(grep -c '^>' "${prefix}.hap1.scaffolds_1.fa")
    hap2_final=\$(grep -c '^>' "${prefix}.hap2.scaffolds_2.fa")

    hap1_first=\$(head -1 "${prefix}.hap1.scaffolds_1.fa")
    hap2_first=\$(head -1 "${prefix}.hap2.scaffolds_2.fa")
    if [[ "\$hap1_first" != ">HAP1_SCAFFOLD_"* ]] || [[ "\$hap2_first" != ">HAP2_SCAFFOLD_"* ]]; then
        echo "FATAL ERROR: Header format validation failed!"
        echo "Hap1 first header: \$hap1_first"
        echo "Hap2 first header: \$hap2_first"
        exit 1
    fi

    if [ "\$hap1_original" -ne "\$hap1_final" ] || [ "\$hap2_original" -ne "\$hap2_final" ]; then
        echo "FATAL ERROR: Final count validation failed!"
        echo "Hap1 - Original: \$hap1_original, Final: \$hap1_final"
        echo "Hap2 - Original: \$hap2_original, Final: \$hap2_final"
        exit 1
    fi

    echo "All validations passed. Proceeding with concatenation..."

    # Concatenate hap1 and hap2 scaffolds
    cat ${prefix}.hap1.scaffolds_1.fa ${prefix}.hap2.scaffolds_2.fa > "${prefix}${asmversion}_combined_scaffolds.fa"

    # Count scaffolds in concatenated file
    cat_fa=\$(grep -c '^>' "${prefix}${asmversion}_combined_scaffolds.fa")
    expected_total=\$((hap1_final + hap2_final))

    if [ "\$cat_fa" -ne "\$expected_total" ]; then
        echo "FATAL ERROR: Concatenated file count mismatch! Expected: \$expected_total, Actual: \$cat_fa"
        exit 1
    fi

    echo "Concatenation successful. Total scaffolds: \$cat_fa"

    # Write comprehensive count report
    cat <<-END_COUNTS > scaffold_counts.txt
	Haplotype 1 - Original: \$hap1_original
	Haplotype 1 - Renamed : \$hap1_final
	Haplotype 2 - Original: \$hap2_original
	Haplotype 2 - Renamed : \$hap2_final
	Combined Total        : \$cat_fa
	Expected Total        : \$expected_total
	Naming Format         : scaffold_N -> HAP1_SCAFFOLD_N / HAP2_SCAFFOLD_N
	Status                : SUCCESS
	END_COUNTS
    
    cat <<-END_VERSIONS > versions.yml
	"${task.process}":
	    bash: \$(bash --version | head -n1 | cut -d' ' -f4)
	END_VERSIONS

    echo "CAT_SCAFFOLDS process completed successfully!"
    """
}
