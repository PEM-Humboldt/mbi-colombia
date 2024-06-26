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
  studyArea= file.path(input_folder, studyArea, "ColombiaDeptos.shp"),  # Ruta del archivo espacial que define el área de estudio
  timeNatCoverList= list( # Lista de rutas de archivos espaciales que representan coberturas naturales en diferentes años.  Cada elemento en la lista se nombra con el año correspondiente al que representa el archivo de cobertura natural. Esto permitira ordenarlos posteriormente
    "2002"= file.path(input_folder, covs, "CLC_natural_2002.shp"), # Cobertura naturalCLCdel año 2002
    "2009"= file.path(input_folder, covs, "CLC_natural_2002.shp"), # Cobertura natural del año 2009
    "2008"= file.path(input_folder, covs, "CLC_natural_2002.shp"),  # Cobertura natural del año 2008
    "2017"= file.path(input_folder, covs, "CLC_natural_2002.shp") # Cobertura natural del año 2017
      )
  )


## Cargar insumos ####

# Este codigo maneja toda la informacion cartografica en el sistema de coordenadas WGS84 4326 https://epsg.io/4326
sf::sf_use_s2(F) # desactivar el uso de la biblioteca s2 para las operaciones geométricas esféricas. Esto optimiza algunos analisis de sf.

### Cargar area de estudio ####
studyArea<- sf::st_read(input$studyArea)

### Cargar coberturas ####
list_covs<- pblapply(input$timeNatCoverList, function(x) st_read(x))

## Cortar coberturas naturales por área de estudio ####
list_covs_studyArea<- pblapply(list_covs, function(NatCovs) {
  test_crop_StudyArea<- NatCovs  %>%  st_crop( StudyArea )
  test_intersects_StudyArea<- sf::st_intersects(StudyArea, test_crop_StudyArea) %>% as.data.frame()
  NatCovs_StudyArea<- st_intersection(StudyArea[unique(test_intersects_StudyArea$row.id)], test_crop_StudyArea[test_intersects_StudyArea$col.id,]) %>% dplyr::select(BIOMA_IAvH)
})


## Estimar area por periodo ####
area_cobsNat<- pblapply(names(list_covs_studyArea), function(i_testArea) {
 
  area_pol<-  list_covs_studyArea[[i_testArea]] %>% dplyr::mutate(period= i_testArea, area_km2= st_area(.) %>%  units::set_units("km2")) %>% 
    st_drop_geometry()
  
  area_pol
  
  }) %>% plyr::rbind.fill()















# Cargar insumos BASE ####
## Este codigo maneja toda la informacion cartografica en el sistema de coordenadas WGS84 4326 https://epsg.io/4326

sf::sf_use_s2(F) # desactivar el uso de la biblioteca s2 para las operaciones geomC)tricas esfC)ricas. Esto optimiza algunos analisis de sf.

## Insumos cartograficos ####
BiomaIAvH<- st_read(input$Bioma_IAvH)
redlist_ecos<- terra::rast(input$redlist_ecos)
PuntosCalor<- st_read(input$PuntosCalor)
IGAC_Deptos<- st_read(input$IGAC_Deptos)

## Insumos Biomodelos ####

### Cargar Biomodelos Stack ####
Biomodelos_files<- list.files(input$biomodelos_folder, recursive = T, pattern  = "\\.tif$", full.names = T)
Biomodelos_data<- data.frame(path= Biomodelos_files) %>%  dplyr::mutate(scientificName= sapply(.$path, function(x) strsplit(gsub("_", " ", tools::file_path_sans_ext(basename(x))), " ")[[1]] %>% {paste(.[1], .[2])} ))

Biomodelos_metadata<- data.table::fread(input$biomodelos_metadata)
Biomodelos_metadata2<- list(Biomodelos_metadata, Biomodelos_data) %>% plyr::join_all()

Biomodelos_stack<- terra::rast(Biomodelos_metadata2$path) %>% setNames(Biomodelos_metadata2$scientificName)

### Cargar Biomodelos Registros ####
Biomodelos_records<- data.table::fread(input$Biomodelos_records)

#### Espacializar Biomodelos registros
Biomodelos_records_spatial<- dplyr::distinct(Biomodelos_records) %>% st_as_sf(coords = c("record_lon", "record_lat"), crs = 4326)

raster_records_base<- terra::rast(Biomodelos_stack[[1]]) %>% setNames("cell") %>% terra::setValues(seq(ncell(.)))
Biomodelos_records_spatial$cell<- terra::extract(raster_records_base, Biomodelos_records_spatial, xy= F) %>% as.data.frame() %>% {.$cell}
Biomodelos_records_spatial2<- dplyr::filter(Biomodelos_records_spatial, !is.na(cell))
Biomodelos_records_spatial_data<- st_drop_geometry(Biomodelos_records_spatial2)

# Generar mapa base ####
map_base_plot<- ggplot() + 
  geom_sf(data = IGAC_Deptos, fill = NA, aes(color = "Departamentos"), alpha= 0.5, size = 0.1) + 
  scale_color_manual("Limite administrativo", values = c("Departamentos" = "black"))+
  theme_void()+
  theme(
    plot.background=element_rect( color =  "gray", size= 0.5),
    panel.grid.major = element_line(color = "gray", linetype = 2, size= 0.2),
    legend.margin = margin(r = 5, unit = "mm"),
    text = element_text(size = 6),
    legend.text = element_text(size = 6),
    legend.title = element_text(size = 6)
  )


# Ejemplo - Analisis Individual -  Antioquia ####

## Delimitar area de estudio -  Antioquia ####
studyarea<- dplyr::filter(IGAC_Deptos, Depto %in% "Antioquia")

