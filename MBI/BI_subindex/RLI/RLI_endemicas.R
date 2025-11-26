#### Load required packages - libraries to run the script----
packages <- c("rstudioapi","sf","dplyr","terra","red", "rredlist","ggplot2", "tibble", "reshape")
lapply(packages,require,character.only=T)

# Set as working directory where the script is saved
dirfolder<- dirname(getSourceEditorContext()$path)
setwd(dirfolder)

#Load IUCN token----
token <- "your_token"

#Create ISO table by country of interest ----
IUCN_countries <- rredlist::rl_countries(key = token) ## ya no tiene results
str(IUCN_countries)

# Obtener los países
IUCN_countries_raw <- rredlist::rl_countries(key = token)

# Inspeccionar qué contiene
str(IUCN_countries_raw)

IUCN_COL <- IUCN_countries_raw$countries %>%
  dplyr::filter(grepl("CO", code, ignore.case = TRUE))


write.csv(IUCN_COL, "Iso_COL.csv")

#Create species table ----
IUCN_sp_col <- rredlist::rl_countries('CO', key = token)
str(IUCN_sp_col) ##cambio rl_sp_country

sp_endemicas <- read.csv2("C:/Users/walter.garcia/Downloads/RLI/RLI/RLI/data/table_2024-07-22-18-20-41.csv")
colnames(sp_endemicas)[2] <-"scientific_name"
sp_endemicas <- sp_endemicas[,2] 
# Extraer el data frame con las evaluaciones
IUCN_sp_df <- IUCN_sp_col$assessments

# Filtrar por las especies de tu lista de endémicas
sp_endemicas_IUCN <- IUCN_sp_df %>%
  filter(taxon_scientific_name %in% sp_endemicas)


IUCN_history <- lapply(seq_len(nrow(sp_endemicas_IUCN)), function(i) {
  name_split <- strsplit(sp_endemicas_IUCN$taxon_scientific_name[i], " ")[[1]]
  genus <- name_split[1]
  species <- paste(name_split[-1], collapse = " ")
  
  message("Descargando historial de ", genus, " ", species, " (", i, "/", nrow(sp_endemicas_IUCN), ")")
  
  res <- tryCatch({
    rredlist::rl_species(genus = genus, species = species, key = token)
  }, error = function(e) {
    message("⚠️ Error con ", genus, " ", species, ": ", e$message)
    return(NULL)
  })
  
  Sys.sleep(runif(1, 1, 2.5)) # pausa entre consultas
  return(res)
})

IUCN_history_DF <- data.frame()

for (i in seq_along(IUCN_history)) {
  df <- IUCN_history[[i]]$assessments  # 👈 CAMBIO AQUÍ
  
  if (is.data.frame(df) && nrow(df) > 0) {
    df$species <- IUCN_history[[i]]$taxon$scientific_name
    IUCN_history_DF <- rbind(IUCN_history_DF, df)
  }
}


IUCN_history_DF_clean <- as.data.frame(lapply(IUCN_history_DF, function(x) {
  if (is.list(x)) {
    sapply(x, function(y) paste(y, collapse = ", "))
  } else {
    x
  }
}), stringsAsFactors = FALSE)

write.csv(IUCN_history_DF_clean, "data/IUCN_history_DF2.csv", row.names = FALSE)

dataset <- data.frame(sp_col = character())
dataset1 <- data.frame(time_col = character())


historyAssesment_data <-  as.data.frame(IUCN_history_DF)
form_matrix <- as.formula(paste0("species", "~", "assess_year"))


historyAssesment_matrix <- dcast(
  historyAssesment_data,
  species ~ year,
  value.var = "code",
  fun.aggregate = function(x) unique(x)[1]
) %>%
  column_to_rownames("species") %>%
  as.data.frame.matrix()


# Adjust threat matrix ----

#Redlist code
adjust_categories<- data.frame(Cat_IUCN= c("CR", "DD", "EN", "EN", "DD", "DD", "LC", "LC", "LC", "NT", "DD", "NT", "RE", "VU", "VU"),
                               code= c("CR", "DD", "E", "EN", "I", "K", "LC", "LR/cd", "LR/lc", "LR/nt", "NA", "NT", "R", "V", "VU"))

RedList_matrix<- historyAssesment_matrix %>% as.matrix()

for(i in seq(nrow(adjust_categories))){
  RedList_matrix[ which(RedList_matrix== adjust_categories[i,]$code, arr.ind = TRUE) ]<- adjust_categories[i,]$Cat_IUCN 
}

for(j in unique(adjust_categories$Cat_IUCN)){
  key<- c(tolower(j), toupper(j), j) %>% paste0(collapse = "|")
  RedList_matrix[ which(grepl(key, RedList_matrix), arr.ind = T) ]    <- j
}

RedList_matrix[which( (!RedList_matrix %in% adjust_categories$Cat_IUCN)  & !is.na(RedList_matrix) , arr.ind = TRUE )]<-NA
RedList_matrix

#RedList_matrix <- read.csv("result/RedList_matrix.csv")
RedList_matrix_2 = as.data.frame.matrix(RedList_matrix)
# Remove species that do not have an assessment before the base year, in this case set to the year 2000

replace_na_with_previous <- function(df, target_col) {
  for (col in 2:(target_col-1)) {
    df[[target_col]] <- ifelse(is.na(df[[target_col]]), df[[col]], df[[target_col]])
  }
  return(df)
}

# Get the index of the base year column
base_year_index <- which(names(RedList_matrix_2) == "2000")


df = RedList_matrix_2
for(k in 2:ncol(RedList_matrix_2)){
  df <- replace_na_with_previous(df, k)
}

df_clean <- df[!is.na(df[,base_year_index]),]


# Select only the columns from the base year foward
df_filtered <- df_clean %>%
  select(all_of(names(df_clean)[base_year_index:ncol(df_clean)]))




# Redlist result ----
RedList_data<- red::rli(df_filtered, boot = F) %>% t() %>% as.data.frame() %>% tibble::rownames_to_column("Year") %>%  setNames(c("Year", "RLI")) %>% 
  dplyr::filter(!Year %in% "Change/year")

RedList_data <- na.omit(RedList_data)

# Redlist figure ----

RedList_trendPlot<- ggplot(RedList_data, aes(x = Year, y = RLI)) +
  geom_line(group = 1, col= "red") +
  geom_point() +
  coord_cartesian(ylim = c(0,1))+
  theme_classic()+
  theme(    panel.grid.major = element_line(color = "gray"),
  ) + theme(text = element_text(size = 4))

RedList_data
RedList_trendPlot

## Write results ----
write.csv(RedList_data, "result/RedList_result.csv", row.names = F)
write.csv(RedList_matrix, "result/RedList_matrix.csv", row.names = T) 
ggsave("result/RedList_Plot.png", RedList_trendPlot, height = 2, width = 4)




