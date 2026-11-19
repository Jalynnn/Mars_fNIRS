%% =========================================================================
%  Test_SlidingWindow_SNR.m
%  Sandbox benchmark comparing static active-task SNR (SNR >= 6.67 / CV <= 15%)
%  against sliding-window SNR across multiple window sizes (50% overlap;
%  prune long channel if > 50% of windows fail). SSCs are excluded from pruning.
%  =========================================================================

fprintf('\n--- Starting Sliding-Window SNR Benchmark ---\n')
clear, clc
warning('off', 'MATLAB:dispatcher:nameConflict');

%% 1. Set MATLAB Paths
addpath(genpath('D:\GitHub\nirs-toolbox'))
addpath('D:\GitHub\spm12')
addpath('D:\GitHub\NIRS_SPM_v4_r1')

%% 2. Load & Sort NIRS Files
fprintf('--- Loading NIRS Files ---\n')
Directory = 'D:\GitHub\Mars_fNIRS\Data\fNIRS';
raw = nirs.io.loadDirectory(Directory, {'Subject'});

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

%% 3. Attach Demographics Metadata
demo_file = 'D:\GitHub\Mars_fNIRS\Data\Demographics\fnirs_demographics_spy_V5.csv';
demo_table = readtable(demo_file);

for i = 1:length(raw)
    subj_val = raw(i).demographics('Subject');
    matched_id = regexp(subj_val, '(?<=P)\d+', 'match', 'once');
    subj_id = str2double(matched_id);
    row_idx = find(demo_table.participant_id == subj_id, 1);

    if ~isempty(row_idx)
        raw(i).demographics('participant_id') = demo_table.participant_id(row_idx);
        raw(i).demographics('session_id')     = demo_table.session_id(row_idx);
    end
end
fprintf('Loaded and matched %d participants.\n', length(raw));

%% 4. Extract Events (Needed to Define Active Task Slice)
fprintf('--- Extracting Active Task Window Events ---\n')
event_csv_path = 'D:\GitHub\Mars_fNIRS\Data\Events\spy_events_all_sessionsV4.csv';
event_table = readtable(event_csv_path);

for i = 1:length(raw)
    subj_id = strtrim(raw(i).demographics('Subject'));
    match_mask = strcmp(strtrim(event_table.fnirs_folder), subj_id) | ...
        strcmp(strrep(strtrim(event_table.fnirs_folder), '-', '_'), strrep(subj_id, '-', '_'));
    subj_events = event_table(match_mask, :);

    if isempty(subj_events)
        warning('No events found in CSV for "%s". Will fall back to full recording.', subj_id);
        continue;
    end

    individual_events = unique(subj_events.event);
    raw(i).stimulus = Dictionary();

    for e = 1:length(individual_events)
        event_name = individual_events{e};
        event_rows = strcmp(subj_events.event, event_name);
        idx_samples = subj_events.onset_fnirs_index(event_rows);
        dur_seconds = subj_events.duration_s(event_rows);

        valid_mask = (idx_samples >= 1) & (idx_samples <= length(raw(i).time));
        idx_samples = idx_samples(valid_mask);
        dur_seconds = dur_seconds(valid_mask);
        if isempty(idx_samples), continue; end

        stim = nirs.design.StimulusEvents();
        stim.name  = event_name;
        stim.onset = raw(i).time(idx_samples);
        stim.dur   = dur_seconds;
        stim.amp   = ones(size(stim.onset));
        raw(i).stimulus(event_name) = stim;
    end
end

%% 5. Sliding-Window vs. Static SNR Benchmark
fprintf('\n--- Evaluating Static vs. Sliding-Window SNR (Threshold = 6.67 / CV = 15%%) ---\n')

snr_threshold = 6.67;          % CV <= 15%
window_sizes_sec = [5, 10, 15, 30, 60]; % Candidate window durations (seconds)
overlap_frac = 0.50;           % 50% sliding step overlap
max_fail_frac = 0.50;          % Prune channel if > 50% of windows fail

