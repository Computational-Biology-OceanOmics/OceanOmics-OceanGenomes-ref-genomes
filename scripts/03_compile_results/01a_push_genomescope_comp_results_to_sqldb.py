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

# run this with singularity run $SING/psycopg2:0.1.sif python 
# File containing genomescope stats data

genomescope_compiled_path = f"genomescope_compiled_results.tsv"  # if your file structure is different this might not work.

# Import genomescope data
print(f"Importing data from {genomescope_compiled_path}")

# Load data
genomescope = pd.read_csv(genomescope_compiled_path, sep="\t")

# Split the 'sample' column up so we have og_id by itself
# Ensure 'sample' column exists
if 'sample' in genomescope.columns:
    # extract og_id from 'sample'
    genomescope['og_id'] = genomescope['sample'].str.split('_').str[0]   
    print("File successfully processed! New columns added.")
else:
    print("Error: 'sample' column not found in the input file.")


# Print summary of changes
print("\n🔍 Final dataset summary:")
print(genomescope.describe())

try:
    # Connect to PostgreSQL
    conn = psycopg2.connect(**db_params)
    cursor = conn.cursor()

    row_count = 0  # Track number of processed rows

    for index, row in genomescope.iterrows():
        row_dict = row.to_dict()

        # Extract primary key values
        og_id = row["og_id"]

        # UPSERT: Insert if not exists, otherwise update
        upsert_query = """
        INSERT INTO raw_qc (
            og_id, homozygosity, heterozygosity, genomesize,
            repeatsize, uniquesize, modelfit, errorrate
        )
        VALUES (
            %(og_id)s, %(homozygosity)s, %(heterozygosity)s, %(genomesize)s,
            %(repeatsize)s, %(uniquesize)s, %(modelfit)s, %(errorrate)s
        )
        ON CONFLICT (og_id) DO UPDATE SET
            homozygosity = EXCLUDED.homozygosity,
            heterozygosity = EXCLUDED.heterozygosity,
            genomesize = EXCLUDED.genomesize,
            repeatsize = EXCLUDED.repeatsize,
            uniquesize = EXCLUDED.uniquesize,
            modelfit = EXCLUDED.modelfit,
            errorrate = EXCLUDED.errorrate;
        """
        params = {
            "og_id": row_dict["og_id"],  # TEXT / VARCHAR
            "homozygosity": float(str(row["homozygosity"]).replace("%", "") if row["homozygosity"] and "%" in str(row["homozygosity"]) else float(row["homozygosity"])), # FLOAT
            "heterozygosity": float(str(row["heterozygosity"]).replace("%", "") if row["heterozygosity"] and "%" in str(row["heterozygosity"]) else float(row["heterozygosity"])), # FLOAT
            "genomesize": int(str(row["genomesize"]).replace(",", "") if row["genomesize"] and "," in str(row["genomesize"]) else int(row["genomesize"])),  # BIGINT        
            "repeatsize": int(str(row["repeatsize"]).replace(",", "") if row["repeatsize"] and "," in str(row["repeatsize"]) else int(row["repeatsize"])),  # BIGINT
            "uniquesize": int(str(row["uniquesize"]).replace(",", "") if row["uniquesize"] and "," in str(row["uniquesize"]) else int(row["uniquesize"])),  # BIGINT
            "modelfit": float(str(row["modelfit"]).replace("%", "") if row["modelfit"] and "%" in str(row["modelfit"]) else float(row["modelfit"])),  # FLOAT
            "errorrate": float(str(row["errorrate"]).replace("%", "") if row["errorrate"] and "%" in str(row["errorrate"]) else float(row["errorrate"])), # FLOAT
        } 

        # Debugging Check
        print(f"Number of columns in query: {upsert_query.count('%s')}")
        print(f"Column names in DataFrame: {genomescope.columns.tolist()}")
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
