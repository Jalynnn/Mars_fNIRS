% GroupLevel.m
% Jalynn Nicoly September 29th, 2026
% This is script 3/4 with a focus on linear mixed-effects models
% Input: FirstLevel_Cohort_Stats.mat
% Task: Performing group level statistics
% Output: Group-level statistical models; ROI summaries; FDR-correct
% hypothesis table

%% Section A: Environment Setup & First-Level Data

% Command Window Update
fprintf('--- Starting fNIRS GroupLevel.m ---\n')

% Clear Terminal
clear, clc

% Silence naming conflict warnings
warning('off', 'MATLAB:dispatcher:nameConflict');

%% 1. Set MATLAB Paths

% Add NIRS Toolbox to MATLAB Path
% addpath(genpath('C:\Users\Jalynn\Documents\GitHub\nirs-toolbox')) % Laptop
addpath(genpath('D:\GitHub\nirs-toolbox')) % PC

% Add NIRS SPM 
% addpath('C:\Users\Jalynn\Documents\GitHub\spm12') % Laptop
addpath('D:\GitHub\spm12') % PC

% https://www.nitrc.org/projects/nirs_spm/
% addpath('C:\Users\Jalynn\Downloads\NIRS_SPM_v4_r1') % Laptop
addpath('D:\GitHub\NIRS_SPM_v4_r1') % PC

%% 2. Load First Level Files

% Command Window Update
fprintf('\n--- Loading First Level Data ---\n')

% Set paths through folder to .mat file from FirstLevel
firstLevel_file = 'D:\GitHub\Mars_fNIRS\Output\FirstLevel\FirstLevel_Cohort_Stats.mat'; % PC

% Verify file exists
if ~exist(firstLevel_file, 'file')
    error('File not found: %s\n', firstLevel_file);
end

% Command Window Update
fprintf('Loading: %s ...\n', firstLevel_file);

% Load the variables exported by FirstLevel.m:
% SubjStats_HRF, SubjStats_FIR, Contrasts_HRF
% Can refer to 'FirstLevel_Cohort_StatsDetailed.txt'
load(firstLevel_file, 'SubjStats_HRF', 'SubjStats_FIR', 'Contrasts_HRF');

% Verification summary in command window
fprintf('Successfully loaded First-Level data:\n');
fprintf('   - SubjStats_HRF: %d participants\n', length(SubjStats_HRF));
fprintf('   - SubjStats_FIR: %d participants\n', length(SubjStats_FIR));
fprintf('   - Contrasts_HRF: TaskMatched (%d tasks), Fixation (%d tasks)\n', ...
    length(fieldnames(Contrasts_HRF.TaskMatched)), length(fieldnames(Contrasts_HRF.Fixation)));

% Check demographics are attached
% % Verify SubjStats also carries the metadata into GroupLevel:
% disp(SubjStats_HRF(1).demographics.keys);

%% Section B

% Command Window Update
fprintf('\n--- Loading Registered MNI Coordinates & Defining ROIs ---\n')

% Recall ptps already have their digitization pairs
% We can extract the channel midpoints and classify channels into the 4
% ROIs based on their MNI space coordinates

% Another script was introduced to do this called
% 'Register_Montage_James_Pipeline' so most of this process takes place
% there

% However, the format is:
% Calculate MNI Midpoint from registered Probe1020 via digpts.txt
% Run nfri 10 mm search on XYZABLT.mat and anatomlabel_final.m
% MNI Atlas Key Table to export table with columns: Channel, Source,
% Detector, MNI, BA, Anatomy
% Form ROIs from BAs (left pfc, left parietal, etc.)
% Section C will do the group LME stats to fit on ROIs

%% 3. Define ROIs

% Set up export directory
group_out_dir = 'D:\GitHub\Mars_fNIRS\Output\GroupLevel'; % PC
if ~exist(group_out_dir, 'dir'), mkdir(group_out_dir); end

%% 3a. Define Channel Montage Configurations

% Physical long channels mapped from Aurora montage (41 LONG channels)
% 49 total - 8 SSCs
long_sd_pairs = [
    1, 1;   1, 2;   1, 3;   2, 2;   2, 3;   2, 4;   3, 1;   3, 3;   4, 3;   4, 4;
    3, 10;  9, 1;   9, 9;   9, 10;  10, 9;  10, 10; 10, 11; 11, 10; 11, 11;
    5, 5;   5, 7;   6, 5;   6, 6;   7, 5;   7, 6;   7, 7;   7, 8;   8, 6;   8, 8;
    12, 12; 12, 13; 13, 13; 13, 14; 14, 12; 14, 13; 14, 14; 14, 15;
    15, 14; 15, 15; 16, 12; 16, 15
];

num_channels = size(long_sd_pairs, 1); % 41

% Part of identifying the 41 long channels is excluding the 8 SSCs which
% were previously identified and available in the Output folder
ssc_pairs = [
    4, 16;
    6, 17;
    7, 18;
    8, 19;
    11, 20;
    13, 21;
    14, 22;
    15, 13
];

%% 3b. Load Pre-Computed Group Cortical MNI Coordinates

mni_avg_file = fullfile(group_out_dir, 'MNIs_Average.mat');

% 41 x 3 coords (X, Y, Z)
load(mni_avg_file, 'MNIs_Mean');

% Command window prompt
fprintf('Loaded pre-computed group cortical MNI coordinates for %d channels.\n', size(MNIs_Mean, 1));

%% 3c. Assign 5 Functional ROIs Based on MNI Coordinates & Brodmann Areas

% Method doc (added left/right parietal):
% Uses the MNI midpoints, X = Left/Right, Y = Front/back, Z =
% dorsal/ventral
% - RPFC (BA 10): Rostral Prefrontal Cortex (medial frontopolar: Y >= 68 mm, Z <= 21 mm)
% - L_DLPFC (BA 9/46): Left Dorsolateral Prefrontal Cortex (Y > 50 mm, X < 0)
% - R_DLPFC (BA 9/46): Right Dorsolateral Prefrontal Cortex (Y > 50 mm, X > 0)
% - L_Parietal (BA 7/40): Left Posterior Parietal Cortex (Y <= 50 mm, X < 0)
% - R_Parietal (BA 7/40): Right Posterior Parietal Cortex (Y <= 50 mm, X > 0)

% Pre-allocate a 41.x1 cell array to store ROI labels
roi_assignments = cell(num_channels, 1);

% Loop through each 41 channels
for c = 1:num_channels

    % Extract the group-averaged MNI coords for the current channel
    x_coord = MNIs_Mean(c, 1);
    y_coord = MNIs_Mean(c, 2);
    z_coord = MNIs_Mean(c, 3);
    
    % Prefrontal Cortex Montage (Channels 1-19)
    % Anterior prefrontal channels
    if y_coord > 50
        
        % Isolate frontopolar channels
        % Frontal Pole / BA 10
        if y_coord >= 68 && z_coord <= 21
            roi_assignments{c} = 'RPFC';

        % Rest of prefrontal is left or right DLPFC
        else
            % Left BA 9/46
            if x_coord < 0
                roi_assignments{c} = 'L_DLPFC';
            % Right BA 9/46
            else
                roi_assignments{c} = 'R_DLPFC';
            end
        end
    % If not prefrontal, then parietal
    % Parietal Montage (Channels 20-41, BA 7/40)
    else
        % Left BA 7/40 (Channels 20-29)
        if x_coord < 0
            roi_assignments{c} = 'L_Parietal';
        % Right BA 7/40 (Channels 30-41)
        else
            roi_assignments{c} = 'R_Parietal';
        end
    end
end

% Assemble Master Atlas Table
Master_Atlas_Table = table(...
    (1:num_channels)', ... % Long channels
    long_sd_pairs(:,1), ... % Sources
    long_sd_pairs(:,2), ... % Detectors
    MNIs_Mean(:,1), ... % X
    MNIs_Mean(:,2), ... % Y
    MNIs_Mean(:,3), ... % Z
    roi_assignments, ... % Assigned ROI label
    'VariableNames', {'Channel', 'Source', 'Detector', 'MNI_X', 'MNI_Y', 'MNI_Z', 'ROI'} ...
);

% The following is specific for RQ1
% The CSVs should report their specific BA Labels and not their assigned
% ROIs

% Parse MNI_Mean_BA.csv - Read first
ba_csv_file = fullfile(group_out_dir, 'MNI_Mean_BA.csv');
nfri_primary = strings(num_channels, 1);

% Check if it exists
if exist(ba_csv_file, 'file')
    % Read table
    T_ba = readtable(ba_csv_file, 'ReadVariableNames', false);

    % Current channel
    cur_ch = 0;
    top_p = -1;

    % Loop through table
    % Goal is to collect the highest probability (top_p) for each channel
    % And use it's corresponding BA label instead of ROI label
    for r = 1:height(T_ba)
        % If not nan; Var1 is ch index
        if ~isnan(T_ba.Var1(r))
            % Current channel
            cur_ch = T_ba.Var1(r);
            top_p = -1;
        % If nan, look to Var7 which is the probability overlap
        elseif cur_ch > 0 && cur_ch <= num_channels && ~isnan(T_ba.Var7(r))
            % Var6 is the BA label
            ba_lbl = string(T_ba.Var6{r});
            pr = T_ba.Var7(r);
            if pr > top_p
                top_p = pr;
                nfri_primary(cur_ch) = sprintf('BA %s (%.0f%%)', ba_lbl, pr * 100);
            end
        end
    end
else
    warning('MNI_Mean_BA.csv not found at %s; falling back to ROI BA labels.', ba_csv_file);
end

Master_Atlas_Table.NFRI_BA_Primary = nfri_primary;

% Var1 channel; Var2 reserved empty; Var3 X; Var4 Y; Var5 Z; Var6 BA label; 
% Var 7 probability

%% 3d. Validation & Sanity Checks

% Confirm that there are exactly 41 long channels
if height(Master_Atlas_Table) ~= 41
    warning('Expected exactly 41 long channels, but found %d!', height(Master_Atlas_Table));
end

% Verify no short-separation channel leaked into the 41 analysis channels
is_ssc_leak = ismember(table2array(Master_Atlas_Table(:, {'Source', 'Detector'})), ssc_pairs, 'rows');
if any(is_ssc_leak)
    error('Short-separation channel detected inside the cortical table!');
end

% Verify all 5 method-specified ROIs are populated without empty groups
roi_names = {'RPFC', 'L_DLPFC', 'R_DLPFC', 'L_Parietal', 'R_Parietal'};

% Command window prompt
fprintf('Assigned Channels across Method-Specified ROIs (5 ROIs):\n');

% Goal is to loop through ROIs and flag empty ones
for r = 1:length(roi_names)

    % Count how many channels for each ROI
    % Once printed, all values were confirmed with the montage image
    count = sum(strcmp(string(Master_Atlas_Table.ROI), roi_names{r}));

    % Print warnings or num of channels per ROI
    if count == 0
        warning('ROI %s has 0 channels assigned!', roi_names{r});
    else
        fprintf('  - %-10s: %2d channels\n', roi_names{r}, count);
    end
end

% Save Master Key Table to Output/GroupLevel
atlas_key_file = fullfile(group_out_dir, 'Cortical_41Channels_MNI_Atlas_Key.csv');
writetable(Master_Atlas_Table, atlas_key_file);
save(fullfile(group_out_dir, 'Master_Atlas_Key.mat'), 'Master_Atlas_Table');

% Command window update prompt
fprintf('Master Atlas Key verified and saved to: %s\n', atlas_key_file);

%% Section C

% Fix the covariates and prep for models

% Methods doc quotes
% "Age was mean-centered across participants; sex and the second-destination 
% indicator were dummy-coded (0 = female, 1 = male; 0 = no second destination, 
% 1 = second destination),"
% "All second-level group models included participant age, sex, and a
% binary indicator of whether the dyad visited a second destination as 
% fixed-effect covariates."

% Command window update prompt
fprintf('\n--- Participant Demographics & Covariate Preparation ---\n');

%% 4. Extract Individual Demographics & Metrics from SubjStats

% Num ptps from first level HRF cohort array (recall firstLevel .txt)
num_ptps = length(SubjStats_HRF);

% Initialize metadata containers
% Pre-allocates all to 59x1 arrays to avoid dynamic resizing in upcoming
% loops
ptp_id = zeros(num_ptps, 1); % Ptp ID
session_id = cell(num_ptps, 1); % Dyad ID
age_raw = nan(num_ptps, 1); % Ptp age in years
gender_raw = cell(num_ptps, 1); % Gender 0,1,2
team_perf_raw = nan(num_ptps, 1); % Team Performance 0 or 1
intended_both = nan(num_ptps, 1); % Indicator of second destination
exec_cert_final = nan(num_ptps, 1); % Unsigned individual certainty
exec_cert_signed = nan(num_ptps, 1); % Signed individual certainty
exec_cert_time = nan(num_ptps, 1); % Elapsed decision time (s)
n_switches_raw = nan(num_ptps, 1); % Tricorder switch counts for covariate

% Fallback load from CSV if demographics dictionary lacks new fields
% This section does get used
% SubjStats has 0/59 for both final signed and popup elapsed
demo_csv_file = 'D:\GitHub\Mars_fNIRS\Data\Demographics\fnirs_demographics_spy_V5.csv';
demo_csv_tbl = [];
if exist(demo_csv_file, 'file')
    demo_csv_tbl = readtable(demo_csv_file);
end

% Loop through each ptp to extract demographic and behavioral outcomes
for i = 1:num_ptps

    % Extracts current ptp demographics
    d = SubjStats_HRF(i).demographics;
    
    % Use d.iskey (lowercase 'k') or ismember(..., d.keys) for nirs.util.Dictionary
    % Extract individual identifiers
    if d.iskey('participant_id'), ptp_id(i) = d('participant_id'); else, ptp_id(i) = i; end
    if d.iskey('session_id'), session_id{i} = char(string(d('session_id'))); else, session_id{i} = sprintf('dyad_%02d', ceil(i/2)); end
    if d.iskey('age'), age_raw(i) = d('age'); end
    if d.iskey('gender'), gender_raw{i} = char(string(d('gender'))); end
    if d.iskey('team_performance'), team_perf_raw(i) = d('team_performance'); end
    if d.iskey('intended_both'), intended_both(i) = d('intended_both'); end
    if d.iskey('exec_cert_final'), exec_cert_final(i) = d('exec_cert_final'); end

    % The following subsection only looks at signed certainty and decision
    % time
    % this is because in Preprocess.m, the Hb_preprocessed_cohort.mat did
    % not include these two - rather they were added later because
    % FirstLevel.m takes over an hour to re-run, the CSV fallback was
    % written. 
    % At this point during cleaning, I considered returning to preprocess
    % and FirstLevel to add these components but it costs more effort than
    % it is likely worth than just keeping the CSV fallback available in
    % this section. Happy to revisit on request.
    
    % RQ2 Primary Predictor with Signed Certainty using csv for ptp id
    % lookup
    if d.iskey('exec_cert_final_signed')
        exec_cert_signed(i) = d('exec_cert_final_signed');
    elseif ~isempty(demo_csv_tbl)
        idx = find(demo_csv_tbl.participant_id == ptp_id(i), 1);
        if ~isempty(idx), exec_cert_signed(i) = demo_csv_tbl.exec_cert_final_signed(idx); end
    end
    
    % RQ2 Covariate Elapsed Decision time using csv for ptp id lookup
    if d.iskey('exec_cert_final_popup_elapsed_s')
        exec_cert_time(i) = d('exec_cert_final_popup_elapsed_s');
    elseif ~isempty(demo_csv_tbl)
        idx = find(demo_csv_tbl.participant_id == ptp_id(i), 1);
        if ~isempty(idx), exec_cert_time(i) = demo_csv_tbl.exec_cert_final_popup_elapsed_s(idx); end
    end

    % Tricorder Covariate n_switches_first_block
    if d.iskey('n_switches_first_block')
        n_switches_raw(i) = d('n_switches_first_block');
    elseif ~isempty(demo_csv_tbl) && ismember('n_switches_first_block', demo_csv_tbl.Properties.VariableNames)
        idx = find(demo_csv_tbl.participant_id == ptp_id(i), 1);
        if ~isempty(idx), n_switches_raw(i) = demo_csv_tbl.n_switches_first_block(idx); end
    end
end

%% 5. Predictor Centering & Categorical Coding

%% 5a. Continuous Covariate: Age (Mean-Centered)

% Compute cohort average age ignoring missing values
% omitnan as in Omit NAN not Omniman :) 
mean_age = mean(age_raw, 'omitnan');
age_centered = age_raw - mean_age;

% Log the age range and mean to command window
fprintf('Age centered around cohort mean: %.2f years (range: %d - %d).\n', ...
    mean_age, min(age_raw), max(age_raw));

%% 5b. Categorical Covariate: Gender / Biosex

% Coding: 0 = Female (ref), 1 = Male, 2 = Other
% Pre-allocate string labels and reference codes
gender_labels = strings(num_ptps, 1);
gender_dummy = zeros(num_ptps, 1);

% For each ptp, normalize demo gender code to standard categories
for i = 1:num_ptps
    % Extract gender as lower case
    g_str = lower(strtrim(gender_raw{i}));

    % Female
    if strcmp(g_str, '1') || startsWith(g_str, 'f')
        gender_labels(i) = "Female";
        gender_dummy(i) = 0;

    % Male
    elseif strcmp(g_str, '2') || startsWith(g_str, 'm')
        gender_labels(i) = "Male";
        gender_dummy(i) = 1;
    
    % Other
    else
        gender_labels(i) = "Other";
        gender_dummy(i) = 2;
    end
end

% Cast to categorical with female explicitly declared first as reference
gender_cat = categorical(gender_labels, {'Female', 'Male', 'Other'});

%% 5c. RQ1 Team Performance

% Ensure binary dummy coding: 1 = Correct/True, 0 = Decoy
if ~all(ismember(team_perf_raw(~isnan(team_perf_raw)), [0, 1]))
    error('Unexpected values in team_performance; expected binary 0/1 coding.');
end

% Stored as double with strict binary [0,1] values
team_perf_dummy = team_perf_raw;

%% 5d. RQ2 Predictors and Covariates

% Unsigned Certainty (C) cohort mean centered
mean_cert = mean(exec_cert_final, 'omitnan');
cert_centered = exec_cert_final - mean_cert;

% Signed Certainty (SC) cohort mean centered
mean_sc = mean(exec_cert_signed, 'omitnan');
sc_centered = exec_cert_signed - mean_sc;

% Elapsed Time (Time) cohort mean centered
mean_time = mean(exec_cert_time, 'omitnan');
time_centered = exec_cert_time - mean_time;

% Command window updates for centering summaries for RQ2
fprintf('RQ2 Predictors Centered around Cohort Means:\n');
fprintf('  -> Unsigned Certainty (C):  mean = %.2f (range: %d - %d)\n', mean_cert, min(exec_cert_final), max(exec_cert_final));
fprintf('  -> Signed Certainty (SC):   mean = %.2f (range: %d - %d)\n', mean_sc, min(exec_cert_signed), max(exec_cert_signed));
fprintf('  -> Elapsed Time (s):        mean = %.2f (range: %d - %d)\n', mean_time, min(exec_cert_time), max(exec_cert_time));

% Just going to slide this tricorder covariate in...
% Tricorder Switch Count (Switches) cohort mean centered across tricorder operators
% Compute cohort average switches ignoring missing values
% omitnan as in Omit NAN not Omniman :) 
mean_switches = mean(n_switches_raw, 'omitnan');
switches_centered = n_switches_raw - mean_switches;

