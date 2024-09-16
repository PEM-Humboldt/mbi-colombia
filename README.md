Rutinas MBI Colombia
================

Este repositorio describe las rutinas utilizadas para la estimación de
indicadores de estado de biodiversidad, asociadas al Piloto para la
construcción de un Índice Multidimensional de Biodiversidad (MBI) para
Colombia. Por su definición multidimensional, el MBI integra múltiples
aspectos de estado y tendencia de la biodiversidad en un único valor de
reporte, que comunica de manera efectiva el estado de la biodiversidad y
facilita la toma de decisiones informadas para su gestión. El MBI está
conformado por el Subíndice de Estado de la Biodiversidad (BI) y el
Subíndice de Contribuciones de la Biodiversidad a las Personas (BCPI).
Cada uno de estos subíndices está constituido por múltiples dimensiones,
y cada dimensión tiene indicadores específicos asociados. Las rutinas de
estimación de estos indicadores descritas en este repositorio incluyen
la organización de insumos, el procesamiento y análisis de datos, y la
estimación y normalización de los indicadores para su integración en el
MBI.

Las rutinas acá documentadas son:

- [Subíndice BI](./MBI/BI_subindex)
  - [Dimensión Diversidad](./MBI/BI_subindex/Dimension_Diversity)
    - [Objetivo
      Genético](./MBI/BI_subindex/Dimension_Diversity/Objective_Genetic)
      - [Indicador genético del estado de
        poblaciones](./MBI/BI_subindex/Dimension_Diversity/Objective_Genetic/GeneticStatePopulations)
  - [Dimensión Función](./MBI/BI_subindex/Dimension_Function)
    - [Objetivo
      Hábitat](./MBI/BI_subindex/Dimension_Function/Objective_Habitat)
      - [Indicador de variación del área de ecosistemas naturales
        continentales](./MBI/BI_subindex/Dimension_Function/Objective_Habitat/VariationNaturalEcosystemsArea)
- [Subíndice BCPI](./MBI/BCPI_subindex)
  - [Dimensión Regulación](./MBI/BCPI_subindex/Dimension_Regulation)
    - [Objetivo Mitigación del Cambio
      Climático](./MBI/BCPI_subindex/Dimension_Regulation/Objective_ClimateChangeMitigation)
      - [Indicador de variación en la extensión de ecosistemas
        estratégicos con potencial de captura de
        carbono](./MBI/BCPI_subindex/Dimension_Regulation/Objective_ClimateChangeMitigation/VariationStrategicEcosystemsCarbonCapture)
  - [Dimensión No Material o
    Intangible](./MBI/BCPI_subindex/Dimension_NonMaterialIntangible)
    - [Objetivo Salud y Calidad de
      vida](./MBI/BCPI_subindex/Dimension_NonMaterialIntangible/Objective_HealthQualityLife)
      - [Indicador de la variación en la huella humana en áreas de
        manejo
        especial](./MBI/BCPI_subindex/Dimension_NonMaterialIntangible/Objective_HealthQualityLife/VariationHumanFootprintSpecialAreas)

## Referencias

- [Soto-Navarro, C. A., Harfoot, M., Hill, S. L., Campbell, J.,
  Campos-Santos, H.-C., Mora, F., Pretorius, C., Kapos, V., Allison, H.,
  & Burgess, N. D. (2020). Building a Multidimensional Biodiversity
  Index—A Scorecard for Biodiversity Health (UNEP-WCMC, 2020). UN
  Environment Programme World Conservation Monitoring Centre
  (UNEP-WCMC), Cambridge, UK and Luc Hoffmann Institute
  (LHI).](https://wedocs.unep.org/bitstream/handle/20.500.11822/38023/biodiversity_index.pdf?sequence=3&isAllowed=y)

- [Soto-Navarro, C. A., Harfoot, M., Hill, S. L. L., Campbell, J., Mora,
  F., Campos, C., Pretorius, C., Pascual, U., Kapos, V., Allison, H., &
  Burgess, N. D. (2021). Towards a multidimensional biodiversity index
  for national application. Nature Sustainability, 4(11), 933-942.
  https://doi.org/10.1038/s41893-021-00753-z](https://www.nature.com/articles/s41893-021-00753-z)
