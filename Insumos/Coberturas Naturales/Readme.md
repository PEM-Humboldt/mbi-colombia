Reclasificación de coberturas
================
Este código reclasifica el mapa de coberturas descargado de la plataforma de [datos abiertos](https://experience.arcgis.com/experience/568ddab184334f6b81a04d2fe9aac262/page/Datos-Abiertos-Geogr%C3%A1ficos-/) del IDEAM. Y Guarda unicamente aquellas que están asociadas a coberturas naturales para se usadas en los indicadores de MBI. La capa de salida tiene proyección 4326.

Es posible también guardar el objeto tabla_m para guardar todas la coberturas con la reclasificación. En este caso la capa se guardará con la proyección MAGNA-SIRGAS: 4686

## Organizar directorio de trabajo

<a id="ID_seccion1"></a>
Las entradas de ejemplo de este ejercicio están almacenadas en
[aquí](https://drive.google.com/file/d/1Xg04VRR4F4lbEFuua1d9FwtHeVZ28A1x/view?usp=drive_link).
Una vez descargadas y descomprimida, reemplaze la carpeta “Originales” en el directorio Datos del proyecto.
El directorio del proyecto está organizado de esta manera que facilita la ejecución del
código:

    Códigos
    │- Huella_Altillanura
    │    
    └-Datos
    │ │
    │ └- Originales: replaze aquí los datos que bajo
    │ │   │
    │ │   
    │ └- Intermedios
    │     │     
    |
    └- Resultados

