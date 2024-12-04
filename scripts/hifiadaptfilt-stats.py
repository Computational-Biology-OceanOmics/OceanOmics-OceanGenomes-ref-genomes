import os
import csv

# Define the base directory where the samples are stored
base_dir = "/scratch/pawsey0812/lhuet/HIFI_ONLY"  # Change this to the correct path
output_csv = "hifiadaptorfilt_stats_summary.csv"

# Open the output CSV file for writing
with open(output_csv, mode='w', newline='') as csvfile:
    csv_writer = csv.writer(csvfile)
    # Write the header
    csv_writer.writerow(['sample', 'contam_reads'])
    
    # Loop through each sample directory
    for sample in os.listdir(base_dir):
        sample_dir = os.path.join(base_dir, sample, '01-data-processing', 'hifiadaptfilt')
        
        # Loop through the subdirectories in hifiadaptfilt
        if os.path.isdir(sample_dir):
            for root, dirs, files in os.walk(sample_dir):
                for file in files:
                    if file.endswith('.stats'):
                        stats_file = os.path.join(root, file)
                        
                        # Open the stats file and search for the line containing contaminated reads
                        with open(stats_file, 'r') as f:
                            for line in f:
                                if "Number of adapter contaminated ccs reads" in line:
                                    # Extract the number of contaminated reads
                                    contam_reads = line.split(":")[1].split()[0]
                                    
                                    # Write the sample and contamination count to the CSV
                                    csv_writer.writerow([sample, contam_reads])
                                    break

print(f"Summary CSV file generated: {output_csv}")
