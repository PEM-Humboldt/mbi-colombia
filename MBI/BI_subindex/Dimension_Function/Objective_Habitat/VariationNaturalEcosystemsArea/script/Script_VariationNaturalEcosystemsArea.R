## Establecer parámetros de sesión ####
### Cargar librerias/paquetes necesarios para el análisis ####

#### Verificar e instalar las librerC-as necesarias ####
packagesPrev <- installed.packages()[,"Package"]  
packagesNeed <- librerias <- c("this.path", "magrittr", "dplyr", "plyr", "pbapply", "sf", "ggplot2", 
                               "tidyr",, "ggnewscale","openxlsx")  # Define los paquetes necesarios para ejecutar el codigo
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
  timeNatCoverList= list( # Lista de rutas de archivos espaciales que representan coberturas naturales en diferentes años.  Cada elemento en la lista se nombra con el año correspondiente al que representa el archivo de cobertura natural. Esto permitira ordenarlos posteriormente
    "2002"= file.path(input_folder, "covs", "CLC_natural_2002.gpkg"), # Cobertura natural del año 2002 IDEAM
    "2009"= file.path(input_folder, "covs", "CLC_natural_2009.gpkg"), # Cobertura natural del año 2008 IDEAM
    "2012"= file.path(input_folder, "covs", "CLC_natural_2012.gpkg"),  # Cobertura natural del año 2009 IDEAM
    "2018"= file.path(input_folder, "covs", "CLC_natural_2018.gpkg") # Cobertura natural del año 2018 IDEAM
  )
)


## Cargar insumos ####

# Este codigo maneja toda la informacion cartografica en el sistema de coordenadas WGS84 4326 https://epsg.io/4326
sf::sf_use_s2(F) # desactivar el uso de la biblioteca s2 para las operaciones geométricas esféricas. Esto optimiza algunos analisis de sf.

### Cargar area de estudio ####
studyArea<- terra::vect(input$studyArea) %>% terra::buffer(0) %>% terra::aggregate() %>% sf::st_as_sf() # se carga y se disuleve para optimizar el analisis

### Cargar coberturas ####
list_covs<- pblapply(input$timeNatCoverList, function(x) st_read(x))
list_covs<- list_covs[sort(names(list_covs))] # ordenar por año

#### Corte de coberturas por area de estudio ####
list_covs_studyArea<- pblapply(list_covs, function(NatCovs) {
  test_crop_studyArea<- NatCovs  %>%  st_crop( studyArea )
  test_intersects_studyArea<- sf::st_intersects(studyArea, test_crop_studyArea) %>% as.data.frame()
  NatCovs_studyArea<- st_intersection(studyArea[unique(test_intersects_studyArea$row.id)], test_crop_studyArea[test_intersects_studyArea$col.id,])
})

## Estimar area por periodo ####
area_cobsNat<- pblapply(names(list_covs_studyArea), function(i_testArea) {
  area_pol<-  list_covs_studyArea[[i_testArea]] %>% dplyr::mutate(period= i_testArea, area_km2= st_area(.) %>%  units::set_units("km2")) %>% 
    st_drop_geometry() %>% dplyr::group_by(period) %>% dplyr::summarise(area_km2= as.numeric(sum(area_km2, na.rm=T)))
  area_pol
  }) %>% plyr::rbind.fill()

## Estimar cambio respecto al periodo anterior y tendencia ####
changeArea_cobsNat<- area_cobsNat %>% dplyr::mutate(changeArea= NA, perc_changeArea= NA, trend=NA)

for(i in seq(nrow(changeArea_cobsNat)) ){
if(i>1){
  changeArea_cobsNat[i,"changeArea"]<- changeArea_cobsNat[i,"area_km2"]  - changeArea_cobsNat[i-1,"area_km2"] # estimar cambio en extension
  changeArea_cobsNat[i,"perc_changeArea"]<-  changeArea_cobsNat[i,"changeArea"] / changeArea_cobsNat[i-1,"area_km2"] # estimar cambio porcentual
  changeArea_cobsNat[i,"trend"]<-  changeArea_cobsNat[i,"perc_changeArea"] + ifelse(is.na(changeArea_cobsNat[i-1,"perc_changeArea"]), 0, mean(changeArea_cobsNat[2:(i-1),"perc_changeArea"], na.rm=T)) # estimar tendencia de cambio
  }
}

## Plot de cambio y tendencia ####
changeArea_cobsNat_data<- changeArea_cobsNat %>% dplyr::mutate(period= as.numeric(period))

changeArea_cobsNat_plotdata<- tidyr::pivot_longer(changeArea_cobsNat_data, cols = -period, names_to = "variable", values_to = "value")

changeArea_plot<- ggplot(changeArea_cobsNat_plotdata, aes(x = period, y = value, color = variable)) +
  geom_line(group = 1) +
  geom_point() +
  facet_wrap(~ variable, scales = "free_y") +
  theme_minimal()+
  theme(text = ggplot2::element_text(size = 8))
print(changeArea_plot)



## Exportar resultados ####
# Exportar tablas
openxlsx::write.xlsx(area_cobsNat, file.path(output, paste0("area_cobsNat", ".xlsx")))
openxlsx::write.xlsx(changeArea_cobsNat, file.path(output, paste0("changeArea_cobsNat", ".xlsx")))
# Exportar figuras
ggsave(file.path(output, paste0("results_trend", ".jpg")), changeArea_plot)




