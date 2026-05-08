# Copy "Liste der hochteuren Medikamente/Substanzen" to silver staging area

rm(list = ls())

bronze_file <- "./src/1 bronze/staging area/hochteure_medis.csv"
silver_file <- "./src/2 silver/staging area/hochteure_medis.csv"
file.copy(bronze_file, silver_file)


# Delete bronze file
file.remove(bronze_file)
