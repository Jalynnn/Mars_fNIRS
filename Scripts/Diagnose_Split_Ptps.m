%% =========================================================================
%  Diagnose_And_Align_Split_Ptps.m
%  Combines physical .nirs file inspection with CSV event index bounds
%  to determine exact participant recoverability.
%  =========================================================================
clear; clc;

split_dir  = 'D:/GitHub/Mars_fNIRS/Data/ExcludedPtpsfNIRS/Split';
csv_path   = 'D:/GitHub/Mars_fNIRS/Data/Events/spy_events_all_sessionsV4.csv';

if ~exist(csv_path, 'file')
    error('Event CSV not found at: %s', csv_path);
end
event_table = readtable(csv_path);
csv_folders = unique(event_table.fnirs_folder);

% Participant tags to inspect
ptps = {'P4', 'P13', 'P14', 'P20', 'P47', 'P48', 'P53'};

fprintf('========================================================================================================================\n');
fprintf(' %-6s | %-6s | %-10s | %-8s | %-8s | %-20s | %-10s | %-12s | %s\n', ...
    'Ptp', 'Part', 'Duration', 'Points(N)', 'Trigs(N)', 'CSV Matched Folder', 'CSV Evs', 'Max Ev Index', 'Alignment Verdict');
fprintf('========================================================================================================================\n');

for i = 1:length(ptps)
    p_str = ptps{i};
    
    for part = 1:2
        % Find corresponding subfolder in Split directory (.1/.2 or _1/_2)
        pattern1 = sprintf('*%s.%d*', p_str, part);
        pattern2 = sprintf('*%s_%d*', p_str, part);
        
        folder_match = dir(fullfile(split_dir, pattern1));
        if isempty(folder_match)
            folder_match = dir(fullfile(split_dir, pattern2));
        end
        
        if isempty(folder_match)
            fprintf(' %-6s | Part %d | [FOLDER NOT FOUND IN SPLIT DIR]\n', p_str, part);
            continue;
        end
        
        folder_name = folder_match(1).name;
        folder_path = fullfile(split_dir, folder_name);
        
        % Check for .nirs file
        nirs_files = dir(fullfile(folder_path, '*.nirs'));
        if isempty(nirs_files)
            % Check if CSV had events mapped to this missing folder
            ev_sub = event_table(strcmp(event_table.fnirs_folder, folder_name), :);
            fprintf(' %-6s | Part %d | %-10s | %-8s | %-8s | %-20s | %-10d | %-12s | [NO .NIRS FILE IN FOLDER]\n', ...
                p_str, part, 'No file', '0', '0', folder_name, height(ev_sub), 'N/A');
            continue;
        end
        
        % Load .nirs timing and triggers
        nirs_path = fullfile(folder_path, nirs_files(1).name);
        nirs_data = load(nirs_path, '-mat');
        
        t = nirs_data.t;
        dur_s = t(end) - t(1);
        num_pts = length(t);
        n_trigs = sum(nirs_data.s(:) > 0);
        
        % Check for exact folder match in CSV
        ev_direct = event_table(strcmp(event_table.fnirs_folder, folder_name), :);
        
        % Also check if CSV stripped the part suffix or used alternate naming
        if isempty(ev_direct)
            clean_token = regexp(folder_name, '^(.*?)[\._][12]$', 'tokens', 'once');
            if ~isempty(clean_token)
                matched_csv_name = csv_folders(strcmp(csv_folders, clean_token{1}));
            else
                matched_csv_name = {};
            end
            if ~isempty(matched_csv_name)
                matched_folder_label = matched_csv_name{1};
                ev_sub = event_table(strcmp(event_table.fnirs_folder, matched_folder_label), :);
            else
                matched_folder_label = 'No CSV entry';
                ev_sub = table();
            end
        else
            matched_folder_label = folder_name;
            ev_sub = ev_direct;
        end
        
        n_ev = height(ev_sub);
        if n_ev > 0
            min_ev_idx = min(ev_sub.onset_fnirs_index);
            max_ev_idx = max(ev_sub.onset_fnirs_index);
            
            if min_ev_idx >= 1 && max_ev_idx <= num_pts
                verdict = sprintf('FITS DIRECTLY (1 to %d <= %d)', max_ev_idx, num_pts);
            elseif min_ev_idx > num_pts
                verdict = sprintf('OUT OF BOUNDS (Min %d > %d pts)', min_ev_idx, num_pts);
            else
                verdict = sprintf('PARTIAL FIT (Max %d > %d pts)', max_ev_idx, num_pts);
            end
        else
            if n_trigs == 0
                verdict = 'FALSE START (0 trigs, 0 events)';
            else
                verdict = 'NO CSV EVENTS MAPPED';
            end
            max_ev_idx = NaN;
        end
        
        if isnan(max_ev_idx)
            max_idx_str = 'None';
        else
            max_idx_str = sprintf('%d', max_ev_idx);
        end
        
        fprintf(' %-6s | Part %d | %8.1f s | %8d | %8d | %-20s | %-10d | %-12s | %s\n', ...
            p_str, part, dur_s, num_pts, n_trigs, matched_folder_label, n_ev, max_idx_str, verdict);
    end
    fprintf('------------------------------------------------------------------------------------------------------------------------\n');
end