% Log the range and mean to command window
fprintf('  -> Tricorder Switches (1st block): mean = %.2f (range: %d - %d, N = %d)\n', ...
    mean_switches, min(n_switches_raw), max(n_switches_raw), sum(~isnan(n_switches_raw)));

%% 5e. Dyadic Covariate & Second Destination

% Code based on whether the dyad visited a second site
% 1 Yes; 0 No
if all(isnan(intended_both))
    second_dest_dummy = zeros(num_ptps, 1);
else
    second_dest_dummy = double(intended_both == 1);
end

%% 5f. Assemble Final Participant Covariates Table

% Combine all raw and centered variables into a master 59 ptp table
Cohort_Covariates = table(ptp_id, session_id, age_raw, age_centered, ...
    gender_cat, gender_dummy, team_perf_raw, team_perf_dummy, ...
    exec_cert_final, cert_centered, ...
    exec_cert_signed, sc_centered, ...
    exec_cert_time, time_centered, ...
    n_switches_raw, switches_centered, ...
    second_dest_dummy, ...
    'VariableNames', {'Participant_ID', 'Session_ID', 'Age', 'Age_Centered', ...
                      'Gender', 'Gender_Dummy', 'Team_Perf', 'Team_Perf_Dummy', ...
                      'Certainty', 'Certainty_Centered', ...
                      'Signed_Certainty', 'SC_Centered', ...
                      'Elapsed_Time', 'Time_Centered', ...
                      'N_Switches', 'Switches_Centered', ...
                      'Intended_Both'});

% Preview the first 8 rows of the table in the command window
fprintf('Cohort Covariate Table created for %d participants:\n', height(Cohort_Covariates));
disp(Cohort_Covariates(1:min(8, height(Cohort_Covariates)), :));

% Save table to Output/GroupLevel
save_cov_file = fullfile(group_out_dir, 'Cohort_Covariates_Table.csv');
writetable(Cohort_Covariates, save_cov_file);
fprintf('Saved Covariate Table to: %s\n', save_cov_file);

%% Section D: Setup Long Table CSVs for both Channel & ROIs

% Command window update prompt
fprintf('\n--- Constructing Track 1 (Channels) & Track 2 (ROIs) ---\n');

%% 6a. Map Second-Destination Indicator for Track Construction

% Map Intended_Both from Section C into Second_Dest_Dummy for downstream LME formulas
Cohort_Covariates.Second_Dest_Dummy = double(Cohort_Covariates.Intended_Both == 1);

%% 6b. Track 1: Channel-Wise Long Table Construction (HbO & HbR)

% Command window update prompt
fprintf('Building Track 1: Channel-level long table...\n');

% The two baseline options
contrast_types = {'TaskMatched', 'Fixation'};

% The select tasks that are transient/events and not sustained/blocks
transient_tasks = {'status_check', 'spam_pop_up', 'tricorder_switch_true', ...
                   'tricorder_switch_decoy', 'certainty_individual', 'certainty_consensus'};

% Empty cell array for per ptp, per task sub-tables
track1_cell = {};

% Loop through each of the baselines
for ct = 1:length(contrast_types)

    % Extract the current baseline
    c_type = contrast_types{ct};

    % If missing struct in baseline
    if ~isfield(Contrasts_HRF, c_type), continue; end
    
    % Retrieve task contrast field names for this baseline set
    task_names = fieldnames(Contrasts_HRF.(c_type));
    
    % Lop through each task in this baseline
    for tn = 1:length(task_names)

        % Extract the current task
        task_name = task_names{tn};
        
        % If this task is transient of sustained
        % Provide numeric indicator
        if ismember(lower(task_name), transient_tasks)
            timescale_name = "Transient";
            timescale_num  = 1;
        else
            timescale_name = "Sustained";
            timescale_num  = 0;
        end
        
        % Extract the 1x~59 arrays for this task
        cs_array = Contrasts_HRF.(c_type).(task_name);

        % N ptps for upcoming loop for this task
        n_ptps = min(height(Cohort_Covariates), length(cs_array));
        
        % Loop three through each ptp for this task in this baseline
        for p = 1:n_ptps

            % Extract channelStat obj for this ptp
            cs = cs_array(p);
            
            % Safe table retrieval
            try
                t_data = cs.table;
            catch
                continue;
            end
            
            % Skip expected unvisited sites or non-tricorder roles
            if isempty(t_data) || height(t_data) == 0 || ~ismember('source', t_data.Properties.VariableNames)
                continue;
            end
            
            % Normalize column types for inner join
            t_data.source = double(t_data.source);
            t_data.detector = double(t_data.detector);
            t_data.type = upper(string(t_data.type));
            
            % Inner join on (source, detector) with Master_Atlas_Table
            % Drops the 8 SSCs and keeps only the 41 valid long cortical channels
            % Drops 8 SSCs retains surviving 41 long channels
            % Includes channel index 1 - 41 and mni coords
            t_merged = innerjoin(t_data, Master_Atlas_Table, ...
                'LeftKeys', {'source', 'detector'}, ...
                'RightKeys', {'Source', 'Detector'});
            
            % Skip if all cortical channels for the ptp/task were pruned
            if isempty(t_merged) || height(t_merged) == 0, continue; end
            
            % Num of surviving long channels for this ptp/task
            n_rows = height(t_merged);
            
            % Subject covariates from Section C (RQ1 + RQ2)
            % Extracts ptp demographics, behavioral, and covariates
            % Replicate across all cahnnel rows for mixed-effects
            sub_id = Cohort_Covariates.Participant_ID(p); % Ptp id
            sess_id = string(Cohort_Covariates.Session_ID(p)); % Dyad id
            age_c = Cohort_Covariates.Age_Centered(p); % age in years mean centered
            g_dum = double(Cohort_Covariates.Gender_Dummy(p)); % numeric gender assigned
            t_perf = Cohort_Covariates.Team_Perf_Dummy(p); % team performance true or decoy 1 or 0
            cert_c = Cohort_Covariates.Certainty_Centered(p); % mean centered unsigned certainty indiv
            sc_c = Cohort_Covariates.SC_Centered(p); % mean centered signed certainty indiv
            time_c = Cohort_Covariates.Time_Centered(p); % mean centered time elapsed in pop up spam
            sw_c = Cohort_Covariates.Switches_Centered(p); % mean centered tricorder switches
            sec_dest = double(Cohort_Covariates.Second_Dest_Dummy(p)); % binary whether second dest site
            
            % Assemble block table for this subject & condition (25 columns)
            block_tbl = table( ...
                repmat(sub_id, n_rows, 1), ... % ptp id
                repmat(sess_id, n_rows, 1), ... % dyad id
                repmat(string(c_type), n_rows, 1), ... % baseline type fixed or task matched for the outer loop
                repmat(string(task_name), n_rows, 1), ... % time contrast name for middle loop
                repmat(timescale_name, n_rows, 1), ... % Transient or sustained current event
                repmat(timescale_num, n_rows, 1), ... % Timescale num matching transient or sustained
                t_merged.type, ... % chromophore HbO or HbR (HbDiff calculated soon)
                t_merged.Channel, ... % cortical channel index 1-41
                t_merged.source, ... % Source index
                t_merged.detector, ... % detector idx
                string(t_merged.ROI), ... % ROI label
                t_merged.MNI_X, ... % X
                t_merged.MNI_Y, ... % Y
                t_merged.MNI_Z, ... % Z
                t_merged.beta, ... % raw beta first level GLM contrast
                t_merged.se, ... % first level standard error
                t_merged.tstat, ... % first level t-stat
                t_merged.p, ... % first level p-val
                repmat(age_c, n_rows, 1), ... % age centered covariate
                repmat(g_dum, n_rows, 1), ... % gender covariate
                repmat(t_perf, n_rows, 1), ... % team performance 
                repmat(cert_c, n_rows, 1), ... % unsigned certainty
                repmat(sc_c, n_rows, 1), ... % signed certainty
                repmat(time_c, n_rows, 1), ... % spam pop up centered time
                repmat(sw_c, n_rows, 1), ... % tricorder switches
                repmat(sec_dest, n_rows, 1), ... % second destination covariate
                'VariableNames', { ...
                    'Participant_ID', 'Session_ID', 'Baseline_Type', 'Task_Contrast', ...
                    'Timescale', 'Timescale_Num', 'Chromophore', 'Channel', 'Source', 'Detector', ...
                    'ROI', 'MNI_X', 'MNI_Y', 'MNI_Z', 'Beta', 'SE', 'T_Stat', 'P_Val', ...
                    'Age_Centered', 'Gender_Dummy', 'Team_Perf_Dummy', 'Certainty_Centered', ...
                    'SC_Centered', 'Time_Centered', 'Switches_Centered', 'Second_Dest_Dummy' ...
                } ...
            );
            
            % append this ptp / task to the cell outside loops
            track1_cell{end+1} = block_tbl;
        end
    end
end

% Exit with error if no valid rows
if isempty(track1_cell)
    error('Track 1 yielded 0 valid rows across all conditions.');
end

% Concat all ptp / tasks into master track one table
Track1_Channel_Long_Table = vertcat(track1_cell{:});

%% 6c. Compute Differential Hemodynamic Response: HbDiff = HbO - HbR (Track 1)

% Command window update
fprintf('Computing exact HbDiff (HbO - HbR) for Track 1 Channels...\n');

% Locate rows corresponding to HbO or HbR
idx_hbo = find(Track1_Channel_Long_Table.Chromophore == "HBO");
idx_hbr = find(Track1_Channel_Long_Table.Chromophore == "HBR");

% Enforce 1-1 row alignment between HbO and HbR before computing |HbO - HbR|
assert(isequal(Track1_Channel_Long_Table.Channel(idx_hbo), Track1_Channel_Long_Table.Channel(idx_hbr)), ...
    'Mismatch in channel alignment between HBO and HBR!');
assert(isequal(Track1_Channel_Long_Table.Participant_ID(idx_hbo), Track1_Channel_Long_Table.Participant_ID(idx_hbr)), ...
    'Mismatch in participant alignment between HBO and HBR!');

% Signed difference and absolute magnitude |HbO - HbR|
signed_diff_beta = Track1_Channel_Long_Table.Beta(idx_hbo) - Track1_Channel_Long_Table.Beta(idx_hbr);
diff_beta = abs(signed_diff_beta);

% Prior to using absolute
% Exact differential formulas
% Beta_HbO - Beta_HbR
% diff_beta = Track1_Channel_Long_Table.Beta(idx_hbo) - Track1_Channel_Long_Table.Beta(idx_hbr);

% Propagated standard error (note: first-order SE approximation for |X| is still sqrt(Var(X)) away from 0)
diff_se = sqrt(Track1_Channel_Long_Table.SE(idx_hbo).^2 + Track1_Channel_Long_Table.SE(idx_hbr).^2);

% Beta_diff / SE_diff
diff_t = diff_beta ./ diff_se;

% two tailed normal approx p-val
diff_p = 2 * (1 - normcdf(abs(diff_t)));

% Construct Track 1 HbDiff slice via HbO clone
t1_diff = Track1_Channel_Long_Table(idx_hbo, :);
t1_diff.Chromophore = repmat("HBDIFF", height(t1_diff), 1);
t1_diff.Beta = diff_beta;
t1_diff.SE = diff_se;
t1_diff.T_Stat = diff_t;
t1_diff.P_Val = diff_p;

% Append HbDiff to HbO and HbR so track one contains all three
Track1_Channel_Long_Table = [Track1_Channel_Long_Table; t1_diff];

% Command window update
fprintf('Track 1 Long Table finalized: %d rows.\n', height(Track1_Channel_Long_Table));

%% 6d. Track 2: Aggregate Channel Estimates into 5 Functional ROIs

% Command window update
fprintf('Building Track 2: ROI-averaged long table...\n');

% Partition track one rows into unqiue ptp x dyad id x baseline x task x
% timescale x chrome x ROI
[roi_groups, grp_p_id, grp_s_id, grp_base, grp_task, grp_tscale, grp_tnum, grp_chrom, grp_roi] = findgroups( ...
    Track1_Channel_Long_Table.Participant_ID, ...
    Track1_Channel_Long_Table.Session_ID, ...
    Track1_Channel_Long_Table.Baseline_Type, ...
    Track1_Channel_Long_Table.Task_Contrast, ...
    Track1_Channel_Long_Table.Timescale, ...
    Track1_Channel_Long_Table.Timescale_Num, ...
    Track1_Channel_Long_Table.Chromophore, ...
    Track1_Channel_Long_Table.ROI ...
);

% Calculate average beta, se, t-test across all survivng long channels for
% each ROI
% Record how many valid channels contributed to each ptp ROI estimate
mean_beta = splitapply(@(x) mean(x, 'omitnan'), Track1_Channel_Long_Table.Beta, roi_groups);
mean_se = splitapply(@(x) mean(x, 'omitnan'), Track1_Channel_Long_Table.SE, roi_groups);
mean_t = splitapply(@(x) mean(x, 'omitnan'), Track1_Channel_Long_Table.T_Stat, roi_groups);
chan_cnt = splitapply(@(x) sum(~isnan(x)), Track1_Channel_Long_Table.Beta, roi_groups);

% Map participant-level covariates matching by Participant_ID to re-attach
% subj-level predictors
[~, cov_idx] = ismember(double(grp_p_id), double(Cohort_Covariates.Participant_ID));

% Creates the 19 column ROI averaged long table for group level LME
Track2_ROI_Long_Table = table( ...
    grp_p_id, grp_s_id, grp_base, grp_task, grp_tscale, grp_tnum, grp_chrom, grp_roi, ...
    chan_cnt, mean_beta, mean_se, mean_t, ...
    Cohort_Covariates.Age_Centered(cov_idx), ...
    double(Cohort_Covariates.Gender_Dummy(cov_idx)), ...
    Cohort_Covariates.Team_Perf_Dummy(cov_idx), ...
    Cohort_Covariates.Certainty_Centered(cov_idx), ...
    Cohort_Covariates.SC_Centered(cov_idx), ...
    Cohort_Covariates.Time_Centered(cov_idx), ...
    Cohort_Covariates.Switches_Centered(cov_idx), ...
    double(Cohort_Covariates.Second_Dest_Dummy(cov_idx)), ...
    'VariableNames', { ...
        'Participant_ID', 'Session_ID', 'Baseline_Type', 'Task_Contrast', ...
        'Timescale', 'Timescale_Num', 'Chromophore', 'ROI', ...
        'Num_Channels', 'Beta_ROI', 'SE_ROI', 'T_Stat_ROI', ...
        'Age_Centered', 'Gender_Dummy', 'Team_Perf_Dummy', ...
        'Certainty_Centered', 'SC_Centered', 'Time_Centered', ...
        'Switches_Centered', ...
        'Second_Dest_Dummy' ...
    } ...
);

% Command window update for length of rows and cols
fprintf('Track 2 Long Table generated (HBO, HBR, HBDIFF): %d rows x %d columns.\n', ...
    height(Track2_ROI_Long_Table), width(Track2_ROI_Long_Table));

%% 6e. Cast Factors to Categorical & Export Track Deliverables

% Command window update
fprintf('Casting grouping and model factors to categorical...\n');

% Explicitly set reference levels for dummy-coded categorical predictors (Female = ref, NoSecond = ref)
% Convert numeric dummy to categorical; gender has 0,1,2 and
% seconddestdummy has 0 and 1
Track1_Channel_Long_Table.Gender_Dummy      = categorical(double(Track1_Channel_Long_Table.Gender_Dummy), [0, 1, 2], {'Female', 'Male', 'Other'});
Track2_ROI_Long_Table.Gender_Dummy          = categorical(double(Track2_ROI_Long_Table.Gender_Dummy), [0, 1, 2], {'Female', 'Male', 'Other'});
Track1_Channel_Long_Table.Second_Dest_Dummy = categorical(double(Track1_Channel_Long_Table.Second_Dest_Dummy), [0, 1], {'NoSecond', 'Second'});
Track2_ROI_Long_Table.Second_Dest_Dummy     = categorical(double(Track2_ROI_Long_Table.Second_Dest_Dummy), [0, 1], {'NoSecond', 'Second'});

% Cast shared structural grouping columns to categorical across both tables
% Loops instead of initial direct contrast comparison
% Converts remining structual grouping to categorical
% fitlme wil treat session id as random-effect grouping factor
cat_cols = {'Session_ID', 'Participant_ID', 'ROI', 'Chromophore', 'Timescale', 'Baseline_Type', 'Task_Contrast'};
for k = 1:length(cat_cols)
    col = cat_cols{k};
    Track1_Channel_Long_Table.(col) = categorical(string(Track1_Channel_Long_Table.(col)));
    Track2_ROI_Long_Table.(col) = categorical(string(Track2_ROI_Long_Table.(col)));
end

% Export Deliverables to Mars_fNIRS\Output\GroupLevel
% Define output file paths
track1_file = fullfile(group_out_dir, 'Track1_Channel_Long_Table.csv');
track2_file = fullfile(group_out_dir, 'Track2_ROI_Long_Table.csv');
save_tracks_mat = fullfile(group_out_dir, 'GroupLevel_Tracks_Data.mat');

% Write both long tables to CSVs
writetable(Track1_Channel_Long_Table, track1_file);
writetable(Track2_ROI_Long_Table, track2_file);
save(save_tracks_mat, 'Track1_Channel_Long_Table', 'Track2_ROI_Long_Table');

% Confirm export complete and list file directory in command window
fprintf('Section D complete. Saved track files to:\n  -> %s\n  -> %s\n  -> %s\n', ...
    track1_file, track2_file, save_tracks_mat);

%% Section E: Manipulation Check with Baseline Contrasts

% Command window update prompt
fprintf('\n--- Running Validation LME Models ---\n');

% Set primary baseline filter to TaskMatched
% Task match is used for baseline contrasts
primary_baseline = 'TaskMatched';

% Initlaize cells for tables like in Section D
% One for track 1 (Channels) and the other for track 2 (ROIs)
validation_chan_rows = {};
validation_roi_rows = {};

% Extract the unique categorical factor levels from track one and two
chroms = categories(Track1_Channel_Long_Table.Chromophore); % HbDiff, HbO, HbR
tasks = categories(Track1_Channel_Long_Table.Task_Contrast); % All tasks
channels = unique(Track1_Channel_Long_Table.Channel); % All cortical coords
rois = categories(Track2_ROI_Long_Table.ROI); % All 5 ROIs

%% 7a. Track 1: Channel-Level Intercept-Only Models (H0: beta0 = 0)
% Formula: Beta ~ 1 + (1 | Session_ID)

% Command window update prompt
fprintf('Evaluating Track 1: Channel manipulation checks across 41 channels...\n');

