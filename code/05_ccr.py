################################################################################
### Authors: Devon Rojas, Christina Mazilu, Katelyn Nutley, Aliah Zewail, Tod Van Gunten
### Date created: Jun 4, 2025
### Project: Highland Clearances
################################################################################

import pandas as pd
from tqdm import tqdm
import glob, os
from parallel_pandas import ParallelPandas

import helpers

from dotenv import load_dotenv
load_dotenv()

def main():
    # Read in scraped interview transcripts
    files = glob.glob(
        os.path.join(os.getenv("RAW_DATA_DIR"), "[0-9]*.csv")
    )
    dfs = []
    for fi in tqdm(files):
        try:
            df = pd.read_csv(fi, index_col=0)
        except Exception:
            df = pd.read_csv(fi, encoding="windows-1252", index_col=0)
        dfs.append(df)
    full_data = pd.concat(dfs, axis = 0)

    place_constructs = pd.read_csv(
        os.path.join(os.getenv("INPUT_DATA_DIR"), "place_identity_land.csv")
    )
    place_constructs = place_constructs.dropna()

    full_text = full_data.dropna(subset=["Answer"])
    tqdm.pandas(desc="Cosine sim")
    cosine_sims = full_text["Answer"].p_apply(helpers.compute_place_identity_measure)
    pd.concat([full_text, cosine_sims], axis = 1).to_csv(
        os.path.join("OUTPUT_DATA_DIR", "cosine_sim.csv"), 
        index = False
    )

if __name__ == "__main__":
    ParallelPandas.initialize(n_cpu=23, split_factor=4)
    main()