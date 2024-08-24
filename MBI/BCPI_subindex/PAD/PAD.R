#### Code to calculate the Living Planet Index 

##Load packages
packages <- c("rstudioapi", "foreach", "dplyr","ggplot2")
lapply(packages,require,character.only=T)

# Set as working directory where the script is saved
dirfolder<- dirname(getSourceEditorContext()$path)
setwd(dirfolder)

#Set data direction
ENA_path <- "Data"
results_path <- "Results"
yearList <- data.frame(year = c("2013", "2014","2015", "2016", "2017", "2019"))

# Function to calculate Simpson's Diversity Index applied to productive activities
df_final <- data.frame(year = NA, PAD = NA)

foreach (i = 1: nrow(yearList))%do%{
  year <- yearList$year[i]
  r_frame <- read.csv2(file.path(ENA_path, paste0(year,"_Usuelo.csv")))
  r_frame1 <- select(r_frame, -KEYPPAL) 
  
  n <- colSums(r_frame1)
  N <- sum(n)
 
  numerator <- sum(n * (n - 1))
  denominator <- N * (N - 1)
  D <- numerator / denominator
  
  df <- data.frame(year = year, PAD = D)
  df_final <- bind_rows(df_final,df)
}

df_final_1 <- na.omit(df_final)

write.csv(df_final_1,file.path(results_path, paste0("PAD.csv")))

#Plot indicator trend
PAD_trendPlot <- ggplot(df_final_1, aes(x = year, y = PAD)) +
  geom_line(group = 1, col= "red") +
  geom_point() +
  theme_classic()+
  theme(    panel.grid.major = element_line(color = "gray"),
  ) + theme(text = element_text(size = 10))

ggsave(file.path(results_path, paste0("PAD.png")), PAD_trendPlot)