% Loop through each chromophore (HbDiff, HbO, HbR)
for c = 1:length(chroms)

    % Extract current chromophore label
    chrom_str = chroms{c};
    
    % For each of the 41 channels
    for ch_idx = 1:length(channels)

        % Extract current channel 1-41
        chan_num = channels(ch_idx);
        
        % For each task contrasts
        for t = 1:length(tasks)

            % Extract current task
            task_str = tasks{t};
            
            % Create row mask filtering Track 1's long table made in a
            % prior section
            sub_idx = Track1_Channel_Long_Table.Baseline_Type == primary_baseline & ...
                      Track1_Channel_Long_Table.Chromophore == chrom_str & ...
                      Track1_Channel_Long_Table.Channel == chan_num & ...
                      Track1_Channel_Long_Table.Task_Contrast == task_str;
                  
            % Similar to RQ1 and RQ2 later, here we want to add a status
            % check for the CSV output

            % Locale first matching row for metadata
            meta_idx = find(sub_idx, 1, 'first');
            if isempty(meta_idx), continue; end
            
            % Extract the valid observations for this channel x task
            sub_tbl = Track1_Channel_Long_Table(sub_idx, :);
            sub_tbl = sub_tbl(~isnan(sub_tbl.Beta), :);
            
            try
                % Abort if zero non-NaN contrast betas remain
                if height(sub_tbl) == 0
                    error('No valid observations remaining.');
                end
                
                % Drop unused Session_ID factor levels so random-effect design matrix has clean dimensions
                sub_tbl.Session_ID = removecats(categorical(sub_tbl.Session_ID));

                % MODEL 1: BASELINE LME with dyad random intercept for
                % channels
                lme = fitlme(sub_tbl, 'Beta ~ 1 + (1 | Session_ID)');
                
                % Extract fixed-effect intercept estimate, SE, t-stat,
                % p-val, and 95% CI
                b0 = lme.Coefficients.Estimate(1);
                se0 = lme.Coefficients.SE(1);
                tstat = lme.Coefficients.tStat(1);
                pval = lme.Coefficients.pValue(1);
                ci = lme.coefCI;
                
                % Append Model Status row among other metadata info for
                % manip check CSVs
                validation_chan_rows(end+1, 1:17) = { ...
                    string(primary_baseline), string(task_str), ...
                    string(Track1_Channel_Long_Table.Timescale(meta_idx)), ...
                    Track1_Channel_Long_Table.Timescale_Num(meta_idx), ...
                    string(chrom_str), chan_num, ...
                    Track1_Channel_Long_Table.Source(meta_idx), ...
                    Track1_Channel_Long_Table.Detector(meta_idx), ...
                    string(Track1_Channel_Long_Table.ROI(meta_idx)), height(sub_tbl), ...
                    b0, se0, tstat, pval, ci(1,1), ci(1,2), "OK" ...
                };
            catch ME
                % Record NaN placeholder row with diagnostic status if model fails to converge or lacks data
                status_msg = "Skipped: " + string(ME.message);
                validation_chan_rows(end+1, 1:17) = { ...
                    string(primary_baseline), string(task_str), ...
                    string(Track1_Channel_Long_Table.Timescale(meta_idx)), ...
                    Track1_Channel_Long_Table.Timescale_Num(meta_idx), ...
                    string(chrom_str), chan_num, ...
                    Track1_Channel_Long_Table.Source(meta_idx), ...
                    Track1_Channel_Long_Table.Detector(meta_idx), ...
                    string(Track1_Channel_Long_Table.ROI(meta_idx)), height(sub_tbl), ...
                    NaN, NaN, NaN, NaN, NaN, NaN, status_msg ...
                };
            end
        end
    end
end

% Convert accumulated channel validation rows into a structured MATLAB table
val_chan_cols = { ...
    'Baseline_Type', 'Task_Contrast', 'Timescale', 'Timescale_Num', ...
    'Chromophore', 'Channel', 'Source', 'Detector', 'ROI', 'N_Obs', ...
    'Beta_0', 'SE', 'T_Stat', 'P_Val', 'CI_Lower', 'CI_Upper', 'Model_Status' ...
};
if isempty(validation_chan_rows)
    Table_Validation_Channels = cell2table(cell(0, length(val_chan_cols)), 'VariableNames', val_chan_cols);
else
    Table_Validation_Channels = cell2table(validation_chan_rows, 'VariableNames', val_chan_cols);
end

% Command window update prompt
fprintf('Track 1 Channel Validation complete: %d rows recorded (%d estimated).\n', ...
    height(Table_Validation_Channels), sum(Table_Validation_Channels.Model_Status == "OK"));

%% 7b. Track 2: ROI-Level Intercept-Only Models (H0: beta0 = 0)
% Tests whether ROI-averaged task activation differs significantly from baseline (0) across the 5 ROIs:
% Formula: Beta_ROI ~ 1 + (1 | Session_ID)

% Command window update
fprintf('Evaluating Track 2: ROI manipulation checks across %d ROIs and %d chromophores...\n', ...
    length(rois), length(chroms));

% Loop through each chromo (HbDiff, HbO, HbR)
for c = 1:length(chroms)

    % Extract current chromo
    chrom_str = chroms{c};
    
    % Loop through each one of the 5 ROIs
    for r = 1:length(rois)

        % Extract the current ROI
        roi_str = rois{r};
        
        % Loop through each of the task contrasts
        for t = 1:length(tasks)

            % Extract the current task
            task_str = tasks{t};
            
            % Create row filtering based on Track two long table from
            % previous section
            sub_idx = Track2_ROI_Long_Table.Baseline_Type == primary_baseline & ...
                      Track2_ROI_Long_Table.Chromophore == chrom_str & ...
                      Track2_ROI_Long_Table.ROI == roi_str & ...
                      Track2_ROI_Long_Table.Task_Contrast == task_str;
                  
            % Find the first matching row for metadata
            meta_idx = find(sub_idx, 1, 'first');
            % skip if baseline x chromo x roi x task does not exist in
            % track two ROIs
            if isempty(meta_idx), continue; end

            % slice track two to the matching ptp row for this ROI x task
            sub_tbl = Track2_ROI_Long_Table(sub_idx, :);
            % Drop any rows with missing (NaN) ROI-averaged contrast estimates
            sub_tbl = sub_tbl(~isnan(sub_tbl.Beta_ROI), :);
            
            % Baseline LME on baseline only but with ROI instead of
            % channels
            try
                % Trigger catch fallback if zero valid participant observations remain
                if height(sub_tbl) == 0
                    error('No valid observations remaining.');
                end
                
                % Remove unobserved Session_ID levels prior to fitting random-effect grouping structure
                sub_tbl.Session_ID = removecats(categorical(sub_tbl.Session_ID));

                % MODEL 1: BASELINE LME with dyad random intercept for ROIs
                lme = fitlme(sub_tbl, 'Beta_ROI ~ 1 + (1 | Session_ID)');
                
                b0 = lme.Coefficients.Estimate(1); % intercept estiamte
                se0 = lme.Coefficients.SE(1); % SE
                tstat = lme.Coefficients.tStat(1); % t-test
                pval = lme.Coefficients.pValue(1); % p-val
                ci = lme.coefCI; % 95% CI
                
                % Append 14-column estimated result row to the Track 2 validation cell accumulator
                validation_roi_rows(end+1, 1:14) = { ...
                    string(primary_baseline), ... % Baseline_Type ('TaskMatched')
                    string(task_str), ... % Task_Contrast name
                    string(Track2_ROI_Long_Table.Timescale(meta_idx)), ... % Timescale ('Transient' or 'Sustained')
                    Track2_ROI_Long_Table.Timescale_Num(meta_idx), ... % Timescale_Num (1 or 0)
                    string(chrom_str), ... % Chromophore ('HBO', 'HBR', 'HBDIFF')
                    string(roi_str), ... % Functional ROI label
                    height(sub_tbl), ... % N_Obs (number of valid participants)
                    b0, se0, tstat, pval, ci(1,1), ci(1,2), ... % Model parameters & 95% CI
                    "OK" ... % Model_Status flag
                };
            catch ME
                % Print warning to Command Window if an ROI-level validation model fails
                warning('ROI model failed for [%s - %s - %s]: %s', chrom_str, roi_str, task_str, ME.message);

                % Format diagnostic status message for table logging
                status_msg = "Skipped: " + string(ME.message);
                
                % Append NaN placeholder row so every Chromophore x ROI x Task combination remains in the CSV
                validation_roi_rows(end+1, 1:14) = { ...
                    string(primary_baseline), ... % Baseline_Type
                    string(task_str), ... % Task_Contrast
                    string(Track2_ROI_Long_Table.Timescale(meta_idx)), ... % Timescale
                    Track2_ROI_Long_Table.Timescale_Num(meta_idx), ... % Timescale_Num
                    string(chrom_str), ... % Chromophore
                    string(roi_str), ... % Functional ROI
                    height(sub_tbl), ... % N_Obs
                    NaN, NaN, NaN, NaN, NaN, NaN, ... % Unestimated statistics filled with NaN
                    status_msg ... % Diagnostic failure reason
                };
            end
        end
    end
end

% Define standardized 14-column headers for the ROI-level manipulation check table
val_roi_cols = { ...
    'Baseline_Type', 'Task_Contrast', 'Timescale', 'Timescale_Num', ...
    'Chromophore', 'ROI', 'N_Obs', 'Beta_0', 'SE', 'T_Stat', 'P_Val', 'CI_Lower', 'CI_Upper', 'Model_Status' ...
};

% Convert accumulated ROI cell rows into a MATLAB table (handling empty edge case gracefully)
if isempty(validation_roi_rows)
    Table_Validation_ROI = cell2table(cell(0, length(val_roi_cols)), 'VariableNames', val_roi_cols);
else
    Table_Validation_ROI = cell2table(validation_roi_rows, 'VariableNames', val_roi_cols);
end

% Report total ROI rows recorded vs. successfully estimated models
fprintf('Track 2 ROI Validation complete: %d rows recorded (%d estimated).\n', ...
    height(Table_Validation_ROI), sum(Table_Validation_ROI.Model_Status == "OK"));

%% 7c. FIR Impulse Shape Validation Check

% fprintf('Verifying FIR dataset availability from SubjStats_FIR...\n');
% 
% if exist('SubjStats_FIR', 'var') && ~isempty(SubjStats_FIR)
%     fprintf('FIR dataset available: %d participants loaded for curve inspection.\n', length(SubjStats_FIR));
% else
%     warning('SubjStats_FIR not found in memory. Proceeding without FIR array inspection.');
% end

%% 7d. Export Validation Deliverables & Print Significant Summary

% Construct output files
val_chan_csv = fullfile(group_out_dir, 'Table_Validation_ManipulationChecks_Channels.csv');
val_roi_csv = fullfile(group_out_dir, 'Table_Validation_ManipulationChecks_ROI.csv');
val_mat = fullfile(group_out_dir, 'GroupLevel_Validation_Models.mat');

% Export channel and ROI manip check tables to CSVs
writetable(Table_Validation_Channels, val_chan_csv);
writetable(Table_Validation_ROI, val_roi_csv);
save(val_mat, 'Table_Validation_Channels', 'Table_Validation_ROI');

% Print confirmation to command window
fprintf('Section E complete. Saved validation deliverables to:\n  -> %s\n  -> %s\n  -> %s\n', ...
    val_chan_csv, val_roi_csv, val_mat);

% Summary display of significant manipulation checks (p < .05, uncorrected)
sig_roi = Table_Validation_ROI(Table_Validation_ROI.P_Val < 0.05, :);
fprintf('\nSignificant ROI-level manipulation checks (p < .05, uncorrected): %d / %d\n', ...
    height(sig_roi), height(Table_Validation_ROI));

% Displays top 12 sig ROI manip checks
disp(head(sig_roi(:, {'Task_Contrast', 'Chromophore', 'ROI', 'Beta_0', 'T_Stat', 'P_Val'}), 12));

%% Section F: RQ1 Team Performance LME Models

% Evaluates whether cortical hemodynamic responses differ between teams that selected the
% true target site first (Team_Perf_Dummy = 1) vs. the decoy site first (Team_Perf_Dummy = 0),
% controlling for mean-centered age, biological sex, second-destination visit, and dyadic clustering:
% * Formula: Beta ~ 1 + Team_Perf_Dummy + Age_Centered + Gender_Dummy + Second_Dest_Dummy + (1 | Session_ID)
% * Weights: Normalized inverse-variance precision weights w_i = (1 / SE_i^2) / mean(1 / SE^2)

% Command window update prompt
fprintf('\n--- Evaluating RQ1 Team Performance LME Models ---\n');

% Restrict RQ1 group models to the primary task-matched baseline family
primary_baseline = 'TaskMatched';

% Initialize cell accumulators for primary Team_Perf_Dummy summaries and full-term covariate breakdowns
rq1_chan_rows      = {};
rq1_chan_full_rows = {};
rq1_roi_rows       = {};
rq1_roi_full_rows  = {};

% Extract unique factor levels from Track 1 and Track 2 to define the evaluation grid
chroms = categories(Track1_Channel_Long_Table.Chromophore); % HbDiff, HbO, HbR
channels = unique(Track1_Channel_Long_Table.Channel); % 1-41
rois = categories(Track2_ROI_Long_Table.ROI); % 5 ROIs

% Evaluate all 11 mission task contrasts (note: site-specific contrasts where all participants share
% a single Team_Perf_Dummy level are safely logged as "Skipped: Single outcome level" in try/catch)
% Initially debated on only 7 general mission tasks - opted to report all
% 11 in CSVs but need to skip in contrasts
% rq1_tasks = { ...
%     'planning_individual', ...
%     'planning_team', ...
%     'status_check', ...
%     'spam_pop_up', ...
%     'tricorder_switch', ...
%     'certainty_individual', ...
%     'certainty_consensus', ...
%     'at_true_site', ...
%     'at_decoy_site', ...
%     'enroute_true_site', ...
%     'enroute_decoy_site' ...
% };

% Was initially hard coded but changed following tricorder split and will
% help with 3 different contrasts task stuff
rq1_tasks = categories(removecats(Track1_Channel_Long_Table.Task_Contrast( ...
    Track1_Channel_Long_Table.Baseline_Type == primary_baseline)));

% Define standardized column headers for Track 1 (Channel) and Track 2 (ROI) primary summary tables
chan_col_names = { ...
    'Baseline_Type', 'Task_Contrast', 'Timescale', 'Timescale_Num', ...
    'Chromophore', 'Channel', 'Source', 'Detector', 'ROI', 'N_Obs', ...
    'Beta_TeamPerf', 'SE', 'T_Stat', 'DF', 'P_Val', 'CI_Lower', 'CI_Upper', 'Cohens_d', 'Model_Status' ...
};

roi_col_names = { ...
    'Baseline_Type', 'Task_Contrast', 'Timescale', 'Timescale_Num', ...
    'Chromophore', 'ROI', 'N_Obs', 'Beta_TeamPerf', 'SE', 'T_Stat', 'DF', ...
    'P_Val', 'CI_Lower', 'CI_Upper', 'Cohens_d', 'Model_Status' ...
};

% Define standardized column headers for full-term covariate & random-effect variance tables
full_chan_cols = { ...
    'Baseline_Type', 'Task_Contrast', 'Timescale', 'Chromophore', ...
    'Channel', 'Source', 'Detector', 'ROI', 'N_Obs', ...
    'Effect_Type', 'Term', 'Estimate', 'SE', 'T_Stat', 'DF', 'P_Val', ...
    'CI_Lower', 'CI_Upper', 'Partial_EtaSq_or_Var', 'ICC', 'Model_Status' ...
};

full_roi_cols = { ...
    'Baseline_Type', 'Task_Contrast', 'Timescale', 'Chromophore', 'ROI', 'N_Obs', ...
    'Effect_Type', 'Term', 'Estimate', 'SE', 'T_Stat', 'DF', 'P_Val', ...
    'CI_Lower', 'CI_Upper', 'Partial_EtaSq_or_Var', 'ICC', 'Model_Status' ...
};

%% 8a. Track 1: Channel-Level Precision-Weighted LME Models (RQ1)

fprintf('Evaluating Track 1: Precision-weighted channel models across %d channels and %d tasks...\n', ...
    length(channels), length(rq1_tasks));

% These upcoming sections should look very similar from Section E looking
% at the baseline contrasts, near identical

% Outer loop: iterate through each chromophore metric ('HBDIFF', 'HBO', 'HBR')
for c = 1:length(chroms)

    % Extract the current chromo
    chrom_str = chroms{c};
    
    % Middle loop: iterate through each of the 41 long cortical channels
    for ch_idx = 1:length(channels)

        % Extract the current channel
        chan_num = channels(ch_idx);
        
        % Inner loop: iterate through each task contrast condition
        for t = 1:length(rq1_tasks)

            % Extract the current task
            task_str = rq1_tasks{t};
            
            % Create logical row mask filtering Track 1 to the active baseline, chromophore, channel, and task
            sub_idx = Track1_Channel_Long_Table.Baseline_Type == primary_baseline & ...
                      Track1_Channel_Long_Table.Chromophore == chrom_str & ...
                      Track1_Channel_Long_Table.Channel == chan_num & ...
                      Track1_Channel_Long_Table.Task_Contrast == task_str;
            
            % Locate first matching row to extract static spatial/timescale metadata even if model fails
            meta_idx = find(sub_idx, 1, 'first');
            if isempty(meta_idx), continue; end
            
            % Extract only required model columns and perform listwise 
            % deletion of missing values
            sub_tbl = Track1_Channel_Long_Table(sub_idx, :);
            req_vars = {'Beta', 'SE', 'Team_Perf_Dummy', 'Age_Centered', 'Gender_Dummy', 'Second_Dest_Dummy', 'Session_ID'};
            sub_tbl = sub_tbl(:, intersect(req_vars, sub_tbl.Properties.VariableNames));
            sub_tbl = rmmissing(sub_tbl);
            
            % Assemble shared metadata prefix for full-model covariate export
            base_meta_ch = { ...
                string(primary_baseline), string(task_str), ...
                string(Track1_Channel_Long_Table.Timescale(meta_idx)), ...
                string(chrom_str), chan_num, ...
                Track1_Channel_Long_Table.Source(meta_idx), ...
                Track1_Channel_Long_Table.Detector(meta_idx), ...
                string(Track1_Channel_Long_Table.ROI(meta_idx)), height(sub_tbl) ...
            };
            
            try
                % Abort if zero complete participant observations remain
                n_sub = height(sub_tbl);
                if n_sub == 0
                    error('No valid observations remaining after SNR pruning / missing data (N = 0).');
                end
                                % Abort if binary outcome Team_Perf_Dummy has < 2 levels 
                % (e.g., site-specific contrasts)
                % Since we are in RQ1, the first site between teams won't
                % work
                if numel(unique(sub_tbl.Team_Perf_Dummy)) < 2
                    error('Single Team_Perf_Dummy level (N = %d; all outcomes = %d).', ...
                        n_sub, unique(sub_tbl.Team_Perf_Dummy));
                end
                if n_sub <= 5
                    error('Insufficient sample size (N = %d <= 5 fixed-effect parameters).', n_sub);
                end
                
                % Compute mean-normalized inverse-variance weights 
                % (1 / SE^2) with variance floor (1e-6)
                raw_w = 1 ./ max(sub_tbl.SE .^ 2, 1e-6);
                w_vec = raw_w / mean(raw_w);
                
                % Drop unobserved categorical levels so design matrices 
                % remain full-rank
                sub_tbl.Gender_Dummy = removecats(categorical(sub_tbl.Gender_Dummy));
                sub_tbl.Second_Dest_Dummy = removecats(categorical(sub_tbl.Second_Dest_Dummy));
                sub_tbl.Session_ID = removecats(categorical(sub_tbl.Session_ID));
                
                % Include Second_Dest_Dummy covariate only when both levels (0 and 1) occur in this task subset
                % MODEL 2 RQ1 for channels
                % if numel(categories(sub_tbl.Second_Dest_Dummy)) > 1
                formula_str = 'Beta ~ 1 + Team_Perf_Dummy + Age_Centered + Gender_Dummy + Second_Dest_Dummy + (1 | Session_ID)';
                % else
                %     fprintf('Else statement entered MODEL 2 RQ1 Channels');
                %     formula_str = 'Beta ~ 1 + Team_Perf_Dummy + Age_Centered + Gender_Dummy + (1 | Session_ID)';
                % end
                
                % Fit precision-weighted REML linear mixed-effects model with dyad random intercept
                % MODEL 2 RQ1 for channels
                lme = fitlme(sub_tbl, formula_str, 'Weights', w_vec);
                
                % Locate the fixed-effect coefficient row for Team_Perf_Dummy
                team_idx = find(strcmp(lme.CoefficientNames, 'Team_Perf_Dummy'));
                if isempty(team_idx)
                    error('Team_Perf_Dummy dropped due to collinearity (N = %d).', n_sub);
                end
                
                % Extract fixed-effect estimate, SE, t-stat, p-value, degrees of freedom, 95% CI, and Cohen's d
                b1 = lme.Coefficients.Estimate(team_idx);
                se1 = lme.Coefficients.SE(team_idx);
                tstat = lme.Coefficients.tStat(team_idx);
                pval = lme.Coefficients.pValue(team_idx);

                df = lme.Coefficients.DF(team_idx);
                if df <= 0 || isnan(pval)
                    error('Saturated model with zero residual degrees of freedom (N = %d, df = %g).', n_sub, df);
                end
                
                ci = lme.coefCI;
                ci_l = ci(team_idx, 1);
                ci_u = ci(team_idx, 2);
                cohens_d = tstat / sqrt(n_sub);
                
                % Record full fixed/random covariate breakdown and primary Team_Perf_Dummy summary row
                rq1_chan_full_rows = extract_lme_full_terms(lme, base_meta_ch, rq1_chan_full_rows, "OK");
                rq1_chan_rows(end+1, 1:19) = { ...
                    string(primary_baseline), string(task_str), ...
                    string(Track1_Channel_Long_Table.Timescale(meta_idx)), ...
                    Track1_Channel_Long_Table.Timescale_Num(meta_idx), ...
                    string(chrom_str), chan_num, ...
                    Track1_Channel_Long_Table.Source(meta_idx), ...
                    Track1_Channel_Long_Table.Detector(meta_idx), ...
                    string(Track1_Channel_Long_Table.ROI(meta_idx)), n_sub, ...
                    b1, se1, tstat, df, pval, ci_l, ci_u, cohens_d, "OK" ...
                };
            catch ME
                % Record NaN placeholder rows with diagnostic status to preserve rectangular CSV grid
                err_txt = string(ME.message);
                if contains(err_txt, "full column rank")
                    err_txt = sprintf("Collinear covariates in small subsample (rank deficient; N = %d).", height(sub_tbl));
                end
                status_msg = "Skipped: " + err_txt;
                rq1_chan_rows(end+1, 1:19) = { ...
                    string(primary_baseline), string(task_str), ...
                    string(Track1_Channel_Long_Table.Timescale(meta_idx)), ...
                    Track1_Channel_Long_Table.Timescale_Num(meta_idx), ...
                    string(chrom_str), chan_num, ...
                    Track1_Channel_Long_Table.Source(meta_idx), ...
                    Track1_Channel_Long_Table.Detector(meta_idx), ...
                    string(Track1_Channel_Long_Table.ROI(meta_idx)), height(sub_tbl), ...
                    NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, status_msg ...
                };
                rq1_chan_full_rows(end+1, 1:21) = [base_meta_ch, { ...
                    "Unestimated", "N/A", NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, status_msg ...
                }];
            end
        end
    end