## Definir carpeta donde se guardan los resultados ####
name_StudyArea<- unique(studyarea$Depto)[1] ########### Aca va el nombre del folder donde se guardaran los resultados, en este ejemplo por defecto el poligono de analisis depto
dir_folder_out<- file.path(output, name_StudyArea); dir.create(dir_folder_out)



## Corte por area de estudio ####
area_analysis<- studyarea  %>% terra::vect() %>% terra::aggregate() %>% st_as_sf() # dissolve corregir geometrias
extent_analysis<- extent(area_analysis)

PuntosCalor_filter<- PuntosCalor %>% sf::st_crop(area_analysis) %>% st_intersection(area_analysis) %>%
  dplyr::mutate( as.data.frame(sf::st_coordinates(.))) %>% dplyr::select(c("X", "Y")) %>% dplyr::distinct() %>% 
  dplyr::mutate(id_point = as.numeric(as.factor(paste(X, Y, sep = "-"))))


## Plot de puntos de calor ####
PuntosCalor_plot<- map_base_plot+
   geom_sf(data= PuntosCalor_filter, aes(colour= "Puntos de calor"), size= 0.1)+
   scale_color_manual(name = "", values = c("Puntos de calor" = "red"))+
coord_sf(xlim= c(extent_analysis[1], extent_analysis[2]),  
         ylim = c(extent_analysis[3], extent_analysis[4]))

print(PuntosCalor_plot)

## Plot densidad de puntos de calor ####
### Estimar densidad ####
densidad <- kde2d(x = PuntosCalor_filter$X, y = PuntosCalor_filter$Y, n = input$n_density, 
                  lims=c(extent(area_analysis)[1:2], extent(area_analysis)[3:4]) ) # n controla la resoluciC3n
raster_densidad <- raster(densidad) 
raster_densidad_calor<- terra::mask(terra::rast(raster_densidad), terra::rast(fasterize::fasterize(area_analysis, raster_densidad)))
raster_densidad_calor2<- raster_densidad_calor       

### Estimar cuantiles ####
valores <- values(raster_densidad_calor)[,1,drop= T] %>% na.omit()   # A
cuantiles <- quantile(valores, probs = seq(0, 1, 0.20), type= 7)
categorias_cuantiles <- cut(valores, breaks = unique(cuantiles), include.lowest = F, labels = FALSE) %>% unlist()

if(length(unique(na.omit(categorias_cuantiles))) == 1){
  categorias_cuantiles[!is.na(categorias_cuantiles)]<- 4
  cuantiles[4]<-max(cuantiles)
}

### Mapa por cuantiles ####

df_raster <- xyFromCell(raster_densidad_calor, cell = cells(raster_densidad_calor)) %>% as.data.frame() %>% 
  dplyr::mutate(values= valores, cell = cells(raster_densidad_calor), Cuantil = categorias_cuantiles)

raster_cuantiles_coltab<- data.frame(value= 2:5, cuantil_val= cuantiles[2:5],  label= c("Baja", "Media", "Alta", "Muy Alta"),
                                     col= c("#95C768", "#FFFFBF", "#fdae61", "#BA1414"))

raster_cuantiles<- terra::rast(raster_densidad_calor)
raster_cuantiles[df_raster$cell]<- df_raster$Cuantil
raster_densidad_calor[raster_cuantiles==1]<- NA; raster_cuantiles[raster_cuantiles==1]<- NA

raster_cuantiles_aes<- raster_cuantiles
levels(raster_cuantiles_aes)<- dplyr::select(raster_cuantiles_coltab, c("value", "label"))
coltab(raster_cuantiles_aes)<- dplyr::select(raster_cuantiles_coltab, c("value", "col"))

map_densidad_q_calor<- map_base_plot+
  guides(color = "none") + ggnewscale::new_scale_fill()+
  geom_spatraster(data=raster_cuantiles_aes)+
  labs(fill = "Frecuencia de\npuntos de calor\n(quintiles)")+
  coord_sf(xlim= c(extent_analysis[1], extent_analysis[2]), ylim = c(extent_analysis[3], extent_analysis[4]) )


map_densidad_calor<-    map_base_plot +   guides(color = "none")+ ggnewscale::new_scale_fill()+
  stars::geom_stars(data=  stars::st_as_stars(raster_densidad_calor2))+
  scale_fill_gradientn("Densidad de\npuntos de calor\n(Kernel - res 350 m)", na.value = NA,
                       colours = raster_cuantiles_coltab$col,
                       values= scales::rescale(raster_cuantiles_coltab$cuantil_val),
                       limits = c(min(raster_cuantiles_coltab$cuantil_val, na.rm = TRUE), max(cuantiles, na.rm = TRUE)),
                       oob = scales::oob_squish, 
                       guide = guide_colorbar(order = 1, frame.colour = "black", ticks.colour = "black")
  )+
  coord_sf(xlim= c(extent_analysis[1], extent_analysis[2]), ylim = c(extent_analysis[3], extent_analysis[4]) )

comp_map_density<- ggarrange(plotlist = list(map_densidad_q_calor, map_densidad_calor), nrow = 1, ncol=2)




##  Analisis de puntos por bioma ####

## Corte de bioma por area de estudio ####
test_crop_area_analysis<- BiomaIAvH  %>%  st_crop( area_analysis )
test_intersects_area_analysis<- sf::st_intersects(area_analysis, test_crop_area_analysis) %>% as.data.frame()
BiomaIAvH_area_analysis<- st_intersection(area_analysis[unique(test_intersects_area_analysis$row.id)], test_crop_area_analysis[test_intersects_area_analysis$col.id,]) %>% dplyr::select(BIOMA_IAvH)

