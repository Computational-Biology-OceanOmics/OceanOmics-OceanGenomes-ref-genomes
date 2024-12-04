# Print column names

echo -e "Filename\t# contigs\tContig N50\tContig N50 (Mb)\t# scaffolds\tScaffold N50\tScaffold N50 (Mb)\tLargest scaffold\tLargest scaffold (Mb)\tTotal scaffold length\tTotal scaffold length (Mb)\tGC content %" > assembly_gfastats_report.txt

tsv_files=$(find . -name "*hap*.assembly_summary")


# Process each file

for file in $tsv_files; do

    awk -v filename="$(basename "$file")" 'BEGIN { OFS="\t" }

        {

            if ($1 == "#" && $2 == "scaffolds") { scaffolds = $3 }

            else if ($1 == "Total" && $2 == "scaffold" && $3 == "length") { scaffold_length = $4 }

            else if ($1 == "Scaffold" && $2 == "N50") { scaffold_N50 = $3 }

            else if ($1 == "Largest" && $2 == "scaffold") { largest_scaffold = $3 }

            else if ($1 == "#" && $2 == "contigs") { contigs = $3 }

            else if ($1 == "Contig" && $2 == "N50") { contig_N50 = $3 }

            else if ($1 == "GC" && $2 == "content") { gc_content = $4 }

        }

        END {

            contig_N50_Mb = contig_N50 / 1000000; # Convert contig N50 to megabases

            scaffold_N50_Mb = scaffold_N50 / 1000000; # Convert scaffold N50 to megabases

            scaffold_length_Mb = scaffold_length / 1000000; # Convert scaffold length to megabases

            largest_scaffold_Mb = largest_scaffold / 1000000; # Convert largest scaffold to megabases

            print filename, contigs, contig_N50, contig_N50_Mb, scaffolds, scaffold_N50, scaffold_N50_Mb, largest_scaffold, largest_scaffold_Mb, scaffold_length, scaffold_length_Mb, gc_content

        }' "$file" >> gfastats_report.txt

done