end

% Convert accumulated Track 1 cell rows into structured MATLAB tables
% The all channel CSV
if isempty(rq1_chan_rows)
    Table_RQ1_Channels = cell2table(cell(0, length(chan_col_names)), 'VariableNames', chan_col_names);
else
    Table_RQ1_Channels = cell2table(rq1_chan_rows, 'VariableNames', chan_col_names);
end

% The covariate CSV
if isempty(rq1_chan_full_rows)
    Table_RQ1_Channels_FullTerms = cell2table(cell(0, length(full_chan_cols)), 'VariableNames', full_chan_cols);
else
    Table_RQ1_Channels_FullTerms = cell2table(rq1_chan_full_rows, 'VariableNames', full_chan_cols);
end

fprintf('Track 1 RQ1 Channels complete: %d rows recorded (%d estimated).\n', ...
    height(Table_RQ1_Channels), sum(Table_RQ1_Channels.Model_Status == "OK"));

%% 8b. Track 2: ROI-Level Precision-Weighted LME Models (RQ1)

fprintf('Evaluating Track 2: Precision-weighted ROI models across %d ROIs, %d tasks, and %d chromophores...\n', ...
    length(rois), length(rq1_tasks), length(chroms));

% Outer loop: iterate through each chromo
for c = 1:length(chroms)

    % Extract the chromo
    chrom_str = chroms{c};
    
    % Middle loop: iterate through each of the 5 ROIs
    for r = 1:length(rois)

        % Extra the current ROI (unlike channel in 8a)
        roi_str = rois{r};
        
        % Inner loop: iterate through each task contrast condition
        for t = 1:length(rq1_tasks)

            % extract the current task
            task_str = rq1_tasks{t};
            
            % Create logical row mask filtering Track 2 to the active baseline, chromophore, ROI, and task
            sub_idx = Track2_ROI_Long_Table.Baseline_Type == primary_baseline & ...
                      Track2_ROI_Long_Table.Chromophore == chrom_str & ...
                      Track2_ROI_Long_Table.ROI == roi_str & ...
                      Track2_ROI_Long_Table.Task_Contrast == task_str;
            
            % Locate first matching row to extract static timescale metadata
            meta_idx = find(sub_idx, 1, 'first');
            if isempty(meta_idx), continue; end
            
            % Extract required model columns and perform listwise deletion of missing values
            sub_tbl = Track2_ROI_Long_Table(sub_idx, :);
            req_vars = {'Beta_ROI', 'SE_ROI', 'Team_Perf_Dummy', 'Age_Centered', 'Gender_Dummy', 'Second_Dest_Dummy', 'Session_ID'};
            sub_tbl = sub_tbl(:, intersect(req_vars, sub_tbl.Properties.VariableNames));
            sub_tbl = rmmissing(sub_tbl);
            
            % Assemble shared metadata prefix for full-model covariate export
            base_meta = { ...
                string(primary_baseline), string(task_str), ...
                string(Track2_ROI_Long_Table.Timescale(meta_idx)), ...
                string(chrom_str), string(roi_str), height(sub_tbl) ...
            };
            
            try
                % Abort if zero complete participant observations remain
                n_sub = height(sub_tbl);
                if n_sub == 0
                    error('No valid observations remaining after missing data exclusion (N = 0).');
                end
                
                % Abort if binary outcome Team_Perf_Dummy has < 2 levels
                % Still RQ1 looking at team performance
                if numel(unique(sub_tbl.Team_Perf_Dummy)) < 2
                    error('Single Team_Perf_Dummy level (N = %d; all outcomes = %d).', ...
                        n_sub, unique(sub_tbl.Team_Perf_Dummy));
                end
                if n_sub <= 5
                    error('Insufficient sample size (N = %d <= 5 fixed-effect parameters).', n_sub);
                end
                
                % Compute mean-normalized inverse-variance weights (1 / SE_ROI^2)
                raw_w = 1 ./ max(sub_tbl.SE_ROI .^ 2, 1e-6);
                w_vec = raw_w / mean(raw_w);
                
                % Drop unobserved categorical levels prior to design matrix construction
                sub_tbl.Gender_Dummy = removecats(categorical(sub_tbl.Gender_Dummy));
                sub_tbl.Second_Dest_Dummy = removecats(categorical(sub_tbl.Second_Dest_Dummy));
                sub_tbl.Session_ID = removecats(categorical(sub_tbl.Session_ID));
                
                % Include Second_Dest_Dummy covariate only when both levels occur in this task subset
                % MODEL 2 RQ1 but for ROI instead of channels
                % if numel(categories(sub_tbl.Second_Dest_Dummy)) > 1
                formula_str = 'Beta_ROI ~ 1 + Team_Perf_Dummy + Age_Centered + Gender_Dummy + Second_Dest_Dummy + (1 | Session_ID)';
                % else
                %     fprint('else statement entered model 2 rq1 roi');
                %     formula_str = 'Beta_ROI ~ 1 + Team_Perf_Dummy + Age_Centered + Gender_Dummy + (1 | Session_ID)';
                % end
                
                % Fit precision-weighted REML linear mixed-effects model on ROI-averaged contrast betas
                lme = fitlme(sub_tbl, formula_str, 'Weights', w_vec);
                
                % Locate the fixed-effect coefficient row for Team_Perf_Dummy
                team_idx = find(strcmp(lme.CoefficientNames, 'Team_Perf_Dummy'));
                if isempty(team_idx)
                    error('Team_Perf_Dummy dropped due to collinearity (N = %d).', n_sub);
                end
                
                % Extract fixed-effect estimate, SE, t-stat, p-value, degrees of freedom, 95% CI, and Cohen's d
                b1 = lme.Coefficients.Estimate(team_idx);
                se1 = lme.Coefficients.SE(team_idx);
                tstat = lme.Coefficients.tStat(team_idx);
                pval = lme.Coefficients.pValue(team_idx);

                df = lme.Coefficients.DF(team_idx);
                if df <= 0 || isnan(pval)
                    error('Saturated model with zero residual degrees of freedom (N = %d, df = %g).', n_sub, df);
                end

                ci = lme.coefCI;
                ci_l = ci(team_idx, 1);
                ci_u = ci(team_idx, 2);
                cohens_d = tstat / sqrt(height(sub_tbl));
                
                % Record full fixed/random covariate breakdown and primary Team_Perf_Dummy summary row
                rq1_roi_full_rows = extract_lme_full_terms(lme, base_meta, rq1_roi_full_rows, "OK");
                rq1_roi_rows(end+1, 1:16) = { ...
                    string(primary_baseline), string(task_str), ...
                    string(Track2_ROI_Long_Table.Timescale(meta_idx)), ...
                    Track2_ROI_Long_Table.Timescale_Num(meta_idx), ...
                    string(chrom_str), string(roi_str), n_sub, ...
                    b1, se1, tstat, df, pval, ci_l, ci_u, cohens_d, "OK" ...
                };
            catch ME
                % Record NaN placeholder rows with diagnostic status to preserve rectangular CSV grid
                err_txt = string(ME.message);
                if contains(err_txt, "full column rank")
                    err_txt = sprintf("Collinear covariates in small subsample (rank deficient; N = %d).", height(sub_tbl));
                end
                status_msg = "Skipped: " + err_txt;
                rq1_roi_rows(end+1, 1:16) = { ...
                    string(primary_baseline), string(task_str), ...
                    string(Track2_ROI_Long_Table.Timescale(meta_idx)), ...
                    Track2_ROI_Long_Table.Timescale_Num(meta_idx), ...
                    string(chrom_str), string(roi_str), height(sub_tbl), ...
                    NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, status_msg ...
                };
                rq1_roi_full_rows(end+1, 1:18) = [base_meta, { ...
                    "Unestimated", "N/A", NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, status_msg ...
                }];
            end
        end
    end
end

% Convert accumulated Track 2 cell rows into structured MATLAB tables
if isempty(rq1_roi_rows)
    Table_RQ1_ROI = cell2table(cell(0, length(roi_col_names)), 'VariableNames', roi_col_names);
else
    Table_RQ1_ROI = cell2table(rq1_roi_rows, 'VariableNames', roi_col_names);
end

if isempty(rq1_roi_full_rows)
    Table_RQ1_ROI_FullTerms = cell2table(cell(0, length(full_roi_cols)), 'VariableNames', full_roi_cols);
else
    Table_RQ1_ROI_FullTerms = cell2table(rq1_roi_full_rows, 'VariableNames', full_roi_cols);
end

fprintf('Track 2 RQ1 ROI complete: %d rows recorded (%d estimated).\n', ...
    height(Table_RQ1_ROI), sum(Table_RQ1_ROI.Model_Status == "OK"));

%% 8c. Multiple Comparisons Correction (FDR q < .05) & Publication Tables (RQ1)

fprintf('\n=== Computing FDR & Formatting Publication Tables for RQ1 ===\n');

% 1. Apply Benjamini-Hochberg FDR across Track 2 ROIs within each chromophore family
Table_RQ1_ROI.P_FDR = nan(height(Table_RQ1_ROI), 1);
Table_RQ1_ROI.FDR_Mult = nan(height(Table_RQ1_ROI), 1);
Table_RQ1_ROI.FDR_m    = nan(height(Table_RQ1_ROI), 1);
Table_RQ1_ROI.Sig_FDR = false(height(Table_RQ1_ROI), 1);

for c = 1:length(chroms)
    c_idx = Table_RQ1_ROI.Chromophore == string(chroms{c});
    % q_adj = compute_bh_fdr(Table_RQ1_ROI.P_Val(c_idx));
    [q_adj, mult_v, m_v] = compute_bh_fdr(Table_RQ1_ROI.P_Val(c_idx));
    Table_RQ1_ROI.P_FDR(c_idx) = q_adj;
    Table_RQ1_ROI.FDR_Mult(c_idx) = mult_v;
    Table_RQ1_ROI.FDR_m(c_idx)    = m_v;
    Table_RQ1_ROI.Sig_FDR(c_idx) = (q_adj < 0.05);
end
Table_RQ1_ROI.Achieved_Power = compute_achieved_power(Table_RQ1_ROI.T_Stat, Table_RQ1_ROI.DF);

% 2. Apply Option B Topographic FDR across Track 1 Channels within each Task x Chromophore family (m <= 41)
Table_RQ1_Channels.P_FDR = nan(height(Table_RQ1_Channels), 1);
Table_RQ1_Channels.FDR_Mult = nan(height(Table_RQ1_Channels), 1);
Table_RQ1_Channels.FDR_m    = nan(height(Table_RQ1_Channels), 1);
tasks_ch = unique(Table_RQ1_Channels.Task_Contrast, 'stable');
for c = 1:length(chroms)
    c_str = string(chroms{c});
    for t = 1:length(tasks_ch)
        slice_idx = Table_RQ1_Channels.Chromophore == c_str & ...
                    Table_RQ1_Channels.Task_Contrast == tasks_ch(t);
        % Table_RQ1_Channels.P_FDR(slice_idx) = compute_bh_fdr(Table_RQ1_Channels.P_Val(slice_idx));
        [q_adj, mult_v, m_v] = compute_bh_fdr(Table_RQ1_Channels.P_Val(slice_idx));
        Table_RQ1_Channels.P_FDR(slice_idx)    = q_adj;
        Table_RQ1_Channels.FDR_Mult(slice_idx) = mult_v;
        Table_RQ1_Channels.FDR_m(slice_idx)    = m_v;
    end
end
Table_RQ1_Channels.Achieved_Power = compute_achieved_power(Table_RQ1_Channels.T_Stat, Table_RQ1_Channels.DF);

% 3. Compute standardized betas (Beta_Std = Beta_Raw * SD(X)/SD(Y)), unique dyad counts, and Brodmann labels
[ch_b_std, ch_ci_l, ch_ci_u, ch_n_d, ch_ba] = format_pub_metrics( ...
    Table_RQ1_Channels, Track1_Channel_Long_Table, 'Channel', 'Beta', 'Beta_TeamPerf', 'CI_Lower', 'CI_Upper', 'Team_Perf_Dummy', Master_Atlas_Table);

[roi_b_std, roi_ci_l, roi_ci_u, roi_n_d, ~] = format_pub_metrics( ...
    Table_RQ1_ROI, Track2_ROI_Long_Table, 'ROI', 'Beta_ROI', 'Beta_TeamPerf', 'CI_Lower', 'CI_Upper', 'Team_Perf_Dummy', Master_Atlas_Table);

% 4. Assemble publication-formatted master tables for Track 1 (Channels) and Track 2 (ROIs)
% Note included model status
Table_RQ1_Channels_Pub = table( ...
    Table_RQ1_Channels.Task_Contrast, Table_RQ1_Channels.Chromophore, Table_RQ1_Channels.Channel, ...
    Table_RQ1_Channels.N_Obs, ch_n_d, Table_RQ1_Channels.Beta_TeamPerf, ...
    ch_b_std, ch_ci_l, ch_ci_u, Table_RQ1_Channels.T_Stat, Table_RQ1_Channels.DF, ...
    Table_RQ1_Channels.P_Val, Table_RQ1_Channels.P_FDR, ...
    Table_RQ1_Channels.FDR_Mult, Table_RQ1_Channels.FDR_m, Table_RQ1_Channels.Achieved_Power, ...
    ch_ba, Table_RQ1_Channels.Model_Status, ...
    'VariableNames', { ...
        'Condition_Contrast', 'Chromophore', 'Channel', 'N_Participants', 'N_Dyads', ...
        'Beta_Raw', 'Beta_Std', 'CI_Std_Lower', 'CI_Std_Upper', 't', 'df', ...
        'p', 'p_FDR', 'FDR_Mult', 'FDR_m', 'Achieved_Power', 'Brodmann_Area', 'Model_Status' ...
    } ...
);

% Note removed BA from this section since it has ROI column
Table_RQ1_ROI_Pub = table( ...
    Table_RQ1_ROI.Task_Contrast, Table_RQ1_ROI.Chromophore, Table_RQ1_ROI.ROI, ...
    Table_RQ1_ROI.N_Obs, roi_n_d, Table_RQ1_ROI.Beta_TeamPerf, ...
    roi_b_std, roi_ci_l, roi_ci_u, Table_RQ1_ROI.T_Stat, Table_RQ1_ROI.DF, ...
    Table_RQ1_ROI.P_Val, Table_RQ1_ROI.P_FDR, ...
    Table_RQ1_ROI.FDR_Mult, Table_RQ1_ROI.FDR_m, Table_RQ1_ROI.Achieved_Power, ...
    Table_RQ1_ROI.Model_Status, ...
    'VariableNames', { ...
        'Condition_Contrast', 'Chromophore', 'ROI', 'N_Participants', 'N_Dyads', ...
        'Beta_Raw', 'Beta_Std', 'CI_Std_Lower', 'CI_Std_Upper', 't', 'df', ...
        'p', 'p_FDR', 'FDR_Mult', 'FDR_m', 'Achieved_Power', 'Model_Status' ...
    } ...
);

%% 8d. Export RQ1 Deliverables & Print Command Window Summaries

% Ensure dedicated significance subfolder exists
sig_out_dir = fullfile(group_out_dir, 'RQ_Sig');
if ~exist(sig_out_dir, 'dir'), mkdir(sig_out_dir); end

% Define output file paths for raw model tables, full-term covariate tables, publication tables, and significant subsets
rq1_chan_csv = fullfile(group_out_dir, 'Table_RQ1_TeamPerformance_Channels.csv');
rq1_roi_csv = fullfile(group_out_dir, 'Table_RQ1_TeamPerformance_ROI.csv');
rq1_mat = fullfile(group_out_dir, 'GroupLevel_RQ1_Models.mat');
chan_pub_csv = fullfile(group_out_dir, 'Table_RQ1_Publication_Channels.csv');
roi_pub_csv = fullfile(group_out_dir, 'Table_RQ1_Publication_ROI.csv');
sig_chan_csv_rq1 = fullfile(sig_out_dir, 'Table_RQ1_Significant_Channels.csv');
sig_roi_csv_rq1 = fullfile(sig_out_dir, 'Table_RQ1_Significant_ROI.csv');

% Export all master tables and combined .mat archive
writetable(Table_RQ1_Channels, rq1_chan_csv);
writetable(Table_RQ1_ROI, rq1_roi_csv);
writetable(Table_RQ1_Channels_FullTerms, fullfile(group_out_dir, 'Table_RQ1_FullModel_Covariates_Channels.csv'));
writetable(Table_RQ1_ROI_FullTerms, fullfile(group_out_dir, 'Table_RQ1_FullModel_Covariates_ROI.csv'));
writetable(Table_RQ1_Channels_Pub, chan_pub_csv);
writetable(Table_RQ1_ROI_Pub, roi_pub_csv);
save(rq1_mat, 'Table_RQ1_Channels', 'Table_RQ1_ROI', 'Table_RQ1_Channels_Pub', 'Table_RQ1_ROI_Pub');

