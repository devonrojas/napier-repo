################################################################################
### Authors: Devon Rojas, Christina Mazilu, Katelyn Nutley, Aliah Zewail, Tod Van Gunten
### Date created: Jun 4, 2025
### Project: Highland Clearances
################################################################################

import pandas as pd
import glob, os, re, json
from tqdm import tqdm
from vaderSentiment.vaderSentiment import SentimentIntensityAnalyzer

from dotenv import load_dotenv
load_dotenv()

def main():
    df = pd.read_csv(os.path.join(os.getenv("INPUT_DATA_DIR", "sent_meta.csv")))
    df.columns = ["text", "line_num", "Area", "Witness", "Location"]
    df.loc[df['text'].isna(),'text'] = ""
    df.head()

    analyzer = SentimentIntensityAnalyzer()
    tqdm.pandas(desc="sentiment")
    df['sentiment'] = df['text'].progress_apply(lambda x: analyzer.polarity_scores(x)["compound"])

    df.to_csv(os.path.join(os.getenv("INPUT_DATA_DIR", "sent_sentiments.csv")), index = False)