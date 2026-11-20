% Preprocess_QTNIRS_Test.m
% Jalynn Nicoly
% Diagnostic copy of Preprocess.m: SNR commented out; Optical Density -> qt-nirs (SCI/PSP) added
% Input: Raw .nirs data; digitization .txt files; Experimental CSVs
% Task: Evaluate surviving channel percentages under qt-nirs without overwriting production .mat
% Output: QA CSV Summary (qtnirs_sci_eventsOnly_qa_summary.csv)

%% SECTION A

% Command Window Update
fprintf('\n--- Starting fNIRS Preprocess_QTNIRS_Test.m ---\n')

% Clear Terminal
clear, clc

% Silence naming conflict warnings
warning('off', 'MATLAB:dispatcher:nameConflict');

%% 1. Set MATLAB Paths

% Add NIRS Toolbox to MATLAB Path
% https://github.com/huppertt/nirs-toolbox.git
addpath(genpath('D:\GitHub\nirs-toolbox')) % PC
% addpath(genpath('C:\Users\Jalynn\Documents\GitHub\nirs-toolbox')) % Laptop

% Add NIRS SPM 
% https://github.com/spm/spm12.git
addpath('D:\GitHub\spm12') % PC
% addpath('C:\Users\Jalynn\Documents\GitHub\spm12') % Laptop

% https://www.nitrc.org/projects/nirs_spm/
addpath('D:\GitHub\NIRS_SPM_v4_r1') % PC
% addpath('C:\Users\Jalynn\Downloads\NIRS_SPM_v4_r1') % Laptop

addpath(genpath('D:\GitHub\qt-nirs')) % PC 

%% 2. Load NIRS Files

% Command Window Update
fprintf('--- Load the NIRS Files for Each Ptp ---\n')

% Add Data Directory
Directory = 'D:\GitHub\Mars_fNIRS\Data\fNIRS'; % PC
% Directory = 'C:\Users\Jalynn\Documents\GitHub\Mars_fNIRS\Data\fNIRS'; % Laptop

raw = nirs.io.loadDirectory(Directory, {'Subject'});

% Sort by ptp id rather than date
subj_names = arrayfun(@(x) x.demographics('Subject'), raw, 'UniformOutput', false);
ptp_num = zeros(length(raw), 1);

for k = 1:length(subj_names)
    token = regexp(subj_names{k}, 'P(?<num>\d+)', 'names');
    if ~isempty(token)
        ptp_num(k) = str2double(token.num);
    else
        ptp_num(k) = k;
    end
end

[~, sort_order] = sort(ptp_num);
raw = raw(sort_order);

fprintf('\n--- Loading Participants Complete ---\n')

%% 3. Attach Demographics Metadata

% demo_file = 'C:\Users\Jalynn\Documents\GitHub\Mars_fNIRS\Data\Demographics\fnirs_demographics_spyV4.csv'; % Laptop
demo_file = 'D:\GitHub\Mars_fNIRS\Data\Demographics\fnirs_demographics_spy_V5.csv';
demo_table = readtable(demo_file);

for i = 1:length(raw)
    subj_val = raw(i).demographics('Subject');
    matched_id = regexp(subj_val, '(?<=P)\d+', 'match', 'once');
    subj_id = str2double(matched_id);
    row_idx = find(demo_table.participant_id == subj_id, 1);

    if ~isempty(row_idx)
        raw(i).demographics('bids_id') = sprintf('sub-%02d', demo_table.participant_id(row_idx));
        raw(i).demographics('participant_id') = demo_table.participant_id(row_idx);
        raw(i).demographics('session_id') = demo_table.session_id(row_idx);
        raw(i).demographics('scenario') = char(demo_table.scenario(row_idx));
        
        raw(i).demographics('age') = demo_table.age(row_idx);
        raw(i).demographics('biosex') = demo_table.biosex(row_idx);
        raw(i).demographics('gender') = demo_table.gender(row_idx);
        
        raw(i).demographics('team_performance') = demo_table.team_performance(row_idx);
        raw(i).demographics('intended_both') = demo_table.intended_both(row_idx);
        raw(i).demographics('exec_cert_final') = demo_table.exec_cert_final(row_idx);
    else
        warning('Participant ID %d not found in demographics CSV.', subj_id);
    end
