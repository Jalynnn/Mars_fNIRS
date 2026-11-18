% AI Gemini Pro 10/05/26
%% Visualize_Dyads.m
% Batch visual inspection of Dyad optical data and split-track P1/P2 events
% Distinct baseline colors + explicit missing-event reporting per tier
clear; clc;
warning('off', 'MATLAB:dispatcher:nameConflict');

%% 1. Ensure Dependencies & Paths

addpath(genpath('D:\GitHub\nirs-toolbox')) % PC
% addpath(genpath('C:\Users\Jalynn\Documents\GitHub\nirs-toolbox')); % Laptop

addpath('D:\GitHub\spm12') % PC
% addpath('C:\Users\Jalynn\Documents\GitHub\spm12'); % Laptop

addpath('D:\GitHub\NIRS_SPM_v4_r1') % PC
% addpath('C:\Users\Jalynn\Downloads\NIRS_SPM_v4_r1'); % Laptop

%% 2. Load Dataset & Events Table
Directory = 'D:\GitHu
b\Mars_fNIRS\Data\fNIRS'; % PC
% Directory = 'C:\Users\Jalynn\Documents\GitHub\Mars_fNIRS\Data\fNIRS'; % Laptop

raw = nirs.io.loadDirectory(Directory, {'Subject'});
event_csv_path = 'D:\GitHub\Mars_fNIRS\Data\Events\spy_events_all_sessionsV4.csv'; % PC
% event_csv_path = 'C:\Users\Jalynn\Documents\GitHub\Mars_fNIRS\Data\Events\spy_events_all_sessionsV4.csv'; % Laptop
event_table = readtable(event_csv_path);

output_qc_dir = 'D:\GitHub\Mars_fNIRS\Output\Dyad_Plots'; % PC
% output_qc_dir = 'C:\Users\Jalynn\Documents\GitHub\Mars_fNIRS\Output\Dyad_Plots'; % Laptop
if ~exist(output_qc_dir, 'dir')
    mkdir(output_qc_dir);
end

%% 3. Construct Dyad Lookup Table & Event Schemes
pair_list = {
    'Pair_01', '2025-10-26-P1',   '2025-10-26-P2';
    % 'Pair_02', '2025-10-27-P3',   '2025-10-27-P4.2';
    'Pair_03', '2025-10-27-P5',   '2025-10-27-P6';
    'Pair_04', '2025-10-30-P7', '2025-10-30-P8';
    'Pair_05', '2025-10-31-P9', '2025-10-31-P10';
    'Pair_06', '2025-10-31-P11', '2025-10-31-P12';
    % 'Pair_07', '2025-11-02-P13.2', '2025-11-02-P14.2';
    'Pair_08', '2025-11-03-P15', '2025-11-03-P16';
    'Pair_09', '2025-11-11-P17', '2025-11-11-P18';
    % 'Pair_10', '2025-11-12-P19', '2025-11-12-P20.1';
    'Pair_11', '2025-11-12-P21', '2025-11-12-P22';
    'Pair_12', '2025-11-15-P23', '2025-11-15-P24';
    'Pair_13', '2025-11-20-P25', '2025-11-20-P26';
    'Pair_14', '2025-11-24-P27', '2025-11-24-P28';
    'Pair_15', '2025-11-25-P29-redo', '2025-11-25-P30-redo';
    'Pair_16', '2025-11-30-P31', '2025-11-30-P32';
    'Pair_17', '2025-12-01-P33', '2025-12-01-P34';
    'Pair_18', '2025-12-05-P35', '2025-12-05-P36';
    'Pair_19', '2025-12-05-P37', '2025-12-05-P38';
    'Pair_20', '2025-12-09-P39', '2025-12-09-P40';
    'Pair_21', '2025-12-11-P41', '2025-12-11-P42';
    'Pair_22', '2025-12-12-P43', '2025-12-12-P44';
    'Pair_23', '2025-12-13-P45', '2025-12-13-P46';
    % 'Pair_24', '2025-12-18-P47.1', '2025-12-18-P48.1';
    'Pair_25', '2025-12-20-P49', '2025-12-20-P50';
    'Pair_26', '2025-12-20-P51', '2025-12-20-P52';
    % 'Pair_27', '2026-01-11-P53.1', '2026-01-11-P54';
    'Pair_28', '2026-01-13-P55', '2026-01-13-P56';
    'Pair_29', '2026-01-14-P57', '2026-01-14-P58';
    'Pair_30', '2026-01-15-P59', '2026-01-15-P60';
    'Pair_31', '2026-01-16-P61', '2026-01-16-P62';
    'Pair_32', '2026-01-16-P63', '2026-01-16-P64';
    'Pair_33', '2026-01-17-P65', '2026-01-17-P66';
};
dyad_table = cell2table(pair_list, ...
    'VariableNames', {'DyadID', 'Partner1_Folder', 'Partner2_Folder'});

