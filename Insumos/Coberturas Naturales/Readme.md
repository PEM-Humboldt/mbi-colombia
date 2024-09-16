Análisis multitemporal de la huella espacial humana
================
En este código se realiza un análisis multitemporal (1970, 1990, 2000, 2015, 2018) de la huella espacial humana por municipios en la altillanura colombiana. 
Se calculan estadísticas zonales (promedio, mediana, desviación estándar) de los valores de huella y estadisticos zonales para obtener la frecuencias de categorias de intensidad de  IHEH. La categorización de IHEH tambien se efectúa en el código 

Los resultados se guardan en dos data frames:

Stat_values: Contiene estadísticas zonales (promedio, mediana, desviación estándar) para cada departamento y año .
Stat_reclass: Contiene la frecuencia y porcentaje de categorías de reclasificación para cada departamento y año.

En la última sección del código las tablas se organizan para su exportación en formatos .csv y html para tener tablas interactivas que faciliten la exploración. Seguidamente se preparan y exportan gráficas de los datos que muestren la evolución de la IHEH a través de los años y permita comparar  entre municipios.

Proporciona información sobre cómo los cambios en la presión y el impacto de las actividades humanas están ejerciendo presión sobre la
biodiversidad en estas áreas. 

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