end

fprintf('Demographics attached for %d participants.\n', length(raw));

%% 4. Extract Events

fprintf('\n--- Extracting Events for Each Participant ---\n')

event_csv_path = 'D:\GitHub\Mars_fNIRS\Data\Events\spy_events_all_sessionsV4.csv'; % PC
% event_csv_path = 'C:\Users\Jalynn\Documents\GitHub\Mars_fNIRS\Data\Events\spy_events_all_sessionsV4.csv'; % Laptop
event_table = readtable(event_csv_path);

events_by_ptp = struct();

for i = 1:length(raw)
    subj_id = strtrim(raw(i).demographics('Subject'));

    match_mask = strcmp(strtrim(event_table.fnirs_folder), subj_id) | ...
        strcmp(strrep(strtrim(event_table.fnirs_folder), '-', '_'), strrep(subj_id, '-', '_'));

    subj_events = event_table(match_mask, :);

    if isempty(subj_events)
        warning('Critical: No events found in CSV for subject "%s" (index %d). Skipped event replacement.', subj_id, i);
        continue; 
    end

    events_by_ptp.(matlab.lang.makeValidName(['ptp_' subj_id])) = subj_events;

    fs = 1 / mean(diff(raw(i).time));
    individual_events = unique(subj_events.event);

    raw(i).stimulus = Dictionary();

    for event = 1:length(individual_events)
        event_name = individual_events{event};
        event_rows = strcmp(subj_events.event, event_name);

        idx_samples = subj_events.onset_fnirs_index(event_rows);
        dur_seconds = subj_events.duration_s(event_rows);

        valid_mask = (idx_samples >= 1) & (idx_samples <= length(raw(i).time));
        if ~all(valid_mask)
            warning('Ptp %s: Excluded %d event(s) for "%s" exceeding time vector bounds.', ...
                subj_id, sum(~valid_mask), event_name)
            idx_samples = idx_samples(valid_mask);
            dur_seconds = dur_seconds(valid_mask);
        end
        if isempty(idx_samples), continue; end

        onset_seconds = raw(i).time(idx_samples);
        
        stim = nirs.design.StimulusEvents();
        stim.name = event_name;
        stim.onset = onset_seconds;
        stim.dur = dur_seconds;
        stim.amp = ones(size(stim.onset));

        raw(i).stimulus(event_name) = stim;
    end
end

fprintf('\n--- All Events Extracted ---\n')

%% SECTION B

%% 5. Montage Application

fprintf('\n--- Registering 3D Optode Digitization Points ---\n')

