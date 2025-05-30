

file.stem <- paste0("C:/Users/",
                    Sys.info()["user"],
                    "/OneDrive - University of Edinburgh/")

setwd(paste0(file.stem,"research/napier/"))

index <- read.csv("raw/napier_index.csv")
index$header <- ""

#txt <- list()
#i <- 2

for(i in 1:nrow(index)){
  print(paste("Downloading record", i, index$Witness[i]))

url_bow <- polite::bow(index$Url[[i]])

html <-
  polite::scrape(url_bow) 

header <- html %>% 
  html_element("h3") %>%
  html_text()

index$header[i] <- gsub("\\n", "", header)


txt <- html %>% 
  #rvest::html_element(xpath = "//*[@id=\"Blog1\"]/div[1]/div/div/div/div[1]") %>%
  #rvest::html_element(xpath = "//*[@id=\"post-body-5401279773803918619\"]") %>%
  rvest::html_element(xpath = "//*[@class=\"post-body entry-content\"]") %>%
  html_text() %>%
  strsplit(., split = "\\n") %>%
  unlist() %>%
  as_tibble_col(column_name = "text") %>%
  filter(text != "") %>%
  add_column(id = i) %>%
  add_column(witness = index$Witness[[i]]) %>%
  add_column(area = index$Area[[i]]) %>%
  mutate(record_row_num = row_number())

  write.csv(txt, paste0("raw/record",i,".csv"))
  write.csv(index, "raw/index_post_download.csv")

}





#post-body-1965303820475649062

