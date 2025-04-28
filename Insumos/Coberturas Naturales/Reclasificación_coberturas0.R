# Título: Reclasificación de coberturas
#
# Descripción: Este código descarga y reclasifica el mapa de coberturas del IDEAM. Se generan dos productos:
# 1  Guarda unicamente aquellas que están asociadas a coberturas naturales para se usadas en los indicadores de MBI.
# 2  Guarda todas las clases de coberturas 

# La capa de salida tiene proyección 4326.
# Es posible también guardar el objeto tabla_m para guardar todas la coberturas con la reclasificación. En este caso la capa se guardará con la proyección MAGNA-SIRGAS: 4686

# Autor(es): Alejandra Narváez Vallejo
#
# Por hacer o  corregir:

## 
## 


#*******************************************************************************
# librerías o dependencias -----------------------------------------------------
#*******************************************************************************
library(sf)
library(terra)
library(readr)
library(dplyr)

#**********************************************************
# Definir directorio(s) de trabajo -----------------------
#**********************************************************

setwd(file.path(this.path::this.path(),".."))

dir_Datos_Or<- file.path("input")
dir_Resultados<- file.path ("output")


#**********************************************************
# Cargar Variables de importancia -------------------------
#**********************************************************

#Colóque en el objeto cobertura.name el nombre del archivo de cobertura descargado de "https://experience.arcgis.com/experience/568ddab184334f6b81a04d2fe9aac262/page/Datos-Abiertos-Geogr%C3%A1ficos-/"

# Defina el año de interés

cobertura.name <- "e_cobertura_tierra_2020_admin.shp"
año<- 2020

#**********************************************************
# Cargar los datos necesarios ----------------------------
#**********************************************************

# cargar las capas

look_up<-read_csv2(file.path(dir_Datos_Or, "lookup_corine.csv"))


cobertura<-read_sf(file.path(dir_Datos_Or, "Coberturas", cobertura.name))

 
#**********************************************************
# Preparar datos ----------------------------
#**********************************************************

# corregir el tipo de datos y seleccionar solo los campos necesarios en sub_cob

cobertura$nivel_3<-as.numeric(as.character(cobertura$nivel_3))
sub_cob<-cobertura%>% select(nivel_3, leyenda)

#****************************************************************************
# Procesamiento ----------------------------
#****************************************************************************
#completar las coberturascon la informacion del lookup
tabla_m<-merge(sub_cob, as.data.frame(look_up), by.x= "nivel_3", by.y= "extraer",all.x=T )

# comprobar que todos tienen un area_type. FALSE y 0 features es correcto
any(is.na(tabla_m$area_type))
tabla_m[which(is.na(tabla_m$area_type)),]

# revisar que la estructura esté bien
dim(sub_cob)
dim(look_up)
dim(tabla_m)

## sólo la coberturas naturales  ####

cov_nat <- filter(tabla_m,area_type=="N")%>%
  dplyr::mutate(fid = row_number())%>%
  dplyr::select(fid)%>% # desactivar si se quiere tener toda la información para revisar
  st_transform(4326)


# disolver los bordes comunes
# desactivar S2
sf::sf_use_s2(F)

sim_cov_nat <-   st_union(cov_nat, by_feature = FALSE)


# guardar los resultados como geopackage

st_write(sim_cov_nat, file.path(dir_Resultados,paste0("CLC_natural_",año, ".gpkg")), delete_layer = T)

## todas las clases de coberturas  ####

cov_nat2 <- tabla_m%>%
  #dplyr::mutate(fid = row_number())%>%
  #dplyr::select(fid)%>% # desactivar si se quiere tener toda la información para revisar
  st_transform(4326)


# guardar los resultados como geopackage

st_write(cov_nat2, file.path(dir_Resultados,paste0("CLC_clases_",año, ".gpkg")), delete_layer = T)