for i = 1:length(raw)
    subj_id = raw(i).demographics('Subject');
    dig_file = fullfile(Directory, subj_id, 'digpts.txt');

    if ~exist(dig_file, 'file')
        alt_files = dir(fullfile(Directory, subj_id, '**', 'digpts.txt'));
        if ~isempty(alt_files)
            dig_file = fullfile(alt_files(1).folder, alt_files(1).name);
        else
            warning('No digpts.txt found for participant: %s. Skipping registration.', subj_id);
            continue;
        end
    end

    fid = fopen(dig_file, 'r');
    dig_data = textscan(fid, '%s %f %f %f', 'Delimiter', ':', 'MultipleDelimsAsOne', true);
    fclose(fid);

    labels = strtrim(dig_data{1});
    coords = [dig_data{2}, dig_data{3}, dig_data{4}];

    is_fid = ismember(lower(labels), {'nz', 'ar', 'al', 'cz', 'iz'});
    is_src = startsWith(lower(labels), 's') & ~is_fid;
    is_det = startsWith(lower(labels), 'd') & ~is_fid;

    fid_labels = labels(is_fid);
    fid_coords = coords(is_fid, :);
    
    src_labels = labels(is_src);
    src_coords = coords(is_src, :);
    
    det_labels = labels(is_det);
    det_coords = coords(is_det, :);

    src_nums = cellfun(@(x) sscanf(x, 's%d'), lower(src_labels));
    [~, src_order] = sort(src_nums);
    src_labels = src_labels(src_order);
    src_coords = src_coords(src_order, :);
    
    det_nums = cellfun(@(x) sscanf(x, 'd%d'), lower(det_labels));
    [~, det_order] = sort(det_nums);
    det_labels = det_labels(det_order);
    det_coords = det_coords(det_order, :);

    std_fid_names = cellfun(@(x) ['FID-' upper(x)], fid_labels, 'UniformOutput', false);
    std_src_names = cellfun(@(x) sprintf('Source-%02d', sscanf(x, 's%d')), lower(src_labels), 'UniformOutput', false);
    std_det_names = cellfun(@(x) sprintf('Detector-%02d', sscanf(x, 'd%d')), lower(det_labels), 'UniformOutput', false);

    all_names = [std_fid_names; std_src_names; std_det_names];
    all_types = [repmat({'FID'}, length(fid_labels), 1); ...
                 repmat({'Source'}, length(src_labels), 1); ...
                 repmat({'Detector'}, length(det_labels), 1)];
    all_xyz = [fid_coords; src_coords; det_coords];
    all_units = repmat({'mm'}, length(all_names), 1);
    
    reg_table = table(all_names, all_xyz(:,1), all_xyz(:,2), all_xyz(:,3), all_types, all_units, ...
        'VariableNames', {'Name', 'X', 'Y', 'Z', 'Type', 'Units'});

    if ~isa(raw(i).probe, 'nirs.core.Probe1020')
        p3d = nirs.core.Probe1020();
        p3d.link = raw(i).probe.link;
        raw(i).probe = p3d;
    end

    raw(i).probe.optodes = reg_table;
end

fprintf('\n Montage application complete for all ptps \n')

%% SECTION C (COMMENTED OUT FOR QT-NIRS TEST)
% %% 6. Quality Control: Signal-to-Noise Ratio (SNR) Thresholding
% ... (SNR pruning disabled for this diagnostic run; passing full `raw` to Optical Density -> qt-nirs) ...

%% Section D. Preprocessing Pipeline Construction w/ NIRS-Toolbox + qt-nirs

fprintf('\n--- Running Optical Density + qt-nirs (SCI/PSP) Diagnostic Pipeline ---\n')

%% 7a. Convert Raw Intensity -> Optical Density (OD)
job_od = nirs.modules.OpticalDensity();
job_od = nirs.modules.FixNaNs(job_od);
od_data = job_od.run(raw);

%% 7b. Run qt-nirs (Scalp Coupling Index & Peak Spectral Power) on Active Task Window
% Parameters aligned with Ivanova, Pollonini & Soltanlou (2026) / Pollonini et al. (2016):
% sci_thresh = 0.60;      % Ivanova et al. (2026) = 0.60 (Pollonini et al., 2016 default = 0.80)
% psp_thresh = 0.075;     % Ivanova et al. (2026) = 0.075 (Pollonini et al., 2016 default = 0.10)
% q_thresh   = 0.60;      % Minimum fraction of good windows required (0.60 = 60% good windows)
% 
% job_qt = nirs.modules.QT();
% job_qt.qThreshold   = q_thresh;
% job_qt.sciThreshold = sci_thresh;
% job_qt.pspThreshold = psp_thresh;
% job_qt.windowSec    = 3;            % 3-second window per Ivanova et al. (2026)
% job_qt.condMask     = 'all';
% job_qt.guiFlag      = 0;            % Disable popup GUI
% job_qt.fCut         = [0.5, 2.5];   % Cardiac band (Hz)

%% 7b. Run qt-nirs (Original Pollonini et al., 2016 Defaults, Nyquist-Safe for 5.09 Hz Fs)
sci_thresh = 0.80;      % Original Pollonini et al. (2016) SCI default (also test 0.70 / 0.75)
psp_thresh = 0.10;      % Original Pollonini et al. (2016) PSP default (set to 0.00 to test SCI-only)
q_thresh   = 0.50;      % Original Pollonini et al. (2016) minimum good-window fraction (50%)

