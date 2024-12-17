## Establecer parámetros de sesión ####
### Cargar librerias/paquetes necesarios para el análisis ####

#### Verificar e instalar las librerC-as necesarias ####
packagesPrev <- installed.packages()[,"Package"]  
packagesNeed <- librerias <- c("this.path", "magrittr", "dplyr", "plyr", "pbapply", "data.table", "raster", "terra", "sf", "ggplot2", 
                               "tidyr", "RColorBrewer", "reshape2", "ggnewscale","openxlsx", "ggspatial",
                               "future", "future.apply", "progressr", "lwgeom")  # Define los paquetes necesarios para ejecutar el codigo
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
  studyArea= file.path(input_folder, "studyArea", "ColombiaDeptos.gpkg"),  # Ruta del archivo espacial que define el área de estudio
  timeNatCoverList= list( # Lista de rutas de archivos espaciales que representan coberturas naturales en diferentes años.  Cada elemento en la lista se nombra con el año correspondiente al que representa el archivo de cobertura natural. Esto permitira ordenarlos posteriormente
    "2002"= file.path(input_folder, "covs", "CLC_natural_2002.gpkg"), # Cobertura natural del año 2002 IDEAM
    "2009"= file.path(input_folder, "covs", "CLC_natural_2009.gpkg"), # Cobertura natural del año 2008 IDEAM
    "2012"= file.path(input_folder, "covs", "CLC_natural_2012.gpkg"),  # Cobertura natural del año 2009 IDEAM
    "2018"= file.path(input_folder, "covs", "CLC_natural_2018nc.gpkg"), # Cobertura natural del año 2018 IDEAM
    "2020"= file.path(input_folder, "covs", "CLC_natural_2020nc.gpkg") # Cobertura natural del año 2020 IDEAM
  ),
  StratEcoSystemList= list( # Lista de rutas de archivos espaciales que representan ecosistemas estrategicos.
    "Manglar"= file.path(input_folder, "strategicEcosystems", "Biom_MFW_Manglar1.shp"), # Biomas asociados a manglar
    "Paramo"= file.path(input_folder, "strategicEcosystems", "paramos_Etter.shp"), # Biomas asociados a Paramo
    "BosqueSeco"= file.path(input_folder, "strategicEcosystems", "BosqueSecoTropical_100K.shp"), # Biomas asociados a BosqueSeco
    "BosqueHumedo"= file.path(input_folder, "strategicEcosystems", "Bioms_BosqueHumedo.gpkg") # Biomas asociados a BosqueHumedo
  )
)


## Cargar insumos ####

# Este codigo maneja toda la informacion cartografica en el sistema de coordenadas WGS84 4326 https://epsg.io/4326
sf::sf_use_s2(F) # desactivar el uso de la biblioteca s2 para las operaciones geométricas esféricas. Esto optimiza algunos analisis de sf.

### Cargar area de estudio ####
studyArea<- terra::vect(input$studyArea) %>% terra::buffer(0) %>% terra::aggregate() %>% sf::st_as_sf() # se carga y se disuleve para optimizar el analisis

### Cargar ecosistemas estrategicos ####
list_strategic<- pblapply(names(input$StratEcoSystemList), function(j) st_read(input$StratEcoSystemList[[j]]) %>% dplyr::mutate(ZonaEcos=j) )


# corregir  proyección de ser necesario

SisRef <- 4326 # sistema de referencia necesario

Proyectar<-function(capa){
  
  if (st_crs(capa)$epsg != st_crs(SisRef)) {
    print(st_crs(capa)$epsg != SisRef)
    capa<- st_transform(capa, crs= SisRef)
    
  } else 
    return(capa)
}

list_strategic <- lapply(list_strategic, Proyectar)

#### Corte de ecosistemas estrategicos por area de estudio ####
strategic_ecosystems<- pblapply(list_strategic, function(eco_strategic) {
  test_crop_studyArea<- eco_strategic  %>%  st_crop( studyArea ) 
  test_intersects_studyArea<- sf::st_intersects(studyArea, test_crop_studyArea)  %>% as.data.frame()
  strategics_studyArea<- st_intersection(studyArea[unique(test_intersects_studyArea$row.id)], test_crop_studyArea[test_intersects_studyArea$col.id,]) %>%  sf::st_set_geometry("geometry")
})  %>% plyr::rbind.fill() %>% st_as_sf() %>% dplyr::group_by(ZonaEcos) %>%
  dplyr::summarise(across(geometry, ~ sf::st_combine(.)), .groups = "keep") %>% 
  dplyr::summarise(across(geometry, ~ sf::st_union(.)), .groups = "drop")

### Cargar coberturas ####
list_covs<- pblapply(input$timeNatCoverList, function(x) st_read(x)  )
list_covs<- list_covs[sort(names(list_covs))] # ordenar por año

