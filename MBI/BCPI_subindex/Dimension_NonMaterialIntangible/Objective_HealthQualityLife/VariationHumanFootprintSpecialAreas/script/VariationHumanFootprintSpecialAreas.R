## Establecer parámetros de sesión ####
### Cargar librerias/paquetes necesarios para el análisis ####

#### Verificar e instalar las librerC-as necesarias ####
packagesPrev <- installed.packages()[,"Package"]  
packagesNeed <- librerias <- c("this.path", "magrittr", "dplyr", "plyr", "pbapply", "data.table", "raster", "terra", "sf", "ggplot2", 
                               "tidyr", "RColorBrewer", "reshape2", "ggnewscale","openxlsx", "ggspatial",
                               "future", "future.apply", "progressr")  # Define los paquetes necesarios para ejecutar el codigo
new.packages <- packagesNeed[!(packagesNeed %in% packagesPrev)]  # Identifica los paquetes que no estC!n instalados
if(length(new.packages)) {install.packages(new.packages, binary = TRUE)}  # Instala los paquetes necesarios que no estC!n previamente instalados

#### Cargar librerias ####
lapply(packagesNeed, library, character.only = TRUE)  # Carga las librerías necesarias

## Establecer entorno de trabajo ####
dir_work <- this.path::this.path() %>% dirname()  # Establece el directorio de trabajo

### Definir entradas necesarias para la ejecución del análisis ####

# Definir la carpeta de entrada-insumos
input_folder<- file.path(dir_work, "input"); # "~/input"

# Crear carpeta output
output<- file.path(dir_work, "output"); dir.create(output)

#### Definir entradas necesarias para la ejecución del análisis ####
input <- list(
  studyArea= file.path(input_folder, "studyArea", "antioquia.shp"),  # Ruta del archivo espacial que define el área de estudio
  time_IHEH_List= list( # Lista de rutas de archivos espaciales que representan huella humana en diferentes años. Deben tener los mismos rangos de valor para ser comparables (ej. 0 a 100) , extension y sistema de coordenadas.  Cada elemento en la lista se nombra con el año correspondiente al que representa el archivo de heulla humana. Esto permitira ordenarlos posteriormente
    "2015"= file.path(input_folder, "HumanFootprint", "IHEH_2015.tif"), # Indice de huella humana para Colombia del año 2015 IAvH
    "2018"= file.path(input_folder, "HumanFootprint", "IHEH_2018.tif"), # Indice de huella humana para Colombia del año 2018 IAvH
    "2019"= file.path(input_folder, "HumanFootprint", "IHEH_2019.tif")  # Indice de huella humana para Colombia del año 2019 IAvH
  ),
  AME_List= list( # Lista de rutas de archivos espaciales que representan areas de manejo especial
    "ResguardosIndigenas"= file.path(input_folder, "SpecialAreas", "Resguardos_ANT2024.gpkg") # Resguardos indigenas formalizados en Colombia - Agencia nacional de tierras 2024
  )
  )


## Cargar insumos ####

# Este codigo maneja toda la informacion cartografica en el sistema de coordenadas WGS84 4326 https://epsg.io/4326
sf::sf_use_s2(F) # desactivar el uso de la biblioteca s2 para las operaciones geométricas esféricas. Esto optimiza algunos analisis de sf.

### Cargar area de estudio ####
studyArea<- terra::vect(input$studyArea) %>% terra::buffer(0) %>% terra::aggregate() %>% sf::st_as_sf() # se carga y se disuleve para optimizar el analisis

### Cargar áreas de manejo especial ####
list_AME<- pblapply(names(input$AME_List), function(j) st_read(input$AME_List[[j]]) %>% dplyr::mutate(type_AME=j) )

#### Corte de áreas de manejo especial por area de estudio ####
ame<- pblapply(list_AME, function(type_ame) {
  test_crop_studyArea<- type_ame  %>%  st_crop( studyArea ) 
  test_intersects_studyArea<- sf::st_intersects(studyArea, test_crop_studyArea)  %>% as.data.frame()
  ame_studyArea<- st_intersection(studyArea[unique(test_intersects_studyArea$row.id)], test_crop_studyArea[test_intersects_studyArea$col.id,]) %>%  sf::st_set_geometry("geometry")
})  %>% plyr::rbind.fill() %>% st_as_sf() %>% dplyr::group_by(type_AME) %>%
  dplyr::summarise(across(geometry, ~ sf::st_combine(.)), .groups = "keep") %>% 
  dplyr::summarise(across(geometry, ~ sf::st_union(.)), .groups = "drop")

### Cargar capas de huella ####
list_IHEH<- pblapply(input$time_IHEH_List, function(x) terra::rast(x)  )
list_IHEH<- list_IHEH[sort(names(list_IHEH))] # ordenar por año


