################################################################################
### Authors: Devon Rojas, Christina Mazilu, Katelyn Nutley, Aliah Zewail, Tod Van Gunten
### Date created: Jun 4, 2025
### Project: Highland Clearances
################################################################################

library(tidyverse)
library(ggplot2)
library(sf)
library(readxl)
library(stringdist)
library(stargazer)

library(dotenv)

load_dot_env(file = ".env")

# Load in Data (MAKE SURE TO SET WORKING DIRECTORY FIRST)
DATA_DIR = Sys.getenv("DATA_DIR")
RAW_DATA_DIR = Sys.getenv("RAW_DATA_DIR")
OUTPUT_DATA_DIR = Sys.getenv("OUTPUT_DATA_DIR")
FIGURES_DIR = Sys.getenv("FIGURES_DIR")

## MAIN DATA TABLES
# data = read_csv("../data/MAIN_DATA.csv")
data = readRDS(file.path(OUTPUT_DATA_DIR, "MAIN_DATA.rds"))
index = read_csv(file.path(RAW_DATA_DIR, "napier_index.csv"))
cosine_sims = read_csv(file.path(OUTPUT_DATA_DIR, "cosine_sim.csv"))
cosine_sims = cosine_sims %>%
  group_by(Area, Location, Witness) %>%
  summarise(across(c(dependence, identity), mean)) %>%
  ungroup() %>%
  mutate(across(c(dependence, identity), ~ scale(.x)[,1]))

# Manual data correction for Edinburgh
x = c(
  NA,
  "Highland",
  "Highland",
  "Highland",
  NA,
  "City of Edinburgh",
  "Highland",
  "Highland",
  "Highland",
  "Highland",
  "City of Edinburgh",
  "City of Edinburgh",
  "Highland",
  "Na h-Eileanan Siar",
  "Glasgow City",
  "Na h-Eileanan Siar",
  "Na h-Eileanan Siar",
  "Highland"
)
corrected_locs = index %>%
  filter(grepl("Edinburgh", Area)) %>%
  distinct(Witness, Area) %>%
  select(Witness, Area) %>%
  mutate(Witness = gsub("�", "", Witness)) %>%
  mutate(Area = gsub("�", "", Area)) %>%
  mutate(Area = gsub(",", "", Area)) %>%
  mutate(current_corrected = x)
corrected_data = data %>%
  left_join(corrected_locs, by = join_by(Witness, Area)) %>%
  mutate(current = ifelse(is.na(current_corrected), current, current_corrected))

## GEO DATA
uk = read_sf(file.path(DATA_DIR, "maps", "LAD_DEC_24_UK_BSC.shp"))
scotland = uk %>%
  filter(LAD24NM %in% lookup_data$LAname) %>%
  rename(council = LAD24NM) %>%
  select(LAD24CD, council, geometry)

highland = read_sf(file.path(DATA_DIR, "maps", "Area_Committee_Areas.shp"))

lookup_data = read_xlsx(path = file.path(DATA_DIR, "maps", "la_lookup.xlsx"),
                        sheet = "SIMD 2020v2 DZ lookup data") 
lookup_data = lookup_data %>% select(LAname) %>% distinct()

crosswalk = read_csv(file.path(DATA_DIR, "maps", "1880s_to_Modern_Council_Area_Mapping.csv"))
colnames(crosswalk) = c("napier", "current")

highland_areas = c(
  "Sutherland",
  "Caithness",
  "Ross",
  "Skye",
  "Lochaber",
  "Inverness",
  "Nairnshire",
  "Badenoch",
  "Dingwall",
  "Ross"
)

highland = highland %>%
  mutate(AreaName = highland_areas) %>%
  group_by(AreaName) %>%
  summarise(geometry = st_union(geometry))

scotland_detail =
  scotland %>%
  bind_rows(highland %>% rename(council = AreaName)) %>%
  filter(council != "Highland")

# Topic prevalence by region
data_detail = corrected_data %>%
  mutate(region = str_split_i(Area, ",", i=1)) %>%
  mutate(region = case_when(
    region == "Inverness-shire" ~ "Inverness",
    region == "Ross-shire" ~ "Ross",
    .default = region
  )) %>%
  mutate(region = case_when(
    grepl("Highland", current) ~ region,
    .default = current
  )) %>%
  filter(region != "Edinburgh")