### Area de bioma por area de estudio ####
BiomaIAvH_area_data<-BiomaIAvH_area_analysis %>% dplyr::mutate(area= st_area(.) %>%  units::set_units("km2")) %>% st_drop_geometry()  %>%  dplyr::group_by(BIOMA_IAvH) %>% dplyr::summarise(area= sum(area))
BiomaIAvH_area_analysis_v2<- list(as.data.frame(BiomaIAvH_area_analysis), BiomaIAvH_area_data) %>% plyr::join_all() %>% st_as_sf()


### Puntos de calor por bioma ####
test_biom<- st_intersects( PuntosCalor_filter, BiomaIAvH_area_analysis) %>% as.data.frame()
BiomaIAvH_puntos<- PuntosCalor_filter %>% dplyr::mutate(BIOMA_IAvH= st_drop_geometry(BiomaIAvH_area_analysis_v2)[test_biom$col.id,"BIOMA_IAvH"])
BiomaIAvH_puntos$cell <- terra::extract( raster_records_base, BiomaIAvH_puntos, xy=T)$cell 

#### Proporcion de puntos de calor por bioma ####
BiomaIAvH_puntos_data <-BiomaIAvH_puntos %>% st_drop_geometry() %>% dplyr::group_by(BIOMA_IAvH) %>%
  dplyr::summarise(n_points_calor = n()) %>% dplyr::mutate(prop_puntos_total = n_points_calor/ sum(.$n_points_calor)) %>% dplyr::arrange(-prop_puntos_total)
BiomaIAvH_puntos_summary<- list(BiomaIAvH_puntos_data,BiomaIAvH_area_data) %>% plyr::join_all() %>% dplyr::mutate(area_km2= as.numeric(area)) %>% dplyr::mutate(density_points_km2= n_points_calor/ area_km2) %>% dplyr::select(-area)
BiomaIAvH_puntos_summary_density<- BiomaIAvH_puntos_summary %>% st_drop_geometry()  %>%   dplyr::select(c("BIOMA_IAvH", "area_km2", "density_points_km2")) %>% dplyr::arrange(-density_points_km2)

BiomaIAvH_puntos_data_export<- BiomaIAvH_puntos_data %>% setNames(c("Bioma IAvH", "No. de puntos de calor", "Prop. de puntos")) %>% as.data.frame()
BiomaIAvH_puntos_summary_export<- BiomaIAvH_puntos_summary_density %>%  setNames(c("Bioma IAvH", "Crea (km2)", "Densidad de puntos por C!rea")) %>% as.data.frame()


#### Mapa de proporcion de puntos por bioma respecto al total de puntos en el area de estudio ####

BiomaIAvH_puntos_summary_sf<- list(as.data.frame(BiomaIAvH_area_analysis_v2), BiomaIAvH_puntos_summary) %>% plyr::join_all() %>% dplyr::mutate(across(where(is.numeric), ~replace_na(., 0))) %>% st_as_sf()
BiomaIAvH_puntos_summary_data<- st_drop_geometry(BiomaIAvH_puntos_summary_sf)

map_prop_puntos_Bioma_IAvH<-  map_base_plot + 
  guides(color = "none")+
  ggnewscale::new_scale_fill()+
  geom_sf(data= BiomaIAvH_puntos_summary_sf %>% dplyr::filter(prop_puntos_total>0), aes( fill = prop_puntos_total), color= NA, alpha= 0.8) +
  coord_sf(xlim= c(extent_analysis[1], extent_analysis[2]), 
           ylim = c(extent_analysis[3], extent_analysis[4]) )+
  scale_fill_gradientn( "DistribuciC3n porcentual\nrelativa de puntos de\ncalor por bioma" , colours = raster_cuantiles_coltab$col, guide = guide_colorbar(order = 2, override.aes = list(size = 3), frame.colour = "black", ticks.colour = "black") )

#### Mapa de densidad de puntos por area km del area de estudio ####
map_dens_puntos_area_Bioma<-     map_base_plot + ggnewscale::new_scale_fill()+
  geom_sf(data= BiomaIAvH_puntos_summary_sf %>% dplyr::filter(prop_puntos_total>0), aes( fill = density_points_km2), color= NA, alpha= 0.8) +
  coord_sf(xlim= c(extent_analysis[1], extent_analysis[2]), 
           ylim = c(extent_analysis[3], extent_analysis[4]) )+
  scale_fill_gradientn("Densidad por C!rea(km2)\nde puntos de\ncalor por bioma", colors = rev(brewer.pal(n = 11, name = "RdYlGn")), guide = guide_colorbar(order = 1, override.aes = list(size = 3), frame.colour = "black", ticks.colour = "black"))


#### Mapa compilado de puntos de calor ####

map_compiled_densidad_calor<- ggarrange(plotlist = 
                                          list(map_densidad_q_calor,
                                               map_densidad_calor,
                                               map_prop_puntos_Bioma_IAvH,
                                               map_dens_puntos_area_Bioma), ncol = 2, nrow =  2, align =  "v" , common.legend = F) 

print(map_compiled_densidad_calor)






##  AnC!lisis de biodiversidad (BIOMODELOS) por puntos de calor ####

### Riqueza de especies ####

#### Riqueza de especies a partir de registros ####
records_matriz_area<- terra::extract( raster_records_base, PuntosCalor_filter) %>%  dplyr::mutate(id_point= PuntosCalor_filter$id_point)
records_data_area<- records_matriz_area %>% list(Biomodelos_records_spatial_data) %>% 
  plyr::join_all() %>% dplyr::filter(!is.na(scientificName)) %>% dplyr::select(-c( "ID")) %>% dplyr::mutate(variable= "biomodelos_records")
biomodelos_data_record<- list(as.data.frame(BiomaIAvH_puntos), records_data_area, Biomodelos_metadata) %>% 
  plyr::join_all()

##### Riqueza de especies con registros  - por Bioma ####
records_bioma_summary_sp<- st_drop_geometry(biomodelos_data_record) %>% dplyr::group_by(BIOMA_IAvH) %>%
  dplyr::summarise(n_species_records_bioma = n_distinct(scientificName))

