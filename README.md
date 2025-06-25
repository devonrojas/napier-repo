# Napier Commission Report data

This repository contains code to download, and the downloaded data, of the Napier Commission Report as digitalised by the University of the Highlands and Islands.  For more information please see here: https://www.uhi.ac.uk/en/research-enterprise/cultural/centre-for-history/research/resources/the-napier-commission/

## Reproduction Pipeline
**Setup:** Ensure you set the following environment variables before running the pipeline. To simplify this, you can create a file named .env to store the key=value pairs. Below are the required environment variables and suggested values:
```bash
DATA_DIR="data"
RAW_DATA_DIR="data/raw"
OUTPUT_DATA_DIR="data/output"
INPUT_DATA_DIR="data/input"
FIGURES_DIR="figures_tables"
```
Once set, run `00_setup.py` to set up these directories.

**Step 1:** The file `01_scrape.py` will download the Napier corpus and save the individual interview transcripts into the `data/raw` folder as files in the pattern: `[Volume]_[PageNo]_[Area]_[Location]_[Witness].csv`. It requires the file `napier_index.csv` also located in the subdirectory `data/raw`.

**Step 2:** The file `02_prep_data.R` will prepare the data for steps 3 and 4. It requires the file `data/input/occupation_classified.csv`. The script outputs the following files: `data/input/sents.txt`: a list of the sentences in the transcripts, `data/input/sent_meta.csv`: sentence-level metadata of the transcripts, and `data/input/out.rds`: an object of prepped documents to be passed into a structural topic model (see Step 4).

**Step 3:** The file `03_sentiment.py` extracts a compound polarity score for each sentence. It requires `data/input/sent_meta.csv`. The results are saved in `data/input/sent_sentiments.csv`.

**Step 4:** The file `04_stm.R` will run a Structural Topic Model on the scraped transcripts. It requires the files: `data/input/sents.txt`, `data/input/out.rds`, and `data/input/sent_sentiments.csv`. It produces a model with an automatically determined topic number, in our case, 37 topics are identified. The model is saved as an RDS file in `models/sent_stm_model_v2.stm`. Additionally, the script produces `data/output/all_topics.txt`, a concatenated document of the keywords and representative documents associated with each topic from the model, and `data/output/MAIN_DATA.rds`, the complete dataset used for our analyses. The script also generates a plot of top keywords by topic. The topic labels of this plot can be set in `data/input/Topics.csv`.

**Step 5:** The file `05_ccr.py` performs the contextualized construct representation method ([Atari et al. n.d.](https://osf.io/bu6wg/)) on a previously validated psychometric scale of place-based identity. Averaged cosine similarity scores for each sentence are saved in `data/output/cosine_sim.csv`.

**Step 6:** The file `06_figures.R` reads in `data/output/cosine_sim.csv` and `data/output/MAIN_DATA.rds` along with supporting geographic shapefiles and metadata to produce the final plots.

## Required packages
The pipeline was developed using Python version 3.12.7 and R version 4.4.0

### Python
`python-dotenv`  
`pandas`  
`tqdm`  
`beautifulsoup4`  
`vaderSentiment`  
`parallel-pandas`  
`transformers`  
`torch`  

### R
`quanteda`  
`readr`  
`stm`  
`tidytext`  
`dotenv`  
`tidyverse`  
`ggplot2`  
`sf`  
`readxl`  
`stringdist`