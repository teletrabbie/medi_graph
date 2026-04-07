# Prepare data of "SwissDRG Antragsverfahren"


rm(list = ls())

# Load libraries
library(readxl)
library(janitor)
library(dplyr)


# Import data to environment
proposals <- rbind(cbind(read_excel("./src/resources/proposals ZE.xlsx"),quelle = "ze"),
                   cbind(read_excel("./src/resources/proposals Medi.xlsx"),quelle = "medi"))

proposals <- clean_names(proposals) %>% 
  filter(!is.na(aktueller_atc_code)) %>% 
  select(-problembeschreibung)
  

# Export as csv (to import folder of Neo4j)
import_folder <- "./src/main/import"
write.table(proposals, file = paste0(import_folder, "/antraege.csv")
            , row.names = FALSE, sep ="|", fileEncoding = "UTF-8")
