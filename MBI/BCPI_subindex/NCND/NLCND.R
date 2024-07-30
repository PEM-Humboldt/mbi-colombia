#### Code to calculate the Living Planet Index 

##Load packages
packages <- c("rstudioapi","sf","tidyverse","raster","units", "foreach")
lapply(packages,require,character.only=T)

# Set as working directory where the script is saved
dirfolder<- dirname(getSourceEditorContext()$path)
setwd(dirfolder)

##Load disaster layers

Erosion <- read_sf("Data/Dis_Erosion.shp")
Landslide <- read_sf("Data/Dis_delizamiento_clip.shp")
Flood <- read_sf("Data/Dis_inunda.shp")

NC_2018 <- raster("D:/Pontificia Universidad Javeriana/BioTablero - Documentos/ecosistemas/cobertura_actual/info_final/coverage_2018_N.tif")

##Merge disaster layer
#check the projection system of the layers
crs_E <- st_crs(Erosion)
crs_L <- st_crs(Landslide)
crs_F <- st_crs(Flood)


#Project if necessary. In this example, the Landslide layer must be reprojected.
Landslide <- st_transform(Landslide, crs_E)

#Union layers and dissolve them into a single polygon
Erosion_val <- st_make_valid(Erosion)
Landslide_val <- st_make_valid(Landslide)
Flood_val <- st_make_valid(Flood)

All_ND_2 <- st_union(Flood_val, Landslide_val)
All_ND_1 <- st_union(All_ND_2, Erosion_val)
All_ND_1 <- st_make_valid(All_ND_1)
#All_ND <- st_union(All_ND_1)
write_sf(All_ND_1, "Data/All_disasters.shp")

##Clip natural land cover layer using the disaster layers----
#All_ND_ <- sf:::as_Spatial(All_ND)
prueba <- mask(x = NC_2018, mask = All_ND_1)
# Calculate the area of each cell
cell_area <- area(prueba)

# Calculate the total area
total_area <- sum(cell_area[], na.rm=TRUE)
print(total_area)

#### Loop for several years ----

#Set data direction
natural_path <- "E:/1. BASEDEDATOSGEOGRAFICA/1. BASEDEDATOSGEOGRAFICA/Informacion Geografica Base/RECLASS_CORINE"
results_path <- "Results/Clip_CLC"
yearList <- data.frame(year = c("2002", "2009","2012", "2018"))

df_final=data.frame(year = NA, NLCND = NA)

foreach (i = 1: nrow(yearList))%do%{
  year <- yearList$year[i]
  r_frame <- raster(file.path(natural_path, paste0("coverage_", year,"_N.tif")))
  natural <- raster::mask(x = r_frame, mask = All_ND_1)
  #writeRaster(natural, file.path(results_path, paste0("All_", year,"_N.tif")))
  # Calculate the area of each cell
  cell_area <- area(natural)
  
  # Calculate the total area
  total_area <- sum(cell_area[], na.rm=TRUE)
  
  df <- data.frame(year = year, NLCND = total_area)
  df_final <- bind_rows(df_final,df)
}

df_final_1 <- na.omit(df_final)

write.csv(df_final_1,file.path(results_path, paste0("All_NLCND.csv")))

NLCND_trendPlot <- ggplot(df_final_1, aes(x = year, y = NLCND)) +
  geom_line(group = 1, col= "red") +
  geom_point() +
  theme_classic()+
  theme(    panel.grid.major = element_line(color = "gray"),
  ) + theme(text = element_text(size = 10))

ggsave(file.path(results_path, paste0("NLCND.png")), NLCND_trendPlot)