% Filter and sort uncorrected significant rows (p < .05) for dedicated RQ_Sig export
sig_chan_tbl = sortrows(Table_RQ1_Channels_Pub(Table_RQ1_Channels_Pub.p < 0.05, :), ...
    {'Condition_Contrast', 'Chromophore', 'p'}, {'ascend', 'ascend', 'ascend'});
sig_roi_tbl  = sortrows(Table_RQ1_ROI_Pub(Table_RQ1_ROI_Pub.p < 0.05, :), ...
    {'Condition_Contrast', 'Chromophore', 'p'}, {'ascend', 'ascend', 'ascend'});

writetable(sig_chan_tbl, sig_chan_csv_rq1);
writetable(sig_roi_tbl, sig_roi_csv_rq1);

% Print export confirmation and significance summaries to Command Window
fprintf('Section F complete. Saved RQ1 deliverables to:\n');
fprintf('  -> Master Channels Pub: %s\n', chan_pub_csv);
fprintf('  -> Master ROIs Pub:     %s\n', roi_pub_csv);
fprintf('  -> Sig Channels:        %s (%d rows)\n', sig_chan_csv_rq1, height(sig_chan_tbl));
fprintf('  -> Sig ROIs:            %s (%d rows)\n', sig_roi_csv_rq1, height(sig_roi_tbl));

fdr_roi_rq1 = Table_RQ1_ROI_Pub(Table_RQ1_ROI_Pub.p_FDR < 0.05, :);
fdr_chan_rq1 = Table_RQ1_Channels_Pub(Table_RQ1_Channels_Pub.p_FDR < 0.05, :);

fprintf('\nSummary of Precision-Weighted RQ1 Effects:\n');
fprintf('  - ROIs:     %d / %d uncorrected (p < .05) | %d / %d FDR-corrected (q < .05)\n', ...
    height(sig_roi_tbl), sum(Table_RQ1_ROI.Model_Status == "OK"), height(fdr_roi_rq1), sum(Table_RQ1_ROI.Model_Status == "OK"));
fprintf('  - Channels: %d / %d uncorrected (p < .05) | %d / %d FDR-corrected (q < .05)\n', ...
    height(sig_chan_tbl), sum(Table_RQ1_Channels.Model_Status == "OK"), height(fdr_chan_rq1), sum(Table_RQ1_Channels.Model_Status == "OK"));

if ~isempty(sig_roi_tbl)
    disp(sig_roi_tbl(:, {'Condition_Contrast', 'Chromophore', 'ROI', 'N_Participants', 'N_Dyads', ...
                         'Beta_Raw', 'Beta_Std', 'CI_Std_Lower', 'CI_Std_Upper', 't', 'p', 'p_FDR'}));
end

%% 8e. Just adds a completely new section for this tricorder model
% Used AI to replicate the prior models so this code is probably repetitive

%% 8e. Supplemental RQ1 Models with Tricorder Switch Covariate (+ Switches_Centered)

fprintf('\n=== Evaluating Supplemental RQ1 Models with Tricorder Covariate (Tricorder Tasks Only) ===\n');

tri_tasks = {'tricorder_switch_true', 'tricorder_switch_decoy'};
rq1_tri_ch_rows  = {};
rq1_tri_roi_rows = {};

% Track 1: Channel-Level Supplemental RQ1 Models
for c = 1:length(chroms)
    chrom_str = chroms{c};
    for ch_idx = 1:length(channels)
        chan_num = channels(ch_idx);
        for t = 1:length(tri_tasks)
            task_str = tri_tasks{t};
            sub_idx = Track1_Channel_Long_Table.Baseline_Type == primary_baseline & ...
                      Track1_Channel_Long_Table.Chromophore == chrom_str & ...
                      Track1_Channel_Long_Table.Channel == chan_num & ...
                      Track1_Channel_Long_Table.Task_Contrast == task_str;
            meta_idx = find(sub_idx, 1, 'first');
            if isempty(meta_idx), continue; end

            sub_tbl = Track1_Channel_Long_Table(sub_idx, {'Beta', 'SE', 'Team_Perf_Dummy', 'Switches_Centered', 'Age_Centered', 'Gender_Dummy', 'Second_Dest_Dummy', 'Session_ID'});
            sub_tbl = rmmissing(sub_tbl);

            try
                n_sub = height(sub_tbl);
                if n_sub == 0
                    error('No valid observations (N = 0 after SNR pruning / missing data).');
                end
                if numel(unique(sub_tbl.Team_Perf_Dummy)) < 2
                    error('Single Team_Perf_Dummy level (N = %d, all outcomes = %d).', ...
                        n_sub, unique(sub_tbl.Team_Perf_Dummy));
                end
                if n_sub <= 6
                    error('Insufficient sample size (N = %d <= 6 fixed-effect parameters).', n_sub);
                end

                raw_w = 1 ./ max(sub_tbl.SE .^ 2, 1e-6);
                w_vec = raw_w / mean(raw_w);
                sub_tbl.Gender_Dummy      = removecats(categorical(sub_tbl.Gender_Dummy));
                sub_tbl.Second_Dest_Dummy = removecats(categorical(sub_tbl.Second_Dest_Dummy));
                sub_tbl.Session_ID        = removecats(categorical(sub_tbl.Session_ID));

                lme = fitlme(sub_tbl, 'Beta ~ 1 + Team_Perf_Dummy + Switches_Centered + Age_Centered + Gender_Dummy + Second_Dest_Dummy + (1 | Session_ID)', 'Weights', w_vec);
                t_idx = find(strcmp(lme.CoefficientNames, 'Team_Perf_Dummy'));
                if isempty(t_idx)
                    error('Team_Perf_Dummy dropped due to collinearity (N = %d).', n_sub);
                end

                df_val = lme.Coefficients.DF(t_idx);
                p_val  = lme.Coefficients.pValue(t_idx);
                if df_val <= 0 || isnan(p_val)
                    error('Saturated model with zero residual degrees of freedom (N = %d, df = %g).', n_sub, df_val);
                end

                ci = lme.coefCI;
                rq1_tri_ch_rows(end+1, 1:19) = { ...
                    string(primary_baseline), string(task_str), ...
                    string(Track1_Channel_Long_Table.Timescale(meta_idx)), ...
                    Track1_Channel_Long_Table.Timescale_Num(meta_idx), ...
                    string(chrom_str), chan_num, ...
                    Track1_Channel_Long_Table.Source(meta_idx), ...
                    Track1_Channel_Long_Table.Detector(meta_idx), ...
                    string(Track1_Channel_Long_Table.ROI(meta_idx)), n_sub, ...
                    lme.Coefficients.Estimate(t_idx), lme.Coefficients.SE(t_idx), ...
                    lme.Coefficients.tStat(t_idx), df_val, ...
                    p_val, ci(t_idx,1), ci(t_idx,2), ...
                    lme.Coefficients.tStat(t_idx) / sqrt(n_sub), "OK" ...
                };
            catch ME
                err_txt = string(ME.message);
                if contains(err_txt, "full column rank")
                    err_txt = sprintf("Collinear covariates in small subsample (rank deficient; N = %d).", height(sub_tbl));
                end
                rq1_tri_ch_rows(end+1, 1:19) = { ...
                    string(primary_baseline), string(task_str), ...
                    string(Track1_Channel_Long_Table.Timescale(meta_idx)), ...
                    Track1_Channel_Long_Table.Timescale_Num(meta_idx), ...
                    string(chrom_str), chan_num, ...
                    Track1_Channel_Long_Table.Source(meta_idx), ...
                    Track1_Channel_Long_Table.Detector(meta_idx), ...
                    string(Track1_Channel_Long_Table.ROI(meta_idx)), height(sub_tbl), ...
                    NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, "Skipped: " + err_txt ...
                };
            end
        end
    end
end

% Track 2: ROI-Level Supplemental RQ1 Models
for c = 1:length(chroms)
    chrom_str = chroms{c};
    for r = 1:length(rois)
        roi_str = rois{r};
        for t = 1:length(tri_tasks)
            task_str = tri_tasks{t};
            sub_idx = Track2_ROI_Long_Table.Baseline_Type == primary_baseline & ...
                      Track2_ROI_Long_Table.Chromophore == chrom_str & ...
                      Track2_ROI_Long_Table.ROI == roi_str & ...
                      Track2_ROI_Long_Table.Task_Contrast == task_str;
            meta_idx = find(sub_idx, 1, 'first');
            if isempty(meta_idx), continue; end

            sub_tbl = Track2_ROI_Long_Table(sub_idx, {'Beta_ROI', 'SE_ROI', 'Team_Perf_Dummy', 'Switches_Centered', 'Age_Centered', 'Gender_Dummy', 'Second_Dest_Dummy', 'Session_ID'});
            sub_tbl = rmmissing(sub_tbl);

            try
                if height(sub_tbl) == 0 || numel(unique(sub_tbl.Team_Perf_Dummy)) < 2
                    error('Insufficient observations or single Team_Perf_Dummy level.');
                end
                raw_w = 1 ./ max(sub_tbl.SE_ROI .^ 2, 1e-6);
                w_vec = raw_w / mean(raw_w);
                sub_tbl.Gender_Dummy      = removecats(categorical(sub_tbl.Gender_Dummy));
                sub_tbl.Second_Dest_Dummy = removecats(categorical(sub_tbl.Second_Dest_Dummy));
                sub_tbl.Session_ID        = removecats(categorical(sub_tbl.Session_ID));

                lme = fitlme(sub_tbl, 'Beta_ROI ~ 1 + Team_Perf_Dummy + Switches_Centered + Age_Centered + Gender_Dummy + Second_Dest_Dummy + (1 | Session_ID)', 'Weights', w_vec);
                t_idx = find(strcmp(lme.CoefficientNames, 'Team_Perf_Dummy'));
                if isempty(t_idx), error('Team_Perf_Dummy dropped due to collinearity.'); end
                ci = lme.coefCI;

                rq1_tri_roi_rows(end+1, 1:16) = { ...
                    string(primary_baseline), string(task_str), ...
                    string(Track2_ROI_Long_Table.Timescale(meta_idx)), ...
                    Track2_ROI_Long_Table.Timescale_Num(meta_idx), ...
                    string(chrom_str), string(roi_str), height(sub_tbl), ...
                    lme.Coefficients.Estimate(t_idx), lme.Coefficients.SE(t_idx), ...
                    lme.Coefficients.tStat(t_idx), lme.Coefficients.DF(t_idx), ...
                    lme.Coefficients.pValue(t_idx), ci(t_idx,1), ci(t_idx,2), ...
                    lme.Coefficients.tStat(t_idx) / sqrt(height(sub_tbl)), "OK" ...
                };
            catch ME
                rq1_tri_roi_rows(end+1, 1:16) = { ...
                    string(primary_baseline), string(task_str), ...
                    string(Track2_ROI_Long_Table.Timescale(meta_idx)), ...
                    Track2_ROI_Long_Table.Timescale_Num(meta_idx), ...
                    string(chrom_str), string(roi_str), height(sub_tbl), ...
                    NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, "Skipped: " + string(ME.message) ...
                };
            end
        end
    end
end

if ~isempty(rq1_tri_ch_rows) && ~isempty(rq1_tri_roi_rows)
    Table_RQ1_TriCov_Channels = cell2table(rq1_tri_ch_rows, 'VariableNames', chan_col_names);
    Table_RQ1_TriCov_ROI      = cell2table(rq1_tri_roi_rows, 'VariableNames', roi_col_names);

    % FDR Correction + Multiplier + Achieved Power (ROI)
    Table_RQ1_TriCov_ROI.P_FDR    = nan(height(Table_RQ1_TriCov_ROI), 1);
    Table_RQ1_TriCov_ROI.FDR_Mult = nan(height(Table_RQ1_TriCov_ROI), 1);
    Table_RQ1_TriCov_ROI.FDR_m    = nan(height(Table_RQ1_TriCov_ROI), 1);
    for c = 1:length(chroms)
        c_idx = Table_RQ1_TriCov_ROI.Chromophore == string(chroms{c});
        [q_adj, mult_v, m_v] = compute_bh_fdr(Table_RQ1_TriCov_ROI.P_Val(c_idx));
        Table_RQ1_TriCov_ROI.P_FDR(c_idx)    = q_adj;
        Table_RQ1_TriCov_ROI.FDR_Mult(c_idx) = mult_v;
        Table_RQ1_TriCov_ROI.FDR_m(c_idx)    = m_v;
    end
    Table_RQ1_TriCov_ROI.Achieved_Power = compute_achieved_power(Table_RQ1_TriCov_ROI.T_Stat, Table_RQ1_TriCov_ROI.DF);

    % FDR Correction + Multiplier + Achieved Power (Channels)
    Table_RQ1_TriCov_Channels.P_FDR    = nan(height(Table_RQ1_TriCov_Channels), 1);
    Table_RQ1_TriCov_Channels.FDR_Mult = nan(height(Table_RQ1_TriCov_Channels), 1);
    Table_RQ1_TriCov_Channels.FDR_m    = nan(height(Table_RQ1_TriCov_Channels), 1);
    for c = 1:length(chroms)
        for t = 1:length(tri_tasks)
            s_idx = Table_RQ1_TriCov_Channels.Chromophore == string(chroms{c}) & ...
                    Table_RQ1_TriCov_Channels.Task_Contrast == string(tri_tasks{t});
            [q_adj, mult_v, m_v] = compute_bh_fdr(Table_RQ1_TriCov_Channels.P_Val(s_idx));
            Table_RQ1_TriCov_Channels.P_FDR(s_idx)    = q_adj;
            Table_RQ1_TriCov_Channels.FDR_Mult(s_idx) = mult_v;
            Table_RQ1_TriCov_Channels.FDR_m(s_idx)    = m_v;
        end
    end
    Table_RQ1_TriCov_Channels.Achieved_Power = compute_achieved_power(Table_RQ1_TriCov_Channels.T_Stat, Table_RQ1_TriCov_Channels.DF);

    % Format Publication Tables
    [tri_ch_b, tri_ch_l, tri_ch_u, tri_ch_nd, tri_ch_ba] = format_pub_metrics( ...
        Table_RQ1_TriCov_Channels, Track1_Channel_Long_Table, 'Channel', 'Beta', 'Beta_TeamPerf', 'CI_Lower', 'CI_Upper', 'Team_Perf_Dummy', Master_Atlas_Table);
    [tri_roi_b, tri_roi_l, tri_roi_u, tri_roi_nd, ~] = format_pub_metrics( ...
        Table_RQ1_TriCov_ROI, Track2_ROI_Long_Table, 'ROI', 'Beta_ROI', 'Beta_TeamPerf', 'CI_Lower', 'CI_Upper', 'Team_Perf_Dummy', Master_Atlas_Table);

    Table_RQ1_TriCov_Channels_Pub = table( ...
        Table_RQ1_TriCov_Channels.Task_Contrast, Table_RQ1_TriCov_Channels.Chromophore, Table_RQ1_TriCov_Channels.Channel, ...
        Table_RQ1_TriCov_Channels.N_Obs, tri_ch_nd, Table_RQ1_TriCov_Channels.Beta_TeamPerf, ...
        tri_ch_b, tri_ch_l, tri_ch_u, Table_RQ1_TriCov_Channels.T_Stat, Table_RQ1_TriCov_Channels.DF, ...
        Table_RQ1_TriCov_Channels.P_Val, Table_RQ1_TriCov_Channels.P_FDR, ...
        Table_RQ1_TriCov_Channels.FDR_Mult, Table_RQ1_TriCov_Channels.FDR_m, Table_RQ1_TriCov_Channels.Achieved_Power, ...
        tri_ch_ba, Table_RQ1_TriCov_Channels.Model_Status, ...
        'VariableNames', {'Condition_Contrast', 'Chromophore', 'Channel', 'N_Participants', 'N_Dyads', ...
                          'Beta_Raw', 'Beta_Std', 'CI_Std_Lower', 'CI_Std_Upper', 't', 'df', ...
                          'p', 'p_FDR', 'FDR_Mult', 'FDR_m', 'Achieved_Power', 'Brodmann_Area', 'Model_Status'});

    Table_RQ1_TriCov_ROI_Pub = table( ...
        Table_RQ1_TriCov_ROI.Task_Contrast, Table_RQ1_TriCov_ROI.Chromophore, Table_RQ1_TriCov_ROI.ROI, ...
        Table_RQ1_TriCov_ROI.N_Obs, tri_roi_nd, Table_RQ1_TriCov_ROI.Beta_TeamPerf, ...
        tri_roi_b, tri_roi_l, tri_roi_u, Table_RQ1_TriCov_ROI.T_Stat, Table_RQ1_TriCov_ROI.DF, ...
        Table_RQ1_TriCov_ROI.P_Val, Table_RQ1_TriCov_ROI.P_FDR, ...
        Table_RQ1_TriCov_ROI.FDR_Mult, Table_RQ1_TriCov_ROI.FDR_m, Table_RQ1_TriCov_ROI.Achieved_Power, ...
        Table_RQ1_TriCov_ROI.Model_Status, ...
        'VariableNames', {'Condition_Contrast', 'Chromophore', 'ROI', 'N_Participants', 'N_Dyads', ...
                          'Beta_Raw', 'Beta_Std', 'CI_Std_Lower', 'CI_Std_Upper', 't', 'df', ...
                          'p', 'p_FDR', 'FDR_Mult', 'FDR_m', 'Achieved_Power', 'Model_Status'});

    writetable(Table_RQ1_TriCov_Channels_Pub, fullfile(group_out_dir, 'Table_RQ1_TricorderCovariate_Publication_Channels.csv'));
    writetable(Table_RQ1_TriCov_ROI_Pub,      fullfile(group_out_dir, 'Table_RQ1_TricorderCovariate_Publication_ROI.csv'));
    fprintf('Saved supplemental RQ1 tricorder-covariate publication tables.\n');
end

%% Section G: RQ2 Individual Certainty Group LME Models (Step 9)

% Evaluates whether cortical hemodynamic responses scale with individual decision certainty,
% comparing three nested Maximum Likelihood (ML) specifications per channel and ROI:
%   - Model 1 (Signed Certainty, Primary) : Beta ~ 1 + SC_Centered + Time_Centered + Age_Centered + Gender_Dummy + Second_Dest_Dummy + (1 | Session_ID)
%   - Model 2 (Unsigned Certainty)        : Beta ~ 1 + Certainty_Centered + Time_Centered + Age_Centered + Gender_Dummy + Second_Dest_Dummy + (1 | Session_ID)
%   - Model 3 (Dual Certainty)            : Beta ~ 1 + SC_Centered + Certainty_Centered + Time_Centered + Age_Centered + Gender_Dummy + Second_Dest_Dummy + (1 | Session_ID)
%   Weights: Normalized inverse-variance precision weights w_i = (1 / SE_i^2) / mean(1 / SE^2)
%   FitMethod: 'ML' (Maximum Likelihood) so AIC comparisons across different fixed-effect structures are valid

% Print section banner to the MATLAB Command Window
fprintf('\n--- Evaluating RQ2 Certainty LME Models (Maximum Likelihood) ---\n');

% Restrict RQ2 group models to the primary task-matched baseline family
primary_baseline = 'TaskMatched';

% Initialize cell accumulators for primary SC_Centered summaries and full-term covariate breakdowns
rq2_chan_rows = {};
rq2_chan_full_rows = {};
rq2_roi_rows = {};
rq2_roi_full_rows = {};

