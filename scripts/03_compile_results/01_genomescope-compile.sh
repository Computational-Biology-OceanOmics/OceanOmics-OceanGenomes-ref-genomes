#!/bin/bash

base_dir="/scratch/pawsey0964/$USER/ref-gen"
TSV="genomescope_compiled_results.tsv"
echo sample,homozygosity,heterozygosity,genomesize,repeatsize,uniquesize,modelfit,errorrate | sed 's/,/\t/g' | tee $TSV

for GSCOPE in $base_dir/OG*/02-kmer-profiling/genomescope2/*_genomescope_summary.txt; do
    PREFIX=$(basename $GSCOPE | awk -F "-genomescope" '{print $1;}')

    # Extract the 8 max-column values (skip header line, then take last 7 data rows)
    mapfile -t vals < <(sed -E 's/ [ ]+/\t/g' $GSCOPE | awk -F '\t' '{print $3;}' | tail -n 8 | awk '{print $1;}')
    # vals[0]=max(header), [1]=homozygosity, [2]=heterozygosity, [3]=genomesize,
    # [4]=repeatsize, [5]=uniquesize, [6]=modelfit, [7]=errorrate

    homo="${vals[1]}"
    het="${vals[2]}"

    # When max homozygosity is exactly 100% the model failed to converge —
    # the 0–100% range is meaningless, store NULL rather than a false value
    if [[ "$homo" == "100%" ]]; then
        homo="NA"
        het="NA"
    fi

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$PREFIX" "$homo" "$het" \
        "${vals[3]}" "${vals[4]}" "${vals[5]}" \
        "${vals[6]}" "${vals[7]}" | tee -a $TSV
done

column -t $TSV
