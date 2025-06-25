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
INPUT_DATA_DIR = Sys.getenv("INPUT_DATA_DIR")
OUTPUT_DATA_DIR = Sys.getenv("OUTPUT_DATA_DIR")
FIGURES_DIR = Sys.getenv("FIGURES_DIR")

## Load in sentences, sentiments and stm input
sents = read_lines(file.path(INPUT_DATA_DIR, "sents.txt"))
sent_sentiments = read_csv(file.path(INPUT_DATA_DIR, "sent_sentiments.csv"))
out = readRDS(file.path(INPUT_DATA_DIR, "out.rds"))

# # Trying to Determine the Optimal or Right K 
# set.seed(1234)
# k_search <- searchK(documents = out$documents, 
#                     vocab = out$vocab, 
#                     K = c(5, 10, 15, 20, 25),
#                     cores = detectCores() - 1,
#                     verbose = TRUE)
# plot(k_search) # Perform elbow test and select best K

# Fit STM Model 
K <- 0 ## Automatically determine topic number
stm_model <- stm(
  documents = out$documents,
  vocab = out$vocab,
  prevalence =~ Area + s(line_num), # Model variation by region and location in interview
  K = K,
  max.em.its = 75,
  seed = 1234,
  data = out$meta,
  init.type = "Spectral",
  verbose = TRUE
)

#! Uncomment to export model to file
# saveRDS(stm_model, file = file.path(DATA_DIR, "sent_stm_model_v2.stm"))
#! Uncomment to load existing model
# stm_model = readRDS(file = file.path(DATA_DIR, "sent_stm_model_v2.stm"))

# Extract top 10 words per topic
top_words <- labelTopics(stm_model, n = 10)
View(top_words)

png(file.path(FIGURES_DIR, "sent_stm.png"), width = 20, height = 15, units = "in", res = 200)
plot(stm_model, n=10)
dev.off()

# Topics of interest
topics = 1:37 # Make sure to set according to topic number determined from model

model_texts = sents[-c(processed$docs.removed)]
model_texts = model_texts[-c(out$docs.removed)]

filename = file.path(OUTPUT_DATA_DIR, "all_topics.txt")
for (topic in topics) {
  thoughts = findThoughts(stm_model, texts = model_texts, n=10, topics = topic)$docs[[1]]
  
  t = capture.output(
    labelTopics(stm_model, n = 10, topics = topic)
  )
  write_lines(t, file = filename, append = T)
  write("\n", file = filename, append = T)
  write_lines(thoughts,
              file = filename,
              sep = "\n\n",
              append = T)
}


### Appending topic proportions to original document dataframe
sent_props = tidy(stm_model, matrix = "gamma") %>%
  pivot_wider(id_cols = document,
              names_from = topic,
              values_from = gamma)

# area_topic_props = bind_cols(model_texts, sent_props, out$meta) %>%
#   group_by(Area) %>%
#   # Get avg topic props per witness interview
#   summarise(across(`1`:`37`, mean))


### COMBINE DATA TOGETHER AND SAVE TO OBJECT
a = sent_props %>% select(-document) %>%
  mutate(top_topic = names(.)[max.col(as.matrix(.))]) %>%
  mutate(top_topic = as.numeric(top_topic)) %>%
  select(top_topic)
full_data = cbind(sent_sentiments, a) %>%
  mutate(grievance_flag = ifelse(sentiment < 0, 1, 0)) %>%
  mutate(Witness = gsub("ï¿½", "", Witness)) %>%
  mutate(Area = gsub("ï¿½", "", Area)) %>% 
  mutate(Area = gsub(",$", "", Area)) %>%
  regex_left_join(occupation_refined, 
            by = c(Witness = "Name", Location = "Place")) %>%
  left_join(crosswalk, by = join_by(Area == napier)) %>%
  inner_join(topic_labels, by = join_by(top_topic == topic_num))
saveRDS(full_data, file = file.path(OUTPUT_DATA_DIR, "MAIN_DATA.rds"))

## Top Words for Topics of Interest
exclude_topics = c(
  1, 3, 7, 10, 14, 24, 26, 27, 
  30, 31, 35, 36, 37
) # Manually identified

topic_labels = read_csv(file.path(INPUT_DATA_DIR, "Topics.csv"))
top_words = tidy(stm_model) %>%
  filter(!topic %in% exclude_topics) %>%
  left_join(topic_labels, by = join_by(topic == topic_num)) %>% 
  group_by(label, term) %>%
  summarise(beta = sum(beta)) %>%
  slice_max(beta, n = 20) %>%
  ungroup() %>%
  ggplot(aes(beta, reorder(term, beta), fill = label)) +
  geom_col() +
  facet_wrap(~label, scales = "free", ncol=3) +
  # scale_fill_viridis_c() +
  theme_classic() +
  theme(legend.position = "none",
        axis.title.y = element_blank())

ggsave(filename = file.path(FIGURES_DIR, "top_words_high_level.png"),
       bg = "white",
       height = 7,
       width = 11,
       dpi = 300)
