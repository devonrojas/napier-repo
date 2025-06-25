################################################################################
### Authors: Devon Rojas, Christina Mazilu, Katelyn Nutley, Aliah Zewail, Tod Van Gunten
### Date created: Jun 4, 2025
### Project: Highland Clearances
################################################################################

import pandas as pd
import os
from transformers import BertModel, BertTokenizer
import torch
from dotenv import load_dotenv
load_dotenv()

place_constructs = pd.read_csv(os.path.join("INPUT_DATA_DIR", "place_identity_land.csv"))
place_constructs = place_constructs.dropna()

# Full size model - longer processing times
# tokenizer = BertTokenizer.from_pretrained("dbmdz/bert-base-historic-multilingual-cased")
# model = BertModel.from_pretrained("dbmdz/bert-base-historic-multilingual-cased")

# Scaled down model – shorter processing times
tokenizer = BertTokenizer.from_pretrained("dbmdz/bert-small-historic-multilingual-cased")
model = BertModel.from_pretrained("dbmdz/bert-small-historic-multilingual-cased")

def get_embedding(input_text):
    # Step 2: Tokenize
    encoded_text = tokenizer(input_text, return_tensors="pt", truncation=True, padding = True)

    # Step 3: Model forward pass
    with torch.no_grad():
        output = model(**encoded_text)  # NOT model([encoded_text])

    attention_mask = encoded_text['attention_mask']
    last_hidden = output.last_hidden_state

    input_mask_expanded = attention_mask.unsqueeze(-1).expand(last_hidden.size()).float()
    sum_embeddings = torch.sum(last_hidden * input_mask_expanded, 1)
    sum_mask = torch.clamp(input_mask_expanded.sum(1), min=1e-9)

    mean_embedding = sum_embeddings / sum_mask  # shape: [1, hidden_size]
    return mean_embedding

def compute_sim(text1, text2):
    e1, e2 = get_embedding(text1), get_embedding(text2)
    return torch.cosine_similarity(e1, e2).squeeze(0).numpy().item()

def compute_place_identity_measure(text):
    sims = place_constructs['question_text'].apply(lambda x: compute_sim(x, text))
    df = pd.concat([pd.Series(sims), place_constructs['type']], axis = 1)
    df.columns = ["sim", "type"]
    return df.groupby("type")["sim"].mean()