# SUHII Computation by Elevation Bands (MATLAB)

## Overview
This MATLAB script computes the Surface Urban Heat Island Intensity (SUHII) stratified by elevation bands using point based Land Surface Temperature (LST) data.

For each elevation band, a rural reference LST is first computed using non-urban points selected according to their land use/land cover class (CORINE Land Cover nomenclature) and their distance from the urban fabric.

SUHII is then computed as the difference between the LST value of each individual point and the mean rural reference LST of the corresponding elevation band.

For interpretative purposes, the script also reports the mean SUHII of urban points for each elevation band.

Example input data required to run the script are available at this [LINK](https://doi.org/10.5281/zenodo.19821093).

---

## Inputs
The script requires a point based shapefile, whose name is defined in the *INPUT PARAMETERS* section of the script.

### Required shapefile attributes

| Attribute | Description |
|---------|-------------|
| `LST_1` | Land Surface Temperature (°C) |
| `DTM` | Terrain elevation (m a.s.l.) |
| `LULC_full` | CORINE Land Cover class (string) |
| `Dist_urb` | Planar distance from urban fabric (m) |

Only CORINE Land Cover Level 1 classes are used internally to distinguish urban and rural areas.

---

## Parameterization
Key parameters controlling the SUHII computation:

- **Elevation bands**
  - Number of bands (`Num_bands`)
  - Band thickness (`Band_size`, m)

- **Rural reference buffer**
  - Minimum distance from urban areas (`buffer_min`, m)
  - Maximum distance from urban areas (`buffer_max`, m)

- **Spatial resolution**
  - Pixel size (m), used to compute areas (km²)

---

## Outputs

### 1. Tabular output (console)
A summary table reporting SUHII statistics for each elevation band:

- Elevation range (m)
- Rural area (km²)
- Urban area (km²)
- Mean rural LST (°C)
- Mean urban LST (°C)
- Mean urban SUHII (°C)

### 2. Shapefile output
A new point shapefile:

PointCloud_SUHII_YYYY.shp

with the following attributes added:

- `SUHII` – point‑wise SUHII (relative to the elevation‑band rural reference LST)
- `SUHII_urb` – point‑wise SUHII for urban points only (NaN elsewhere)

---

## Processing Steps
1. Load point shapefile and extract attributes  
2. Remove points with missing LST values  
3. Define elevation bands  
4. For each elevation band:
   - Select urban and rural points  
   - Identify rural reference points using land‑cover class and distance buffer  
   - Compute mean rural and urban LST  
   - Compute mean urban SUHII  
   - Compute point‑wise SUHII  
5. Export aggregated statistics and SUHII shapefile

---

## Requirements
- MATLAB R2021a or newer  
- Mapping Toolbox (required)