known_short_pairs = [
    4, 16; 6, 17; 7, 18; 8, 19;
    11, 20; 13, 21; 14, 22; 15, 23
];

n_ptps = length(raw);
n_win_configs = length(window_sizes_sec);

% Track surviving long channels per participant: [n_ptps x (1 + n_win_configs)]
% Col 1 = Static baseline; Cols 2..end = window_sizes_sec
surviving_counts = zeros(n_ptps, 1 + n_win_configs);
total_long_per_ptp = zeros(n_ptps, 1);

% Granular channel-by-participant table rows
chan_rows = {};

for i = 1:n_ptps
    s_id = strtrim(raw(i).demographics('Subject'));
    ptp_id = raw(i).demographics('participant_id');
    if isempty(ptp_id), ptp_id = NaN; end
    
    d = raw(i).data;
    fs = raw(i).Fs;
    link = raw(i).probe.link;
    
    % Identify active task slice (first event onset to last event end)
    stims = raw(i).stimulus;
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
        first_sample = max(1, round(min(task_onsets) * fs));
        last_sample  = min(size(d, 1), round(max(task_ends) * fs));
        task_slice   = first_sample:last_sample;
    else
        task_slice   = 1:size(d, 1);
    end
    
    d_active = d(task_slice, :);
    n_samples = size(d_active, 1);
    
    % Identify unique physical source-detector pairs
    [unique_pairs, ~, pair_idx] = unique(link(:, 1:2), 'rows', 'stable');
    num_pairs = size(unique_pairs, 1);
    
    % Flag SSC pairs (never pruned)
    pair_is_short = false(num_pairs, 1);
    for p = 1:num_pairs
        s_val = unique_pairs.source(p);
        d_val = unique_pairs.detector(p);
        if any(known_short_pairs(:, 1) == s_val & known_short_pairs(:, 2) == d_val)
            pair_is_short(p) = true;
        end
    end
    
    long_pair_indices = find(~pair_is_short);
    total_long_per_ptp(i) = length(long_pair_indices);
    
    % --- A. Static Active-Task SNR Baseline ---
    mean_static = mean(d_active, 1);
    std_static  = std(d_active, 0, 1);
    snr_static  = mean_static ./ (std_static + eps);
    
    % --- B. Sliding-Window SNR Across Candidate Window Sizes ---
    win_fail_frac = nan(num_pairs, n_win_configs);
    
    for w_idx = 1:n_win_configs
        w_sec  = window_sizes_sec(w_idx);
        w_samp = max(2, round(w_sec * fs));
        step_samp = max(1, round(w_samp * (1 - overlap_frac)));
        
        if n_samples <= w_samp
            win_starts = 1;
            win_ends   = n_samples;
        else
            win_starts = 1:step_samp:(n_samples - w_samp + 1);
            win_ends   = win_starts + w_samp - 1;
        end
        n_wins = length(win_starts);
        
        % Compute SNR per window across all measurement columns: [n_wins x n_cols]
        snr_windows = zeros(n_wins, size(d_active, 2));
        for w = 1:n_wins
            seg = d_active(win_starts(w):win_ends(w), :);
            mu  = mean(seg, 1);
            sd  = std(seg, 0, 1);
            snr_windows(w, :) = mu ./ (sd + eps);
        end
        
        % Evaluate each long physical pair
        for lp = 1:length(long_pair_indices)
            p = long_pair_indices(lp);
            cols = (pair_idx == p);
            % Window fails if ANY wavelength in that pair falls below 6.67
            win_failed = any(snr_windows(:, cols) < snr_threshold, 2);
            win_fail_frac(p, w_idx) = mean(win_failed);
        end
    end
    
    % Tally results per long channel & record granular rows
    for lp = 1:length(long_pair_indices)
        p = long_pair_indices(lp);
        src = unique_pairs.source(p);
        det = unique_pairs.detector(p);
        cols = (pair_idx == p);
        
        min_snr_stat = min(snr_static(cols));
        keep_static  = double(~any(snr_static(cols) < snr_threshold));
        surviving_counts(i, 1) = surviving_counts(i, 1) + keep_static;
        
        keep_wins = zeros(1, n_win_configs);
        fail_pcts = zeros(1, n_win_configs);
        for w_idx = 1:n_win_configs
            fail_pcts(w_idx) = win_fail_frac(p, w_idx) * 100;
            % Prune if > 50% of windows fail; keep if <= 50% fail
            keep_wins(w_idx) = double(win_fail_frac(p, w_idx) <= max_fail_frac);
            surviving_counts(i, 1 + w_idx) = surviving_counts(i, 1 + w_idx) + keep_wins(w_idx);
        end
        
        row_cell = [{s_id, ptp_id, src, det, sprintf('S%d-D%d', src, det), keep_static, min_snr_stat}, ...
                    num2cell(keep_wins), num2cell(fail_pcts)];
        chan_rows(end+1, :) = row_cell; %#ok<SAGROW>
    end
