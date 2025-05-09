# Path to your samples file (YOUR OG NUMBERS)
OGnum="OG.txt"
 
# Generate the include filter arguments
include_filters=$(awk '{print "--include " $0 "*.bam"}' "$OGnum" | xargs)
 
# Set your S3 bucket path
s3_bucket="pawsey0812:oceanomics-repo"
 
# Run rclone with the include filters
rclone ls $s3_bucket $include_filters > to_download1.txt
 
 
#second, make a loop that inserts the path into rclone to copy them onto your scratch using the file
for line in $(awk '{print $2}' to_download.txt); do
rclone copy $s3_bucket/${line}  /scratch/pawsey0964/lhuet/download/NOVA_250312_LA/
done


bc2092
bc2089 
 rclone copy s3:oceanomics/OceanGenomes/pacbio/PACB_241018_LA/r84154_20241018_071531/2_A01/hifi_reads/m84154_241019_171510_s3.hifi_reads.bc2089.bam