records_bioma_summary_sp_uicn<- st_drop_geometry(biomodelos_data_record) %>% dplyr::filter(threatStatus_UICN %in% c("EN", "CR", "VU")) %>% 
  dplyr::group_by(BIOMA_IAvH) %>% dplyr::summarise(n_species_uicn_records_bioma = n_distinct(scientificName))

## Registros en zonas con puntos de calor
species_records_bioma<- dplyr::filter(biomodelos_data_record, !is.na(scientificName))

BiomaIAvH_richness_summary_sf<- list( as.data.frame(BiomaIAvH_puntos_summary_sf),
                                      records_bioma_summary_sp,
                                      records_bioma_summary_sp_uicn ) %>% plyr::join_all() %>% st_as_sf()


##### Plot Riqueza de especies con registros  - por Bioma #####
map_richness_sp_records_Bioma <-    map_base_plot + 
  ggnewscale::new_scale_fill()+
  geom_sf(data= BiomaIAvH_richness_summary_sf, aes( fill = n_species_records_bioma),
          color= NA, alpha= 0.8) +
  scale_fill_gradientn("No. especies registradas\npor Bioma con puntos\nde calor\n(registros historicos)", colors = brewer.pal(n = 11, name = "Blues"), 
                       na.value= NA, guide = guide_colorbar(order = 1, frame.colour = "black", ticks.colour = "black"))+
  coord_sf(xlim= c(extent_analysis[1], extent_analysis[2]), 
           ylim = c(extent_analysis[3], extent_analysis[4]) ) +
  ggnewscale::new_scale_color()+
  geom_point(data= species_records_bioma, aes(x=X, y=Y, color= "purple"), size= 0.8,
             alpha= 0.8, shape= 17)+
  scale_color_manual("", values = c("purple" = "purple"), labels= "Registros historicos\nen zonas de puntos\nde calor", guide = guide_legend(order = 2, override.aes = list(size = 3)))



#### Riqueza de especies con modelos  - por Bioma ####
biomodelos_matriz_area<- terra::extract(Biomodelos_stack, PuntosCalor_filter, xy= T) %>% dplyr::select(-"ID") 
biomodelos_presencia <- biomodelos_matriz_area  %>% dplyr::mutate(id_point= PuntosCalor_filter$id_point) %>%
  melt(id.vars = c("id_point"), variable.name = "scientificName") %>% dplyr::filter(value > 0) %>% dplyr::filter(!is.na(scientificName)) %>% dplyr::select(-value) %>% 
  dplyr::mutate(variable= "biomodelos_map")
biomodelos_data_model<- list(as.data.frame(BiomaIAvH_puntos), biomodelos_presencia, Biomodelos_metadata) %>% 
  plyr::join_all() 

models_bioma_summary_sp<- st_drop_geometry(biomodelos_data_model) %>% dplyr::group_by(BIOMA_IAvH) %>%
  dplyr::summarise(n_species_models_bioma = n_distinct(scientificName))

models_bioma_summary_sp_uicn<- st_drop_geometry(biomodelos_data_model) %>% dplyr::filter(threatStatus_UICN %in% c("EN", "CR", "VU")) %>% 
  dplyr::group_by(BIOMA_IAvH) %>% dplyr::summarise(n_species_uicn_models_bioma = n_distinct(scientificName))

species_models_bioma<- dplyr::filter(biomodelos_data_model, !is.na(scientificName))

BiomaIAvH_richness_summary_model_sf<- list( as.data.frame(BiomaIAvH_richness_summary_sf),
                                            models_bioma_summary_sp,
                                            models_bioma_summary_sp_uicn
) %>% plyr::join_all() %>%  st_as_sf()

##### Plot Riqueza de especies con modelos  - por Bioma #####
map_richness_sp_models_Bioma <-    map_base_plot + 
  guides(color = "none")+
  ggnewscale::new_scale_fill()+
  geom_sf(data= BiomaIAvH_richness_summary_model_sf, aes( fill = n_species_models_bioma),
          color= NA, alpha= 0.8) +
  scale_fill_gradientn("Riqueza estimada de\nespecies por Bioma en\nzonas de puntos de calor\n(Mapas de distribuciC3n)", colors = brewer.pal(n = 11, name = "Blues"), 
                       na.value= NA, guide = guide_colorbar(order = 1, frame.colour = "black", ticks.colour = "black"))+
  coord_sf(xlim= c(extent_analysis[1], extent_analysis[2]), 
           ylim = c(extent_analysis[3], extent_analysis[4]) ) +
  ggnewscale::new_scale_color()



#### Densidad Riqueza de especies con modelos  - por Bioma #####

data_coords_richness<- biomodelos_data_model %>% dplyr::group_by(id_point) %>% dplyr::summarise(n= n_distinct(scientificName))

richness_density_plot<- ggplot(data_coords_richness, aes(x = n)) +
  geom_density(fill = "blue", alpha = 0.5, bw = 0.5, color= NA) +
  labs(x = "Riqueza de especies estimada (Mapas de distribuciC3n)", y = "Densidad de\npuntos de calor") +
  annotate("text", size=3, x = -Inf, y = Inf, hjust= 0, vjust= 1,
           label =  paste0("N= ",  unique(nrow(data_coords_richness)), "\nBanwidth= 0.5") ) +
  theme_minimal()+
  theme(
    text = element_text(size = 6),
    axis.text.y = element_text(angle = 90)
  )


#### Plot compilado Riqueza de especies  - por Bioma #####
map_compiled_richness_sp<- ggarrange(plotlist =  list(richness_density_plot,
                                                      ggarrange(plotlist = list(map_richness_sp_models_Bioma,
                                                                                map_richness_sp_records_Bioma),
                                                                ncol = 2, nrow = 1, common.legend = F, align = "h")),
                                     nrow = 2, heights  = c(1/3, 2/3)
)