job_qt = nirs.modules.QT();
job_qt.qThreshold   = q_thresh;
job_qt.sciThreshold = sci_thresh;
job_qt.pspThreshold = psp_thresh;
job_qt.windowSec    = 5;            % Original 5-second window (~25 samples at 5.09 Hz)
job_qt.condMask     = 'all';
job_qt.guiFlag      = 0;
job_qt.fCut         = [0.5, 2.0];   % 30-120 bpm cardiac band; safely below 2.545 Hz Nyquist

known_short_pairs = [
    4, 16; 6, 17; 7, 18; 8, 19;
    11, 20; 13, 21; 14, 22; 15, 23
];

qa_summary = struct('Subject', {}, 'TotalChan', {}, 'ShortChan', {}, ...
    'LongChan', {}, 'PrunedChan', {}, 'SurvivingLong', {}, 'PctSurviving', {}, ...
    'TotalWindows', {}, 'BadWindows', {}, 'PrunedChanList', {}, 'Status', {});

od_clean = od_data;

for i = 1:length(od_data)
    s_id = od_data(i).demographics('Subject');
    link = od_data(i).probe.link;

    % Trim temporary copy to active task window (first event onset to last event end)
    od_active = od_data(i);
    stims = od_active.stimulus;
    cond_keys = stims.keys;
    task_onsets = [];
    task_ends = [];

    for k = 1:length(cond_keys)
        st = stims(cond_keys{k});
        if ~isempty(st.onset)
            n_pts = length(st.onset);
            durs = st.dur;
            if isscalar(durs)
                durs = repmat(durs, n_pts, 1);
            elseif isempty(durs)
                durs = zeros(n_pts, 1);
            else
                durs = durs(:);
            end
            task_onsets = [task_onsets; st.onset(:)];
            task_ends   = [task_ends; st.onset(:) + durs];
        end
    end

    if ~isempty(task_onsets)
        t_start = max(od_active.time(1), min(task_onsets));
        t_end   = min(od_active.time(end), max(task_ends));
        keep_t  = od_active.time >= t_start & od_active.time <= t_end;
        od_active.data = od_active.data(keep_t, :);
        od_active.time = od_active.time(keep_t);
    end

    % Guard against any remaining Inf/NaN values before qt-nirs filtfilt
    od_active.data(~isfinite(od_active.data)) = 0;
    
    % Run qt-nirs -> returns ScansQuality object with .qMats
    sq_out = job_qt.run(od_active);
    qMats  = sq_out.qMats;

    % Identify unique source-detector pairs and protect SSCs
    [unique_pairs, ~, pair_idx] = unique(link(:, 1:2), 'rows', 'stable');
    num_pairs = size(unique_pairs, 1);
    pair_is_short = false(num_pairs, 1);
    for p = 1:num_pairs
        s_val = unique_pairs.source(p);
        d_val = unique_pairs.detector(p);
        if any(known_short_pairs(:, 1) == s_val & known_short_pairs(:, 2) == d_val)
            pair_is_short(p) = true;
        end
    end

    % Map qMats.bad_links back to source-detector pairs (excluding SSCs)
    bad_pair_mask = false(num_pairs, 1);
    if isfield(qMats, 'bad_links') && ~isempty(qMats.bad_links)
        bad_links = qMats.bad_links;
        % qMats.bad_links stores either linear channel-pair indices or [source, detector] pairs
        if size(bad_links, 2) == 2
            for r = 1:size(bad_links, 1)
                p_hit = find(unique_pairs.source == bad_links(r, 1) & ...
                             unique_pairs.detector == bad_links(r, 2));
                if ~isempty(p_hit) && ~pair_is_short(p_hit)
                    bad_pair_mask(p_hit) = true;
                end
            end
        else
            valid_idx = bad_links(bad_links >= 1 & bad_links <= num_pairs);
            for idx_b = valid_idx(:)'
                if ~pair_is_short(idx_b)
                    bad_pair_mask(idx_b) = true;
                end
            end
        end
    end

    % Document QA metrics
    num_short_pairs = sum(pair_is_short);
    num_long_pairs  = num_pairs - num_short_pairs;
    num_bad_pairs   = sum(bad_pair_mask);
    surviving_long  = num_long_pairs - num_bad_pairs;

    bad_chan_names = {};
    bad_pair_indices = find(bad_pair_mask);
    for b = 1:length(bad_pair_indices)
        bp = bad_pair_indices(b);
        bad_chan_names{end+1} = sprintf('S%d-D%d', unique_pairs.source(bp), unique_pairs.detector(bp)); %#ok<AGROW>
    end

    n_tot_win = NaN; n_bad_win = NaN;
    if isfield(qMats, 'n_windows'),   n_tot_win = qMats.n_windows; end
    if isfield(qMats, 'bad_windows'), n_bad_win = numel(qMats.bad_windows); end

    qa_summary(i).Subject        = s_id;
    qa_summary(i).TotalChan      = num_pairs;
    qa_summary(i).ShortChan      = num_short_pairs;
    qa_summary(i).LongChan       = num_long_pairs;
    qa_summary(i).PrunedChan     = num_bad_pairs;
    qa_summary(i).SurvivingLong  = surviving_long;
    qa_summary(i).PctSurviving   = 100 * (surviving_long / max(1, num_long_pairs));
    qa_summary(i).TotalWindows   = n_tot_win;
    qa_summary(i).BadWindows     = n_bad_win;
    qa_summary(i).PrunedChanList = strjoin(bad_chan_names, '; ');

    if surviving_long == 0
        qa_summary(i).Status = 'Excluded_ZeroChannels';
    else
        qa_summary(i).Status = 'Usable';
    end

    % Physically remove pruned long-channel columns from full OD recording
    bad_measurement_rows  = ismember(pair_idx, bad_pair_indices);
    good_measurement_rows = ~bad_measurement_rows;

    od_clean(i).data       = od_data(i).data(:, good_measurement_rows);
    od_clean(i).probe.link = link(good_measurement_rows, :);