% Extract unique factor levels from Track 1 and Track 2 to define the evaluation grid
chroms = categories(Track1_Channel_Long_Table.Chromophore); % HBDIFF,HBO,HBR
channels = unique(Track1_Channel_Long_Table.Channel); % 1 to 41
rois = categories(Track2_ROI_Long_Table.ROI); % 5 ROIs

% Evaluate all 11 mission task contrasts for RQ2
% rq2_tasks = { ...
%     'planning_individual', ...
%     'planning_team', ...
%     'status_check', ...
%     'spam_pop_up', ...
%     'tricorder_switch', ...
%     'certainty_individual', ...
%     'certainty_consensus', ...
%     'at_true_site', ...
%     'at_decoy_site', ...
%     'enroute_true_site', ...
%     'enroute_decoy_site' ...
% };

% Was initially hard coded but changed following tricorder split and will
% help with 3 different contrasts task stuff
rq2_tasks = categories(removecats(Track1_Channel_Long_Table.Task_Contrast( ...
    Track1_Channel_Long_Table.Baseline_Type == primary_baseline)));

% Define standardized column headers for Track 1 (Channel, 25 cols) and Track 2 (ROI, 22 cols) summary tables
chan_col_names_rq2 = { ...
    'Baseline_Type', 'Task_Contrast', 'Timescale', 'Timescale_Num', ...
    'Chromophore', 'Channel', 'Source', 'Detector', 'ROI', 'N_Obs', ...
    'Beta_SC', 'SE_SC', 'T_Stat_SC', 'DF_SC', 'P_Val_SC', 'CI_Lower_SC', 'CI_Upper_SC', ...
    'Beta_Time', 'P_Val_Time', ...
    'AIC_M1_Signed', 'AIC_M2_Unsigned', 'AIC_M3_Dual', 'Delta_AIC_M2_M1', 'Delta_AIC_M3_M1', 'Model_Status' ...
};

roi_col_names_rq2 = { ...
    'Baseline_Type', 'Task_Contrast', 'Timescale', 'Timescale_Num', ...
    'Chromophore', 'ROI', 'N_Obs', ...
    'Beta_SC', 'SE_SC', 'T_Stat_SC', 'DF_SC', 'P_Val_SC', 'CI_Lower_SC', 'CI_Upper_SC', ...
    'Beta_Time', 'P_Val_Time', ...
    'AIC_M1_Signed', 'AIC_M2_Unsigned', 'AIC_M3_Dual', 'Delta_AIC_M2_M1', 'Delta_AIC_M3_M1', 'Model_Status' ...
};

%% 9a. Track 1: Channel-Level Precision-Weighted ML Models (RQ2)

fprintf('Evaluating Track 1: Precision-weighted ML channel models across %d channels and %d tasks...\n', ...
    length(channels), length(rq2_tasks));

% Outer loop: iterate through each chromophore metric ('HBDIFF', 'HBO', 'HBR')
for c = 1:length(chroms)
    chrom_str = chroms{c};
    
    % Middle loop: iterate through each of the 41 long cortical channels
    for ch_idx = 1:length(channels)
        chan_num = channels(ch_idx);
        
        % Inner loop: iterate through each task contrast condition
        for t = 1:length(rq2_tasks)
            task_str = rq2_tasks{t};
            
            % Create logical row mask filtering Track 1 to the active baseline, chromophore, channel, and task
            sub_idx = Track1_Channel_Long_Table.Baseline_Type == primary_baseline & ...
                      Track1_Channel_Long_Table.Chromophore == chrom_str & ...
                      Track1_Channel_Long_Table.Channel == chan_num & ...
                      Track1_Channel_Long_Table.Task_Contrast == task_str;
            
            % Locate first matching row to extract static spatial/timescale metadata even if model fails
            meta_idx = find(sub_idx, 1, 'first');
            if isempty(meta_idx), continue; end
            
            % Extract only required model columns and perform listwise deletion of missing values
            sub_tbl = Track1_Channel_Long_Table(sub_idx, :);
            req_vars = {'Beta', 'SE', 'SC_Centered', 'Certainty_Centered', 'Time_Centered', ...
                        'Age_Centered', 'Gender_Dummy', 'Second_Dest_Dummy', 'Session_ID'};
            sub_tbl = sub_tbl(:, intersect(req_vars, sub_tbl.Properties.VariableNames));
            sub_tbl = rmmissing(sub_tbl);
            
            % Assemble shared metadata prefix for full-model covariate export
            base_meta_ch = { ...
                string(primary_baseline), string(task_str), ...
                string(Track1_Channel_Long_Table.Timescale(meta_idx)), ...
                string(chrom_str), chan_num, ...
                Track1_Channel_Long_Table.Source(meta_idx), ...
                Track1_Channel_Long_Table.Detector(meta_idx), ...
                string(Track1_Channel_Long_Table.ROI(meta_idx)), height(sub_tbl) ...
            };
            
            try
                % Abort if zero complete participant observations remain
                n_sub = height(sub_tbl);
                if n_sub == 0
                    error('No valid observations remaining after SNR pruning / missing data (N = 0).');
                end

                % Abort if continuous predictor SC_Centered lacks sufficient unique spread (< 3 levels)
                if numel(unique(sub_tbl.SC_Centered)) < 3
                    error('Fewer than 3 unique SC_Centered values (N = %d).', n_sub);
                end
                if n_sub <= 6
                    error('Insufficient sample size (N = %d <= 6 fixed-effect parameters).', n_sub);
                end
                
                % Compute mean-normalized inverse-variance weights (1 / SE^2) with variance floor (1e-6)
                raw_w = 1 ./ max(sub_tbl.SE .^ 2, 1e-6);
                w_vec = raw_w / mean(raw_w);
                
                % Drop unobserved categorical levels so design matrices remain full-rank
                sub_tbl.Gender_Dummy = removecats(categorical(sub_tbl.Gender_Dummy));
                sub_tbl.Second_Dest_Dummy = removecats(categorical(sub_tbl.Second_Dest_Dummy));
                sub_tbl.Session_ID = removecats(categorical(sub_tbl.Session_ID));
                
                % Include Second_Dest_Dummy covariate only when both levels (0 and 1) occur in this task subset
                has_second = numel(categories(sub_tbl.Second_Dest_Dummy)) > 1;
                % if has_second
                f1 = 'Beta ~ 1 + SC_Centered + Time_Centered + Age_Centered + Gender_Dummy + Second_Dest_Dummy + (1 | Session_ID)';
                f2 = 'Beta ~ 1 + Certainty_Centered + Time_Centered + Age_Centered + Gender_Dummy + Second_Dest_Dummy + (1 | Session_ID)';
                f3 = 'Beta ~ 1 + SC_Centered + Certainty_Centered + Time_Centered + Age_Centered + Gender_Dummy + Second_Dest_Dummy + (1 | Session_ID)';
                % else
                %     fprint('else statement entered model 2 rq2 channel'); 
                %     f1 = 'Beta ~ 1 + SC_Centered + Time_Centered + Age_Centered + Gender_Dummy + (1 | Session_ID)';
                %     f2 = 'Beta ~ 1 + Certainty_Centered + Time_Centered + Age_Centered + Gender_Dummy + (1 | Session_ID)';
                %     f3 = 'Beta ~ 1 + SC_Centered + Certainty_Centered + Time_Centered + Age_Centered + Gender_Dummy + (1 | Session_ID)';
                % end
                
                % Fit all three nested certainty models via Maximum Likelihood ('ML') for AIC comparison
                % MODEL 3 RQ2 for channels
                lme1 = fitlme(sub_tbl, f1, 'Weights', w_vec, 'FitMethod', 'ML');
                lme2 = fitlme(sub_tbl, f2, 'Weights', w_vec, 'FitMethod', 'ML');
                lme3 = fitlme(sub_tbl, f3, 'Weights', w_vec, 'FitMethod', 'ML');
                
                % Locate the fixed-effect coefficient row for primary predictor SC_Centered in Model 1
                sc_idx = find(strcmp(lme1.CoefficientNames, 'SC_Centered'));
                if isempty(sc_idx)
                    error('SC_Centered dropped due to collinearity (N = %d).', n_sub);
                end
                
                % Extract Signed Certainty (SC_Centered) fixed-effect parameters and 95% confidence bounds
                b_sc = lme1.Coefficients.Estimate(sc_idx);
                se_sc = lme1.Coefficients.SE(sc_idx);
                t_sc = lme1.Coefficients.tStat(sc_idx);
                p_sc = lme1.Coefficients.pValue(sc_idx);

                df_sc = lme1.Coefficients.DF(sc_idx);
                if df_sc <= 0 || isnan(p_sc)
                    error('Saturated model with zero residual degrees of freedom (N = %d, df = %g).', n_sub, df_sc);
                end

                ci_sc = lme1.coefCI;
                ci_l_sc = ci_sc(sc_idx, 1);
                ci_u_sc = ci_sc(sc_idx, 2);
                
                % Extract Elapsed Decision Time covariate slope and p-value from Model 1
                time_idx = find(strcmp(lme1.CoefficientNames, 'Time_Centered'));
                if ~isempty(time_idx)
                    b_time = lme1.Coefficients.Estimate(time_idx);
                    p_time = lme1.Coefficients.pValue(time_idx);
                else
                    b_time = nan;
                    p_time = nan;
                end
                
                % Extract Akaike Information Criterion (AIC) across Models 1-3 and compute relative deltas
                % (positive Delta_AIC indicates Model 1 Signed Certainty provides a better fit)
                aic1 = lme1.ModelCriterion.AIC;
                aic2 = lme2.ModelCriterion.AIC;
                aic3 = lme3.ModelCriterion.AIC;
                daic2 = aic2 - aic1;
                daic3 = aic3 - aic1;
                
                % Record full Model 1 covariate breakdown and primary RQ2 channel summary row
                rq2_chan_full_rows = extract_lme_full_terms(lme1, base_meta_ch, rq2_chan_full_rows, "OK");
                rq2_chan_rows(end+1, 1:25) = { ...
                    string(primary_baseline), string(task_str), ...
                    string(Track1_Channel_Long_Table.Timescale(meta_idx)), ...
                    Track1_Channel_Long_Table.Timescale_Num(meta_idx), ...
                    string(chrom_str), chan_num, ...
                    Track1_Channel_Long_Table.Source(meta_idx), ...
                    Track1_Channel_Long_Table.Detector(meta_idx), ...
                    string(Track1_Channel_Long_Table.ROI(meta_idx)), n_sub, ...
                    b_sc, se_sc, t_sc, df_sc, p_sc, ci_l_sc, ci_u_sc, ...
                    b_time, p_time, aic1, aic2, aic3, daic2, daic3, "OK" ...
                };
            catch ME
                % Record NaN placeholder rows with diagnostic status to preserve rectangular CSV grid
                err_txt = string(ME.message);
                if contains(err_txt, "full column rank")
                    err_txt = sprintf("Collinear covariates in small subsample (rank deficient; N = %d).", height(sub_tbl));
                end
                status_msg = "Skipped: " + err_txt;
                rq2_chan_rows(end+1, 1:25) = { ...
                    string(primary_baseline), string(task_str), ...
                    string(Track1_Channel_Long_Table.Timescale(meta_idx)), ...
                    Track1_Channel_Long_Table.Timescale_Num(meta_idx), ...
                    string(chrom_str), chan_num, ...
                    Track1_Channel_Long_Table.Source(meta_idx), ...
                    Track1_Channel_Long_Table.Detector(meta_idx), ...
                    string(Track1_Channel_Long_Table.ROI(meta_idx)), height(sub_tbl), ...
                    NaN, NaN, NaN, NaN, NaN, NaN, NaN, ...
                    NaN, NaN, NaN, NaN, NaN, NaN, NaN, status_msg ...
                };
                rq2_chan_full_rows(end+1, 1:21) = [base_meta_ch, { ...
                    "Unestimated", "N/A", NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, status_msg ...
                }];
            end
        end
    end
end

% Convert accumulated Track 1 cell rows into structured MATLAB tables
if isempty(rq2_chan_rows)
    Table_RQ2_Channels = cell2table(cell(0, length(chan_col_names_rq2)), 'VariableNames', chan_col_names_rq2);
else
    Table_RQ2_Channels = cell2table(rq2_chan_rows, 'VariableNames', chan_col_names_rq2);
end
if isempty(rq2_chan_full_rows)
    Table_RQ2_Channels_FullTerms = cell2table(cell(0, length(full_chan_cols)), 'VariableNames', full_chan_cols);
else
    Table_RQ2_Channels_FullTerms = cell2table(rq2_chan_full_rows, 'VariableNames', full_chan_cols);
end

fprintf('Track 1 RQ2 Channels complete: %d rows recorded (%d estimated).\n', ...
    height(Table_RQ2_Channels), sum(Table_RQ2_Channels.Model_Status == "OK"));

%% 9b. Track 2: ROI-Level Precision-Weighted ML Models (RQ2)

fprintf('Evaluating Track 2: Precision-weighted ML ROI models across %d ROIs, %d tasks, and %d chromophores...\n', ...
    length(rois), length(rq2_tasks), length(chroms));

% Outer loop: iterate through each chromophore metric ('HBDIFF', 'HBO', 'HBR')
for c = 1:length(chroms)
    chrom_str = chroms{c};
    
    % Middle loop: iterate through each of the 5 functional ROIs
    for r = 1:length(rois)
        roi_str = rois{r};
        
        % Inner loop: iterate through each task contrast condition
        for t = 1:length(rq2_tasks)
            task_str = rq2_tasks{t};
            
            % Create logical row mask filtering Track 2 to the active baseline, chromophore, ROI, and task
            sub_idx = Track2_ROI_Long_Table.Baseline_Type == primary_baseline & ...
                      Track2_ROI_Long_Table.Chromophore == chrom_str & ...
                      Track2_ROI_Long_Table.ROI == roi_str & ...
                      Track2_ROI_Long_Table.Task_Contrast == task_str;
            
            % Locate first matching row to extract static timescale metadata
            meta_idx = find(sub_idx, 1, 'first');
            if isempty(meta_idx), continue; end
            
            % Extract required model columns and perform listwise deletion of missing values
            sub_tbl  = Track2_ROI_Long_Table(sub_idx, :);
            req_vars = {'Beta_ROI', 'SE_ROI', 'SC_Centered', 'Certainty_Centered', 'Time_Centered', ...
                        'Age_Centered', 'Gender_Dummy', 'Second_Dest_Dummy', 'Session_ID'};
            sub_tbl  = sub_tbl(:, intersect(req_vars, sub_tbl.Properties.VariableNames));
            sub_tbl  = rmmissing(sub_tbl);
            
            % Assemble shared metadata prefix for full-model covariate export
            base_meta = { ...
                string(primary_baseline), string(task_str), ...
                string(Track2_ROI_Long_Table.Timescale(meta_idx)), ...
                string(chrom_str), string(roi_str), height(sub_tbl) ...
            };
            
            try
                % Abort if zero complete participant observations remain
                n_sub = height(sub_tbl);
                if n_sub == 0
                    error('No valid observations remaining after missing data exclusion (N = 0).');
                end

                % Abort if continuous predictor SC_Centered lacks sufficient unique spread
                if numel(unique(sub_tbl.SC_Centered)) < 3
                    error('Fewer than 3 unique SC_Centered values (N = %d).', n_sub);
                end
                if n_sub <= 6
                    error('Insufficient sample size (N = %d <= 6 fixed-effect parameters).', n_sub);
                end
                
                % Compute mean-normalized inverse-variance weights (1 / SE_ROI^2)
                raw_w = 1 ./ max(sub_tbl.SE_ROI .^ 2, 1e-6);
                w_vec = raw_w / mean(raw_w);
                
                % Drop unobserved categorical levels prior to design matrix construction
                sub_tbl.Gender_Dummy = removecats(categorical(sub_tbl.Gender_Dummy));
                sub_tbl.Second_Dest_Dummy = removecats(categorical(sub_tbl.Second_Dest_Dummy));
                sub_tbl.Session_ID = removecats(categorical(sub_tbl.Session_ID));
                
                % Include Second_Dest_Dummy covariate only when both levels occur in this task subset
                has_second = numel(categories(sub_tbl.Second_Dest_Dummy)) > 1;
                % if has_second
                f1 = 'Beta_ROI ~ 1 + SC_Centered + Time_Centered + Age_Centered + Gender_Dummy + Second_Dest_Dummy + (1 | Session_ID)';
                f2 = 'Beta_ROI ~ 1 + Certainty_Centered + Time_Centered + Age_Centered + Gender_Dummy + Second_Dest_Dummy + (1 | Session_ID)';
                f3 = 'Beta_ROI ~ 1 + SC_Centered + Certainty_Centered + Time_Centered + Age_Centered + Gender_Dummy + Second_Dest_Dummy + (1 | Session_ID)';
                % else
                %     fprint('else statement entered model 2 rq2 roi');
                %     f1 = 'Beta_ROI ~ 1 + SC_Centered + Time_Centered + Age_Centered + Gender_Dummy + (1 | Session_ID)';
                %     f2 = 'Beta_ROI ~ 1 + Certainty_Centered + Time_Centered + Age_Centered + Gender_Dummy + (1 | Session_ID)';
                %     f3 = 'Beta_ROI ~ 1 + SC_Centered + Certainty_Centered + Time_Centered + Age_Centered + Gender_Dummy + (1 | Session_ID)';
                % end
                
                % Fit all three nested certainty models via Maximum Likelihood ('ML') on ROI averages
                % MODEL 3 RQ2 for ROIs
                lme1 = fitlme(sub_tbl, f1, 'Weights', w_vec, 'FitMethod', 'ML');
                lme2 = fitlme(sub_tbl, f2, 'Weights', w_vec, 'FitMethod', 'ML');
                lme3 = fitlme(sub_tbl, f3, 'Weights', w_vec, 'FitMethod', 'ML');
                
                % Locate the fixed-effect coefficient row for primary predictor SC_Centered in Model 1
                sc_idx = find(strcmp(lme1.CoefficientNames, 'SC_Centered'));
                if isempty(sc_idx)
                    error('SC_Centered dropped due to collinearity (N = %d).', n_sub);
                end
                
                % Extract Signed Certainty (SC_Centered) fixed-effect parameters and 95% confidence bounds
                b_sc = lme1.Coefficients.Estimate(sc_idx);
                se_sc = lme1.Coefficients.SE(sc_idx);
                t_sc = lme1.Coefficients.tStat(sc_idx);
                p_sc = lme1.Coefficients.pValue(sc_idx);

                df_sc = lme1.Coefficients.DF(sc_idx);
                if df_sc <= 0 || isnan(p_sc)
                    error('Saturated model with zero residual degrees of freedom (N = %d, df = %g).', n_sub, df_sc);
                end

                ci_sc = lme1.coefCI;
                ci_l_sc = ci_sc(sc_idx, 1);
                ci_u_sc = ci_sc(sc_idx, 2);
                
                % Extract Elapsed Decision Time covariate slope and p-value from Model 1
                time_idx = find(strcmp(lme1.CoefficientNames, 'Time_Centered'));
                if ~isempty(time_idx)
                    b_time = lme1.Coefficients.Estimate(time_idx);
                    p_time = lme1.Coefficients.pValue(time_idx);
                else
                    b_time = nan;
                    p_time = nan;
                end
                
                % Extract AIC criteria across Models 1-3 and compute relative model-selection deltas
                aic1 = lme1.ModelCriterion.AIC;
                aic2 = lme2.ModelCriterion.AIC;
                aic3 = lme3.ModelCriterion.AIC;
                daic2 = aic2 - aic1;
                daic3 = aic3 - aic1;
                
                % Record full Model 1 covariate breakdown and primary RQ2 ROI summary row
                rq2_roi_full_rows = extract_lme_full_terms(lme1, base_meta, rq2_roi_full_rows, "OK");
                rq2_roi_rows(end+1, 1:22) = { ...
                    string(primary_baseline), string(task_str), ...
                    string(Track2_ROI_Long_Table.Timescale(meta_idx)), ...
                    Track2_ROI_Long_Table.Timescale_Num(meta_idx), ...
                    string(chrom_str), string(roi_str), n_sub, ...
                    b_sc, se_sc, t_sc, df_sc, p_sc, ci_l_sc, ci_u_sc, ...
                    b_time, p_time, aic1, aic2, aic3, daic2, daic3, "OK" ...
                };
            catch ME
                % Record NaN placeholder rows with diagnostic status to preserve rectangular CSV grid
                err_txt = string(ME.message);
                if contains(err_txt, "full column rank")
                    err_txt = sprintf("Collinear covariates in small subsample (rank deficient; N = %d).", height(sub_tbl));
                end
                status_msg = "Skipped: " + err_txt;
                rq2_roi_rows(end+1, 1:22) = { ...
                    string(primary_baseline), string(task_str), ...
                    string(Track2_ROI_Long_Table.Timescale(meta_idx)), ...
                    Track2_ROI_Long_Table.Timescale_Num(meta_idx), ...
                    string(chrom_str), string(roi_str), height(sub_tbl), ...
                    NaN, NaN, NaN, NaN, NaN, NaN, NaN, ...
                    NaN, NaN, NaN, NaN, NaN, NaN, NaN, status_msg ...
                };
                rq2_roi_full_rows(end+1, 1:18) = [base_meta, { ...
                    "Unestimated", "N/A", NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, status_msg ...
                }];
            end
        end
    end