end

%% 6. Build & Export Benchmark CSVs
out_dir = 'D:\GitHub\Mars_fNIRS\Output\Experiments\SlidingWindow_SNR';
if ~exist(out_dir, 'dir'), mkdir(out_dir); end

% --- Export 1: High-Level Comparison Summary CSV ---
method_names = [{'Static_ActiveTask'}, arrayfun(@(x) sprintf('Win_%ds', x), window_sizes_sec, 'UniformOutput', false)];
n_methods = length(method_names);

summary_tbl = table();
summary_tbl.Method                 = method_names';
summary_tbl.Window_Sec             = [NaN; window_sizes_sec(:)];
summary_tbl.Total_Long_Channels    = repmat(sum(total_long_per_ptp), n_methods, 1);
summary_tbl.Surviving_Channels     = sum(surviving_counts, 1)';
summary_tbl.Survival_Pct           = (summary_tbl.Surviving_Channels ./ summary_tbl.Total_Long_Channels) * 100;
summary_tbl.Pruned_Channels        = summary_tbl.Total_Long_Channels - summary_tbl.Surviving_Channels;
summary_tbl.Pruned_Pct             = (summary_tbl.Pruned_Channels ./ summary_tbl.Total_Long_Channels) * 100;
summary_tbl.Mean_Surviving_Per_Ptp = mean(surviving_counts, 1)';
summary_tbl.SD_Surviving_Per_Ptp   = std(surviving_counts, 0, 1)';
summary_tbl.Median_Surviving_Ptp   = median(surviving_counts, 1)';
summary_tbl.Min_Surviving_Ptp      = min(surviving_counts, [], 1)';
summary_tbl.Max_Surviving_Ptp      = max(surviving_counts, [], 1)';
summary_tbl.Ptps_Zero_Channels     = sum(surviving_counts == 0, 1)';

summary_csv = fullfile(out_dir, 'SlidingWindow_SNR_Summary.csv');
writetable(summary_tbl, summary_csv);

% --- Export 2: Granular Channel x Participant Survival Matrix CSV ---
keep_headers = arrayfun(@(x) sprintf('Win_%ds_Keep', x), window_sizes_sec, 'UniformOutput', false);
fail_headers = arrayfun(@(x) sprintf('Win_%ds_FailPct', x), window_sizes_sec, 'UniformOutput', false);
all_headers  = [{'Subject', 'Participant_ID', 'Source', 'Detector', 'Channel_Label', 'Static_Keep', 'Static_Min_SNR'}, ...
                keep_headers, fail_headers];

chan_tbl = cell2table(chan_rows, 'VariableNames', all_headers);
chan_csv = fullfile(out_dir, 'SlidingWindow_SNR_ChannelMatrix.csv');
writetable(chan_tbl, chan_csv);

%% 7. Print Comparison Table to Command Window
fprintf('\n=== SLIDING-WINDOW SNR BENCHMARK SUMMARY (SNR >= 6.67 | Prune if > 50%% Windows Fail) ===\n');
disp(summary_tbl);
fprintf('Saved Summary CSV:        %s\n', summary_csv);
fprintf('Saved Channel Matrix CSV: %s\n', chan_csv);
