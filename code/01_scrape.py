################################################################################
### Authors: Devon Rojas
### Date created: Jun 4, 2025
### Project: Highland Clearances
################################################################################

import pandas as pd
import requests
import re, os
import itertools
from tqdm import tqdm
from bs4 import BeautifulSoup

from dotenv import load_dotenv
load_dotenv()

def extract_first_header(url):
    res = requests.get(url)
    soup = BeautifulSoup(res.text, 'html.parser')

    # Find the first header (you can specify the header level, e.g., bold, etc.)
    first_header = soup.find(['b'])  # Adjust header levels as needed

    if first_header:
        return first_header.text.strip()
    else:
        return None  # Return None if no header is found

def extract_page(url):
    res = requests.get(url)
    soup = BeautifulSoup(res.text, 'html.parser')

    t = soup.find(class_ = "post-body entry-content")
    t = t.text.strip()
    lines = [line.strip() 
            for line in t.split("\n\n") 
            if line.strip()]
    lines = [l.strip() 
            for line in lines 
            for l in re.split(r"(?<![^\n])(\d+)(?:\.)?(?=\s+)", line, flags=re.M) 
            if l.strip()]
    lines = [("".join([c for c in line_num if c.isdigit()]), line) 
            for line_num, line in itertools.pairwise(lines) 
            if line_num[0].isdigit()]
    
    records = []
    for line_num, line in lines:
        parts = line.split("\n—")
        # Remove line numbers
        parts = [re.sub("(\\d+\\.)", "", p) for p in parts]
        interviewer, utterance, question, answer = None, None, None, None
        # If 3 parts, assume interviewer identification, question, and witness answer
        if len(parts) == 3:
            interviewer, question, answer = parts
            interviewer = interviewer.strip()
            question = question.strip()
            answer = answer.strip()
        # If 2 parts, assume question and answer
        elif len(parts) == 2:
            utterance, answer = parts
            utterance = utterance.strip()
            answer = answer.strip()
        elif len(parts) == 1:
            utterance = parts[0].strip()
        else: # TODO: Find better way to deal with inconsistent formatting
            utterance = "\n".join(parts)
            # raise ValueError("Encountered line with more than 3 parts")
        if utterance and utterance.endswith("?"):
            question = utterance
            utterance = None
        records.append([line_num, interviewer, utterance, question, answer])
    df = pd.DataFrame.from_records(records, columns=["LineNo", "Interviewer", "Statement", "Question", "Answer"])

    return df

def make_record(row):
    page = extract_page(row["Url"])
    for col in index.columns[:-1]:
        page[col] = row[col]
    return page

def main():
    index = pd.read_csv(os.path.join(os.getenv("RAW_DATA_DIR", "napier_index.csv")), 
                        encoding='windows-1252')
    index = index.dropna()

    tqdm.pandas(desc="Parse")
    dfs = index.progress_apply(make_record, axis = 1)

    # Save to individual files
    for df in dfs:
        vol = df.iloc[0]['Vol']
        page = df.iloc[0]['Page']
        area = df.iloc[0]['Area'].replace(", ", "_")
        location = df.iloc[0]['Location']
        witness = df.iloc[0]["Witness"]

        df.to_csv(f"{vol:02d}_{page:04d}_{area}_{location}_{witness}.csv", index=False)