end

% Convert accumulated Track 2 cell rows into structured MATLAB tables
if isempty(rq2_roi_rows)
    Table_RQ2_ROI = cell2table(cell(0, length(roi_col_names_rq2)), 'VariableNames', roi_col_names_rq2);
else
    Table_RQ2_ROI = cell2table(rq2_roi_rows, 'VariableNames', roi_col_names_rq2);
end

if isempty(rq2_roi_full_rows)
    Table_RQ2_ROI_FullTerms = cell2table(cell(0, length(full_roi_cols)), 'VariableNames', full_roi_cols);
else
    Table_RQ2_ROI_FullTerms = cell2table(rq2_roi_full_rows, 'VariableNames', full_roi_cols);
end

fprintf('Track 2 RQ2 ROI complete: %d rows recorded (%d estimated).\n', ...
    height(Table_RQ2_ROI), sum(Table_RQ2_ROI.Model_Status == "OK"));

%% 9c. Multiple Comparisons Correction (FDR q < .05) & Publication Tables (RQ2)

fprintf('\n=== Computing FDR, Multipliers & Achieved Power for RQ2 ===\n');

% 1. Apply Benjamini-Hochberg FDR across Track 2 ROIs within each chromophore family (NaN-safe)
Table_RQ2_ROI.P_FDR_SC = nan(height(Table_RQ2_ROI), 1);
Table_RQ2_ROI.FDR_Mult = nan(height(Table_RQ2_ROI), 1);
Table_RQ2_ROI.FDR_m    = nan(height(Table_RQ2_ROI), 1);
for c = 1:length(chroms)
    c_idx = Table_RQ2_ROI.Chromophore == string(chroms{c});
    [q_adj, mult_v, m_v] = compute_bh_fdr(Table_RQ2_ROI.P_Val_SC(c_idx));
    Table_RQ2_ROI.P_FDR_SC(c_idx) = q_adj;
    Table_RQ2_ROI.FDR_Mult(c_idx) = mult_v;
    Table_RQ2_ROI.FDR_m(c_idx)    = m_v;
end
Table_RQ2_ROI.Achieved_Power = compute_achieved_power(Table_RQ2_ROI.T_Stat_SC, Table_RQ2_ROI.DF_SC);

% 2. Apply Option B Topographic FDR across Track 1 Channels within each Task x Chromophore family (m <= 41)
Table_RQ2_Channels.P_FDR_SC = nan(height(Table_RQ2_Channels), 1);
Table_RQ2_Channels.FDR_Mult = nan(height(Table_RQ2_Channels), 1);
Table_RQ2_Channels.FDR_m    = nan(height(Table_RQ2_Channels), 1);
tasks_ch = unique(Table_RQ2_Channels.Task_Contrast, 'stable');
for c = 1:length(chroms)
    c_str = string(chroms{c});
    for t = 1:length(tasks_ch)
        slice_idx = Table_RQ2_Channels.Chromophore == c_str & ...
                    Table_RQ2_Channels.Task_Contrast == tasks_ch(t);
        [q_adj, mult_v, m_v] = compute_bh_fdr(Table_RQ2_Channels.P_Val_SC(slice_idx));
        Table_RQ2_Channels.P_FDR_SC(slice_idx) = q_adj;
        Table_RQ2_Channels.FDR_Mult(slice_idx) = mult_v;
        Table_RQ2_Channels.FDR_m(slice_idx)    = m_v;
    end
end
Table_RQ2_Channels.Achieved_Power = compute_achieved_power(Table_RQ2_Channels.T_Stat_SC, Table_RQ2_Channels.DF_SC);

% 3. Compute standardized betas, dyad counts, and Brodmann labels
[ch_b_std, ch_ci_l, ch_ci_u, ch_n_d, ch_ba] = format_pub_metrics( ...
    Table_RQ2_Channels, Track1_Channel_Long_Table, 'Channel', 'Beta', 'Beta_SC', 'CI_Lower_SC', 'CI_Upper_SC', 'SC_Centered', Master_Atlas_Table);

[roi_b_std, roi_ci_l, roi_ci_u, roi_n_d, ~] = format_pub_metrics( ...
    Table_RQ2_ROI, Track2_ROI_Long_Table, 'ROI', 'Beta_ROI', 'Beta_SC', 'CI_Lower_SC', 'CI_Upper_SC', 'SC_Centered', Master_Atlas_Table);

% 4. Assemble publication-formatted master tables for Track 1 (Channels) and Track 2 (ROIs)
Table_RQ2_Channels_Pub = table( ...
    Table_RQ2_Channels.Task_Contrast, Table_RQ2_Channels.Chromophore, Table_RQ2_Channels.Channel, ...
    Table_RQ2_Channels.N_Obs, ch_n_d, Table_RQ2_Channels.Beta_SC, ...
    ch_b_std, ch_ci_l, ch_ci_u, Table_RQ2_Channels.T_Stat_SC, Table_RQ2_Channels.DF_SC, ...
    Table_RQ2_Channels.P_Val_SC, Table_RQ2_Channels.P_FDR_SC, ...
    Table_RQ2_Channels.FDR_Mult, Table_RQ2_Channels.FDR_m, Table_RQ2_Channels.Achieved_Power, ...
    Table_RQ2_Channels.Delta_AIC_M2_M1, Table_RQ2_Channels.Delta_AIC_M3_M1, ch_ba, Table_RQ2_Channels.Model_Status, ...
    'VariableNames', { ...
        'Condition_Contrast', 'Chromophore', 'Channel', 'N_Participants', 'N_Dyads', ...
        'Beta_SC_Raw', 'Beta_SC_Std', 'CI_Std_Lower', 'CI_Std_Upper', 't_SC', 'df', ...
        'p_SC', 'p_FDR_SC', 'FDR_Mult', 'FDR_m', 'Achieved_Power', ...
        'Delta_AIC_Unsigned', 'Delta_AIC_Dual', 'Brodmann_Area', 'Model_Status' ...
    } ...
);

Table_RQ2_ROI_Pub = table( ...
    Table_RQ2_ROI.Task_Contrast, Table_RQ2_ROI.Chromophore, Table_RQ2_ROI.ROI, ...
    Table_RQ2_ROI.N_Obs, roi_n_d, Table_RQ2_ROI.Beta_SC, ...
    roi_b_std, roi_ci_l, roi_ci_u, Table_RQ2_ROI.T_Stat_SC, Table_RQ2_ROI.DF_SC, ...
    Table_RQ2_ROI.P_Val_SC, Table_RQ2_ROI.P_FDR_SC, ...
    Table_RQ2_ROI.FDR_Mult, Table_RQ2_ROI.FDR_m, Table_RQ2_ROI.Achieved_Power, ...
    Table_RQ2_ROI.Delta_AIC_M2_M1, Table_RQ2_ROI.Delta_AIC_M3_M1, Table_RQ2_ROI.Model_Status, ...
    'VariableNames', { ...
        'Condition_Contrast', 'Chromophore', 'ROI', 'N_Participants', 'N_Dyads', ...
        'Beta_SC_Raw', 'Beta_SC_Std', 'CI_Std_Lower', 'CI_Std_Upper', 't_SC', 'df', ...
        'p_SC', 'p_FDR_SC', 'FDR_Mult', 'FDR_m', 'Achieved_Power', ...
        'Delta_AIC_Unsigned', 'Delta_AIC_Dual', 'Model_Status' ...
    } ...
);

%% 9d. Export RQ2 Deliverables & Print Command Window Summaries

% Ensure dedicated significance subfolder exists
sig_out_dir = fullfile(group_out_dir, 'RQ_Sig');
if ~exist(sig_out_dir, 'dir'), mkdir(sig_out_dir); end

% Define output file paths for publication tables, full-term covariate tables, .mat archive, and significant subsets
rq2_chan_csv = fullfile(group_out_dir, 'Table_RQ2_Publication_Channels.csv');
rq2_roi_csv = fullfile(group_out_dir, 'Table_RQ2_Publication_ROI.csv');
rq2_mat = fullfile(group_out_dir, 'GroupLevel_RQ2_Models.mat');
sig_chan_csv_rq2 = fullfile(sig_out_dir, 'Table_RQ2_Significant_Channels.csv');
sig_roi_csv_rq2 = fullfile(sig_out_dir, 'Table_RQ2_Significant_ROI.csv');

% Export all master tables and combined .mat archive
writetable(Table_RQ2_Channels_Pub, rq2_chan_csv);
writetable(Table_RQ2_ROI_Pub, rq2_roi_csv);
writetable(Table_RQ2_Channels_FullTerms, fullfile(group_out_dir, 'Table_RQ2_FullModel_Covariates_Channels.csv'));
writetable(Table_RQ2_ROI_FullTerms, fullfile(group_out_dir, 'Table_RQ2_FullModel_Covariates_ROI.csv'));
save(rq2_mat, 'Table_RQ2_Channels', 'Table_RQ2_ROI', 'Table_RQ2_Channels_Pub', 'Table_RQ2_ROI_Pub');

% Filter and sort uncorrected significant rows (p_SC < .05) for dedicated RQ_Sig export
sig_chan_rq2 = sortrows(Table_RQ2_Channels_Pub(Table_RQ2_Channels_Pub.p_SC < 0.05, :), ...
    {'Condition_Contrast', 'Chromophore', 'p_SC'}, {'ascend', 'ascend', 'ascend'});
sig_roi_rq2  = sortrows(Table_RQ2_ROI_Pub(Table_RQ2_ROI_Pub.p_SC < 0.05, :), ...
    {'Condition_Contrast', 'Chromophore', 'p_SC'}, {'ascend', 'ascend', 'ascend'});

writetable(sig_chan_rq2, sig_chan_csv_rq2);
writetable(sig_roi_rq2, sig_roi_csv_rq2);

% Print export confirmation and significance summaries to Command Window
fprintf('\nSection G complete. Saved RQ2 deliverables to:\n');
fprintf('  -> Master Channels Pub: %s\n', rq2_chan_csv);
fprintf('  -> Master ROIs Pub:     %s\n', rq2_roi_csv);
fprintf('  -> Sig Channels:        %s (%d rows)\n', sig_chan_csv_rq2, height(sig_chan_rq2));
fprintf('  -> Sig ROIs:            %s (%d rows)\n', sig_roi_csv_rq2, height(sig_roi_rq2));

fdr_roi_rq2  = Table_RQ2_ROI_Pub(Table_RQ2_ROI_Pub.p_FDR_SC < 0.05, :);
fdr_chan_rq2 = Table_RQ2_Channels_Pub(Table_RQ2_Channels_Pub.p_FDR_SC < 0.05, :);
fprintf('\nSummary of Precision-Weighted RQ2 Certainty Effects:\n');
fprintf('  - ROIs:     %d / %d uncorrected (p < .05) | %d / %d FDR-corrected (q < .05)\n', ...
    height(sig_roi_rq2), sum(Table_RQ2_ROI.Model_Status == "OK"), height(fdr_roi_rq2), sum(Table_RQ2_ROI.Model_Status == "OK"));
fprintf('  - Channels: %d / %d uncorrected (p < .05) | %d / %d FDR-corrected (q < .05)\n', ...
    height(sig_chan_rq2), sum(Table_RQ2_Channels.Model_Status == "OK"), height(fdr_chan_rq2), sum(Table_RQ2_Channels.Model_Status == "OK"));

if ~isempty(sig_roi_rq2)
    disp(sig_roi_rq2(:, {'Condition_Contrast', 'Chromophore', 'ROI', 'N_Participants', 'N_Dyads', ...
                         'Beta_SC_Std', 't_SC', 'p_SC', 'p_FDR_SC', 'Delta_AIC_Unsigned'}));
end

%% Just adds a completely new section for this tricorder model
% Used AI to replicate the prior models so this code is probably repetitive

%% 9e. Supplemental RQ2 Models with Tricorder Switch Covariate (+ Switches_Centered)

fprintf('\n=== Evaluating Supplemental RQ2 Models with Tricorder Covariate (Tricorder Tasks Only) ===\n');

tri_tasks = {'tricorder_switch_true', 'tricorder_switch_decoy'};
rq2_tri_ch_rows  = {};
rq2_tri_roi_rows = {};

% Track 1: Channel-Level Supplemental RQ2 Models
for c = 1:length(chroms)
    chrom_str = chroms{c};
    for ch_idx = 1:length(channels)
        chan_num = channels(ch_idx);
        for t = 1:length(tri_tasks)
            task_str = tri_tasks{t};
            sub_idx = Track1_Channel_Long_Table.Baseline_Type == primary_baseline & ...
                      Track1_Channel_Long_Table.Chromophore == chrom_str & ...
                      Track1_Channel_Long_Table.Channel == chan_num & ...
                      Track1_Channel_Long_Table.Task_Contrast == task_str;
            meta_idx = find(sub_idx, 1, 'first');
            if isempty(meta_idx), continue; end

            sub_tbl = Track1_Channel_Long_Table(sub_idx, {'Beta', 'SE', 'SC_Centered', 'Certainty_Centered', 'Switches_Centered', 'Time_Centered', 'Age_Centered', 'Gender_Dummy', 'Second_Dest_Dummy', 'Session_ID'});
            sub_tbl = rmmissing(sub_tbl);

            try
                n_sub = height(sub_tbl);
                if n_sub == 0
                    error('No valid observations (N = 0 after SNR pruning / missing data).');
                end
                if numel(unique(sub_tbl.SC_Centered)) < 3
                    error('Fewer than 3 unique SC_Centered values (N = %d).', n_sub);
                end
                if n_sub <= 7
                    error('Insufficient sample size (N = %d <= 7 fixed-effect parameters).', n_sub);
                end

                raw_w = 1 ./ max(sub_tbl.SE .^ 2, 1e-6);
                w_vec = raw_w / mean(raw_w);
                sub_tbl.Gender_Dummy      = removecats(categorical(sub_tbl.Gender_Dummy));
                sub_tbl.Second_Dest_Dummy = removecats(categorical(sub_tbl.Second_Dest_Dummy));
                sub_tbl.Session_ID        = removecats(categorical(sub_tbl.Session_ID));

                f1 = 'Beta ~ 1 + SC_Centered + Switches_Centered + Time_Centered + Age_Centered + Gender_Dummy + Second_Dest_Dummy + (1 | Session_ID)';
                f2 = 'Beta ~ 1 + Certainty_Centered + Switches_Centered + Time_Centered + Age_Centered + Gender_Dummy + Second_Dest_Dummy + (1 | Session_ID)';
                f3 = 'Beta ~ 1 + SC_Centered + Certainty_Centered + Switches_Centered + Time_Centered + Age_Centered + Gender_Dummy + Second_Dest_Dummy + (1 | Session_ID)';

                lme1 = fitlme(sub_tbl, f1, 'Weights', w_vec, 'FitMethod', 'ML');
                lme2 = fitlme(sub_tbl, f2, 'Weights', w_vec, 'FitMethod', 'ML');
                lme3 = fitlme(sub_tbl, f3, 'Weights', w_vec, 'FitMethod', 'ML');

                sc_idx = find(strcmp(lme1.CoefficientNames, 'SC_Centered'));
                if isempty(sc_idx)
                    error('SC_Centered dropped due to collinearity (N = %d).', n_sub);
                end

                df_sc = lme1.Coefficients.DF(sc_idx);
                p_sc  = lme1.Coefficients.pValue(sc_idx);
                if df_sc <= 0 || isnan(p_sc)
                    error('Saturated model with zero residual degrees of freedom (N = %d, df = %g).', n_sub, df_sc);
                end

                ci_sc = lme1.coefCI;
                time_idx = find(strcmp(lme1.CoefficientNames, 'Time_Centered'));
                if ~isempty(time_idx), b_time = lme1.Coefficients.Estimate(time_idx); p_time = lme1.Coefficients.pValue(time_idx);
                else, b_time = nan; p_time = nan; end

                aic1 = lme1.ModelCriterion.AIC; aic2 = lme2.ModelCriterion.AIC; aic3 = lme3.ModelCriterion.AIC;
                rq2_tri_ch_rows(end+1, 1:25) = { ...
                    string(primary_baseline), string(task_str), ...
                    string(Track1_Channel_Long_Table.Timescale(meta_idx)), ...
                    Track1_Channel_Long_Table.Timescale_Num(meta_idx), ...
                    string(chrom_str), chan_num, ...
                    Track1_Channel_Long_Table.Source(meta_idx), ...
                    Track1_Channel_Long_Table.Detector(meta_idx), ...
                    string(Track1_Channel_Long_Table.ROI(meta_idx)), n_sub, ...
                    lme1.Coefficients.Estimate(sc_idx), lme1.Coefficients.SE(sc_idx), ...
                    lme1.Coefficients.tStat(sc_idx), df_sc, ...
                    p_sc, ci_sc(sc_idx,1), ci_sc(sc_idx,2), ...
                    b_time, p_time, aic1, aic2, aic3, (aic2 - aic1), (aic3 - aic1), "OK" ...
                };
            catch ME
                err_txt = string(ME.message);
                if contains(err_txt, "full column rank")
                    err_txt = sprintf("Collinear covariates in small subsample (rank deficient; N = %d).", height(sub_tbl));
                end
                rq2_tri_ch_rows(end+1, 1:25) = { ...
                    string(primary_baseline), string(task_str), ...
                    string(Track1_Channel_Long_Table.Timescale(meta_idx)), ...
                    Track1_Channel_Long_Table.Timescale_Num(meta_idx), ...
                    string(chrom_str), chan_num, ...
                    Track1_Channel_Long_Table.Source(meta_idx), ...
                    Track1_Channel_Long_Table.Detector(meta_idx), ...
                    string(Track1_Channel_Long_Table.ROI(meta_idx)), height(sub_tbl), ...
                    NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, "Skipped: " + err_txt ...
                };
            end
        end
    end
end