#### Corte de capas de huella por áreas de manejo especial en area de estudio ####
list_IHEH_studyArea<- pblapply(list_IHEH, function(layerIHEH) {
  layerIHEH_studyArea<- lapply(split(ame, ame$type_AME), function(x) {terra::crop(layerIHEH, x) %>% terra::mask(ame)})
})


## Estimar huella promedio por periodo en areas de manejo especial ####
IHEH_typeAME <- pblapply(names(list_IHEH_studyArea), function(i_testArea) {
  
  huella_AME<- lapply(names(list_IHEH_studyArea[[i_testArea]]), function(y) {
    data.frame(type_AME=y, period= i_testArea, IHEH_mean= mean(terra::values(list_IHEH_studyArea[[i_testArea]][[y]], na.rm=T)))
  }) %>% plyr::rbind.fill()
    
  }) %>% plyr::rbind.fill()

print(IHEH_typeAME)

## Estimar huella proemedio por  periodo ####
IHEH_AME<- IHEH_typeAME %>% dplyr::group_by(period) %>% dplyr::summarise(IHEH_mean= as.numeric(sum(IHEH_mean, na.rm=T)))
print(IHEH_AME)

## Estimar cambio respecto al periodo anterior y tendencia ####
changeIHEH_AME<- IHEH_AME %>% dplyr::mutate(changeIHEH= NA, perc_changeIHEH= NA, trend=NA)
for(i in seq(nrow(changeIHEH_AME)) ){
if(i>1){
  changeIHEH_AME[i,"changeIHEH"]<- changeIHEH_AME[i,"IHEH_mean"]  - changeIHEH_AME[i-1,"IHEH_mean"] # estimar cambio en extension
  changeIHEH_AME[i,"perc_changeIHEH"]<-  changeIHEH_AME[i,"changeIHEH"] / changeIHEH_AME[i-1,"IHEH_mean"] # estimar cambio porcentual
  changeIHEH_AME[i,"trend"]<-  changeIHEH_AME[i,"perc_changeIHEH"] + ifelse(is.na(changeIHEH_AME[i-1,"perc_changeIHEH"]), 0, mean(unlist(changeIHEH_AME[2:i-1,"perc_changeIHEH"]), na.rm=T)) # estimar tendencia de cambio
  }
}

## Plot de cambio y tendencia ####
changeIHEH_AME_data<- changeIHEH_AME %>% dplyr::mutate(period= as.numeric(period),
                                                       perc_changeIHEH   =perc_changeIHEH   *100,
                                                       trend=trend*100) %>%
  dplyr::rename(`Promedio de IHEH`= IHEH_mean , 
                `Cambio de IHEH`= changeIHEH  ,
                Tendencia= trend, 
                Periodo= period, 
                `% de Cambio IHEH`= perc_changeIHEH )




changeIHEH_AME_plotdata<- tidyr::pivot_longer(changeIHEH_AME_data, cols = -Periodo, names_to = "variable", values_to = "value")%>% 
  dplyr::mutate(variable = factor(variable, levels=c("Periodo",       "Promedio de IHEH",  "Cambio de IHEH",   "% de Cambio IHEH", "Tendencia"  ) ))

changeIHEH_plot<- ggplot(changeIHEH_AME_plotdata, aes(x = Periodo, y = value, color = variable)) +
  geom_line(group = 1) +
  geom_point() + facet_wrap(~ variable, scales = "free_y") + 
  labs(color="", x="", y="")+
  theme_minimal()

print(changeIHEH_plot)


## Exportar resultados
# Exportar tablas

openxlsx::write.xlsx(IHEH_typeAME, file.path(output, paste0("IHEH_typeAME", ".xlsx")))
#openxlsx::write.xlsx(IHEH_AME, file.path(output, paste0("IHEH_AME", ".xlsx")))
openxlsx::write.xlsx(changeIHEH_AME_data, file.path(output, paste0("changeIHEH_AME", ".xlsx")))

# Exportar figuras
ggsave(file.path(output, paste0("results_trend", ".jpg")), changeIHEH_plot)

# exportar resultados espaciales
folder_IHEH_studyArea<- file.path(output, "IHEH_studyArea"); dir.create(folder_IHEH_studyArea)
export_rast<- pblapply(names(list_IHEH_studyArea), function(i_testArea) {
  layer<-  list_IHEH_studyArea[[i_testArea]]
  dir_layer<- file.path(folder_IHEH_studyArea,i_testArea ); dir.create(dir_layer)
  
  lapply(names(layer), function(j) {
    terra::writeRaster(layer[[j]], file.path(dir_layer, paste0(basename(folder_IHEH_studyArea),"_", i_testArea, "_", j, ".tif")), overwrite=T)
  })
  
})

