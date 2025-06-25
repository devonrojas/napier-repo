################################################################################
### Authors: Devon Rojas
### Date created: Jun 4, 2025
### Project: Highland Clearances
################################################################################

library(sf)
library(ggplot2)
library(readxl)
library(stringdist)

uk = read_sf("../data/maps/LAD_DEC_24_UK_BSC.shp")
lookup_data = read_xlsx(path = "../data/maps/la_lookup.xlsx",
                        sheet = "SIMD 2020v2 DZ lookup data") 

lookup_data = lookup_data %>%
  select(LAname) %>%
  distinct()

crosswalk = read_csv("../data/1880s_to_Modern_Council_Area_Mapping.csv")
colnames(crosswalk) = c("napier", "current")


cosine_sims %>%  
  select(Area, dependence, identity) %>%
  left_join(crosswalk, by = join_by(Area == napier)) %>%
  group_by(current) %>%
  summarise(across(c(dependence, identity), mean)) %>%
  mutate(across(c(dependence, identity), ~scale(.x)[,1])) %>%
  right_join(scotland_valid, by = join_by(current == council)) %>%
  pivot_longer(c(dependence, identity), names_to = "dimension") %>%
  ggplot(aes(geometry = geometry)) +
  geom_sf(data = scotland, alpha = 0.2, color = "lightgrey") +
  geom_sf(aes(fill = value)) +
  scale_fill_viridis_c(option = "magma") +
  facet_wrap(~dimension) +
  theme_void()

scotland = uk %>%
  filter(LAD24NM %in% lookup_data$LAname) %>%
  rename(council = LAD24NM) %>%
  select(LAD24CD, council, geometry)

scotland %>%
  # filter(council == "Na h-Eileanan Siar") %>%
  ggplot(aes(geometry = geometry)) +
  geom_sf(fill = "gray") + 
  theme_void()

scotland_null = scotland %>%
  filter(!council %in% crosswalk$current)
scotland_valid = scotland %>%
  filter(council %in% crosswalk$current)

joined_data = area_topic_props %>% 
  left_join(crosswalk, by = join_by(Area == napier)) %>%
  group_by(current) %>%
  summarise(across(`1`:`37`, mean)) %>%
  right_join(scotland_valid, by = join_by(current == council)) %>%
  replace(is.na(.), 0) %>%
  pivot_longer(`1`:`37`, names_to = "topic") %>%
  mutate(topic = as.numeric(topic)) %>%
  inner_join(topic_labels, by = join_by(topic == topic_num))

agg_data = joined_data %>% 
  group_by(current, label, geometry) %>% 
  summarise(value = mean(value, na.rm = T))
agg_data %>%
  ggplot(aes(geometry = geometry)) +
  geom_sf(data = scotland, alpha = 0.2, color = "lightgrey") +
  geom_sf(aes(fill = value)) +
  scale_fill_viridis_c(option="magma") +
  facet_wrap(~label, nrow = 2,
             strip.position = "bottom") +
  theme_void() +
  theme(plot.margin = margin(1, 1, 1, 1, "cm"),
        panel.spacing = unit(2, "lines"),
        strip.clip = "off") +
  labs(
    fill = "Topic Prevalence"
  )

for(i in unique(joined_data$topic)) {
    p = joined_data %>%
      filter(topic == i) %>%
      ggplot(aes(geometry = geometry)) +
      geom_sf(data = scotland, alpha = 0.2, color = "lightgrey") +
      geom_sf(aes(fill = value)) +
      scale_fill_viridis_c(option="magma") +
      facet_wrap(~current, nrow = 2,
                 strip.position = "bottom") +
      theme_void() +
      theme(plot.margin = margin(1, 1, 1, 1, "cm"),
            panel.spacing = unit(2, "lines"),
            strip.clip = "off") +
      labs(
        fill = "Topic Prevalence",
        title = topic_labels[i, "sub_label"][[1]]
      )
    ggsave(filename = file.path("../figures_tables", paste0("topic_", i, ".png")),
           p, bg = "white",
           width = 10, height = 6, dpi = 300,
           units = "in")
}

occupation_data = read_excel("../data/occupation_data.xlsx")
occupation_data = occupation_data %>%
  mutate(Name = tools::toTitleCase(tolower(Name))) %>%
  mutate(Name = trimws(gsub("Mr", "", Name))) %>%
  mutate(Name = gsub("\\.", "", Name)) %>%
  mutate(Name = gsub("M'", "Mc", Name)) %>%
  mutate(Name = gsub("\\s\\s", " ", Name)) %>%
  drop_na(Name) %>%
  distinct(Name, Place, .keep_all = T)

## Hugh Mackay Merchant Greenock 60 is interviewed twice
docs %>%
  left_join(occupation_data, by = join_by(Witness == Name, Location == Place))

