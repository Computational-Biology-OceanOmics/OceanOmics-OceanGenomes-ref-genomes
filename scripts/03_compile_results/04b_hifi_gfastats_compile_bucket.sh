#!/bin/bash
# Download and compile hifi gfastats from the refassemblies bucket.
# Outputs hifi_gfastats_report_bucket.txt
# Usage: bash 04b_hifi_gfastats_compile_bucket.sh
# Requires: /tmp/all_hifi_gfastats.txt (format: OG|version_dir|filename)

MANIFEST="/tmp/all_hifi_gfastats.txt"
OUTFILE="hifi_gfastats_report_bucket.txt"
TMPDIR=$(mktemp -d /tmp/hifi_gfa_XXXXXX)

echo -e "filename\tnum_contigs\tcontig_n50\tcontig_n50_size_mb\tnum_scaffolds\tscaffold_n50\tscaffold_n50_size_mb\tlargest_scaffold\tlargest_scaffold_size_mb\ttotal_scaffold_length\ttotal_scaffold_length_size_mb\tgc_content_percent" > "$OUTFILE"

total=$(grep -cvE "\.bp\.p_ctg\.|versions\.yml" "$MANIFEST")
count=0

while IFS='|' read -r og ver fname; do
    # Skip bp.p_ctg (unbinned primary) and versions.yml
    if echo "$fname" | grep -qE "\.bp\.p_ctg\.|versions\.yml"; then
        continue
    fi

    count=$((count + 1))
    echo "[$count/$total] Downloading $fname"

    local_file="$TMPDIR/$fname"
    rclone copy "pawsey0964:oceanomics-refassemblies/$og/$ver/gfastats/$fname" "$TMPDIR/" --quiet

    if [[ ! -f "$local_file" ]]; then
        echo "  WARNING: failed to download $fname — skipping"
        continue
    fi

    awk -v filename="$fname" 'BEGIN { OFS="\t" }
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
            contig_N50_Mb = contig_N50 / 1000000
            scaffold_N50_Mb = scaffold_N50 / 1000000
            scaffold_length_Mb = scaffold_length / 1000000
            largest_scaffold_Mb = largest_scaffold / 1000000
            print filename, contigs, contig_N50, contig_N50_Mb, scaffolds, scaffold_N50, scaffold_N50_Mb, largest_scaffold, largest_scaffold_Mb, scaffold_length, scaffold_length_Mb, gc_content
        }' "$local_file" >> "$OUTFILE"

    rm -f "$local_file"
done < "$MANIFEST"

rm -rf "$TMPDIR"
echo ""
echo "Written: $OUTFILE  ($count files processed)"
wc -l "$OUTFILE"
