#====================
#
#
#   Interact with 
#  ArcResults Drive
#
#
#====================


# Set working directory
setwd('/home/rstudio/users/gold1/fmv/data')

# load packages
library(tidyverse)
library(googledrive)

# Drive Auth ####

if (!drive_has_token()) {
  
  drive_auth('gold1@roar.stolaf.edu')
  
  }


## Specify Drive Location ####

drive_id_arc <- as_id("https://drive.google.com/drive/folders/1oHbTsYdQMY86T69nszp1wj47X9HfBDiT")

## inspect drive contents
drive_contents <- drive_ls(drive_id_arc) 

# Retrieve Soil Codes ####

## specify names of state soil code csvs not already in folder ####
soilcodes_to_load <- drive_contents %>%
  dplyr::filter(str_detect(name, "soilcodes.+csv$")) %>% 
  filter(!is.element(name, list.files('ArcResults/soilcodes'))) %>%
  .[[1]]

## download from drive ####
walk(soilcodes_to_load,
    ~ drive_download(.x, path = file.path('ArcResults','soilcodes',.x),
                     overwrite = T))

soilcode_csvs <- list.files('ArcResults/soilcodes') %>%
  sort()

## Find the maximum soil codes across all indiv states ####
max_n <- map(soilcode_csvs, 
     ~ nrow(read_csv(file.path('ArcResults/soilcodes', .x),
                     show_col_types = F))) %>%
  unlist() %>%
  max()


## Collate state soil codes into single df ####
soil_tbl <- tibble(rowid = seq_len(max_n))

for (i in seq_len(length(soilcode_csvs))) {
  
  state <- str_extract(soilcode_csvs[[i]], "(?<=_)[:upper:]{2}")
  
  tmp <- read_csv(file.path('ArcResults/soilcodes',
                            soilcode_csvs[[i]]),
                  show_col_types = F) %>%
    arrange(farmlndcl) %>%
    rowid_to_column() %>%
    dplyr::select(rowid, farmlndcl) %>%
    rename({{ state }} := "farmlndcl")

  soil_tbl <- soil_tbl %>%
    left_join(tmp)

}

## Count soil types ####
soil_counts <- soil_tbl %>% pivot_longer(
  cols = !rowid,
  names_to = "state",
  values_to = 'farmlndcl') %>%
  filter(!is.na(farmlndcl)) %>%
  count(farmlndcl) %>%
  mutate(prop = round(n/length(soilcode_csvs),2)) %>%
  arrange(desc(n))


# Load Parquet files ####

## download all PCIS pqt state files ####
setwd("/home/rstudio/users/gold1/fmv/data/ArcResults/parquet")

## build vector of all state pqt files ####
pcis_pqt <- drive_contents %>%
  filter(str_detect(name, "pqt")) %>%
  pull(name) |>
  sort()

## vector of state pqt files NOT already in folder ####
pcis_to_load <- pcis_pqt %>%
  tibble(name = .) %>% 
  filter(!is.element(name, list.files())) %>%
  pull()

walk(pcis_pqt,
     ~ drive_download(file = .x, 
                      path = .x,
                      overwrite = T)
     )

setwd('/home/rstudio/users/gold1/fmv')
