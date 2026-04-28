clc
clear all
close all

%% =========================================================================
%  1. USER PARAMETERS
% =========================================================================

% Methods for computing Proportion of Vegetation (PV) and Land Surface Emissivity (LSE)
pv_method      = 'threshold';  % 'minmax' or 'threshold'
NDVI_s         = 0.2;          % soil NDVI threshold (threshold method)
NDVI_v         = 0.86;         % vegetation NDVI threshold
lse_method     = 'linear';     % 'linear' or 'sndvithm'

% Landsat file prefixes (Level-1 thermal and Level-2 surface reflectance)
file_prefix_L1 = 'LC09_L1TP_194029_20250810_20250811_02_T1_';
file_prefix_L2 = 'LC09_L2SP_194029_20250810_20250811_02_T1_';  
file_ext       = '.TIF';

% Optional: Pixel-quality masks based on QA_PIXEL band
maskCloud       = 'yes';
maskCloudShadow = 'yes';
maskSnowIce     = 'yes';
maskCirrus      = 'yes';
maskWater       = 'no';

% Optional: Cropping to Area Of Interest (AOI)
AOI_crop = 'yes';
AOI_file = 'AOI.shp';


%% =========================================================================
%  2. AUTOMATIC SATELLITE IDENTIFICATION
% =========================================================================
if contains(file_prefix_L1,'LC08')
    satellite = 'L8';
elseif contains(file_prefix_L1,'LC09')
    satellite = 'L9';
elseif contains(file_prefix_L1,'LT05')
    satellite = 'L5';
else
    error('Satellite not recognized. Supported: L5, L8, L9.');
end

fprintf('\n✅ Detected satellite: %s\n', satellite);


%% =========================================================================
%  3. BAND MAPPING AND SENSOR CONSTANTS
% =========================================================================

switch satellite
    
    % ------------------ Landsat 8 / 9 ------------------
    case {'L8','L9'}
        bands = struct( ...
            'Blue',  "SR_B2", ...
            'Green', "SR_B3", ...
            'Red',   "SR_B4", ...
            'NIR',   "SR_B5", ...
            'SWIR1', "SR_B6", ...
            'SWIR2', "SR_B7", ...
            'TIR',   "B10" ...
        );
        lambda = 10.9e-6;  % Central wavelength of TIR band

        if strcmp(satellite,'L8')
            ML = 0.0003342; AL = 0.1; K1 = 774.8853; K2 = 1321.0789;
        else
            ML = 0.0003800; AL = 0.1; K1 = 799.0284; K2 = 1329.2405;
        end
    
    % ------------------ Landsat 5 ------------------
    case 'L5'
        bands = struct( ...
            'Blue',  "SR_B1", ...
            'Green', "SR_B2", ...
            'Red',   "SR_B3", ...
            'NIR',   "SR_B4", ...
            'SWIR1', "SR_B5", ...
            'SWIR2', "SR_B7", ...
            'TIR',   "B6" ...
        );
        lambda = 11.5e-6;  % Central wavelength of TIR band
        
        ML = 5.5375e-2; AL = 1.18243; 
        K1 = 607.76;     K2 = 1260.56;
end

rho_c = 1.438e-2;   % Constant used in LST equation


%% =========================================================================
%  4. BUILD FILE PATHS
% =========================================================================

file_Blue  = file_prefix_L2 + bands.Blue  + file_ext;
file_Green = file_prefix_L2 + bands.Green + file_ext;
file_Red   = file_prefix_L2 + bands.Red   + file_ext;
file_NIR   = file_prefix_L2 + bands.NIR   + file_ext;
file_SWIR1 = file_prefix_L2 + bands.SWIR1 + file_ext;
file_SWIR2 = file_prefix_L2 + bands.SWIR2 + file_ext;
file_QA    = file_prefix_L2 + "QA_PIXEL"  + file_ext;

file_TIR   = file_prefix_L1 + bands.TIR   + file_ext;


%% =========================================================================
%  5. READ RASTER DATA AND BUILD VALID MASK
% =========================================================================

info_ref = georasterinfo(file_TIR);
R = info_ref.RasterReference;

filelist = {file_Blue,file_Green,file_Red,file_NIR,file_SWIR1,file_SWIR2,file_TIR};
nodata = cell(size(filelist));

for i = 1:numel(filelist)
    info = georasterinfo(filelist{i});
    nodata{i} = info.MissingDataIndicator;
end

