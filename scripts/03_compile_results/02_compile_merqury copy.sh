#!/bin/bash


### COMPILE completeness stats 

output_file="merqury.completeness.stats.tsv"
echo -e "sample\tk_mer_set\tsolid_k-mers\ttotal_k_mers\tcompleteness" > $output_file
#find all .merqury.completeness.stats files 
completeness_files=$(find . -name "*completeness.stats")

        
for i in $completeness_files; do
    cat "$i" >> "$output_file"
  done
 



### COMPILE QV STATS 

output_file="merqury.qv.stats.tsv"
echo -e "sample\tunique_k_mers_assembly\tk_mers_total\tqv\terror" > $output_file
#find all .merqury.completeness.stats files 
        completeness_files=$(find . -name "*.hifiasm.qv")
        

for i in $completeness_files; do
     cat "$i" >> "$output_file"
done
