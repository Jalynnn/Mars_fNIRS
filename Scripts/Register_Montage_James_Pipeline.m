% Register_Montage_James_Pipeline.m
clear; clc;

%% 1. Path Setup & Toolboxes
project_root    = 'D:\GitHub\Mars_fNIRS';
mni_scripts_dir = fullfile(project_root, 'Scripts', 'MNI_Related_Scripts');
addpath(genpath(mni_scripts_dir));

data_dir    = fullfile(project_root, 'Data');
% results_dir = fullfile(data_dir, 'Derivatives', 'FirstLevel_Results');
results_dir = 'D:\GitHub\Mars_fNIRS\Scripts\GroupLevelOutput';
if ~exist(results_dir, 'dir'), mkdir(results_dir); end

%% 2. Base 41-Channel Montage Pairings
ch_pairs = [
    1, 1;   1, 2;   1, 3;   2, 2;   2, 3;   2, 4;   3, 1;   3, 3;   4, 3;   4, 4;
    3, 10;  9, 1;   9, 9;   9, 10;  10, 9;  10, 10; 10, 11; 11, 10; 11, 11;
    5, 5;   5, 7;   6, 5;   6, 6;   7, 5;   7, 6;   7, 7;   7, 8;   8, 6;   8, 8;
    12, 12; 12, 13; 13, 13; 13, 14; 14, 12; 14, 13; 14, 14; 14, 15;
    15, 14; 15, 15; 16, 12; 16, 15
];
n_ch = size(ch_pairs, 1);

%% 3. Locate All Digitization Files
dig_files = dir(fullfile(data_dir, '**', 'digpts*.txt'));
if isempty(dig_files)
    dig_files = dir(fullfile(data_dir, '**', '*digit*.txt'));
end
fprintf('Found %d digitization text files.\n', length(dig_files));

%% 4. Batch Process Participants
MNIs = cell(length(dig_files), 1);

for i = 1:length(dig_files)
    txt_path   = fullfile(dig_files(i).folder, dig_files(i).name);
    sub_folder = dig_files(i).folder;
    
    fprintf('[%02d/%02d] Processing: %s ... ', i, length(dig_files), dig_files(i).name);
    
    try
        opts = detectImportOptions(txt_path);
        opts.VariableNamingRule = 'preserve';
        raw_tbl = readtable(txt_path, opts);
        xyz_mat = table2array(raw_tbl(:, 2:4));
        
        if size(xyz_mat, 1) < 20
            fprintf('SKIP (Incomplete rows: %d)\n', size(xyz_mat, 1));
            continue;
        end
        
        landmarks  = xyz_mat(1:5, :);
        opt_coords = xyz_mat(6:end, :);
        
        % Write ch_configs.csv
        cfg_csv = fullfile(sub_folder, 'ch_configs.csv');
        fid = fopen(cfg_csv, 'w');
        fprintf(fid, 'Channel,Source,Detector\n');
        for c = 1:n_ch
            fprintf(fid, '%d,%d,%d\n', c, ch_pairs(c, 1), ch_pairs(c, 2));
        end
        fclose(fid);
        
        % Write References.csv (12 rows: Nz, Iz, Ar, Al, ..., Cz)
        ref_csv = fullfile(sub_folder, 'References.csv');
        ref_mat = zeros(12, 3);
        ref_mat(1, :)  = landmarks(1, :); % Nz
        ref_mat(2, :)  = landmarks(5, :); % Iz
        ref_mat(3, :)  = landmarks(2, :); % Ar (RPA)
        ref_mat(4, :)  = landmarks(3, :); % Al (LPA)
        ref_mat(12, :) = landmarks(4, :); % Cz
        
        fid = fopen(ref_csv, 'w');
        fprintf(fid, 'Reference,X,Y,Z\n');
        for r = 1:12
            fprintf(fid, '%d,%.4f,%.4f,%.4f\n', r, ref_mat(r, 1), ref_mat(r, 2), ref_mat(r, 3));
        end
        fclose(fid);
        
        % Write Optodes.csv
        opt_csv = fullfile(sub_folder, 'Optodes.csv');
        fid = fopen(opt_csv, 'w');
        fprintf(fid, 'Optode,X,Y,Z\n');
        for s = 1:16
            fprintf(fid, 'S%d,%.4f,%.4f,%.4f\n', s, opt_coords(s, 1), opt_coords(s, 2), opt_coords(s, 3));
        end
        for d = 1:(size(opt_coords, 1) - 16)
            fprintf(fid, 'D%d,%.4f,%.4f,%.4f\n', d, opt_coords(16 + d, 1), opt_coords(16 + d, 2), opt_coords(16 + d, 3));
        end
        fclose(fid);
        
        % Package F and execute registration
        prev_dir = pwd;
        cd(sub_folder);
        
        clear F;
        F = cell(3, 1);
        F{1, 1} = char(opt_csv, ref_csv, cfg_csv);
        F{2, 1} = 'none';
        F{3, 1} = 'none';
        
        try
            spm_fnirs_spatialpreproc_ui(F);
        catch
            % Catch the optional line 113 load('none') error since POS.mat is already saved
        end
        
        pos_file = fullfile(sub_folder, 'POS.mat');
        if exist(pos_file, 'file')
            load(pos_file, 'R');
            if isfield(R, 'ch') && isfield(R.ch, 'xyzC')
                MNIs{i} = R.ch.xyzC'; % 41 x 3
                fprintf('SUCCESS\n');
            else
                fprintf('FAIL (R.ch.xyzC missing)\n');
            end
        else
            fprintf('FAIL (POS.mat missing)\n');
        end
        
        cd(prev_dir);
    catch ME
        fprintf('ERROR: %s\n', ME.message);
        cd(prev_dir);
    end
end

%% 5. Group Average & NFRI Anatomical Atlas Labeling
valid_mask = ~cellfun(@isempty, MNIs);
fprintf('\nTotal valid registered subjects: %d / %d\n', sum(valid_mask), length(dig_files));

if sum(valid_mask) == 0
    error('No subjects registered successfully.');
end

MNIs_pruned = MNIs(valid_mask);
dataStack   = cat(3, MNIs_pruned{:});
MNIs_Mean   = mean(dataStack, 3, 'omitnan');
MNIs_Mean   = round(MNIs_Mean, 2);

% Save group mean MNI coordinates
save(fullfile(results_dir, 'MNIs_Average.mat'), 'MNIs_Mean');
fprintf('Saved group MNI coordinates to: %s\n', fullfile(results_dir, 'MNIs_Average.mat'));

% Run NFRI Brodmann Area labeling with radius = 30 mm
fprintf('\n--- Running anatomlabel_final (Radius = 30 mm) ---\n');
out_atlas_base = fullfile(results_dir, 'MNI_Mean_BA');
anatomlabel_final(MNIs_Mean, out_atlas_base, 30, 5);

fprintf('\nPipeline completed successfully!\n');
