import psycopg2
import pandas as pd
import numpy as np  # Required for handling infinity values

# PostgreSQL connection parameters
db_params = {
    'dbname': 'oceanomics',
    'user': 'postgres',
    'password': 'oceanomics',
    'host': '203.101.227.69',
    'port': 5432
}


# File containing omnic stats data

genomescope_compiled_path = f"final_omnic_stats_report.txt"  # if your file structure is different this might not work.

# Import omnic data
print(f"Importing data from {genomescope_compiled_path}")

# Load data
omnic = pd.read_csv(genomescope_compiled_path, sep="\t")

# Split the 'sample' column up so we have og_id by itself
# Ensure 'sample' column exists
if 'sample' in omnic.columns:
    # Split 'sample' into 2 new columns
    omnic['og_id'] = omnic['sample'].str.split('_').str[0]
    omnic['seq_date'] = omnic['sample'].str.split('_').str[1].str.lstrip('v')
    
    if 'stage' in omnic.columns:
        # Change to '0' pre curation and '2' post
        omnic['stage'] = omnic['stage'].replace({'04-scaffolding': '0', '05-decontamination': '2'}).astype(int)
        print("stage replaced")
    else:
        print("Error: 'stage' column could not be found in input file")

    # Save the updated DataFrame back to a tab-delimited file
    output_file = f"genomescope_compiled_results_split.tsv"
    omnic.to_csv(output_file, sep="\t", index=False)
    
    print("File successfully processed! New columns added.")
else:
    print("Error: 'sample' column not found in the input file.")


# Print summary of changes
print("\n🔍 Final dataset summary:")
print(omnic.describe())

try:
    # Connect to PostgreSQL
    conn = psycopg2.connect(**db_params)
    cursor = conn.cursor()

    row_count = 0  # Track number of processed rows

    for index, row in omnic.iterrows():
        row_dict = row.to_dict()

        # Extract primary key values
        og_id, seq_date, stage, haplotype = row["og_id"], row["seq_date"], row["stage"], row["haplotype"]

        # UPSERT: Insert if not exists, otherwise update
        upsert_query = """
        INSERT INTO ref_genomes (
            og_id, seq_date, stage, haplotype, total, total_unmapped, total_single_sided_mapped, total_mapped,
            total_dups, total_nodups, cis, trans
        )
        VALUES (
            %(og_id)s, %(seq_date)s, %(stage)s, %(haplotype)s, %(total)s, %(total_unmapped)s, %(total_single_sided_mapped)s, %(total_mapped)s,
            %(total_dups)s, %(total_nodups)s, %(cis)s, %(trans)s
        )
        ON CONFLICT (og_id, seq_date, stage, haplotype) DO UPDATE SET
            total = EXCLUDED.total,
            total_unmapped = EXCLUDED.total_unmapped,
            total_single_sided_mapped = EXCLUDED.total_single_sided_mapped,
            total_mapped = EXCLUDED.total_mapped,
            total_dups = EXCLUDED.total_dups,
            total_nodups = EXCLUDED.total_nodups,
            cis = EXCLUDED.cis,
            trans = EXCLUDED.trans;
        """
        params = {
            "og_id": row_dict["og_id"],  # TEXT / VARCHAR
            "seq_date": row_dict["seq_date"],  # TEXT or DATE
            "stage": row_dict["stage"],  # INT
            "haplotype": row_dict["haplotype"],  # INT
            "total": None if pd.isna(row_dict["total"]) else int(row_dict["total"]),  # BIGINT
            "total_unmapped": None if pd.isna(row_dict["total_unmapped"]) else int(row_dict["total_unmapped"]),  # BIGINT
            "total_single_sided_mapped": None if pd.isna(row_dict["total_single_sided_mapped"]) else int(row_dict["total_single_sided_mapped"]),  # BIGINT
            "total_mapped": None if pd.isna(row_dict["total_mapped"]) else int(row_dict["total_mapped"]),  # BIGINT        
            "total_dups": None if pd.isna(row_dict["total_dups"]) else int(row_dict["total_dups"]),  # BIGINT
            "total_nodups": None if pd.isna(row_dict["total_nodups"]) else int(row_dict["total_nodups"]),  # BIGINT
            "cis": None if pd.isna(row_dict["cis"]) else int(row_dict["cis"]),  # BIGINT
            "trans": None if pd.isna(row_dict["trans"]) else int(row_dict["trans"]),  # BIGINT
        }

        # Debugging Check
        print(f"Number of columns in query: {upsert_query.count('%s')}")
        print(f"Column names in DataFrame: {omnic.columns.tolist()}")
        print("row:", row_dict)
        print("params:", params)

        cursor.execute(upsert_query, params)
        row_count += 1  

        conn.commit()
        print(f"✅ Successfully processed {row_count} rows!")

except Exception as e:
    conn.rollback()
    print(f"❌ Error: {e}")

finally:
    cursor.close()
    conn.close()