topic_by_region = data_detail %>%
  group_by(region, label) %>%
  summarise(count = sum(grievance_flag)) %>%
  mutate(pct = count/sum(count)) %>%
  regex_left_join(scotland_detail, by = c(region = "council")) %>%
  filter(!grepl("Edinburgh|Glasgow", council)) %>%
  ggplot(aes(geometry = geometry)) +
   # Geo plotting
   geom_sf(data = scotland, alpha = 0.2, color="lightgrey") +
   geom_sf(aes(fill = pct), color=NA) +
   ###
   facet_wrap(~label) +
   theme_void() +
   labs(fill = "Topic Prevalence") +
   theme(legend.position="bottom",
         legend.title.position="top")
ggsave(filename = file.path(FIGURES_DIR, "topic_by_region.png"),
       topic_by_region,
       bg="white",
       width=10,
       height=8,
       dpi=300)

# Grievance topic proportion by area
occ_labels = c(
  "landowner" = "Land Owner",
  "small_landowner" = "Small Land Owner",
  "clergy" = "Clergy",
  "professional" = "Professional",
  "land_worker" = "Land Worker",
  "labourer" = "Labourer"
)
p = data_detail %>%
  drop_na(current) %>%
  filter(occ_cat != "other") %>%
  filter(!grepl("Edinburgh|Glasgow", current)) %>%
  group_by(occ_cat, region, label) %>%
  summarise(count = sum(grievance_flag)) %>%
  mutate(pct = count/sum(count)) %>%
  mutate(label = factor(label, levels = c(
    "Social and Religious Disruption",
    "Displacement and Population Change",
    "Land ownership and governance",
    "Environmental and Agricultural Decline",
    "Economic Hardship and Material Conditions",
    "Land Use and Access Conflicts"
  ))) %>%
  ggplot(aes(x = fct_rev(region), y = pct, fill = fct_rev(label))) +
  geom_col() +
  scale_y_continuous(labels = scales::percent) +
  # scale_x_discrete(labels = occ_labels) +
  scale_fill_discrete_sequential(palette = "Terrain",
                                 nmax = 7,
                                 order = 2:7) +
  facet_wrap(~occ_cat, labeller = as_labeller(occ_labels)) +
  coord_flip() +
  theme_classic() +
  theme(legend.position = "bottom",
        legend.title.position = "top") +
  # guides(fill = guide_legend(nrow = 1)) +
  labs(x = "Class",
       y = "Percent",
       fill = "Grievance Category")
ggsave(filename = file.path(FIGURES_DIR, "grievance_by_area_occ.png"),
       p,
       bg = "white",
       width = 12,
       height = 7,
       dpi = 300)

overall_topic_props = data_detail %>%
  drop_na(current) %>%
  filter(occ_cat != "other") %>%
  filter(!grepl("Edinburgh|Glasgow", current)) %>%
  group_by(label) %>%
  summarise(count = sum(grievance_flag)) %>%
  mutate(pct = count/sum(count)) %>%
  arrange(pct) %>%
  mutate(label = factor(label, levels = c(
    "Social and Religious Disruption",
    "Displacement and Population Change",
    "Land ownership and governance",
    "Environmental and Agricultural Decline",
    "Economic Hardship and Material Conditions",
    "Land Use and Access Conflicts"
  ))) %>%
  ggplot(aes(x = "Overall", y = pct, fill = fct_rev(label))) +
  geom_col() +
  geom_text(aes(label = scales::percent(pct, 2)),
            position=position_stack(vjust=0.5)) +
  scale_y_continuous(labels = scales::percent) +
  scale_fill_discrete_sequential(palette="Terrain",
                                 nmax=7,
                                 order=2:7) +
  theme_void() +
  # theme(legend.position="bottom",
  #       legend.title.position = "top") +
  coord_flip() +
  labs(fill = "Grievance Type")
ggsave(filename = file.path(FIGURES_DIR, "overall_topic_props.png"),
       overall_topic_props,
       bg = "white",
       width = 8,
       height = 4,
       dpi = 300)

# Grievance topic proportion by area map
p = data_detail %>%
  drop_na(current) %>%
  filter(!grepl("Edinburgh|Glasgow", Area)) %>%
  group_by(current, label) %>%
  summarise(count = sum(grievance_flag)) %>%
  mutate(pct = count/sum(count)) %>%
  slice_max(pct, n = 1) %>%
  left_join(scotland_detail, by = join_by(current == council)) %>%
  ggplot(aes(geometry = geometry)) +
  # Geo plotting
  geom_sf(data = scotland, alpha=0.2, color="lightgrey") +
  geom_sf(aes(fill = label)) +
  ###
  scale_fill_discrete_sequential(palette="Terrain") +
  theme_void()

