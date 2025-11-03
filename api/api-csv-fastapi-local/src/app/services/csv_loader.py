import pandas as pd
from pathlib import Path

CSV_PATH = Path(__file__).resolve().parents[2] / "data" / "data.csv"

def load_csv_as_dict():
    df = pd.read_csv(CSV_PATH, dtype={"id": str})
    return {str(row["id"]): row.to_dict() for _, row in df.iterrows()}
