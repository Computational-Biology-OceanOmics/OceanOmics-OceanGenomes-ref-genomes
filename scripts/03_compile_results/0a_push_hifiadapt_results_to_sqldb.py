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


# File containing hifiadapt stats data

hifiadapt_compiled_path = f"hifiadaptorfilt_stats_summary.tsv"  # if your file structure is different this might not work.

# Import hifiadapt data
print(f"Importing data from {hifiadapt_compiled_path}")

# Load data
hifiadapt = pd.read_csv(hifiadapt_compiled_path, sep="\t")
hifiadapt.rename(columns={"sample": "og_id"}, inplace=True)

# Print summary
print("\n🔍 Dataset summary:")
print(hifiadapt.describe())
print(hifiadapt.columns)

try:
    # Connect to PostgreSQL
    conn = psycopg2.connect(**db_params)
    cursor = conn.cursor()

    row_count = 0  # Track number of processed rows

    for index, row in hifiadapt.iterrows():
        row_dict = row.to_dict()

        # Extract primary key values
        og_id = row["og_id"]

        # UPSERT: Insert if not exists, otherwise update
        upsert_query = """
        INSERT INTO raw_qc (
            og_id, contam_reads
        )
        VALUES (
            %(og_id)s, %(contam_reads)s
        )
        ON CONFLICT (og_id) DO UPDATE SET
            contam_reads = EXCLUDED.contam_reads;
        """
        params = {
            "og_id": row_dict["og_id"],  # TEXT / VARCHAR
            "contam_reads": row_dict["contam_reads"],  # TEXT or DATE
        }

        # Debugging Check
        print(f"Number of columns in query: {upsert_query.count('%s')}")
        print(f"Column names in DataFrame: {hifiadapt.columns.tolist()}")
        print("row:", row_dict)
        print("params:", params)

        cursor.execute(upsert_query, params)
        row_count += 1  

        conn.commit()
        print(f"✅ Successfully processed {row_count} rows!")

except Exception as e:
    conn.rollback()
    print(f"❌ completeness: {e}")

finally:
    cursor.close()
    conn.close()
