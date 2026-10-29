% Preprocess.m
% Jalynn Nicoly September 29th, 2026
% This is script 1/4 to load and clean the fNIRS data
% Load; Digitize; BLL; Bandpass; Check Quality; Export as .fif? Save
% variables too; Motion artifact corrects (TDDR?); Short separation
% channels; Prunes bad channels; applies wavelet motion correction;
% downsamples to 1 hz; filters 0.01 to 0.2 Hz
% Input: Raw .nirs data; digitization .txt files;
% Output: Cleaned time series .mat? .fif?; File of excluded bad channels;
% Signal to noise ratio values for quality diagnostics

%% SECTION A

% Command Window Update
fprintf('\n--- Starting fNIRS Preprocess.m ---\n')

% Clear Terminal
clear, clc

% Silence naming conflict warnings
warning('off', 'MATLAB:dispatcher:nameConflict');

%% 1. Set MATLAB Paths

% Add NIRS Toolbox to MATLAB Path
% https://github.com/huppertt/nirs-toolbox.git
% addpath(genpath('D:\GitHub\nirs-toolbox')) % PC
addpath(genpath('C:\Users\Jalynn\Documents\GitHub\nirs-toolbox')) % Laptop

% Add NIRS SPM 
% https://github.com/spm/spm12.git
% addpath('D:\GitHub\spm12') % PC
addpath('C:\Users\Jalynn\Documents\GitHub\spm12') % Laptop

% https://www.nitrc.org/projects/nirs_spm/
% addpath('D:\GitHub\NIRS_SPM_v4_r1') % PC
addpath('C:\Users\Jalynn\Downloads\NIRS_SPM_v4_r1') % Laptop

%% 2. Load NIRS Files

% Quote from Methods
% "Hemodynamics data were recorded with NIRSport2 at 5.1 Hz from 8 short
% channels, and 16 sources and 15 detectors, forming 41 long-separation 
% channels over the bilateral prefrontal and parietal cortex."

% All ptps analyzed under 'Spy' condition

% Command Window Update
fprintf('--- Load the NIRS Files for Each Ptp ---\n')

% Add Data Directory
% Directory = 'D:\GitHub\Mars_fNIRS\Data\fNIRS'; % PC
Directory = 'C:\Users\Jalynn\Documents\GitHub\Mars_fNIRS\Data\fNIRS'; % Laptop