% Read bands
[Blue,~]  = readgeoraster(file_Blue);
[Green,~] = readgeoraster(file_Green);
[Red,~]   = readgeoraster(file_Red);
[NIR,~]   = readgeoraster(file_NIR);
[SWIR1,~] = readgeoraster(file_SWIR1);
[SWIR2,~] = readgeoraster(file_SWIR2);
[TIR,~]   = readgeoraster(file_TIR);
[QA,~]    = readgeoraster(file_QA);

% Convert to double
Blue=double(Blue); Green=double(Green); Red=double(Red);
NIR=double(NIR);   SWIR1=double(SWIR1); SWIR2=double(SWIR2);
TIR=double(TIR);

% Basic valid mask (exclude NoData)
valid_mask = ...
    (Blue~=nodata{1}) & (Green~=nodata{2}) & ...
    (Red~=nodata{3})  & (NIR~=nodata{4})   & ...
    (SWIR1~=nodata{5})&(SWIR2~=nodata{6})  & ...
    (TIR~=nodata{7});


%% =========================================================================
%  6. PIXEL‑QUALITY (QA_PIXEL) MASKING
% =========================================================================

qa_mask = false(size(QA));

if strcmp(satellite,'L5')
    qa_mask = qa_mask | (bitget(QA,1)==1);
    if strcmpi(maskCloud,'yes')
        qa_mask = qa_mask | (bitget(QA,4)==1 & bitget(QA,10)==1);
    end
    if strcmpi(maskCloudShadow,'yes')
        qa_mask = qa_mask | (bitget(QA,5)==1 & bitget(QA,12)==1);
    end
    if strcmpi(maskSnowIce,'yes')
        qa_mask = qa_mask | (bitget(QA,6)==1 & bitget(QA,14)==1);
    end
    if strcmpi(maskWater,'yes')
        qa_mask = qa_mask | (bitget(QA,8)==1);
    end

else
    
    if strcmpi(maskCloud,'yes')
        qa_mask = qa_mask | (bitget(QA,4)==1 & bitget(QA,10)==1);
        qa_mask = qa_mask |  bitget(QA,2)==1;
    end
    if strcmpi(maskCloudShadow,'yes')
        qa_mask = qa_mask | (bitget(QA,5)==1 & bitget(QA,12)==1);
    end
    if strcmpi(maskSnowIce,'yes')
        qa_mask = qa_mask | (bitget(QA,6)==1 & bitget(QA,14)==1);
    end
    if strcmpi(maskCirrus,'yes')
        qa_mask = qa_mask | (bitget(QA,3)==1 & bitget(QA,16)==1);
    end
    if strcmpi(maskWater,'yes')
        qa_mask = qa_mask | bitget(QA,8)==1;
    end
end

valid_mask = valid_mask & ~qa_mask;


%% =========================================================================
%  7. AOI MASK (OPTIONAL)
% =========================================================================

if isequal(AOI_crop,'yes')

    fprintf('✅ Applying AOI mask...\n');

    % Read AOI polygon
    AOI = readgeotable(AOI_file);
    coordTable_AOI = geotable2table(AOI,["X","Y"]);
    Xa = coordTable_AOI.X;
    Ya = coordTable_AOI.Y;

    % Build coordinate grid from raster reference
    [x,y] = worldGrid(R,'gridvectors');
    [X,Y] = meshgrid(x,y);

    % Build AOI mask
    AOI_mask = false(size(X));
    for i=1:numel(Xa)
        aoix = Xa{i};
        aoiy = Ya{i};
        AOI_mask = AOI_mask | inpolygon(X,Y,aoix,aoiy);
    end

    % Apply AOI mask
    valid_mask = valid_mask & AOI_mask;
end


%% =========================================================================
%  8. SURFACE REFLECTANCE CONVERSION
% =========================================================================

Blue  = 0.0000275.*Blue  - 0.2;
Green = 0.0000275.*Green - 0.2;
Red   = 0.0000275.*Red   - 0.2;
NIR   = 0.0000275.*NIR   - 0.2;
SWIR1 = 0.0000275.*SWIR1 - 0.2;
SWIR2 = 0.0000275.*SWIR2 - 0.2;


%% =========================================================================
%  9. SPECTRAL INDICES
% =========================================================================

NDVI = (NIR-Red)./(NIR+Red);   NDVI(~valid_mask)=NaN;
NDWI = (Green-NIR)./(Green+NIR); NDWI(~valid_mask)=NaN;
NDBI = (SWIR1-NIR)./(SWIR1+NIR); NDBI(~valid_mask)=NaN;
UI   = (SWIR2-NIR)./(SWIR2+NIR); UI(~valid_mask)=NaN;


