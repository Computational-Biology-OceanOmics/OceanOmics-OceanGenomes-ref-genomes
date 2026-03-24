process RENAME_SCAFFOLDS {
    tag "${meta.id}"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/fastqc:0.12.1--hdfd78af_0' :
        'biocontainers/fastqc:0.12.1--hdfd78af_0' }"

    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path("*.renamed.fa")        , emit: renamed_fasta
    tuple val(meta), path("scaffold_counts.txt") , emit: count_report
    path "versions.yml"                          , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def output = "${prefix}.renamed.fa"
    """
    # Function to rename scaffolds using sequential numbering (HAP1_SCAFFOLD_1, HAP1_SCAFFOLD_2, ...)
    rename_scaffolds_sequential() {
        local input_file=\$1
        local output_file=\$2

        echo "Renaming scaffolds in \$input_file..."

        awk '
        BEGIN { counter = 1 }
        /^>/ {
            print ">HAP1_SCAFFOLD_" counter
            counter++
            next
        }
        { print }
        ' "\$input_file" > "\$output_file"

        return \$?
    }

    # Function to validate scaffold counts
    validate_counts() {
        local original_count=\$1
        local renamed_count=\$2

        if [ "\$original_count" -eq "\$renamed_count" ]; then
            echo "SUCCESS: Original: \$original_count, Renamed: \$renamed_count"
            return 0
        else
            echo "ERROR: Count mismatch! Original: \$original_count, Renamed: \$renamed_count"
            return 1
        fi
    }

    echo "Starting RENAME_SCAFFOLDS process for ${prefix}"
    echo "Using sequential HAP1_SCAFFOLD_N naming format for agp-tpf-utils compatibility"

    original=\$(grep -c '^>' ${fasta} || echo 0)
    echo "Original scaffold count: \$original"

    success=false
    for attempt in 1 2 3; do
        echo "Attempt \$attempt..."
        rm -f "${output}"

        if rename_scaffolds_sequential "${fasta}" "${output}"; then
            if [ -s "${output}" ]; then
                renamed=\$(grep -c '^>' ${output} || echo 0)
                first_header=\$(head -1 ${output})
                if [[ "\$first_header" == ">HAP1_SCAFFOLD_"* ]]; then
                    if validate_counts \$original \$renamed; then
                        echo "Renaming successful on attempt \$attempt"
                        success=true
                        break
                    else
                        echo "Count validation failed on attempt \$attempt, retrying..."
                    fi
                else
                    echo "Header format incorrect (\$first_header) on attempt \$attempt, retrying..."
                fi
            else
                echo "Output file is empty on attempt \$attempt, retrying..."
            fi
        else
            echo "Rename command failed on attempt \$attempt, retrying..."
        fi

        [ "\$attempt" -lt 3 ] && sleep 2
    done

    if [ "\$success" = false ]; then
        echo "FATAL ERROR: Failed to rename scaffolds after 3 attempts"
        echo "Input file contents (first 5 lines):"
        head -5 "${fasta}"
        exit 1
    fi

    final=\$(grep -c '^>' ${output} || echo 0)
    echo "Sample scaffold headers:"
    grep '^>' ${output} | head -5
    [ "\$final" -gt 5 ] && echo "..." && grep '^>' ${output} | tail -3

    cat <<-END_COUNTS > scaffold_counts.txt
	Original scaffold count : \$original
	Renamed scaffold count  : \$final
	Naming format           : HAP1_SCAFFOLD_N (agp-tpf-utils compatible)
	Status                  : SUCCESS
	END_COUNTS

    cat <<-END_VERSIONS > versions.yml
	"${task.process}":
	    bash: \$(bash --version | head -n1 | cut -d' ' -f4)
	END_VERSIONS

    echo "RENAME_SCAFFOLDS process completed successfully!"
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.renamed.fa
    touch scaffold_counts.txt

    cat <<-END_VERSIONS > versions.yml
	"${task.process}":
	    bash: \$(bash --version | head -n1 | cut -d' ' -f4)
	END_VERSIONS
    """
}
