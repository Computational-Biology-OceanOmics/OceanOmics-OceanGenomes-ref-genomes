output_file="BUSCO_compiled_results.tsv"
echo -e "sample\tComplete\tSingle_copy\tMulti_copy\tFragmented\tMissing\tn_markers\tdomain\tNumber_of_scaffolds\tNumber_of_contigs\tTotal_length\tPercent_gaps\tScaffold_N50\tContigs_N50" > $output_file



# Find all .tsv files in the current directory and its subdirectories
tsv_files=$(find . -name "*.hic1-busco.batch_summary.txt")


# Append the data rows from each .tsv file to the output file
for file in $tsv_files; do
  # Skip the first line (header row) and append the rest to the output file
  tail -n +2 "$file" >> "$output_file"
done