%% =========================================================================
% 10. THERMAL PROCESSING → TOA RADIANCE and BRIGHTNESS TEMPERATURE
% =========================================================================

L_lambda = ML.*TIR + AL;
L_lambda(~valid_mask)=NaN;

TB = K2 ./ log(K1./L_lambda + 1);
TB(~valid_mask)=NaN;


%% =========================================================================
% 11. PROPORTION OF VEGETATION (PV)
% =========================================================================

PV = NaN(size(NDVI));

switch pv_method
    case 'threshold'
        mask_soil = NDVI <= NDVI_s;
        mask_veg  = NDVI >= NDVI_v;
        mask_mix  = ~mask_soil & ~mask_veg;

        PV(mask_mix) = ((NDVI(mask_mix)-NDVI_s)./(NDVI_v-NDVI_s)).^2;
        PV(mask_veg) = 1;
        PV(mask_soil)= 0;

    case 'minmax'
        ndvi_min = nanmin(NDVI(:));
        ndvi_max = nanmax(NDVI(:));
        PV = ((NDVI - ndvi_min) ./ (ndvi_max - ndvi_min)).^2;
end

PV(~valid_mask)=NaN;


%% =========================================================================
% 12. LAND SURFACE EMISSIVITY (LSE)
% =========================================================================

epsilon = NaN(size(PV));

switch lower(lse_method)

    % ------------------------------------------------------------
    case 'linear'
        % Standard linear NDVI-based emissivity
        epsilon = 0.004 .* PV + 0.986;

    % ------------------------------------------------------------
    case 'sndvithm'
        % SNDVITHM = Soil–NDVI–Threshold Method (Sobrino et al.)
        % Typical emissivity values:
        eps_w = 0.991;   % Water
        eps_s = 0.964;   % Soil
        eps_v = 0.984;   % Vegetation

        % Classification based on NDVI
        mask_water = NDVI <= 0;
        mask_soilv = NDVI > 0 & NDVI <= NDVI_s;
        mask_vegv  = NDVI >= NDVI_v;
        mask_mixv  = NDVI > NDVI_s & NDVI < NDVI_v;

        % Assign values
        epsilon(mask_water) = eps_w;
        epsilon(mask_soilv) = eps_s;
        epsilon(mask_vegv)  = eps_v;

        % Mixed pixels: linear blend using PV
        epsilon(mask_mixv)  = eps_s + (eps_v - eps_s).*PV(mask_mixv);

    % ------------------------------------------------------------
    otherwise
        error('lse_method must be ''linear'' or ''sndvithm''');
end

epsilon(~valid_mask) = NaN;


% Land Surface Temperature (°C)
LST = TB ./ (1 + (lambda .* TB ./ rho_c).*log(epsilon)) - 273.15;
LST(~valid_mask)=NaN;

disp('✅ Land Surface Temperature successfully computed.');
epsilon(~valid_mask)=NaN;


%% =========================================================================
% 13. LAND SURFACE TEMPERATURE (LST)
% =========================================================================

LST = TB ./ (1 + (lambda .* TB ./ rho_c).*log(epsilon)) - 273.15;
LST(~valid_mask)=NaN;

disp('✅ Land Surface Temperature successfully computed.');


%% =========================================================================
% 14. EXTRACT EPSG CODE FROM RASTER METADATA
% =========================================================================

default_epsg = 32632;
epsg_code = default_epsg;

if isprop(R,'ProjectedCRS') && isprop(R.ProjectedCRS,'Name')
    nameStr = R.ProjectedCRS.Name;
    tok = regexp(nameStr,'UTM zone\s+(\d+)([NS])','tokens');
    if ~isempty(tok)
        zone = str2double(tok{1}{1});
        hemi = tok{1}{2};
        epsg_code = 32600 + zone + (hemi=='S')*100;
    end
end


%% =========================================================================
% 15. SAVE OUTPUT MAPS TO GEOTIFF
% =========================================================================

date_tokens = regexp(file_prefix_L1, '\d{8}', 'match');
if ~isempty(date_tokens)
    acquisition_date = date_tokens{1};
else
    acquisition_date = 'unknownDate';
end

maps = struct('NDVI',NDVI,'NDWI',NDWI,'NDBI',NDBI,'UI',UI,'LST',LST);
names = fieldnames(maps);

for i = 1:numel(names)
    fname = sprintf('%s_%s_map.tif', names{i}, acquisition_date);
    geotiffwrite(fname, maps.(names{i}), R, 'CoordRefSysCode', epsg_code);
    fprintf('✅ Saved: %s\n', fname);
end