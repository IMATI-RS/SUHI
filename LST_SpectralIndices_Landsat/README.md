# Retrieval of LST and Spectral Indices from Landsat products (MATLAB)

## Overview
This MATLAB script processes single Landsat Collection 2 scenes (Landsat 5 TM, Landsat 8 OLI/TIRS, and Landsat 9 OLI 2/TIRS 2) to derive raster maps of key spectral indices (NDVI, NDWI, NDBI, UI) and Land Surface Temperature (LST, expressed in °C).  

The workflow includes pixel quality masking, emissivity estimation, and land surface temperature retrieval using a single channel algorithm. All output products are exported as georeferenced GeoTIFF files.  

---

## Inputs
The script expects all input files to be located in the same directory and automatically adapts band selection based on the detected satellite.

### Required Landsat bands

| Product | Variable | Landsat 5 TM | Landsat 8 / 9 |
|-------|----------|--------------|---------------|
| Surface Reflectance (L2) | Blue  | SR_B1 | SR_B2 |
|  | Green | SR_B2 | SR_B3 |
|  | Red   | SR_B3 | SR_B4 |
|  | NIR   | SR_B4 | SR_B5 |
|  | SWIR1 | SR_B5 | SR_B6 |
|  | SWIR2 | SR_B7 | SR_B7 |
| QA mask | Pixel quality | QA_PIXEL | QA_PIXEL |
| Thermal (L1) | TIR band | B6 | B10 |

File prefixes for L1 (thermal) and L2 (reflectance) products are defined in the **USER PARAMETERS** section of the script.

### Optional input
- **AOI shapefile** (`AOI.shp`) for spatial clipping (must share the same CRS as the raster data)

---

## Outputs
The script generates 30 m GeoTIFF maps:

- `NDVI_YYYYMMDD_map.tif`
- `NDWI_YYYYMMDD_map.tif`
- `NDBI_YYYYMMDD_map.tif`
- `UI_YYYYMMDD_map.tif`
- `LST_YYYYMMDD_map.tif` (°C)

All outputs preserve original georeferencing and EPSG code.

---

## Requirements
- MATLAB R2021a or newer  
- Mapping Toolbox (required) 
