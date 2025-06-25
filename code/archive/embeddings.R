library(tidyverse)
library(text2vec)
library(umap)
library(ggrepel)

# Load in Data
DATA_DIR = "../raw"
# DATA_DIR = "~/Downloads/transcripts"
files = list.files(DATA_DIR, pattern = "\\d.*.csv$", full.names = TRUE)

corpus = tibble()
for (file in files) {
  df = read_csv(file)
  corpus = rbind(df, corpus)
}
corpus = corpus %>% drop_na(Answer)

corpus = corpus %>%
  unite("text", Statement, Question, Answer, sep = "\n", na.rm = T) %>%
  group_by(Witness, Area, Location) %>%
  summarise(text = paste(text, collapse = "\n"),
            .groups = "drop")

corpus %>%
  unnest_tokens(word, text) %>%
  anti_join(stop_words)

tokens = word_tokenizer(corpus$text)
# Lowercase
tokens = lapply(tokens, tolower)
# Remove stopwords
tokens = lapply(tokens, function(x) x[!x %in% stop_words$word])
# Remove numeric
tokens = lapply(tokens, function(x) x[!grepl("[0-9]", x)])
it = itoken(tokens, progressbar = T)
vocab = create_vocabulary(it, ngram = c(1, 3))
vocab = prune_vocabulary(vocab, term_count_min = 5)
vectorizer = vocab_vectorizer(vocab)
tcm = create_tcm(it, vectorizer, skip_grams_window = 5)

glove = GlobalVectors$new(rank = 100, x_max = 10)
wv_main = glove$fit_transform(tcm, n_iter = 15, 
                              convergence_tol = 0.01, n_threads = detectCores() - 1)
wv_context = glove$components
word_vectors = wv_main + t(wv_context)

# Project into 2D for visualization
custom.config = umap.defaults
custom.config$random_state = 1234
custom.config$min_dist = 0.05
custom.config$metric = "euclidean"
custom.config$n_neighbors = 10
word_umap = umap(word_vectors)

word_coords = word_umap$layout %>%
  as.table() %>%
  as.data.frame() %>%
  as_tibble() %>%
  pivot_wider(names_from = Var2, values_from = Freq) %>%
  mutate(X = median(A), Y = median(B)) %>%
  mutate(dist = sqrt((A - X)^2 + (B - Y)^2)) %>%
  mutate(threshold = quantile(dist, 0.995)) %>%
  filter(dist <= threshold)

focal_word = word_vectors["rent", , drop = F]
top_words = sim2(word_vectors, focal_word, method = "cosine", norm = "l2")
# Get top 50 words for focal word
closest = head(sort(top_words[,1], decreasing = T), 50) %>%
  names()

word_coords %>%
  # Optional: Filter list by closest word list from above
  filter(Var1 %in% closest) %>%
  # sample_frac(size = 0.05) %>%
  ggplot(aes(x = A, y = B)) +
  # geom_point() +
  geom_text(aes(label = Var1)) +
  theme_classic() +
  labs(x = "PC1",
       y = "PC2")
  # theme_void()
