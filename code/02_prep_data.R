################################################################################
### Authors: Devon Rojas, Christina Mazilu, Katelyn Nutley, Aliah Zewail, Tod Van Gunten
### Date created: Jun 2, 2025
### Project: Highland Clearances
################################################################################

# Load necessary libraries
library(quanteda)
library(readr)
library(stm)
library(tidyverse)
library(tidytext)
library(dotenv)

load_dot_env(file = ".env")

# Load in Data (MAKE SURE TO SET WORKING DIRECTORY FIRST)
DATA_DIR = Sys.getenv("DATA_DIR")
RAW_DATA_DIR = Sys.getenv("RAW_DATA_DIR")
OUTPUT_DATA_DIR = Sys.getenv("OUTPUT_DATA_DIR")
FIGURES_DIR = Sys.getenv("FIGURES_DIR")

# Pull list of interview files
files = list.files(RAW_DATA_DIR, pattern = "\\d.*.csv$", full.names = TRUE)

if (length(files) == 0) stop("No CSV files found in ", RAW_DATA_DIR)

# The data in the Napier Commission is loaded as individual interviews; so you need to 
# upload the whole file.

# Load in individual files and combine into single dataframe
docs = tibble()
for (file in files) {
  df = read_csv(file)
  docs = rbind(df, docs)
}
# Drop missing Answer data
docs = docs %>% drop_na(Answer)

# Load in coded occupation data
occupation_refined = read_csv(file.path(DATA_DIR, "occupation_classified.csv"))
occupation_refined = occupation_refined %>%
  mutate(occ_cat = ifelse(grepl("bart", occ_cat), "landowner", occ_cat)) %>%
  mutate(occ_cat = factor(occ_cat, 
                          levels = c(
                            "land_worker",
                            "labourer",
                            "small_landowner",
                            "professional",
                            "clergy",
                            "landowner",
                            "other"
                          ))) %>%
  mutate(Name = tools::toTitleCase(tolower(Name))) %>%
  mutate(Name = trimws(gsub("Mr", "", Name))) %>%
  mutate(Name = gsub("\\.", "", Name)) %>%
  mutate(Name = gsub("M'", "Mc", Name)) %>%
  mutate(Name = gsub("\\s\\s", " ", Name)) %>%
  drop_na(Name) %>%
  distinct(Name, Place, .keep_all = T)

# Join interview text with occupation classifications
combined = docs %>%
  unite("text", Answer, na.rm = T) %>%
  select(text, Area, Witness, Location) %>%
  mutate(text = iconv(text, from="windows-1252", to="UTF-8")) %>%
  mutate(text = gsub("[\\-\\_]", " ", text)) %>%
  mutate(text = gsub("\\s+\\?", "?", text)) %>%
  mutate(Witness = gsub("ï¿½", "", Witness)) %>%
  mutate(Area = gsub("ï¿½", "", Area)) %>% 
  mutate(Area = gsub(",$", "", Area)) %>%
  regex_left_join(occupation_refined, 
                  by = c(Witness = "Name", Location = "Place")) %>%
  ungroup() %>%
  mutate(occ_bin = case_when(
    occ_cat == "professional" ~ "high",
    occ_cat == "clergy" ~ "high",
    occ_cat == "landowner" ~ "high",
    occ_cat == "land_worker" ~ "low",
    occ_cat == "labourer" ~ "low",
    occ_cat == "small_landowner" ~ "low",
    .default = NA
  )) %>%
  drop_na(occ_bin) %>%
  group_by(Area, Location, Witness) %>%
  mutate(line_num = row_number())

### DATA PREPROCESSING
sents = tokenize_sentences(combined$text)
sents = sapply(sents, function(x) gsub("[^a-zA-Z ]", "", x))

meta = combined %>%
  select(line_num, Area, Witness, Location, Occupation = occ_bin) %>%
  replace(is.na(.), "Unknown")

sent_counts = sapply(sents, length)
meta = meta[rep(1:nrow(meta), sent_counts), ]

sents = unlist(sents)
write_lines(sents, file = file.path(INPUT_DATA_DIR, "sents.txt"))

number_words = c(
  "zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
  "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen",
  "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety", "hundred", "thousand", "million"
)

# PreProcess for STM
processed <- textProcessor(
  documents = sents,
  meta = meta,
  lowercase = TRUE,
  removestopwords = TRUE,
  customstopwords = number_words,
  removenumbers = TRUE,
  removepunctuation = TRUE,
  stem = TRUE,
  wordLengths = c(3, Inf),
  language = "en",
  verbose = TRUE
)

out <- prepDocuments(
  documents = processed$documents,
  vocab = processed$vocab,
  meta = processed$meta,
  lower.thresh = 5
)

joined = cbind(sents, meta)
joined = joined[-c(processed$docs.removed),]
joined = joined[-c(out$docs.removed),]
write_csv(joined, file = file.path(OUTPUT_DATA_DIR, "sent_meta.csv"))

saveRDS(file.path(INPUT_DATA_DIR, "out.rds"))
