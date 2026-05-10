# Copy "ATC Alternations" to silver staging area

rm(list = ls())

bronze_file <- "./src/1 bronze/staging area/atc_alterations.csv"
silver_file <- "./src/2 silver/staging area/atc_alterations.csv"
file.copy(bronze_file, silver_file)