end

qa_table = struct2table(qa_summary);
disp(qa_table(1:min(10, height(qa_table)), :));

num_usable   = sum(strcmp(qa_table.Status, 'Usable'));
num_excluded = sum(strcmp(qa_table.Status, 'Excluded_ZeroChannels'));
total_long   = sum(qa_table.LongChan);
total_surv   = sum(qa_table.SurvivingLong);

fprintf('\n=== qt-nirs Cohort QC Summary (SCI >= %.2f | PSP >= %.3f | Q >= %.2f) ===\n', ...
    sci_thresh, psp_thresh, q_thresh);
fprintf('Usable Participants: %d / %d (%d zero-channel dropouts)\n', num_usable, height(qa_table), num_excluded);
fprintf('Surviving Long Channels: %d / %d (%.1f%% overall | Median %.1f chs/ptp)\n', ...
    total_surv, total_long, 100 * (total_surv / total_long), median(qa_table.SurvivingLong));

% Export diagnostic QA CSV only (does NOT overwrite Hb_preprocessed_cohort.mat)
qa_export_dir = 'D:\GitHub\Mars_fNIRS\Output\Preprocess'; % PC
if ~exist(qa_export_dir, 'dir'), mkdir(qa_export_dir); end

% out_csv = fullfile(qa_export_dir, sprintf('qtnirs_sci%02d_psp%03d_q%02d_eventsOnly_qa_summary.csv', ...
    % round(sci_thresh * 100), round(psp_thresh * 1000), round(q_thresh * 100)));

out_csv = fullfile(qa_export_dir, sprintf('qtnirs_sci%02d_psp%03d_q%02d_win%ds_fcut05_20_eventsOnly_qa_summary.csv', ...
    round(sci_thresh * 100), round(psp_thresh * 1000), round(q_thresh * 100), job_qt.windowSec));

writetable(qa_table, out_csv);
fprintf('Saved qt-nirs QA summary to: %s\n', out_csv);

%% 7c. Modified Beer-Lambert Law (MBLL) -> 10. Bandpass Filter (Kept intact for reference)
% jobs = nirs.modules.BeerLambertLaw();
% jobs = nirs.modules.FixNaNs(jobs);
% jobs = nirs.modules.Resample(jobs);
% jobs.Fs = 1.0;
% jobs = nirs.modules.WaveletFilter(jobs);
% jobs = nirs.modules.BandPassFilter(jobs);
% jobs.highpass = 0.01;
% jobs.lowpass = 0.20;
% jobs.do_downsample = false;
% Hb = jobs.run(od_clean);