print(map_compiled_richness_sp)



## Riqueza de sp amenazadas ####

##### Plot Riqueza de sp amenazadas con registros  - por Bioma #####
species_records_bioma_UICN<- species_records_bioma %>%  dplyr::filter(threatStatus_UICN %in% c("EN", "CR", "VU")) 

map_richnessUICN_sp_records_Bioma <-    map_base_plot + 
  guides(color = "none")+
  ggnewscale::new_scale_fill()+
  geom_sf(data= BiomaIAvH_richness_summary_sf, aes( fill = n_species_uicn_records_bioma),
          color= NA, alpha= 0.8) +
  scale_fill_gradientn("No. especies amenazadas\nregistradas por Bioma con\n puntos de calor\n(registros historicos)", colors = brewer.pal(n = 11, name = "Reds"), 
                       na.value= NA, guide = guide_colorbar(order = 1, frame.colour = "black", ticks.colour = "black"))+
  coord_sf(xlim= c(extent_analysis[1], extent_analysis[2]), 
           ylim = c(extent_analysis[3], extent_analysis[4]) ) +
  ggnewscale::new_scale_color()+
  geom_point(data= species_records_bioma_UICN, aes(x=X, y=Y, color= "brown"), size= 0.8,
             alpha= 0.8, shape= 17)+
  scale_color_manual("", values = c("brown" = "purple"), labels= "Registros historicos de\nespecies amenazadas\nen zonas de puntos\nde calor", guide = guide_legend(order = 2, override.aes = list(size = 3)))


##### Plot Riqueza de sp amenazadas con modelos  - por Bioma #####
map_richnessUICN_sp_models_Bioma <-    map_base_plot + 
  guides(color = "none")+
  ggnewscale::new_scale_fill()+
  geom_sf(data= BiomaIAvH_richness_summary_model_sf, aes( fill = n_species_uicn_models_bioma),
          color= NA, alpha= 0.8) +
  scale_fill_gradientn("Riqueza estimada de\nespecies amenazadas por\nBioma con puntos de calor\n(Mapas de distribuciC3n)", colors = brewer.pal(n = 11, name = "Reds"), 
                       na.value= NA, guide = guide_colorbar(order = 1, frame.colour = "black", ticks.colour = "black"))+
  coord_sf(xlim= c(extent_analysis[1], extent_analysis[2]), 
           ylim = c(extent_analysis[3], extent_analysis[4]) ) +
  ggnewscale::new_scale_color()


#### Densidad Riqueza de sp amenazadas con modelos  - por Bioma #####
data_coords_richnessUICN<- biomodelos_data_model %>% dplyr::filter(threatStatus_UICN %in% c("EN", "CR", "VU")) %>%
  dplyr::group_by(id_point) %>% dplyr::summarise(n= n_distinct(scientificName))

richnessUICN_density_plot<- ggplot(data_coords_richnessUICN, aes(x = n)) +
  geom_density(fill = "red", alpha = 0.6, bw = 0.5, color= NA) +
  labs(x = "Riqueza estimada de de especies amenazadas (Mapas de distribuciC3n)", y = "Densidad de\npuntos de calor") +
  annotate("text", size=3, x = -Inf, y = Inf, hjust= 0, vjust= 1,
           label =  paste0("N= ",  unique(nrow(data_coords_richnessUICN)), "\nBanwidth= 0.5") ) +
  theme_minimal()+
  theme(
    text = element_text(size = 6),
    axis.text.y = element_text(angle = 90)
  )


#### Plot compilado Riqueza de sp amenazadas  - por Bioma #####
map_compiled_richnessUICN_sp<- ggarrange(plotlist =  list(richnessUICN_density_plot,
                                                          ggarrange(plotlist = list(map_richnessUICN_sp_records_Bioma,
                                                                                    map_richnessUICN_sp_models_Bioma),
                                                                    ncol = 2, nrow = 1, common.legend = F, align = "h")),
                                         nrow = 2, heights  = c(1/3, 2/3)
)

print(map_compiled_richnessUICN_sp)

## Riqueza de sp endemicas ####

##### Plot Riqueza de sp endemicas con registros  - por Bioma #####

records_bioma_summary_sp_endemicas<- st_drop_geometry(biomodelos_data_record) %>% dplyr::filter(endemic  %in% "End\xe9mica") %>% 
  dplyr::group_by(BIOMA_IAvH) %>% dplyr::summarise(n_species_endemicas_records_bioma = n_distinct(scientificName))


BiomaIAvH_richnessendemicas_summary_sf<-list( as.data.frame(BiomaIAvH_puntos_summary_sf),
                                              records_bioma_summary_sp_endemicas
) %>% plyr::join_all() %>%  st_as_sf()


species_records_bioma_endemicas<- species_records_bioma %>%  dplyr::filter(endemic  %in% "End\xe9mica")


map_richnessendemicas_sp_records_Bioma <-    map_base_plot + 
  guides(color = "none")+
  ggnewscale::new_scale_fill()+
  geom_sf(data= BiomaIAvH_richnessendemicas_summary_sf, aes( fill = n_species_endemicas_records_bioma),
          color= NA, alpha= 0.8) +
  scale_fill_gradientn("No. especies endemicas\nregistradas por Bioma con\n puntos de calor\n(registros historicos)", colors =  brewer.pal(n = 11, name = "Greens"), 
                       na.value= NA, guide = guide_colorbar(order = 1, frame.colour = "black", ticks.colour = "black"))+
  coord_sf(xlim= c(extent_analysis[1], extent_analysis[2]), 
           ylim = c(extent_analysis[3], extent_analysis[4]) ) +
  ggnewscale::new_scale_color()+
  geom_point(data= species_records_bioma_endemicas, aes(x=X, y=Y, color= "brown"), size= 0.8,
             alpha= 0.8, shape= 17)+
  scale_color_manual("", values = c("brown" = "purple"), labels= "Registros historicos de\nespecies endemicas\nen zonas de puntos\nde calor", guide = guide_legend(order = 2, override.aes = list(size = 3)))