% Defined Event Tiers
macro_tier = {'planning_individual', 'planning_team', ...
              'enroute_decoy_site', 'at_decoy_site', ...
              'enroute_true_site', 'at_true_site', ...
              'execution', 'debrief'};

subphase_tier = {'planning_baseline', 'null_block', 'null_event', ...
                 'null_event_prespam', ...
                 'fixation_baseline_start', 'fixation_baseline_end'};

task_tier = {'certainty_individual', 'certainty_consensus', ...
             'status_check', 'spam_pop_up', 'tricorder_switch'};

% ----------------------------------------------------
% Hard-Coded Color Map (Normalized RGB [0, 1])
% ----------------------------------------------------
color_map = containers.Map();

% 1. Blocks / Sustained
color_map('planning_individual')  = [0.20, 0.60, 0.86];  % Sky Blue
color_map('planning_team')        = [0.10, 0.35, 0.70];  % Deep Navy
color_map('enroute_decoy_site')   = [0.95, 0.65, 0.20];  % Gold / Amber
color_map('at_decoy_site')        = [0.85, 0.45, 0.10];  % Burnt Orange
color_map('enroute_true_site')    = [0.40, 0.75, 0.35];  % Grass Green
color_map('at_true_site')         = [0.15, 0.55, 0.25];  % Forest Green
color_map('execution')            = [0.90, 0.30, 0.25];  % Coral Red
color_map('debrief')              = [0.55, 0.25, 0.70];  % Purple

% 2. Baselines / Nulls (Distinct Harmonized Hues)
color_map('planning_baseline')       = [0.60, 0.52, 0.78];  % Muted Lavender
color_map('null_block')              = [0.35, 0.60, 0.65];  % Steel Seafoam
color_map('null_event')              = [0.55, 0.70, 0.55];  % Sage Green
color_map('null_event_prespam')      = [0.75, 0.55, 0.40];  % Dusty Bronze
color_map('fixation_baseline_start') = [0.20, 0.45, 0.55];  % Deep Slate Blue
color_map('fixation_baseline_end')   = [0.45, 0.30, 0.45];  % Deep Eggplant

% 3. Events / Transients
color_map('certainty_individual') = [0.10, 0.80, 0.80];  % Bright Cyan
color_map('certainty_consensus')  = [0.00, 0.50, 0.55];  % Dark Teal
color_map('status_check')         = [0.95, 0.15, 0.15];  % Alert Crimson
color_map('spam_pop_up')          = [1.00, 0.18, 0.60];  % Neon Magenta
color_map('tricorder_switch')     = [1.00, 0.82, 0.00];  % Electric Yellow

% Dual-lane coordinates: Top lane = P1, Bottom lane = P2
y_p1 = [0.55, 0.55, 1.00, 1.00];
y_p2 = [0.00, 0.00, 0.45, 0.45];

%% 4. Iterate Over Dyads
num_dyads = height(dyad_table);