% Track 2: ROI-Level Supplemental RQ2 Models
for c = 1:length(chroms)
    chrom_str = chroms{c};
    for r = 1:length(rois)
        roi_str = rois{r};
        for t = 1:length(tri_tasks)
            task_str = tri_tasks{t};
            sub_idx = Track2_ROI_Long_Table.Baseline_Type == primary_baseline & ...
                      Track2_ROI_Long_Table.Chromophore == chrom_str & ...
                      Track2_ROI_Long_Table.ROI == roi_str & ...
                      Track2_ROI_Long_Table.Task_Contrast == task_str;
            meta_idx = find(sub_idx, 1, 'first');
            if isempty(meta_idx), continue; end

            sub_tbl = Track2_ROI_Long_Table(sub_idx, {'Beta_ROI', 'SE_ROI', 'SC_Centered', 'Certainty_Centered', 'Switches_Centered', 'Time_Centered', 'Age_Centered', 'Gender_Dummy', 'Second_Dest_Dummy', 'Session_ID'});
            sub_tbl = rmmissing(sub_tbl);

            try
                n_sub = height(sub_tbl);
                if n_sub == 0
                    error('No valid observations (N = 0 after missing data exclusion).');
                end
                if numel(unique(sub_tbl.SC_Centered)) < 3
                    error('Fewer than 3 unique SC_Centered values (N = %d).', n_sub);
                end
                if n_sub <= 7
                    error('Insufficient sample size (N = %d <= 7 fixed-effect parameters).', n_sub);
                end

                raw_w = 1 ./ max(sub_tbl.SE_ROI .^ 2, 1e-6);
                w_vec = raw_w / mean(raw_w);
                sub_tbl.Gender_Dummy      = removecats(categorical(sub_tbl.Gender_Dummy));
                sub_tbl.Second_Dest_Dummy = removecats(categorical(sub_tbl.Second_Dest_Dummy));
                sub_tbl.Session_ID        = removecats(categorical(sub_tbl.Session_ID));

                f1 = 'Beta_ROI ~ 1 + SC_Centered + Switches_Centered + Time_Centered + Age_Centered + Gender_Dummy + Second_Dest_Dummy + (1 | Session_ID)';
                f2 = 'Beta_ROI ~ 1 + Certainty_Centered + Switches_Centered + Time_Centered + Age_Centered + Gender_Dummy + Second_Dest_Dummy + (1 | Session_ID)';
                f3 = 'Beta_ROI ~ 1 + SC_Centered + Certainty_Centered + Switches_Centered + Time_Centered + Age_Centered + Gender_Dummy + Second_Dest_Dummy + (1 | Session_ID)';

                lme1 = fitlme(sub_tbl, f1, 'Weights', w_vec, 'FitMethod', 'ML');
                lme2 = fitlme(sub_tbl, f2, 'Weights', w_vec, 'FitMethod', 'ML');
                lme3 = fitlme(sub_tbl, f3, 'Weights', w_vec, 'FitMethod', 'ML');

                sc_idx = find(strcmp(lme1.CoefficientNames, 'SC_Centered'));
                if isempty(sc_idx)
                    error('SC_Centered dropped due to collinearity (N = %d).', n_sub);
                end

                df_sc = lme1.Coefficients.DF(sc_idx);
                p_sc  = lme1.Coefficients.pValue(sc_idx);
                if df_sc <= 0 || isnan(p_sc)
                    error('Saturated model with zero residual degrees of freedom (N = %d, df = %g).', n_sub, df_sc);
                end

                ci_sc = lme1.coefCI;
                time_idx = find(strcmp(lme1.CoefficientNames, 'Time_Centered'));
                if ~isempty(time_idx), b_time = lme1.Coefficients.Estimate(time_idx); p_time = lme1.Coefficients.pValue(time_idx);
                else, b_time = nan; p_time = nan; end

                aic1 = lme1.ModelCriterion.AIC; aic2 = lme2.ModelCriterion.AIC; aic3 = lme3.ModelCriterion.AIC;
                rq2_tri_roi_rows(end+1, 1:22) = { ...
                    string(primary_baseline), string(task_str), ...
                    string(Track2_ROI_Long_Table.Timescale(meta_idx)), ...
                    Track2_ROI_Long_Table.Timescale_Num(meta_idx), ...
                    string(chrom_str), string(roi_str), n_sub, ...
                    lme1.Coefficients.Estimate(sc_idx), lme1.Coefficients.SE(sc_idx), ...
                    lme1.Coefficients.tStat(sc_idx), df_sc, ...
                    p_sc, ci_sc(sc_idx,1), ci_sc(sc_idx,2), ...
                    b_time, p_time, aic1, aic2, aic3, (aic2 - aic1), (aic3 - aic1), "OK" ...
                };
            catch ME
                err_txt = string(ME.message);
                if contains(err_txt, "full column rank")
                    err_txt = sprintf("Collinear covariates in small subsample (rank deficient; N = %d).", height(sub_tbl));
                end
                rq2_tri_roi_rows(end+1, 1:22) = { ...
                    string(primary_baseline), string(task_str), ...
                    string(Track2_ROI_Long_Table.Timescale(meta_idx)), ...
                    Track2_ROI_Long_Table.Timescale_Num(meta_idx), ...
                    string(chrom_str), string(roi_str), height(sub_tbl), ...
                    NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, "Skipped: " + err_txt ...
                };
            end
        end
    end
end

if ~isempty(rq2_tri_ch_rows) && ~isempty(rq2_tri_roi_rows)
    Table_RQ2_TriCov_Channels = cell2table(rq2_tri_ch_rows, 'VariableNames', chan_col_names_rq2);
    Table_RQ2_TriCov_ROI      = cell2table(rq2_tri_roi_rows, 'VariableNames', roi_col_names_rq2);

    % FDR Correction + Multiplier + Achieved Power (ROI)
    Table_RQ2_TriCov_ROI.P_FDR_SC = nan(height(Table_RQ2_TriCov_ROI), 1);
    Table_RQ2_TriCov_ROI.FDR_Mult = nan(height(Table_RQ2_TriCov_ROI), 1);
    Table_RQ2_TriCov_ROI.FDR_m    = nan(height(Table_RQ2_TriCov_ROI), 1);
    for c = 1:length(chroms)
        c_idx = Table_RQ2_TriCov_ROI.Chromophore == string(chroms{c});
        [q_adj, mult_v, m_v] = compute_bh_fdr(Table_RQ2_TriCov_ROI.P_Val_SC(c_idx));
        Table_RQ2_TriCov_ROI.P_FDR_SC(c_idx) = q_adj;
        Table_RQ2_TriCov_ROI.FDR_Mult(c_idx) = mult_v;
        Table_RQ2_TriCov_ROI.FDR_m(c_idx)    = m_v;
    end
    Table_RQ2_TriCov_ROI.Achieved_Power = compute_achieved_power(Table_RQ2_TriCov_ROI.T_Stat_SC, Table_RQ2_TriCov_ROI.DF_SC);

    % FDR Correction + Multiplier + Achieved Power (Channels)
    Table_RQ2_TriCov_Channels.P_FDR_SC = nan(height(Table_RQ2_TriCov_Channels), 1);
    Table_RQ2_TriCov_Channels.FDR_Mult = nan(height(Table_RQ2_TriCov_Channels), 1);
    Table_RQ2_TriCov_Channels.FDR_m    = nan(height(Table_RQ2_TriCov_Channels), 1);
    for c = 1:length(chroms)
        for t = 1:length(tri_tasks)
            s_idx = Table_RQ2_TriCov_Channels.Chromophore == string(chroms{c}) & ...
                    Table_RQ2_TriCov_Channels.Task_Contrast == string(tri_tasks{t});
            [q_adj, mult_v, m_v] = compute_bh_fdr(Table_RQ2_TriCov_Channels.P_Val_SC(s_idx));
            Table_RQ2_TriCov_Channels.P_FDR_SC(s_idx) = q_adj;
            Table_RQ2_TriCov_Channels.FDR_Mult(s_idx) = mult_v;
            Table_RQ2_TriCov_Channels.FDR_m(s_idx)    = m_v;
        end
    end
    Table_RQ2_TriCov_Channels.Achieved_Power = compute_achieved_power(Table_RQ2_TriCov_Channels.T_Stat_SC, Table_RQ2_TriCov_Channels.DF_SC);

    [tri2_ch_b, tri2_ch_l, tri2_ch_u, tri2_ch_nd, tri2_ch_ba] = format_pub_metrics( ...
        Table_RQ2_TriCov_Channels, Track1_Channel_Long_Table, 'Channel', 'Beta', 'Beta_SC', 'CI_Lower_SC', 'CI_Upper_SC', 'SC_Centered', Master_Atlas_Table);
    [tri2_roi_b, tri2_roi_l, tri2_roi_u, tri2_roi_nd, ~] = format_pub_metrics( ...
        Table_RQ2_TriCov_ROI, Track2_ROI_Long_Table, 'ROI', 'Beta_ROI', 'Beta_SC', 'CI_Lower_SC', 'CI_Upper_SC', 'SC_Centered', Master_Atlas_Table);

    Table_RQ2_TriCov_Channels_Pub = table( ...
        Table_RQ2_TriCov_Channels.Task_Contrast, Table_RQ2_TriCov_Channels.Chromophore, Table_RQ2_TriCov_Channels.Channel, ...
        Table_RQ2_TriCov_Channels.N_Obs, tri2_ch_nd, Table_RQ2_TriCov_Channels.Beta_SC, ...
        tri2_ch_b, tri2_ch_l, tri2_ch_u, Table_RQ2_TriCov_Channels.T_Stat_SC, Table_RQ2_TriCov_Channels.DF_SC, ...
        Table_RQ2_TriCov_Channels.P_Val_SC, Table_RQ2_TriCov_Channels.P_FDR_SC, ...
        Table_RQ2_TriCov_Channels.FDR_Mult, Table_RQ2_TriCov_Channels.FDR_m, Table_RQ2_TriCov_Channels.Achieved_Power, ...
        Table_RQ2_TriCov_Channels.Delta_AIC_M2_M1, Table_RQ2_TriCov_Channels.Delta_AIC_M3_M1, tri2_ch_ba, Table_RQ2_TriCov_Channels.Model_Status, ...
        'VariableNames', {'Condition_Contrast', 'Chromophore', 'Channel', 'N_Participants', 'N_Dyads', ...
                          'Beta_SC_Raw', 'Beta_SC_Std', 'CI_Std_Lower', 'CI_Std_Upper', 't_SC', 'df', ...
                          'p_SC', 'p_FDR_SC', 'FDR_Mult', 'FDR_m', 'Achieved_Power', ...
                          'Delta_AIC_Unsigned', 'Delta_AIC_Dual', 'Brodmann_Area', 'Model_Status'});

    Table_RQ2_TriCov_ROI_Pub = table( ...
        Table_RQ2_TriCov_ROI.Task_Contrast, Table_RQ2_TriCov_ROI.Chromophore, Table_RQ2_TriCov_ROI.ROI, ...
        Table_RQ2_TriCov_ROI.N_Obs, tri2_roi_nd, Table_RQ2_TriCov_ROI.Beta_SC, ...
        tri2_roi_b, tri2_roi_l, tri2_roi_u, Table_RQ2_TriCov_ROI.T_Stat_SC, Table_RQ2_TriCov_ROI.DF_SC, ...
        Table_RQ2_TriCov_ROI.P_Val_SC, Table_RQ2_TriCov_ROI.P_FDR_SC, ...
        Table_RQ2_TriCov_ROI.FDR_Mult, Table_RQ2_TriCov_ROI.FDR_m, Table_RQ2_TriCov_ROI.Achieved_Power, ...
        Table_RQ2_TriCov_ROI.Delta_AIC_M2_M1, Table_RQ2_TriCov_ROI.Delta_AIC_M3_M1, Table_RQ2_TriCov_ROI.Model_Status, ...
        'VariableNames', {'Condition_Contrast', 'Chromophore', 'ROI', 'N_Participants', 'N_Dyads', ...
                          'Beta_SC_Raw', 'Beta_SC_Std', 'CI_Std_Lower', 'CI_Std_Upper', 't_SC', 'df', ...
                          'p_SC', 'p_FDR_SC', 'FDR_Mult', 'FDR_m', 'Achieved_Power', ...
                          'Delta_AIC_Unsigned', 'Delta_AIC_Dual', 'Model_Status'});

    writetable(Table_RQ2_TriCov_Channels_Pub, fullfile(group_out_dir, 'Table_RQ2_TricorderCovariate_Publication_Channels.csv'));
    writetable(Table_RQ2_TriCov_ROI_Pub,      fullfile(group_out_dir, 'Table_RQ2_TricorderCovariate_Publication_ROI.csv'));
    fprintf('Saved supplemental RQ2 tricorder-covariate publication tables.\n');
end

%% =========================================================================
%  LOCAL HELPERS: Shared Statistical, Formatting & Extraction Utilities
% =========================================================================

% 1. Benjamini-Hochberg False Discovery Rate (FDR) Correction (NaN-Safe)
% function q_adj = compute_bh_fdr(p_raw)
function [q_adj, fdr_mult, fdr_m] = compute_bh_fdr(p_raw)
    % Initialize output vector with NaNs so unestimated model rows stay NaN
    q_adj     = nan(size(p_raw));
    fdr_mult  = nan(size(p_raw));
    fdr_m     = nan(size(p_raw));
    valid_idx = ~isnan(p_raw);
    p_valid   = p_raw(valid_idx);
    if isempty(p_valid), return; end
    
    % Sort valid p-values ascending and compute raw BH step-up ratios p_(i) * m / i
    [p_sorted, sort_order] = sort(p_valid, 'ascend');
    m = length(p_valid);
    mult_sorted = m ./ (1:m)';
    q_sorted    = p_sorted .* mult_sorted;
    
    % Enforce cumulative monotonicity from largest rank down to 1 and clamp at 1.0
    for k = m-1:-1:1
        q_sorted(k) = min(q_sorted(k), q_sorted(k+1));
    end
    q_sorted = min(q_sorted, 1);
    
    % Restore original row order and write back into valid positions
    q_valid = zeros(size(p_valid));
    mult_valid = zeros(size(p_valid));

    q_valid(sort_order) = q_sorted;
    mult_valid(sort_order) = mult_sorted;

    q_adj(valid_idx) = q_valid;
    fdr_mult(valid_idx) = mult_valid;
    fdr_m(valid_idx)    = m;
end

% 1b. Two-Tailed Post-Hoc Achieved Power via Noncentral t-CDF (matches G*Power)
function pwr = compute_achieved_power(t_vec, df_vec, alpha)
    if nargin < 3, alpha = 0.05; end
    pwr = nan(size(t_vec));
    valid = ~isnan(t_vec) & ~isnan(df_vec) & (df_vec > 0);
    if ~any(valid), return; end
    
    tc  = tinv(1 - alpha / 2, df_vec(valid));
    ncp = abs(t_vec(valid));
    pwr(valid) = (1 - nctcdf(tc, df_vec(valid), ncp)) + nctcdf(-tc, df_vec(valid), ncp);
end

% 2. Compute Standardized Betas, 95% CIs, Unique Dyad Counts & Brodmann Labels
% Modified to include atlas lookup table
function [b_std, ci_low, ci_upp, n_dyads, ba_label] = format_pub_metrics( ...
    res_tbl, long_tbl, unit_col, y_col, beta_col, cil_col, ciu_col, x_col, atlas_tbl)
    
    n_rows   = height(res_tbl);
    b_std    = nan(n_rows, 1);
    ci_low   = nan(n_rows, 1);
    ci_upp   = nan(n_rows, 1);
    n_dyads  = nan(n_rows, 1);
    ba_label = strings(n_rows, 1);
    
    for row = 1:n_rows
        % Map functional ROI code to full Brodmann Area anatomical label
        % ba_label(row) = map_roi_to_ba(string(res_tbl.ROI(row)));

        % Updated! Now uses BA Label instead of ROI
        if strcmp(unit_col, 'Channel') && nargin >= 9 && ismember('NFRI_BA_Primary', atlas_tbl.Properties.VariableNames)
            ch_idx_atlas = find(atlas_tbl.Channel == res_tbl.Channel(row), 1);
            if ~isempty(ch_idx_atlas)
                ba_label(row) = atlas_tbl.NFRI_BA_Primary(ch_idx_atlas);
            end
        end
        
        % Match participant observations in the long table for this Task x Chromophore x Unit slice
        idx = long_tbl.Baseline_Type == "TaskMatched" & ...
              long_tbl.Task_Contrast == res_tbl.Task_Contrast(row) & ...
              long_tbl.Chromophore   == res_tbl.Chromophore(row) & ...
              long_tbl.(unit_col)    == res_tbl.(unit_col)(row);
        
        sub = rmmissing(long_tbl(idx, {y_col, x_col, 'Session_ID'}));
        n_dyads(row) = numel(unique(sub.Session_ID));
        
        % Compute standardized beta via Beta_Std = Beta_Raw * (SD(X) / SD(Y))
        if height(sub) > 1 && ~isnan(res_tbl.(beta_col)(row))
            sx = std(double(sub.(x_col)));
            sy = std(double(sub.(y_col)));
            if sy > 0
                scale_factor = sx / sy;
                b_std(row)   = res_tbl.(beta_col)(row) * scale_factor;
                ci_low(row)  = res_tbl.(cil_col)(row)  * scale_factor;
                ci_upp(row)  = res_tbl.(ciu_col)(row)  * scale_factor;
            end
        end
    end
end

% 3. Map Functional ROI Identifier to Anatomical Brodmann Area Description
function ba_str = map_roi_to_ba(roi_str)
    switch roi_str
        case "RPFC"
            ba_str = "BA 10 – Rostral Prefrontal Cortex";
        case "L_DLPFC"
            ba_str = "BA 9/46 – Left Dorsolateral Prefrontal Cortex";
        case "R_DLPFC"
            ba_str = "BA 9/46 – Right Dorsolateral Prefrontal Cortex";
        case "L_Parietal"
            ba_str = "BA 7/40 – Left Posterior Parietal Cortex";
        case "R_Parietal"
            ba_str = "BA 7/40 – Right Posterior Parietal Cortex";
        otherwise
            ba_str = roi_str;
    end
end

% 4. Extract Full Fixed-Effect Covariates & Random-Effect Variance Breakdown
function rows = extract_lme_full_terms(lme, base_meta, rows, status_str)
    if nargin < 4
        status_str = "OK";
    end
    coef_tbl = lme.Coefficients;
    ci       = lme.coefCI;
    
    % Extract all fixed effects (Intercept, Primary Predictor, & All Covariates) with partial eta-squared
    for k = 1:height(coef_tbl)
        t_val  = coef_tbl.tStat(k);
        df_val = coef_tbl.DF(k);
        np2    = (t_val^2) / (t_val^2 + df_val);
        
        rows(end+1, :) = [base_meta, { ...
            "Fixed", string(coef_tbl.Name{k}), ...
            coef_tbl.Estimate(k), coef_tbl.SE(k), t_val, df_val, coef_tbl.pValue(k), ...
            ci(k, 1), ci(k, 2), np2, NaN, status_str ...
        }];
    end
    
    % Extract dyadic random-intercept variance and Intraclass Correlation Coefficient (ICC)
    [psi, mse] = covarianceParameters(lme);
    var_dyad   = psi{1}(1, 1);
    icc_val    = var_dyad / (var_dyad + mse);
    
    rows(end+1, :) = [base_meta, { ...
        "Random", "Session_ID (Intercept)", ...
        NaN, NaN, NaN, NaN, NaN, NaN, NaN, ...
        var_dyad, icc_val, status_str ...
    }];
end