# Grievance topic proportion by area map
p = data_detail %>%
  drop_na(current) %>%
  filter(!grepl("Edinburgh|Glasgow", Area)) %>%
  group_by(current, label) %>%
  summarise(count = sum(grievance_flag)) %>%
  mutate(pct = count/sum(count)) %>%
  left_join(scotland_detail, by = join_by(current == council)) %>%
  ggplot(aes(geometry = geometry)) +
  # Geo plotting
  geom_sf(data = scotland, alpha=0.2, color="lightgrey") +
  geom_sf(aes(fill = pct)) +
  ###
  facet_wrap(~label) +
  theme_void()
ggsave(filename = file.path(FIGURES_DIR, "grievances_by_area.png"),
       p,
       bg = "white",
       width = 16,
       height = 10)

identity = cosine_sims %>%
  mutate(Area = gsub("ï¿½", "", Area)) %>%
  mutate(Area = gsub(",$", "", Area)) %>%
  filter(!grepl("Edinburgh|Glasgow", Area)) %>%
  left_join(crosswalk, by = join_by(Area == napier)) %>%
  mutate(region = str_split_i(Area, ",", i=1)) %>%
  mutate(region = case_when(
    region == "Inverness-shire" ~ "Inverness",
    region == "Ross-shire" ~ "Ross",
    .default = region
  )) %>%
  mutate(region = case_when(
    grepl("Highland", current) ~ region,
    .default = current
  )) %>%
  filter(region != "Edinburgh") %>%
  drop_na(current) %>%
  left_join(corrected_locs, by = join_by(Witness, Area)) %>%
  mutate(current = ifelse(is.na(current_corrected), current, current_corrected)) %>%
  group_by(region) %>%
  summarise(across(c(dependence, identity), mean)) %>%
  mutate(c = (dependence + identity)/2) %>%
  mutate(c = scale(c)[,1]) %>%
  left_join(scotland_detail, by = join_by(region == council)) %>%
  ggplot(aes(geometry = geometry)) +
  # Geo plotting
  geom_sf(data = scotland, alpha=0.2, color="lightgrey", linewidth=0.25) +
  geom_sf(aes(fill = c), linewidth = 0.25, color=NA) +
  ###
  scale_fill_viridis_c(option="magma") +
  theme_void() +
  labs(fill = "Z-Scored Place-Based Identity")
ggsave(filename = file.path(FIGURES_DIR, "identity_map.png"),
       identity,
       bg = "white",
       width=7,
       height=7,
       dpi=300)


identity_by_occ = cosine_sims %>%
  mutate(Area = gsub("ï¿½", "", Area)) %>%
  mutate(Area = gsub(",$", "", Area)) %>%
  filter(!grepl("Edinburgh|Glasgow", Area)) %>%
  left_join(crosswalk, by = join_by(Area == napier)) %>%
  mutate(region = str_split_i(Area, ",", i=1)) %>%
  mutate(region = case_when(
    region == "Inverness-shire" ~ "Inverness",
    region == "Ross-shire" ~ "Ross",
    .default = region
  )) %>%
  mutate(region = case_when(
    grepl("Highland", current) ~ region,
    .default = current
  )) %>%
  filter(region != "Edinburgh") %>%
  drop_na(current) %>%
  left_join(corrected_locs, by = join_by(Witness, Area)) %>%
  mutate(current = ifelse(is.na(current_corrected), current, current_corrected)) %>%
  regex_left_join(occupation_refined, by = c(Witness = "Name", Location = "Place")) %>%
  filter(occ_cat != "other") %>%
  group_by(region, occ_cat) %>%
  summarise(across(c(dependence, identity), mean)) %>%
  mutate(c = (dependence + identity)/2) %>%
  mutate(c = scale(c)[,1]) %>%
  mutate(col = case_when(
    c < 0 ~ -1,
    c > 0 ~ 1,
    .default = 0
  )) %>%
  # mutate(occ_cat = occ_labels[occ_cat]) %>%
  # unnest(occ_cat) %>%
  ggplot(aes(x = region, y = c, color = col)) +
  geom_point() +
  geom_hline(yintercept=0, color = "black", linetype="dashed") +
  scale_color_continuous_diverging(palette = "Red-Green",
                                   l1 = 30, l2 = 90,
                                   p1 = 0.9, p2 = 1.2) +
  facet_wrap(~occ_cat, labeller = as_labeller(occ_labels)) +
  coord_flip() +
  theme_classic() +
  theme(legend.position="bottom",
        legend.title.position = "top") +
  labs(color = "Z-Scored Place-Based Identity Measure")
ggsave(filename = file.path(FIGURES_DIR, "identity_by_occ.png"),
       identity_by_occ,
       bg = "white",
       width = 8,
       height = 6,
       dpi = 300)

