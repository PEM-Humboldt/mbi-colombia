#### Load required packages - libraries to run the script----
packages <- c("rstudioapi","sf","dplyr","terra","red", "rredlist","ggplot2")
lapply(packages,require,character.only=T)

# Set as working directory where the script is saved
dirfolder<- dirname(getSourceEditorContext()$path)
setwd(dirfolder)

#Load IUCN token----
token <- "YOUR TOKEN"

#Create ISO table by country of interest ----
IUCN_countries <- rredlist::rl_countries(key = token)$results
IUCN_COL <- dplyr::filter(IUCN_countries, isocode == "CO")
write.csv(IUCN_COL, "data/Iso_COL.csv")

#Create species table ----
IUCN_sp_col <- rredlist::rl_sp_country('CO', key = token)$result

sp_endemicas <- read.csv2("data/table_2024-07-22-18-20-41.csv", sep = ",")
colnames(sp_endemicas)[2] <-"scientific_name"
sp_endemicas <- sp_endemicas[,2] 
sp_endemicas_IUCN <- filter(IUCN_sp_col,IUCN_sp_col$scientific_name %in%  sp_endemicas)


IUCN_history <- lapply(X = sp_endemicas_IUCN$scientific_name, FUN = rredlist::rl_history, key = token)

IUCN_history_DF <- as.data.frame(matrix(NA,0,10))
for (i in 1:length(IUCN_history)){
  df=IUCN_history[[i]]$result
  if (is.data.frame(df)){
    df$species=IUCN_history[[i]]$name
    IUCN_history_DF=rbind.data.frame(IUCN_history_DF,df)
  }
  else {
    next
  }
} 

write.csv(IUCN_history_DF, "data/IUCN_history_DF.csv")

dataset <- data.frame(sp_col = character())
dataset1 <- data.frame(time_col = character())


historyAssesment_data <-  as.data.frame(IUCN_history_DF)
form_matrix <- as.formula(paste0("species", "~", "assess_year"))


historyAssesment_matrix <-   reshape2::dcast(historyAssesment_data, form_matrix,  value.var = "code",
                                            fun.aggregate = function(x) {unique(x)[1]}) %>% tibble::column_to_rownames("species") %>% as.data.frame.matrix()


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

# Remove species that do not have an assessment before the base year, in this case set to the year 2000
replace_na_with_previous <- function(df, target_col) {
  for (col in 2:(target_col-1)) {
    df[[target_col]] <- ifelse(is.na(df[[target_col]]), df[[col]], df[[target_col]])
  }
  return(df)
}

df <- replace_na_with_previous(RedList_matrix, which(names(RedList_matrix) == "2000"))

df_clean <- df %>%
  filter(!is.na(2000))

# Get the index of the base year column
base_year_index <- which(names(df_clean) == "2000")

# Select only the columns from the base year onward
df_filtered <- df_clean %>%
  select(X, all_of(names(df_clean)[base_year_index:ncol(df_clean)]))


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