##### Plot Riqueza de sp endemicas con modelos  - por Bioma #####
models_bioma_summary_sp_endemicas<- st_drop_geometry(biomodelos_data_model) %>% dplyr::filter(endemic  %in% "End\xe9mica") %>% 
  dplyr::group_by(BIOMA_IAvH) %>% dplyr::summarise(n_species_models_records_bioma = n_distinct(scientificName))

BiomaIAvH_richnessendemicas_summary_model_sf<- list( as.data.frame(BiomaIAvH_puntos_summary_sf),
                                                     models_bioma_summary_sp_endemicas
) %>% plyr::join_all() %>%  st_as_sf()


map_richnessendemicas_sp_models_Bioma <-    map_base_plot + 
  guides(color = "none")+
  ggnewscale::new_scale_fill()+
  geom_sf(data= BiomaIAvH_richnessendemicas_summary_model_sf, aes( fill = n_species_models_records_bioma),
          color= NA, alpha= 0.8) +
  scale_fill_gradientn("Riqueza estimada de\nespecies endemicas por\nBioma con puntos de calor\n(Mapas de distribuciC3n)", colors = brewer.pal(n = 11, name = "Greens"), 
                       na.value= NA, guide = guide_colorbar(order = 1, frame.colour = "black", ticks.colour = "black"))+
  coord_sf(xlim= c(extent_analysis[1], extent_analysis[2]), 
           ylim = c(extent_analysis[3], extent_analysis[4]) ) +
  ggnewscale::new_scale_color()

#### Densidad Riqueza de sp endemicas con modelos  - por Bioma #####
data_coords_richnessendemicas<- biomodelos_data_model %>% dplyr::filter(endemic  %in% "End\xe9mica") %>%
  dplyr::group_by(id_point) %>% dplyr::summarise(n= n_distinct(scientificName))

richnessendemicas_density_plot<- ggplot(data_coords_richnessendemicas, aes(x = n)) +
  geom_density(fill = "darkgreen", alpha = 0.6, bw = 0.5, color= NA) +
  labs(x = "No. estimado de especies endemicas (Mapas de distribuciC3n)", y = "Densidad de\npuntos de calor") +
  annotate("text", size=3, x = -Inf, y = Inf, hjust= 0, vjust= 1,
           label =  paste0("N= ",  unique(nrow(data_coords_richnessendemicas)), "\nBanwidth= 0.5") ) +
  theme_minimal()+
  theme(
    text = element_text(size = 6),
    axis.text.y = element_text(angle = 90)
  )

#### Plot compilado Riqueza de sp endemicas  - por Bioma #####
map_compiled_richnessendemicas_sp<- ggarrange(plotlist =  list(richnessendemicas_density_plot,
                                                               ggarrange(plotlist = list(map_richnessendemicas_sp_records_Bioma,
                                                                                         map_richnessendemicas_sp_models_Bioma),
                                                                         ncol = 2, nrow = 1, common.legend = F, align = "h")),
                                              nrow = 2, heights  = c(1/3, 2/3)
)

print(map_compiled_richnessendemicas_sp)

## Riqueza de sp exoticas ####

##### Plot Riqueza de sp exoticas con registros  - por Bioma #####
records_bioma_summary_sp_exoticas<- st_drop_geometry(biomodelos_data_record) %>% dplyr::filter(especies_exoticas %in% "Ex\xf3tica") %>% 
  dplyr::group_by(BIOMA_IAvH) %>% dplyr::summarise(n_species_exoticas_records_bioma = n_distinct(scientificName))


BiomaIAvH_richnessexoticas_summary_sf<-list( as.data.frame(BiomaIAvH_puntos_summary_sf),
                                             records_bioma_summary_sp_exoticas
) %>% plyr::join_all() %>%  st_as_sf()

species_records_bioma_exoticas<- species_records_bioma %>%  dplyr::filter(especies_exoticas %in% "Ex\xf3tica")

map_richnessexoticas_sp_records_Bioma <-    map_base_plot + 
  guides(color = "none")+
  ggnewscale::new_scale_fill()+
  geom_sf(data= BiomaIAvH_richnessexoticas_summary_sf, aes( fill = n_species_exoticas_records_bioma),
          color= NA, alpha= 0.8) +
  scale_fill_gradientn("No. especies exoticas\nregistradas por Bioma con\n puntos de calor\n(registros historicos)", colors =  rev(c("#a78b5e", "#ccb27a", "#f0d586", "#ffd700")), 
                       na.value= NA, guide = guide_colorbar(order = 1, frame.colour = "black", ticks.colour = "black"))+
  coord_sf(xlim= c(extent_analysis[1], extent_analysis[2]), 
           ylim = c(extent_analysis[3], extent_analysis[4]) ) +
  ggnewscale::new_scale_color()+
  geom_point(data= species_records_bioma_exoticas, aes(x=X, y=Y, color= "brown"), size= 0.8,
             alpha= 0.8, shape= 17)+
  scale_color_manual("", values = c("brown" = "purple"), labels= "Registros historicos de\nespecies exoticas\nen zonas de puntos\nde calor", guide = guide_legend(order = 2, override.aes = list(size = 3)))

##### Plot Riqueza de sp exoticas con modelos  - por Bioma #####

models_bioma_summary_sp_exoticas<- st_drop_geometry(biomodelos_data_model) %>% dplyr::filter(especies_exoticas %in% "Ex\xf3tica") %>% 
  dplyr::group_by(BIOMA_IAvH) %>% dplyr::summarise(n_species_models_records_bioma = n_distinct(scientificName))

