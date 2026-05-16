import pytest, pandas as pd, numpy as np, os

PROCESSED_FILE_PATH = "data/processed/cleaned_code/cleaned_code_20260505_084402.parquet"
FEATURE_FILE_PATH = "data/feature/embedded_features_20260505_085524.parquet"

def test_tc_data_01_processed_parquet_schema():
    assert os.path.exists(PROCESSED_FILE_PATH)
    df = pd.read_parquet(PROCESSED_FILE_PATH)
    required_fields = ["id", "language", "repo_name", "file_name", "code_snippet", "snippet_hash"]
    for field in required_fields: assert field in df.columns
    assert df["code_snippet"].isna().sum() == 0

def test_tc_data_02_feature_layer_embeddings():
    assert os.path.exists(FEATURE_FILE_PATH)
    df = pd.read_parquet(FEATURE_FILE_PATH)
    assert "embedding" in df.columns
    assert len(df["embedding"].iloc[0]) > 0

def test_tc_data_03_feature_embeddings_length():
    df = pd.read_parquet(FEATURE_FILE_PATH)
    vector_lengths = df["embedding"].apply(lambda x: len(x) if isinstance(x, (list, np.ndarray)) else 0)
    assert (vector_lengths == 0).sum() == 0
    assert len(vector_lengths.unique()) == 1