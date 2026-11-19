%% Quick Time-Series Plotter for Ptp 15, 18, and 40 (HbO, HbR, HbDiff)
load('D:\GitHub\Mars_fNIRS\Output\Preprocess\Hb_preprocessed_cohort.mat', 'Hb');
cov_tbl = readtable('D:\GitHub\Mars_fNIRS\Output\GroupLevel\Cohort_Covariates_Table.csv');

out_dir = 'D:\GitHub\Mars_fNIRS\Output\GroupLevel\QC_Signal_Plots';
if ~exist(out_dir, 'dir'), mkdir(out_dir); end

target_pids = [15, 18, 40];

for k = 1:length(target_pids)
    pid = target_pids(k);
    idx = find(cov_tbl.Participant_ID == pid, 1);
    
    if isempty(idx)
        fprintf('Participant %d not found in Cohort_Covariates_Table.csv (likely excluded upstream).\n', pid);
        continue;
    end
    
    d_obj = Hb(idx);
    t = d_obj.time;
    data = d_obj.data;
    link = d_obj.probe.link;
    
    % Identify surviving long channels (exclude short-separation detector 16 and pruned NaN/zero columns)
    is_hbo = strcmpi(string(link.type), "hbo");
    is_hbr = strcmpi(string(link.type), "hbr");
    is_long = link.detector ~= 16;
    
    hbo_cols = find(is_hbo & is_long);
    hbr_cols = find(is_hbr & is_long);
    
    % Keep only channels with non-NaN, non-zero surviving signal
    valid_hbo = hbo_cols(any(~isnan(data(:, hbo_cols)) & data(:, hbo_cols) ~= 0, 1));
    
    % Match corresponding HbR columns by (source, detector)
    n_valid = length(valid_hbo);
    hbo_mat = nan(length(t), n_valid);
    hbr_mat = nan(length(t), n_valid);
    ch_labels = strings(n_valid, 1);
    
    for c = 1:n_valid
        col_o = valid_hbo(c);
        src = link.source(col_o);
        det = link.detector(col_o);
        col_r = find(is_hbr & link.source == src & link.detector == det, 1);
        
        hbo_mat(:, c) = data(:, col_o);
        if ~isempty(col_r)
            hbr_mat(:, c) = data(:, col_r);
        end
        ch_labels(c) = sprintf('S%d-D%d', src, det);
    end
    
    hbdiff_mat = hbo_mat - hbr_mat;
    
    % Build 3-Panel Stacked Figure (HbO, HbR, HbDiff)
    fig = figure('Position', [100, 100, 1400, 820], 'Color', 'w', 'Visible', 'off');
    
    % 1. HbO
    subplot(3, 1, 1);
    plot(t, hbo_mat, 'LineWidth', 0.9); hold on;
    plot(t, mean(hbo_mat, 2, 'omitnan'), 'k', 'LineWidth', 2.0);
    title(sprintf('Participant %d (Cohort Index %d) | Surviving Long Channels: %d — HbO', pid, idx, n_valid), 'FontWeight', 'bold');
    ylabel('HbO (\muM)'); grid on; xlim([t(1), t(end)]);
    
    % 2. HbR
    subplot(3, 1, 2);
    plot(t, hbr_mat, 'LineWidth', 0.9); hold on;
    plot(t, mean(hbr_mat, 2, 'omitnan'), 'k', 'LineWidth', 2.0);
    title('HbR (Individual Surviving Channels + Bold Black Mean)', 'FontWeight', 'bold');
    ylabel('HbR (\muM)'); grid on; xlim([t(1), t(end)]);
    
    % 3. HbDiff
    subplot(3, 1, 3);
    plot(t, hbdiff_mat, 'LineWidth', 0.9); hold on;
    plot(t, mean(hbdiff_mat, 2, 'omitnan'), 'k', 'LineWidth', 2.0);
    title('HbDiff (HbO - HbR)', 'FontWeight', 'bold');
    xlabel('Time (s)'); ylabel('HbDiff (\muM)'); grid on; xlim([t(1), t(end)]);
    
    out_file = fullfile(out_dir, sprintf('Signals_Ptp%02d_HbO_HbR_HbDiff.png', pid));
    exportgraphics(fig, out_file, 'Resolution', 300);
    close(fig);
    fprintf('Saved: %s (%d surviving long channels)\n', out_file, n_valid);
end