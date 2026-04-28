clc
clear all
close all

%% =========================================================================
%  1. INPUT PARAMETERS
% =========================================================================

% Input shapefile name (point cloud for the selected summer composite)
year = 2025;
shp_name = sprintf('PointCloud_CompositeEstate%d.shp', year);

% Elevation band parameters
Num_bands = 4;        % Number of elevation classes
Band_size = 150;      % Elevation interval [m]

% Rural reference buffer (planar distance from urban fabric)
buffer_min = 150;     % [m]
buffer_max = 1500;    % [m]

% Spatial resolution parameters
pixel_size      = 30;                     % [m]
pixel_area_km2  = (pixel_size^2) / 1e6;   % Pixel area [km²]


%% =========================================================================
%  2. LOAD DATA FROM SHAPEFILE
% =========================================================================

[shape, data] = shaperead(shp_name);

% Extract key attributes
LST        = transpose(extractfield(data, 'LST_1'));       % Land Surface Temperature
DTM        = transpose(extractfield(data, 'DTM'));         % Elevation
LULC_full  = transpose(extractfield(data, 'LULC_full'));   % Corine LULC code
Dist_urb   = transpose(extractfield(data, 'Dist_urb'));    % Distance to urban fabric [m]

% Extract only Level‑1 CLC class (the only one actually used)
LULC_1 = str2double(cellstr(extractBetween(string(LULC_full), 1, 1)));


%% =========================================================================
%  3. BUILD MAIN DATA MATRIX
% =========================================================================

% Column indices
iLST      = 1;
iDTM      = 2;
iLULC1    = 3;
iLULCfull = 4;
iDistUrb  = 5;

% Build the matrix (each row = 1 point)
Matrix = [ ...
    LST, ...
    DTM, ...
    LULC_1, ...
    LULC_full, ...
    Dist_urb ];

% Remove rows with missing LST
mask_valid = ~isnan(Matrix(:, iLST));
Matrix = Matrix(mask_valid, :);

fprintf('Removed %d rows with missing LST values.\n', sum(~mask_valid));


%% =========================================================================
%  4. ADD COLUMN FOR PIXEL-WISE SUHII
% =========================================================================

iSUHIIpix = size(Matrix, 2) + 1;
Matrix(:, iSUHIIpix) = nan;


%% =========================================================================
%  5. COMPUTE SUHII BY ELEVATION BAND + PIXEL-WISE SUHII
% =========================================================================
% Output format:
%   [DTM_lower | DTM_upper | Rural_area | Urban_area | LST_rural | LST_urban | SUHII_mean]

results = nan(Num_bands, 7);

for i = 1:Num_bands

    % Elevation limits of the current band
    DTM_low = (i - 1) * Band_size;
    DTM_up  =  i      * Band_size;

    % Select points inside this elevation band
    mask_band = Matrix(:, iDTM) >= DTM_low & Matrix(:, iDTM) < DTM_up;
    Matrix_i = Matrix(mask_band, :);

    if isempty(Matrix_i)
        warning('No points found in elevation band %d–%d m.', DTM_low, DTM_up);
        continue
    end

    % Local variables for this band
    LST_i  = Matrix_i(:, iLST);
    LULC_i = Matrix_i(:, iLULC1);
    Dist_i = Matrix_i(:, iDistUrb);

    % Land-use masks
    urb_mask     = (LULC_i == 1);                      % Urban (LULC class 1)
    rur_mask     = (LULC_i == 2 | LULC_i == 3);        % Rural (LULC class 2 or 3)
    rur_ref_mask = rur_mask & (Dist_i >= buffer_min) & (Dist_i <= buffer_max);

    % Areas [km²]
    Area_urb = sum(urb_mask)     * pixel_area_km2;
    Area_rur = sum(rur_ref_mask) * pixel_area_km2;

    % Mean rural and urban LST
    LST_rural = mean(LST_i(rur_ref_mask), 'omitnan');
    LST_urban = mean(LST_i(urb_mask),     'omitnan');

    % SUHII (Urban minus Rural)
    SUHII = LST_urban - LST_rural;

    % Pixel-wise SUHII
    SUHII_pixel_i = LST_i - LST_rural;

    % Write back pixel-wise SUHII into the main matrix
    idx_global = find(mask_band);
    Matrix(idx_global, iSUHIIpix) = SUHII_pixel_i;

    % Save aggregated statistics for this band
    results(i, :) = [ ...
        DTM_low, ...
        DTM_up, ...
        Area_rur, ...
        Area_urb, ...
        LST_rural, ...
        LST_urban, ...
        SUHII ];
end


%% =========================================================================
%  6. DISPLAY RESULTS
% =========================================================================

results = round(results, 3);

T_results = array2table(results, ...
    'VariableNames', { ...
        'DTM_lower_m', ...
        'DTM_upper_m', ...
        'RuralArea_km2', ...
        'UrbanArea_km2', ...
        'LST_rural_degC', ...
        'LST_urban_degC', ...
        'SUHII_urban_mean_degC' });

disp('SUHII statistics by elevation band:');
disp(T_results);


%% =========================================================================
%  7. GENERATE OUTPUT SHAPEFILE
% =========================================================================

% Rebuild pixel-wise SUHII in original order
SUHII_output = nan(numel(data), 1);
SUHII_output(mask_valid) = Matrix(:, iSUHIIpix);

% SUHII for urban pixels only; NaN elsewhere
SUHII_urb_output = nan(numel(data), 1);
is_urban = (LULC_1 == 1);
SUHII_urb_output(is_urban) = SUHII_output(is_urban);

% Build output shapefile structure
shape_out = shape;

for i = 1:numel(shape_out)
    shape_out(i).fid        = i;
    shape_out(i).LST        = data(i).LST_1;     % Original LST
    shape_out(i).LULC_1     = LULC_1(i);         % Level‑1 CLC class
    shape_out(i).SUHII      = SUHII_output(i);   % Pixel-wise SUHII
    shape_out(i).SUHII_urb  = SUHII_urb_output(i);
end

% Output name
out_name = sprintf('PointCloud_SUHII_%d.shp', year);

% Write shapefile
shapewrite(shape_out, out_name);

fprintf('\nSUHII shapefile successfully created: %s\n', out_name);