for d = 1:num_dyads
    dyad_id   = dyad_table.DyadID{d};
    p1_folder = dyad_table.Partner1_Folder{d};
    p2_folder = dyad_table.Partner2_Folder{d};
    
    fprintf('[%02d/%02d] Processing %s (%s vs %s)...\n', ...
        d, num_dyads, dyad_id, p1_folder, p2_folder);
    
    % Locate participant indices in loaded 'raw' array
    idx_p1 = [];
    idx_p2 = [];
    for i = 1:length(raw)
        subj_name = raw(i).demographics('Subject');
        if strcmp(subj_name, p1_folder) % || startsWith(p1_folder, subj_name)
            idx_p1 = i;
        end
        if strcmp(subj_name, p2_folder) % || startsWith(p2_folder, subj_name)
            idx_p2 = i;
        end
    end
    
    if isempty(idx_p1) || isempty(idx_p2)
        warning('Skipping %s: Could not find both folders in raw data.', dyad_id);
        continue;
    end
    
    raw_p1 = raw(idx_p1);
    raw_p2 = raw(idx_p2);
    
    % Extract events per subject
    p1_events = event_table(strcmp(event_table.fnirs_folder, p1_folder), :);
    p2_events = event_table(strcmp(event_table.fnirs_folder, p2_folder), :);
    
    if isempty(p1_events) || isempty(p2_events)
        warning('Skipping %s: Missing CSV event rows for one or both subjects.', dyad_id);
        continue;
    end
    
    % Sampling rates per participant
    fs1 = 1 / mean(diff(raw_p1.time));
    fs2 = 1 / mean(diff(raw_p2.time));
    
    % Anchor t = 0 to onset of planning_baseline
    p1_plan_idx = p1_events.onset_fnirs_index(strcmp(p1_events.event, 'planning_baseline'));
    p2_plan_idx = p2_events.onset_fnirs_index(strcmp(p2_events.event, 'planning_baseline'));
    
    if isempty(p1_plan_idx) || isempty(p2_plan_idx)
        warning('Skipping %s: "planning_baseline" event trigger missing for synchronization.', dyad_id);
        continue;
    end
    
    t0_p1 = (p1_plan_idx(1) - 1) / fs1;
    t0_p2 = (p2_plan_idx(1) - 1) / fs2;
    
    % Shift timelines: t = 0 is now planning_baseline onset
    time_p1_aligned = raw_p1.time - t0_p1;
    time_p2_aligned = raw_p2.time - t0_p2;
    
    p1_events.rel_onset_s = ((p1_events.onset_fnirs_index - 1) / fs1) - t0_p1;
    p2_events.rel_onset_s = ((p2_events.onset_fnirs_index - 1) / fs2) - t0_p2;
    
    % Master event set for this dyad
    all_events    = unique([p1_events.event; p2_events.event]);
    categorized   = [macro_tier, subphase_tier, task_tier];
    uncategorized = setdiff(all_events, categorized, 'stable');
    curr_task_tier = [task_tier, uncategorized'];
    
    % Audit missing events per tier for both participants
    p1_ev_list = unique(p1_events.event);
    p2_ev_list = unique(p2_events.event);
    
    fmt_missing = @(tier_events) helper_build_missing_str(tier_events, p1_ev_list, p2_ev_list);
    
    missing_macro_str = fmt_missing(macro_tier);
    missing_sub_str   = fmt_missing(subphase_tier);
    missing_task_str  = fmt_missing(task_tier);
    
    %% 5. Render 5-Panel Synchronized Plot
    fig = figure('Color', 'w', 'Position', [40 20 1450 960], 'Visible', 'on');
    t = tiledlayout(5, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
    
    % ----------------------------------------------------
    % Panel 1: Partner 1 Optical Channels (Top)
    % ----------------------------------------------------
    ax1 = nexttile;
    plot(time_p1_aligned, raw_p1.data);
    ylabel('Raw Intensity');
    title(sprintf('%s — Partner 1 (%s): Optical Channels', dyad_id, p1_folder), 'FontWeight', 'bold');
    grid on;
    
    % ----------------------------------------------------
    % Panel 2: Blocks / Sustained Phases (Split P1 / P2)
    % ----------------------------------------------------
    ax2 = nexttile;
    hold on;
    for m = 1:length(macro_tier)
        ev_name = macro_tier{m};
        if isKey(color_map, ev_name), col = color_map(ev_name); else, col = [0.3 0.3 0.3]; end
        
        r1 = p1_events(strcmp(p1_events.event, ev_name), :);
        for j = 1:height(r1)
            t_s = r1.rel_onset_s(j);
            t_e = t_s + max(r1.duration_s(j), 1);
            h_vis = 'off';
            if j == 1, h_vis = 'on'; end
            fill([t_s, t_e, t_e, t_s], y_p1, col, 'EdgeColor', 'none', ...
                 'FaceAlpha', 0.6, 'DisplayName', ev_name, 'HandleVisibility', h_vis);
        end
        
        r2 = p2_events(strcmp(p2_events.event, ev_name), :);
        for j = 1:height(r2)
            t_s = r2.rel_onset_s(j);
            t_e = t_s + max(r2.duration_s(j), 1);
            h_vis = 'off';
            if isempty(r1) && j == 1, h_vis = 'on'; end
            fill([t_s, t_e, t_e, t_s], y_p2, col, 'EdgeColor', 'none', ...
                 'FaceAlpha', 0.6, 'DisplayName', ev_name, 'HandleVisibility', h_vis);
        end
    end
    hold off;
    ylabel('Blocks / Sustained');
    title(missing_macro_str, 'FontSize', 8.5, 'FontWeight', 'normal', 'Interpreter', 'none');
    ylim([0 1.05]);
    yticks([0.22, 0.77]);
    yticklabels({'P2', 'P1'});
    legend('Interpreter', 'none', 'Location', 'eastoutside');
    grid on;
    
    % ----------------------------------------------------
    % Panel 3: Baselines & Null Phases (Split P1 / P2)
    % ----------------------------------------------------
    ax3 = nexttile;
    hold on;
    sub_active = intersect(all_events, subphase_tier, 'stable');
    for s = 1:length(sub_active)
        ev_name = sub_active{s};
        if isKey(color_map, ev_name), col = color_map(ev_name); else, col = [0.3 0.3 0.3]; end
        
        r1 = p1_events(strcmp(p1_events.event, ev_name), :);
        for j = 1:height(r1)
            t_s = r1.rel_onset_s(j);
            t_e = t_s + max(r1.duration_s(j), 1);
            h_vis = 'off';
            if j == 1, h_vis = 'on'; end
            fill([t_s, t_e, t_e, t_s], y_p1, col, 'EdgeColor', 'none', ...
                 'FaceAlpha', 0.7, 'DisplayName', ev_name, 'HandleVisibility', h_vis);
        end
        
        r2 = p2_events(strcmp(p2_events.event, ev_name), :);
        for j = 1:height(r2)
            t_s = r2.rel_onset_s(j);
            t_e = t_s + max(r2.duration_s(j), 1);
            h_vis = 'off';
            if isempty(r1) && j == 1, h_vis = 'on'; end
            fill([t_s, t_e, t_e, t_s], y_p2, col, 'EdgeColor', 'none', ...
                 'FaceAlpha', 0.7, 'DisplayName', ev_name, 'HandleVisibility', h_vis);
        end
    end
    hold off;
    ylabel('Baselines / Null');
    title(missing_sub_str, 'FontSize', 8.5, 'FontWeight', 'normal', 'Interpreter', 'none');
    ylim([0 1.05]);
    yticks([0.22, 0.77]);
    yticklabels({'P2', 'P1'});
    legend('Interpreter', 'none', 'Location', 'eastoutside');
    grid on;
    
    % ----------------------------------------------------
    % Panel 4: In-Task Transients & Probes (Split P1 / P2)
    % ----------------------------------------------------
    ax4 = nexttile;
    hold on;
    task_active = intersect(all_events, curr_task_tier, 'stable');
    for k = 1:length(task_active)
        ev_name = task_active{k};
        if isKey(color_map, ev_name), col = color_map(ev_name); else, col = [0.2 0.2 0.2]; end
        
        r1 = p1_events(strcmp(p1_events.event, ev_name), :);
        for j = 1:height(r1)
            t_s = r1.rel_onset_s(j);
            t_e = t_s + max(r1.duration_s(j), 1);
            h_vis = 'off';
            if j == 1, h_vis = 'on'; end
            fill([t_s, t_e, t_e, t_s], y_p1, col, 'EdgeColor', 'none', ...
                 'FaceAlpha', 0.75, 'DisplayName', ev_name, 'HandleVisibility', h_vis);
        end
        
        r2 = p2_events(strcmp(p2_events.event, ev_name), :);
        for j = 1:height(r2)
            t_s = r2.rel_onset_s(j);
            t_e = t_s + max(r2.duration_s(j), 1);
            h_vis = 'off';
            if isempty(r1) && j == 1, h_vis = 'on'; end
            fill([t_s, t_e, t_e, t_s], y_p2, col, 'EdgeColor', 'none', ...
                 'FaceAlpha', 0.75, 'DisplayName', ev_name, 'HandleVisibility', h_vis);
        end
    end
    hold off;
    ylabel('Events / Transients');
    title(missing_task_str, 'FontSize', 8.5, 'FontWeight', 'normal', 'Interpreter', 'none');
    ylim([0 1.05]);
    yticks([0.22, 0.77]);
    yticklabels({'P2', 'P1'});
    legend('Interpreter', 'none', 'Location', 'eastoutside');
    grid on;
    
    % ----------------------------------------------------
    % Panel 5: Partner 2 Optical Channels (Bottom)
    % ----------------------------------------------------
    ax5 = nexttile;
    plot(time_p2_aligned, raw_p2.data);
    xlabel('Time Relative to Planning Baseline (s)');
    ylabel('Raw Intensity');
    title(sprintf('Partner 2 (%s): Optical Channels', p2_folder), 'FontWeight', 'bold');
    grid on;
    
    % ----------------------------------------------------
    % Synchronize Timelines & Format Bounds
    % ----------------------------------------------------
    linkaxes([ax1, ax2, ax3, ax4, ax5], 'x');
    max_t = max([p1_events.rel_onset_s + p1_events.duration_s; ...
                 p2_events.rel_onset_s + p2_events.duration_s]);
    xlim([-60, max_t + 60]);
    
    % Save visual audit figure
    save_path = fullfile(output_qc_dir, sprintf('Dyad_QC_%s.png', dyad_id));
    exportgraphics(fig, save_path, 'Resolution', 200);
    fprintf('  Saved diagnostic plot to: %s\n', save_path);
end

fprintf('\nDyad visualization run completed across all pairs.\n');

%% Helper Function for Missing Event Reporting
function out_str = helper_build_missing_str(expected_tier, p1_evs, p2_evs)
    p1_missing = setdiff(expected_tier, p1_evs);
    p2_missing = setdiff(expected_tier, p2_evs);
    
    parts = {};
    if ~isempty(p1_missing)
        parts{end+1} = ['P1 Missing: [' strjoin(p1_missing, ', ') ']'];
    end
    if ~isempty(p2_missing)
        parts{end+1} = ['P2 Missing: [' strjoin(p2_missing, ', ') ']'];
    end
    
    if isempty(parts)
        out_str = 'Status: All Expected Events Present';
    else
        out_str = ['Audit Alert -> ' strjoin(parts, ' | ')];
    end
end