% NIRS File for Ptp1:
% filePath = 'D:\GitHub\Mars_fNIRS\Data\fNIRS\2025-10-26-P1\2025-10-26_001.nirs';
% info = whos('-file', filePath);
% disp(table({info.name}', {info.size}', {info.class}', 'VariableNames', {'Name', 'Size', 'Class'}));
    %  Name          Size           Class   
    % _______    _____________    __________
    % 
    % {'SD' }    {[      1 1]}    {'struct'}
    % {'aux'}    {[20960 4 3]}    {'double'}
    % {'d'  }    {[ 20960 98]}    {'double'}
    % {'s'  }    {[ 20960 66]}    {'double'}
    % {'t'  }    {[  20960 1]}    {'double'}
    % Number of time samples: 20960
    % Number of sensors/ports: 4
    % Number of measure axes: 3
    % Number of raw intensities: 98 (49 x 2)
    % Provides Number of Channels: 49
    % Provided by Number of Wavelengths: 2
    % Number of trigger channels: 66
    % Montage metadata: 1 1 struct; source-detector setup

    % raw(1).Fs: 5.0863 (Sampling rate)

% Search for all .nirs/.snirf files
% Assigns the first subfolder the subj ID
% Raw is an array of nirs.core.Data objects
% 'Subject ID' is added to raw dictionary per folder/subj
raw = nirs.io.loadDirectory(Directory, {'Subject'});

% Later I learned that it was sorting raw in an interesting way (e.g.
% raw(1) was ptp 14.2 and I wanted this to be more intuitive

% Sort by ptp id rather than date
subj_names = arrayfun(@(x) x.demographics('Subject'), raw, 'UniformOutput', false);

% Initialize as empty
ptp_num = zeros(length(raw), 1);

% Loop through each of the subj_names from raw
for k = 1:length(subj_names)

    % Only use the ptp id that comes after 'p' in the folder name
    token = regexp(subj_names{k}, 'P(?<num>\d+(\.\d+)?)', 'names');
    
    if ~isempty(token)
        ptp_num(k) = str2double(token.num);
    else
        ptp_num(k) = k;
    end
end

% Sort by the ptp_numbers
[~, sort_order] = sort(ptp_num);
raw = raw(sort_order);

% Confirm fix in command window
% fprintf('Raw(1) is now: %s\n', raw(1).demographics('Subject'));

% Command Window Update
fprintf('\n Providing a Visual of Raw(1) \n')
fprintf('\n For Better Visuals; Visualize_Dyads.m \n')

% Uses built-in GUI
% This version simply outputs the 49 channels x 2 wavelengths
% Along with the received LSL stimulus in the legend
raw(1).draw();

% Use the Visualize_Events.m script for the visual with the 
% events provided by the CSV file
% Alt: Visualize_Dyads.m

% Command Window Update
fprintf('\n--- Loading Participants Complete ---\n')

%% 3. Attach Demographics Metadata

demo_file = 'C:\Users\Jalynn\Documents\GitHub\Mars_fNIRS\Data\Demographics\fnirs_demographics_spyV4.csv';
demo_table = readtable(demo_file);

for i = 1:length(raw)
    % Extract current subj id
    subj_val = raw(i).demographics('Subject');

    % Convert to numeric
    matched_id = regexp(subj_val, '(?<=P)\d+', 'match', 'once');
    subj_id = str2double(matched_id);

    % Find matching row
    row_idx = find(demo_table.participant_id == subj_id, 1);

    if ~isempty(row_idx)
        % Core identifiers & dyad structure
        raw(i).demographics('bids_id') = sprintf('sub-%02d', demo_table.participant_id(row_idx));
        raw(i).demographics('participant_id') = demo_table.participant_id(row_idx);
        raw(i).demographics('session_id') = demo_table.session_id(row_idx); % Dyad / Team ID
        raw(i).demographics('scenario') = char(demo_table.scenario(row_idx));
        
        % Individual-level covariates
        raw(i).demographics('age') = demo_table.age(row_idx);
        raw(i).demographics('biosex') = demo_table.biosex(row_idx);
        raw(i).demographics('gender') = demo_table.gender(row_idx);
        
        % Team & task performance metrics (RQ1 / RQ2)
        raw(i).demographics('team_performance') = demo_table.team_performance(row_idx);
        raw(i).demographics('intended_both') = demo_table.intended_both(row_idx);
        raw(i).demographics('exec_cert_final') = demo_table.exec_cert_final(row_idx);
    else
        warning('Participant ID %d not found in demographics CSV.', subj_id);
    end
end

% Command window update
fprintf('Demographics attached for %d participants.\n', length(raw));

%% 4. Extract Events

% Command Window Update
fprintf('\n--- Extracting Events for Each Participant ---\n')

% Load Events File
% event_csv_path = 'D:\GitHub\Mars_fNIRS\Data\Events\spy_events_all_sessions(in).csv'; % PC
event_csv_path = 'C:\Users\Jalynn\Documents\GitHub\Mars_fNIRS\Data\Events\spy_events_all_sessionsV3'; % Laptop
event_table = readtable(event_csv_path);

% Event data will be grouped by ptp stored in a struct
events_by_ptp = struct();

% Goal is to search through csv and assign events
% to the corresponding ptp in both (1) the struct and 
% (2) in the "raw" variable
% Loop through all participants
for i = 1:length(raw)

    % Subject was assigned when raw was created
    % Subject refers to the name of the folder/the ptp
    subj_id = raw(i).demographics('Subject');

    % Search events_table for only this subj_id
    % Save only the events for this subj
    subj_events = event_table(strcmp(event_table.fnirs_folder, subj_id), :);

    % Confirm there are events
    % if empty end, else continue
    if isempty(subj_events), continue; end

    % Store the subj_events for each subj_id
    % Uses the struct defined above
    % The folder names are not appropraite for matlab conventions
    events_by_ptp.(matlab.lang.makeValidName(['ptp_' subj_id])) = subj_events;

    % While the events are saved in a separate struct...
    % We can assign all of the events to each individual
    % Using their position in raw
    % E.g. Ptp 1 is raw(1)
    fs = 1 / mean(diff(raw(i).time));
    individual_events = unique(subj_events.event);

    % The LSL triggers that were sent are still saved in the fNIRS data
    % We want to remove them and instead use the CSV
    % This for now just creates an empty dictionary
    raw(i).stimulus = Dictionary();

    % Now we need to populate that dictionary with the CSV events
    for event = 1:length(individual_events)

        % Pulls the event name from the list of csv events for this
        % participant
        event_name = individual_events{event};

        % Creates a boolean mask matching all rows in the event table that
        % correspond with this condition name
        event_rows = strcmp(subj_events.event, event_name);

        % Extract sample indices and durations in second from table
        idx_samples = subj_events.onset_fnirs_index(event_rows);
        dur_seconds = subj_events.duration_s(event_rows);

        % Safety check - only keep valid indices within raw time bounds
        valid_mask = (idx_samples >= 1) & (idx_samples <= length(raw(i).time));
        if ~all(valid_mask)
            warning('Ptp %s: Excluded %d event(s) for "%s" exceeding time vector bounds.', ...
                subj_id, sum(~valid_mask), event_name)
            idx_samples = idx_samples(valid_mask);
            dur_seconds = dur_seconds(valid_mask);
        end
        if isempty(idx_samples), continue; end

        % map sample indices to elapsed seconds using raw(i).time
        onset_seconds = raw(i).time(idx_samples);
        
        % Create empty NIRS Toolbox stimulus event object
        stim = nirs.design.StimulusEvents();
        % Assign the csv name to stimulus object
        stim.name = event_name;
        % Assign the csv onset to stimulus object in seconds
        stim.onset = onset_seconds;
        % Extract corresponding event duration in seconds
        stim.dur = dur_seconds;
        % Set regressor weights to 1 matching the number of event
        % occurrences
        stim.amp = ones(size(stim.onset));

        % Register stimulus event object into ptp's data object stimulus
        % dictionary (the empty one before the for loop)
        raw(i).stimulus(event_name) = stim;
    end
end

% Command Window Update
fprintf('\n--- All Events Extracted ---\n')

%% SECTION B

% This section utilizes the participants digitzation files for montage
% mapping for when we have to create visuals.

%% 5. Montage Application

% Command window updates
fprintf('\n--- Registering 3D Optode Digitization Points ---\n')

% Loop through all participants
for i = 1:length(raw)
    % Collect ptp id
    subj_id = raw(i).demographics('Subject');

    % Searches for the digitization file in this subj folder
    dig_file = fullfile(Directory, subj_id, 'digpts.txt');

    % Not all ptps have digitization files (ptp 3 comes to mind)
    if ~exist(dig_file, 'file')
        % Check subfolders if they exist but I'm pretty sure there aren't
        % any
        alt_files = dir(fullfile(Directory, subj_id, '**', 'digpts.txt'));
        if ~isempty(alt_files)
            dig_file = fullfile(alt_files(1).folder, alt_files(1).name);
        else
            warning('No digpts.txt found for participant: %s. Skipping registration.', subj_id);
            continue;
        end
    end

    % Read digpts.txt
    fid = fopen(dig_file, 'r');
    dig_data = textscan(fid, '%s %f %f %f', 'Delimiter', ':', 'MultipleDelimsAsOne', true);
    fclose(fid);

    % Pulls the label from col 1 and then the x, y, and z in mm and assigns
    % to coords
    labels = strtrim(dig_data{1});
    coords = [dig_data{2}, dig_data{3}, dig_data{4}];

    % Separates fiducials from the sources and detectors
    is_fid = ismember(lower(labels), {'nz', 'ar', 'al', 'cz', 'iz'});
    is_src = startsWith(lower(labels), 's') & ~is_fid;
    is_det = startsWith(lower(labels), 'd') & ~is_fid;

    % Ha ok now a little repetitive solution
    % Separate the fiducials/source/detectors by labels and coords
    fid_labels = labels(is_fid);
    fid_coords = coords(is_fid, :);
    
    src_labels = labels(is_src);
    src_coords = coords(is_src, :);
    
    det_labels = labels(is_det);
    det_coords = coords(is_det, :);

    % Sort sources and detectors numerically (s1, s2, ..., s16; d1, d2, ..., d23
    % This is a defensive check in case s1, s10, .. s2
    % extra and doesn't apply to this study but will keep
    % Do it for the sources
    src_nums = cellfun(@(x) sscanf(x, 's%d'), lower(src_labels));
    [~, src_order] = sort(src_nums);
    src_labels = src_labels(src_order);
    src_coords = src_coords(src_order, :);
    
    % Then for the detectors
    det_nums = cellfun(@(x) sscanf(x, 'd%d'), lower(det_labels));
    [~, det_order] = sort(det_nums);
    det_labels = det_labels(det_order);
    det_coords = det_coords(det_order, :);

    % Format into NIRS-Toolbox registered optodes table
    % This way we can assign the montage to raw objects
    % sub-parts of the table
    % Standardize names for Probe1020 internal parser:
    % 'FID-NZ', 'Source-01', 'Detector-01'
    std_fid_names = cellfun(@(x) ['FID-' upper(x)], fid_labels, 'UniformOutput', false);
    std_src_names = cellfun(@(x) sprintf('Source-%02d', sscanf(x, 's%d')), lower(src_labels), 'UniformOutput', false);
    std_det_names = cellfun(@(x) sprintf('Detector-%02d', sscanf(x, 'd%d')), lower(det_labels), 'UniformOutput', false);

    all_names = [std_fid_names; std_src_names; std_det_names];
    all_types = [repmat({'FID'}, length(fid_labels), 1); ...
                 repmat({'Source'}, length(src_labels), 1); ...
                 repmat({'Detector'}, length(det_labels), 1)];
    all_xyz   = [fid_coords; src_coords; det_coords];
    all_units = repmat({'mm'}, length(all_names), 1);
    
    % Build registered 3D optodes table
    reg_table = table(all_names, all_xyz(:,1), all_xyz(:,2), all_xyz(:,3), all_types, all_units, ...
        'VariableNames', {'Name', 'X', 'Y', 'Z', 'Type', 'Units'});

    % Promote 2D Probe to 3D Probe1020
    if ~isa(raw(i).probe, 'nirs.core.Probe1020')
        p3d = nirs.core.Probe1020();
        p3d.link = raw(i).probe.link;
        raw(i).probe = p3d;
    end

    % Assigning .optodes automatically populates .srcPos, .detPos, and .distances
    raw(i).probe.optodes = reg_table;
end

% Command window updates
fprintf('\n Montage application complete for all ptps \n')

%% SECTION C

% This section address the raw channel quality control (SNR Check) and
% creates documentation on the participants

% Quote from Methods
% "Of the 64 participants in 32 dyads, 58 contributed usable fNIRS data
% (i.e., six had poor signal quality and two experienced equipment issues). 
% These 58 participants came from 31 dyads: 27 with both members and 4 
% with one usable member.  Channels with poor signal quality were 
% identified prior to optical density conversion and excluded per 
% participant if the signal-to-noise ratio was below 3.0 (corresponding 
% to a baseline coefficient of variation threshold of 33.3%)."

%% 6. Qualtiy Control: Signal-to-Noise Ratio (SNR) Thresholding

% Background info on the SNR section
% For a while I used 50% of bad channels as a reason to remove ptps, even
% though I won't be removing ptps

% The SNR analysis run on all raw channels without trim produced only 25 usable
% participants
% 47 were excluded for poor signal quality; as in more than 50% of their
% channels were excluded following the snr threshold
% This is documented in PreprocessOutput/cohort_channel_snr_qa_summary.csv

% The next step was trimming before the first event and after the last
% event so that we are not considering the setup/takedown signals in the
% snr analysis
% 39 were excluded for poor signal quality instead of 47
% This is documented in PreprocessOutput/snr_eventsOnly_qa_summary.csv

% My next step is to use 'all' instead of 'any'
% What this means: both wavelengths need to be under the 3.0 threshold to
% remove the channel; not just one of them
% 18 were excluded for poor signal quality following this change
% This is documented in PreprocessOutput/3snr_eventsOnly_bothWavelengths_qa_summary.csv

% It is thoroughly documented that 18 ptps have >50% bad channels but
% rather than tampering with the threshold, and ensuring that SSCs were not
% being marked as bad channels, the script goes on to remove the noisy
% channels and not remove any ptps

% Command window updates
fprintf('\n--- Initiating Quality Control (SNR) ---\n')

% Methods: SNR < 3.0 (CV > 33.3%) BEFORE optical density conversion
snr_threshold = 3.0;

% Creates an empty struct with a list of the following items for ptps to be
% added to for a complete quality assessment summary
% Subject ID, Total Channels, Number of Short Channels, Number of Long
% Channels, Number of Channels Pruned from SNR, the list of pruned channels, 
% and the Status of the ptp
qa_summary = struct('Subject', {}, 'TotalChan', {}, 'ShortChan', {}, ...
    'LongChan', {}, 'PrunedChan', {}, 'PrunedChanList', {}, 'Status', {});

% Prepare for a list of only the cleaned raw files
% Just a copy of raw for now
raw_clean = raw;

% Loop through each of the raw participants
for i = 1:length(raw)
    % Collect subject id
    s_id = raw(i).demographics('Subject');

    % Collect the raw fnirs intensity matrix
    d = raw(i).data;

    % Collect all 98 channels 
    % 49 channels with 8 as SSCs; 41 long
    link = raw(i).probe.link;

    % Collect the distance of each channel
    distances = raw(i).probe.distances;

    % Find which channels are short separation channels
    % Well not yet - establishes threshold
    is_short = distances < 15;

    % Actually compute SNR
    % Previously, only the following three lines were required
    % They were replaced once I wanted to keep snr within the events

    % % mean intensity across all time points
    % mean_intensity = mean(d, 1);
    % 
    % % Std across all time points
    % std_intensity = std(d, 1);
    % 
    % % SNR = mean / std; add eps so avoid divide by zero
    % chan_snr = mean_intensity ./ (std_intensity + eps);

    % Use only the active task window:
    % Pull each stimulus from the dictionary
    stims = raw(i).stimulus;

    % Sets the condition key
    cond_keys = stims.keys;

    % Create empty arrays for event timings
    task_onsets = [];
    task_ends   = [];

    % Loop through all events
    for k = 1:length(cond_keys)
        % Collec the name of the event
        c_name = cond_keys{k};

        % Extract stimulus object
        st = stims(c_name);

        % Check that it exist in ptp session
        if ~isempty(st.onset)
            % Collect the onset
            n_pts = length(st.onset);

            % Collect the duration of the event
            durs = st.dur;

            % Case A: All occurrences have identical duration
            if length(durs) == 1
                durs = repmat(durs, n_pts, 1);
            % Case B: Empty so duration is 0
            elseif isempty(durs)
                durs = zeros(n_pts, 1);
            % Case C: Numeric vector - explicit duration
            else
                durs = durs(:);
            end

            % Append start times and calculated end times
            task_onsets = [task_onsets; st.onset(:)];
            task_ends   = [task_ends; st.onset(:) + durs];
        end
    end

    % Convert timestamps (durations) to samples (can't just add 60 seconds)
    if ~isempty(task_onsets)
        first_sample = max(1, round(min(task_onsets) * raw(i).Fs));
        last_sample  = min(size(d, 1), round(max(task_ends) * raw(i).Fs));
        task_slice   = first_sample:last_sample;
    else
        % Fallback to full duration if no task keys found
        task_slice   = 1:size(d, 1);
    end

    % Compute SNR strictly across the active task slice
    d_active = d(task_slice, :);

    % mean intensity across all time points
    mean_intensity = mean(d_active, 1);

    % Std across all time points
    std_intensity = std(d_active, 1);

    % SNR = mean / std; add eps so avoid divide by zero
    chan_snr = mean_intensity ./ (std_intensity + eps);

    % Since we are still working with raw data before conversion, we have
    % each channel twice at 760 and 850 nm
    % We can use unique to find each source/detector pair
    % We want to evaluate rejection based on the pair
    [unique_pairs, ~, pair_idx] = unique(link(:, 1:2), 'rows', 'stable');
    num_pairs = size(unique_pairs, 1);

    % fprintf('Number of unique pairs %d', num_pairs);
    % To be sure that SSC are not pruned...
    known_short_pairs = [
        4, 16; 6, 17; 7, 18; 8, 19;
        11, 20; 13, 21; 14, 22; 15, 23
        ];

    % which pairs are SSC pairs
    % default set them all to false
    pair_is_short = false(num_pairs, 1);

    % loop through each pair
    for p = 1:num_pairs
        s_val = unique_pairs.source(p);
        d_val = unique_pairs.detector(p);
        if any(known_short_pairs(:, 1) == s_val & known_short_pairs(:, 2) == d_val)
            pair_is_short(p) = true;
        end
    end

    % Ok now evaluate by pair for rejection
    % default set all pairs to false
    bad_pair_mask = false(num_pairs, 1);

    % for each of the pairs
    for p = 1:num_pairs
        % Never prune SSCs
        if pair_is_short(p)
            continue;
        end

        % identify rows corresponding to this pair we are at in the loop
        rows_for_this_pair = (pair_idx == p);

        % use 'any' for one or the either wavelength
        % use 'all' if both wavelengths to exclude one channel
        if all(chan_snr(rows_for_this_pair) < snr_threshold)
            % Marks this channel as bad since it falls below the threshold
            bad_pair_mask(p) = true;
        end
    end

    % Document the quality assessment
    num_short_pairs = sum(pair_is_short);
    num_long_pairs = num_pairs - num_short_pairs;
    num_bad_pairs = sum(bad_pair_mask);
    surviving_long = num_long_pairs - num_bad_pairs;
    
    % Compile string labels of dropped channels (e.g., 'S1-D2; S4-D5')
    bad_chan_names = {};
    bad_pair_indices = find(bad_pair_mask);
    for b = 1:length(bad_pair_indices)
        bp = bad_pair_indices(b);
        bad_chan_names{end+1} = sprintf('S%d-D%d', unique_pairs.source(bp), unique_pairs.detector(bp));
    end
    
    qa_summary(i).Subject = s_id;
    qa_summary(i).TotalChan = num_pairs;
    qa_summary(i).ShortChan = num_short_pairs;
    qa_summary(i).LongChan = num_long_pairs;
    qa_summary(i).PrunedChan = num_bad_pairs;
    qa_summary(i).PrunedChanList = strjoin(bad_chan_names, '; ');
    
    % Participant Usability Check:
    % Cara noted 6 participants had poor signal quality. Which ones??
    % OLD: If over 50% of a participant's long channels are pruned, flag as unusable.
    % if num_bad_pairs > (0.50 * num_long_pairs)
    %     qa_summary(i).Status = 'Excluded_PoorSignal';
    % else
    %     qa_summary(i).Status = 'Usable';
    % end
    % NEW: Retain all ptps with surviving data
    if surviving_long == 0
        qa_summary(i).Status = 'Excluded_ZeroChannels';
    else
        qa_summary(i).Status = 'Usable';
    end

    % Here is where we actually remove the channels!
    % Map the bad physical pairs back to the full measurement rows (both wavelengths)
    bad_measurement_rows = ismember(pair_idx, bad_pair_indices);
    good_measurement_rows = ~bad_measurement_rows;
    
    % Slices the time-series matrix: deletes columns of noisy channels.
    % This prevents NaN explosions during Wavelet decomposition and Bandpass filtering.
    % Since I initially considered just making bad channels NaN
    raw_clean(i).data = d(:, good_measurement_rows);
    
    % Slices the probe link table: deletes matching rows from channel metadata.
    % Ensures probe.link row count perfectly equals size(raw_clean(i).data, 2).
    raw_clean(i).probe.link = link(good_measurement_rows, :);

end

% For each ptp and their quality assessment move from struct to table
qa_table = struct2table(qa_summary);

% Display overview of the first 10 participants
disp(qa_table(1:min(10, height(qa_table)), :));

% Check total usability status across cohort
num_usable = sum(strcmp(qa_table.Status, 'Usable'));
num_excluded = sum(strcmp(qa_table.Status, 'Excluded_ZeroChannels'));
fprintf('\nCohort Channel QC Complete: %d participants usable for GLM/ROI analysis | %d total hardware dropouts.\n', ...
    num_usable, num_excluded);

% Write CSV report into Derivatives folder
qa_export_dir = 'C:\Users\Jalynn\Documents\GitHub\Mars_fNIRS\Scripts\PreprocessOutput';
if ~exist(qa_export_dir, 'dir')
    mkdir(qa_export_dir);
end
writetable(qa_table, fullfile(qa_export_dir, '3snr_eventsOnly_bothWavelengths_qa_summary.csv'));

% Command window updates
fprintf('\n--- Quality Control Complete ---\n')
fprintf('\n Quality Assessment Summary available at: \n\t PreprocessOutput/3snr_eventsOnly_bothWavelengths_qa_summary.csv \n\n')

%% Section D. Preprocessing Pipeline Construction w/ NIRS-Toolbox

% Classic optical density conversion, beer lambert law, wavelet filter, and
% bandpass filter

% Command window updates
fprintf('\n--- Running Preprocessing Pipeline ---\n')

%% 7. Optical Density * Modified Beer-Lambert Law (MBLL)

% Quote from Method
% "Concentration changes in oxygenated (HbO) and deoxygenated hemoglobin
% (HbR) were computed with the modified Beer–Lambert law, relative to 
% the 60s fixation periods at the start and end of the session."

% Convert raw optical intensity to optical density
jobs = nirs.modules.OpticalDensity();
jobs = nirs.modules.BeerLambertLaw(jobs);

% Added! This is following ptp30 with the following error
% >>> FAILED at Participant Index 24 (2025-11-25-P30-redo):
% Error: The vector of time instants must have at least two elements after all missing values have been removed.
% Raw Data Stats -> Non-positive values: 0 | NaNs: 0 | Min: 3.2e-07 | Max: 0.105412
% Note that this was initially added before optical density/BMLL but...
% It was MBLL that generated 131,000+ NaNs
jobs = nirs.modules.FixNaNs(jobs);

%% 8. Resample to 1 Hz

% Quote from Method
% "Data were down-sampled to 1 Hz."

jobs = nirs.modules.Resample(jobs);
jobs.Fs = 1.0;

%% 9. Wavelet-Based Motion Artifact Correction (Molavi & Dumont, 2012)

% Quote from Method
% "Motion artifacts were identified and corrected 
% with a Daubechies wavelet-based approach (Molavi & Dumont, 2012) 
% implemented with NIRS Toolbox (Santosa et al., 2018).

jobs = nirs.modules.WaveletFilter(jobs);

%% 10. Bandpass Filter (0.01 to 0.20 Hz)

% Quote from Method
% "Physiological noise and slow drifts were attenuated with a Butterworth band-pass 
% filter (0.01–0.2 Hz)." 

jobs = nirs.modules.BandPassFilter(jobs);
jobs.highpass = 0.01;
jobs.lowpass = 0.30;

%% 11. Execute

Hb = jobs.run(raw_clean);

% Command window updates
fprintf('\n--- Preprocessing Pipeline Complete ---\n')

%% Section E

% The goal is to export the cleaned data to avoid running preprocess.m
% again

%% 12. Save Preprocess Data

% Folder to save the export to
export_dir = 'C:\Users\Jalynn\Documents\GitHub\Mars_fNIRS\Data\Derivatives';

% Name of the output file
save_file = fullfile(export_dir, 'Hb_preprocessed_cohort.mat');

% Command window update
fprintf('Saving preprocessed cohort of data to %s ... \n', save_file)

% -v7.3 tells MATLAB to use HDF5-based file format instead of old v7
save(save_file, 'Hb', 'qa_table', '-v7.3');

% Command window update
fprintf('Saved succcessfully!\n')
