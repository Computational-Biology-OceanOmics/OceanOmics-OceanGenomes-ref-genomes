output_file="merqury.qv.stats2.tsv"
base_dir="/scratch/pawsey0964/lhuet/refgenomes/OG*" 
echo -e "sample\tk_mer_set\tsolid_k-mers\ttotal_k_mers\tcompleteness" > "$output_file"

# Find all .hifiasm.completeness.stats files
completeness_files=$(find $base_dir -name "*.hifiasm.completeness.stats")

for file in $completeness_files; do
    sample_base=$(basename "$file" .hifiasm.completeness.stats)
    
    while IFS=$'\t' read -r sample unique_k_mers k_mers_total qv error; do
        # Trim whitespace
        trimmed_sample=$(echo "$sample" | xargs)

        if [[ "$trimmed_sample" == "Both" ]]; then
            new_sample="${sample_base}.hifiasm.dual"
            echo -e "${new_sample}\t${unique_k_mers}\t${k_mers_total}\t${qv}\t${error}" >> "$output_file"
        else
            echo -e "${sample}\t${unique_k_mers}\t${k_mers_total}\t${qv}\t${error}" >> "$output_file"
        fi
    done < "$file"
done