BiomaIAvH_richnessexoticas_summary_model_sf<- list( as.data.frame(BiomaIAvH_puntos_summary_sf),
                                                    models_bioma_summary_sp_exoticas
) %>% plyr::join_all() %>%  st_as_sf()


map_richnessexoticas_sp_models_Bioma <-    map_base_plot + 
  guides(color = "none")+
  ggnewscale::new_scale_fill()+
  geom_sf(data= BiomaIAvH_richnessexoticas_summary_model_sf, aes( fill = n_species_models_records_bioma),
          color= NA, alpha= 0.8) +
  scale_fill_gradientn("Riqueza estimada de\nespecies exoticas por\nBioma con puntos de calor\n(Mapas de distribuciC3n)", colors = rev(c("#a78b5e", "#ccb27a", "#f0d586", "#ffd700")), 
                       na.value= NA, guide = guide_colorbar(order = 1, frame.colour = "black", ticks.colour = "black"))+
  coord_sf(xlim= c(extent_analysis[1], extent_analysis[2]), 
           ylim = c(extent_analysis[3], extent_analysis[4]) ) +
  ggnewscale::new_scale_color()


#### Densidad Riqueza de sp exoticas con modelos  - por Bioma #####
data_coords_richnessexoticas<- biomodelos_data_model %>% dplyr::filter(especies_exoticas %in% "Ex\xf3tica") %>%
  dplyr::group_by(id_point) %>% dplyr::summarise(n= n_distinct(scientificName))

richnessexoticas_density_plot<- ggplot(data_coords_richnessexoticas, aes(x = n)) +
  geom_density(fill = "gold", alpha = 0.6, bw = 0.5, color= NA) +
  labs(x = "No. estimado de especies exoticas (Mapas de distribuciC3n)", y = "Densidad de\npuntos de calor") +
  annotate("text", size=3, x = -Inf, y = Inf, hjust= 0, vjust= 1,
           label =  paste0("N= ",  unique(nrow(data_coords_richnessexoticas)), "\nBanwidth= 0.5") ) +
  theme_minimal()+
  theme(
    text = element_text(size = 6),
    axis.text.y = element_text(angle = 90)
  )

#### Plot compilado Riqueza de sp exoticas  - por Bioma #####

map_compiled_richnessexoticas_sp<- ggarrange(plotlist =  list(richnessexoticas_density_plot,
                                                              ggarrange(plotlist = list(map_richnessexoticas_sp_records_Bioma,
                                                                                        map_richnessexoticas_sp_models_Bioma),
                                                                        ncol = 2, nrow = 1, common.legend = F, align = "h")),
                                             nrow = 2, heights  = c(1/3, 2/3)
)

print(map_compiled_richnessexoticas_sp)




##  AnC!lisis de ecosistemas amenazados por puntos de calor ####
### Corte Ecosistemas amenazados por area de estudio ####
redlist_ecos_studyarea<- redlist_ecos %>% terra::crop(area_analysis)
studyarea_raster<- area_analysis %>% fasterize::fasterize(raster(redlist_ecos_studyarea)) %>% terra::rast()
redlist_ecos_studyarea2<- terra::mask(redlist_ecos_studyarea, studyarea_raster)

### Conteo de puntos de calor por ecosistema ####
filter_vals<- terra::freq(redlist_ecos_studyarea2)
dat_levels<-  data.frame(ID=1:4, Nivel=c("Critico", "En Peligro", "PreocupaciC3n\nmenor", "Vulnerable"), 
                         colors= c("red", "orange", "darkgreen", "gold"),
                         stringsAsFactors=FALSE) %>% dplyr::filter(ID %in% filter_vals$value)

ecosistemas_redlist_data <- terra::extract(redlist_ecos_studyarea2, PuntosCalor_filter, xy= T)

points_amenazados <- PuntosCalor_filter %>% dplyr::mutate(RedListEco= ecosistemas_redlist_data$RedListEco) %>%  dplyr::filter(!is.na(RedListEco)) %>% 
  dplyr::filter(! RedListEco %in% "PreocupaciC3n\nmenor" ) %>%  dplyr::filter(! RedListEco %in% 3 )

dat_levels2<- dat_levels %>% dplyr::mutate(RedListEco= ID )

ecosistemas_redlist_data_summ<- ecosistemas_redlist_data %>% dplyr::select(-"ID") %>% 
  dplyr::filter(!is.na(RedListEco)) %>% group_by(RedListEco) %>% dplyr::summarise(n= n()) %>% 
  list(dat_levels2) %>% plyr::join_all() %>% dplyr::mutate(RedListEco= Nivel)


#### Plot barras conteo de puntos de calor por ecosistema ####
plot_bar_ecosistemas<- ggplot(ecosistemas_redlist_data_summ, aes(x = RedListEco, y = n, fill = RedListEco)) +
  geom_bar(stat = "identity", position = "dodge") +
  labs(y= "No. de puntos de calor", x= "Ecosistemas amenazados")+
  scale_fill_manual("Ecosistemas amenazados", values = setNames( dat_levels$colors, dat_levels$Nivel))+
  theme_minimal()+
  theme(
    legend.position = "none",
    text = element_text(size = 6),
    axis.text.y = element_text(angle = 90)
  )


