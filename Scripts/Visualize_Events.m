% AI Gemini Pro 10/01/26

%% Visualize_Events.m
% Visual inspection of Participant 1 optical data and 3 synchronized event tiers

clear; clc;
warning('off', 'MATLAB:dispatcher:nameConflict');

%% 1. Ensure Dependencies & Paths
addpath(genpath('D:\GitHub\nirs-toolbox'));
addpath('D:\GitHub\spm12');
addpath('D:\GitHub\NIRS_SPM_v4_r1');

%% 2. Load Data for Participant 1
Directory = 'D:\GitHub\Mars_fNIRS\Data\fNIRS';
raw = nirs.io.loadDirectory(Directory, {'Subject'});

% Locate Participant 1
p1_idx = 1;
for i = 1:length(raw)
    if strcmp(raw(i).demographics('Subject'), '2025-10-26-P1')
        p1_idx = i;
        break;
    end
end
raw_p1 = raw(p1_idx);

%% 3. Load Events CSV & Attach to P1
event_csv_path = 'D:\GitHub\Mars_fNIRS\Data\Events\spy_events_all_sessions(in).csv';
event_table = readtable(event_csv_path);

p1_events = event_table(strcmp(event_table.fnirs_folder, '2025-10-26-P1'), :);

fs = 1 / mean(diff(raw_p1.time));
raw_p1.stimulus = Dictionary();

unique_events = unique(p1_events.event);

for e = 1:length(unique_events)
    ev_name = unique_events{e};
    ev_rows = p1_events(strcmp(p1_events.event, ev_name), :);
    
    st = nirs.design.StimulusEvents();
    st.name  = ev_name;
    st.onset = (ev_rows.onset_fnirs_index - 1) / fs;
    st.dur   = ev_rows.duration_s;
    st.amp   = ones(height(ev_rows), 1);
    
    raw_p1.stimulus(ev_name) = st;
end

%% 4. Plot 4-Panel Synchronized Layout
figure('Color', 'w', 'Position', [80 60 1300 850]);

% Force all tiles to maintain identical horizontal dimensions
t = tiledlayout(4, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

% Retrieve all stimulus keys
all_stim_keys = raw_p1.stimulus.keys;

macro_tier    = {'planning', 'execution', 'debrief'};
subphase_tier = {'null_block', 'null_event', 'null_event_prespam', ...
                 'enroute_decoy_site', 'at_decoy_site', ...
                 'enroute_true_site', 'at_true_site', ...
                 'fixation_baseline_start', 'fixation_baseline_end'};
task_tier     = {'status_check', 'spam_pop_up', 'tricorder_switch'};

categorized   = [macro_tier, subphase_tier, task_tier];
uncategorized = setdiff(all_stim_keys, categorized, 'stable');
task_tier     = [task_tier, uncategorized];

% ----------------------------------------------------
% Panel 1: Optical Channels (Top)
% ----------------------------------------------------
ax1 = nexttile;
plot(raw_p1.time, raw_p1.data);
ylabel('Raw Intensity');
title('Participant 1: Optical Channels');
grid on;

% ----------------------------------------------------
% Panel 2: Macro Phases
% ----------------------------------------------------
ax2 = nexttile;
hold on;
macro_colors = [0.20 0.60 0.86; 0.90 0.49 0.13; 0.55 0.27 0.68];

for m = 1:length(macro_tier)
    ev_name = macro_tier{m};
    if ismember(ev_name, all_stim_keys)
        st = raw_p1.stimulus(ev_name);
        for j = 1:length(st.onset)
            t_start = st.onset(j);
            t_end   = t_start + max(st.dur(j), 1);
            if j == 1, h_vis = 'on'; else, h_vis = 'off'; end
            
            fill([t_start, t_end, t_end, t_start], [0, 0, 1, 1], ...
                 macro_colors(m, :), 'EdgeColor', 'none', 'FaceAlpha', 0.55, ...
                 'DisplayName', ev_name, 'HandleVisibility', h_vis);
        end
    end
end
hold off;
ylabel('Phases');
ylim([0 1.1]);
yticks([]);
legend('Interpreter', 'none', 'Location', 'eastoutside');
grid on;

% ----------------------------------------------------
% Panel 3: Sub-Phases & Navigation (Including null_event)
% ----------------------------------------------------
ax3 = nexttile;
hold on;
sub_active = intersect(all_stim_keys, subphase_tier, 'stable');
sub_colors = lines(max(length(sub_active), 1));

for s = 1:length(sub_active)
    ev_name = sub_active{s};
    st = raw_p1.stimulus(ev_name);
    for j = 1:length(st.onset)
        t_start = st.onset(j);
        t_end   = t_start + max(st.dur(j), 1);
        if j == 1, h_vis = 'on'; else, h_vis = 'off'; end
        
        fill([t_start, t_end, t_end, t_start], [0, 0, 1, 1], ...
             sub_colors(s, :), 'EdgeColor', 'none', 'FaceAlpha', 0.6, ...
             'DisplayName', ev_name, 'HandleVisibility', h_vis);
    end
end
hold off;
ylabel('Events 1');
ylim([0 1.1]);
yticks([]);
legend('Interpreter', 'none', 'Location', 'eastoutside');
grid on;

% ----------------------------------------------------
% Panel 4: In-Task Events & Probes (Bottom)
% ----------------------------------------------------
ax4 = nexttile;
hold on;
task_active = intersect(all_stim_keys, task_tier, 'stable');
task_colors = lines(max(length(task_active), 1));

for k = 1:length(task_active)
    ev_name = task_active{k};
    st = raw_p1.stimulus(ev_name);
    for j = 1:length(st.onset)
        t_start = st.onset(j);
        t_end   = t_start + max(st.dur(j), 1);
        if j == 1, h_vis = 'on'; else, h_vis = 'off'; end
        
        fill([t_start, t_end, t_end, t_start], [0, 0, 1, 1], ...
             task_colors(k, :), 'EdgeColor', 'none', 'FaceAlpha', 0.7, ...
             'DisplayName', ev_name, 'HandleVisibility', h_vis);
    end
end
hold off;
xlabel('Time (s)');
ylabel('Events 2');
ylim([0 1.1]);
yticks([]);
legend('Interpreter', 'none', 'Location', 'eastoutside');
grid on;

% ----------------------------------------------------
% Synchronize Timeline Across All 4 Subplots
% ----------------------------------------------------
linkaxes([ax1, ax2, ax3, ax4], 'x');