#### Corte de coberturas por ecosistemas estrategicos en area de estudio ####
list_covs_studyArea<- pblapply(list_covs, function(NatCovs) {
  test_crop_studyArea<- NatCovs  %>%  st_crop( strategic_ecosystems ) %>% sf::st_set_geometry("geometry") %>%   dplyr::summarise(across(geometry, ~ sf::st_combine(.)), .groups = "keep") %>%  dplyr::summarise(across(geometry, ~ sf::st_union(.)), .groups = "drop") 
  test_intersects_studyArea<- sf::st_intersects(strategic_ecosystems, test_crop_studyArea) %>% as.data.frame()
  NatCovs_studyArea<- sf::st_intersection(strategic_ecosystems[unique(test_intersects_studyArea$row.id),], test_crop_studyArea[unique(test_intersects_studyArea$col.id),])
})


## Estimar area de cobertura natural por ecosistema - periodo ####
area_cobsNat_ecosystem <- pblapply(names(list_covs_studyArea), function(i_testArea) {
  area_pol<-  list_covs_studyArea[[i_testArea]] %>% dplyr::mutate(period= i_testArea, area_km2= st_area(.) %>%  units::set_units("km2")) %>% 
    st_drop_geometry() %>% dplyr::group_by(ZonaEcos, period) %>% dplyr::summarise(area_km2= as.numeric(sum(area_km2, na.rm=T)))
  area_pol
  }) %>% plyr::rbind.fill()

print(area_cobsNat_ecosystem)

## Estimar area de cobertura natural por  periodo ####
area_cobsNat<- area_cobsNat_ecosystem %>% dplyr::group_by(period) %>% dplyr::summarise(area_km2= as.numeric(sum(area_km2, na.rm=T)))
print(area_cobsNat)

## Estimar cambio respecto al periodo anterior y tendencia ####
changeArea_cobsNat<- area_cobsNat %>% dplyr::mutate(changeArea= NA, perc_changeArea= NA, trend=NA)
for(i in seq(nrow(changeArea_cobsNat)) ){
if(i>1){
  changeArea_cobsNat[i,"changeArea"]<- changeArea_cobsNat[i,"area_km2"]  - changeArea_cobsNat[i-1,"area_km2"] # estimar cambio en extension
  changeArea_cobsNat[i,"perc_changeArea"]<-  changeArea_cobsNat[i,"changeArea"] / changeArea_cobsNat[i-1,"area_km2"] # estimar cambio porcentual
  changeArea_cobsNat[i,"trend"]<-  changeArea_cobsNat[i,"perc_changeArea"] + ifelse(is.na(changeArea_cobsNat[i-1,"perc_changeArea"]), 0, mean(unlist(changeArea_cobsNat[2:i-1,"perc_changeArea"]), na.rm=T)) # estimar tendencia de cambio
  }
}

## Plot de cambio y tendencia ####

changeArea_cobsNat_data<- changeArea_cobsNat %>% dplyr::mutate(period= as.numeric(period),
                                                               perc_changeArea=perc_changeArea*100,
                                                               trend=trend*100) %>%
  dplyr::rename(`% Cambio Area`= perc_changeArea, 
                `Cambio de Área`= changeArea   ,
                Tendencia= trend, 
                Periodo= period, 
                `Área km^2`= area_km2)

changeArea_cobsNat_plotdata<- tidyr::pivot_longer(changeArea_cobsNat_data, cols = -Periodo, names_to = "variable", values_to = "value") %>% 
  dplyr::mutate(variable = factor(variable, levels=c("Periodo",       "Área km^2",  "Cambio de Área",   "% Cambio Area", "Tendencia"  ) ))

changeArea_plot<- ggplot(changeArea_cobsNat_plotdata, aes(x = Periodo, y = value, color = variable)) +
  geom_line(group = 1) +
  geom_point() +
  facet_wrap(~ variable, scales = "free_y") +
  labs(color="", x="", y="")+
  theme_minimal()+
  theme(text = ggplot2::element_text(size = 8))
print(changeArea_plot)

ggplot(area_cobsNat_ecosystem)+
  geom_line(aes(x=period, y=area_km2,group=ZonaEcos,col=ZonaEcos))

ggplot(filter(area_cobsNat_ecosystem, ZonaEcos!="BosqueHumedo"))+
  geom_line(aes(x=period, y=area_km2,group=ZonaEcos,col=ZonaEcos))


## Exportar resultados ####
# Exportar tablas
openxlsx::write.xlsx(area_cobsNat_ecosystem, file.path(output, paste0("area_cobsNat_ecosystem", ".xlsx")))
openxlsx::write.xlsx(area_cobsNat, file.path(output, paste0("area_cobsNat", ".xlsx")))
openxlsx::write.xlsx(changeArea_cobsNat_data, file.path(output, paste0("changeArea_cobsNat", ".xlsx")))

# Exportar figuras
ggsave(file.path(output, paste0("results_trend", ".jpg")), changeArea_plot)

# exportar resultados espaciales
folder_cobsNat_ecosystem<- file.path(output, "cobsNat_ecosystem"); dir.create(folder_cobsNat_ecosystem)
export_pol<- pblapply(names(list_covs_studyArea), function(i_testArea) {
  pol<-  list_covs_studyArea[[i_testArea]]
  sf::st_write(pol, file.path(folder_cobsNat_ecosystem, paste0(basename(folder_cobsNat_ecosystem), "_", i_testArea, ".gpkg")), delete_dsn=T)
})

