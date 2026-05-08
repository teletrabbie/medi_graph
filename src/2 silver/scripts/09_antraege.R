# Prepare data of "SwissDRG Antragsverfahren"


rm(list = ls())

# Load libraries
library(readxl)
library(janitor)
library(dplyr)


# Import data to environment
proposals <- rbind(cbind(read_excel("./src/1 bronze/staging area/proposals ZE.xlsx"),quelle = "ze"),
                   cbind(read_excel("./src/1 bronze/staging area/proposals Medi.xlsx"),quelle = "medi"))

proposals <- clean_names(proposals) %>% 
  filter(!is.na(aktueller_atc_code)) %>% 
  select(-problembeschreibung)
  

# Export as csv
import_folder <- "./src/2 silver/staging area/"
write.table(proposals, file = paste0(import_folder, "/antraege.csv")
            , row.names = FALSE, sep ="|", fileEncoding = "UTF-8")