#### Plot points puntos de calor por ecosistema ####
points_amenazados<- sf::st_as_sf(points_amenazados, coords = c("x", "y"),   crs= "+proj=longlat +datum=WGS84 +ellps=WGS84 +towgs84=0,0,0")
plot_ecosistemas_mapa<- map_base_plot+
  geom_spatraster(data= redlist_ecos_studyarea2, aes(fill = RedListEco ), alpha= 0.8)+
  scale_fill_gradientn( "Ecosistemas\namenazados", colors =  dat_levels$colors, labels= dat_levels$Nivel, breaks= dat_levels$ID,
                        na.value= NA, guide= guide_legend(order = 1)
  )+
  ggnewscale::new_scale_color()+
  geom_point(data= points_amenazados, aes(x=X, y=Y, color= "brown"), size= 0.8,
             alpha= 0.8, shape= 17)+
  scale_color_manual("", values = c("brown" = "purple"), labels= "Puntos de calor\nen ecosistemas\namenazados", guide = guide_legend(order = 3, override.aes = list(size = 3)))+
  coord_sf(xlim= c(extent_analysis[1], extent_analysis[2]), 
           ylim = c(extent_analysis[3], extent_analysis[4]) )


#### Plot puntos de calor - por ecosistemas amenazados #####
plot_ecosistemas_mapa_compilado<- ggarrange(plotlist = list(plot_bar_ecosistemas,
                                                            plot_ecosistemas_mapa),
                                            ncol = 2, nrow = 1, common.legend = F, widths = c(0.4,0.6), heights = c(0.5,1))


print(plot_ecosistemas_mapa_compilado)

## Generar Reporte de resultados ####

### Cargar plantilla reporte ####
doc <- read_docx(input$template_reporte)
estilos_disponibles <- styles_info(doc)
estilo_normal<- dplyr::filter(estilos_disponibles, style_id %in% "NormalPrincipal")

setwd(dir_folder_out)


#### Generar texto ####
doc <- doc %>%
  body_remove()  %>%
  ##### Titulo ####
  body_add_par("REPORTE AFECTACICN POTENCIAL EN LA BIODIVERSIDAD POR PUNTOS DE CALOR TEMPORADA SECA 2023-2024", style = "TituloPrincipal") %>% 
  ##### Ventana de analisis ####
  body_add_fpar(fpar(ftext("Ventana espacial de anC!lisis: ", 
                           prop = fp_text(bold = TRUE, font.size = as.numeric(estilo_normal$font.size)/2, font.family = estilo_normal$font.family)), 
                     ftext(paste0(name_StudyArea, "."))), style = "NormalPrincipal") %>% 
  ##### Ventana Temporal ####
  body_add_fpar(fpar(ftext("Ventana temporal de datos: ", 
                           prop = fp_text(bold = TRUE, font.size = as.numeric(estilo_normal$font.size)/2, font.family = estilo_normal$font.family)), 
                     ftext("1 de diciembre de 2023 - 31 de enero de 2024.")), style = "NormalPrincipal") %>% 
  ##### Fuente de datos ####
  body_add_fpar(fpar(ftext("Fuente de datos: ", 
                           prop = fp_text(bold = TRUE, font.size = as.numeric(estilo_normal$font.size)/2, font.family = estilo_normal$font.family)), 
                     ftext("Puntos de calor, SatC)lite VIIRS y MODIS, Lista Roja de Ecosistemas de Colombia, Biomodelos, y clasificaciC3n de Biomas IAvH.")), style = "NormalPrincipal") %>% 
  body_add_fpar(fpar(ftext("URL puntos de calor: ", 
                           prop = fp_text(bold = TRUE, font.size = as.numeric(estilo_normal$font.size)/2, font.family = estilo_normal$font.family)), 
                     ftext("http://puntosdecalor.ideam.gov.co/archivos-ftp/")), style = "NormalPrincipal") %>% 
  ##### SelecciC3n de datos ####
  body_add_fpar(fpar(ftext("SelecciC3n de datos: ", 
                           prop = fp_text(bold = TRUE, font.size = as.numeric(estilo_normal$font.size)/2, font.family = estilo_normal$font.family)), 
                     ftext("Puntos de calor de la ventana espacial y temporal definida en coberturas naturales (Corine Land Cover Colombia adaptada para Colombia).")), style = "NormalPrincipal") %>%
  body_add_fpar(fpar(ftext("NC:mero total de puntos identificados: ", 
                           prop = fp_text(bold = TRUE, font.size = as.numeric(estilo_normal$font.size)/2, font.family = estilo_normal$font.family)), 
                     ftext(paste0(max(PuntosCalor_filter$id_point), "."))), style = "NormalPrincipal") %>% 
  body_add_break() %>% 
  ##### Tabla 1 ####
  body_add_par("Tabla 1: Top de biomas con mayor cantidad de puntos de calor.", style = "FiguraPrincipal") %>% 
  body_add_table(value =  BiomaIAvH_puntos_data_export %>%  
                   {.[if(nrow(.)>=10){seq(10)}else{seq(nrow(.))},]}, style = "EstiloRP") %>% 
  body_add_break() %>% 
  ##### Tabla 2 ####
  body_add_par("Tabla 2: Top de biomas mC!s afectados de acuerdo a la densidad de puntos de calor.", style = "FiguraPrincipal") %>% 
  body_add_table(value = BiomaIAvH_puntos_summary_density %>%  setNames(c("Bioma IAvH", "Crea (km2)", "Densidad de puntos por C!rea")) %>% 
                   {.[if(nrow(.)>=10){seq(10)}else{seq(nrow(.))},]}, style = "EstiloRP")  %>% 
  body_add_break() %>% 
  body_add_gg(value = map_compiled_densidad_calor, width = 6.5, height = 6, res = 300) %>% 
  ##### Figura 1 ####
  body_add_par("Figura 1. DistribuciC3n espacial de puntos de calor en periodo de anC!lisis.", style = "FiguraPrincipal") %>% 
  body_add_break() %>% 
  body_add_gg(value = map_compiled_richness_sp, width = 6.5, height = 6, res = 300) %>% 
  ##### Figura 2 ####
  body_add_par("Figura 2. Impacto potencial en la biodiversidad. La figura de arriba representa densidad de puntos de calor y en el b