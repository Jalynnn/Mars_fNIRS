%% Section F (RQ1)

% 8B "All second-level group models included participant age, sex, and a
% binary indicator of whether the dyad visited a second destination as fixed-effect covariates."

% this is where I had to confirm second dest as optional for those that
% didn't have it - maybe it would have been fine without since tricorder
% was fine without?
% if numel(categories(sub_tbl.Second_Dest_Dummy)) > 1
%     formula_str = 'Beta ~ 1 + Team_Perf_Dummy + Age_Centered + Gender_Dummy + Second_Dest_Dummy + (1 | Session_ID)';
% else
%     formula_str = 'Beta ~ 1 + Team_Perf_Dummy + Age_Centered + Gender_Dummy + (1 | Session_ID)';
% end

% Method doc
% y[i,d] = b0 + b1Team[d] + b2Age[i,d] + b3Sex[i,d] + b4Second[d] + u[d] + e[i,d] 
% roi contrasts estimates [participant] [dyad] = beta + team performance 0
% or 1 based on first arrival + age in years mean centered + gender dummy
% coded + 1 or 0 based on if a second location was visited + dyad intercept
% + validation
% "LME modeling was selected to handle the hierarchical, nested dependencies 
% inherent to dyadic data. Because each participant contributes one contrast 
% estimate per model, each model included a random intercept for dyad."

% "Team Performance: LME models evaluated ROI contrast
% estimates as a function of the binary team performance outcome 
% (Correct vs.\ Decoy first-site selection), with the random intercept for 
% dyad accounting for cross-partner dependencies. "
% represents: 
% formula_str = 'Beta_ROI ~ 1 + Team_Perf_Dummy + Age_Centered + Gender_Dummy + Second_Dest_Dummy + (1 | Session_ID)';
% lme = fitlme(sub_tbl, formula_str);

% Precision-Weighted via Inverse-Variance Weights: w = 1 / SE^2

% Command window update prompt
% fprintf('\n--- Evaluating RQ1 Team Performance LME Models ---\n');
% 
% primary_baseline = 'TaskMatched';
% rq1_chan_rows = {};
% rq1_chan_full_rows = {};
% full_chan_cols = { ...
%     'Baseline_Type', 'Task_Contrast', 'Timescale', 'Chromophore', ...
%     'Channel', 'Source', 'Detector', 'ROI', 'N_Obs', ...
%     'Effect_Type', 'Term', 'Estimate', 'SE', 'T_Stat', 'DF', 'P_Val', ...
%     'CI_Lower', 'CI_Upper', 'Partial_EtaSq_or_Var', 'ICC', 'Model_Status' ...
% };

% rq1_roi_rows = {};
% rq1_roi_full_rows = {};
% full_roi_cols = { ...
%     'Baseline_Type', 'Task_Contrast', 'Timescale', 'Chromophore', 'ROI', 'N_Obs', ...
%     'Effect_Type', 'Term', 'Estimate', 'SE', 'T_Stat', 'DF', 'P_Val', ...
%     'CI_Lower', 'CI_Upper', 'Partial_EtaSq_or_Var', 'ICC', 'Model_Status' ...
% };

% chroms = categories(Track1_Channel_Long_Table.Chromophore); % HbDiff, HbO, HbR
% channels = unique(Track1_Channel_Long_Table.Channel); % 1-41
% rois = categories(Track2_ROI_Long_Table.ROI); % 5 ROIs

% Explicitly restrict RQ1 to the 7 general mission tasks
% rq1_tasks = { ...
%     'planning_individual', ...
%     'planning_team', ...
%     'status_check', ...
%     'spam_pop_up', ...
%     'tricorder_switch', ...
%     'certainty_individual', ...
%     'certainty_consensus' ...
% };
% Put back to the full 11 tasks
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

% chan_col_names = { ...
%     'Baseline_Type', 'Task_Contrast', 'Timescale', 'Timescale_Num', ...
%     'Chromophore', 'Channel', 'Source', 'Detector', 'ROI', 'N_Obs', ...
%     'Beta_TeamPerf', 'SE', 'T_Stat', 'DF', 'P_Val', 'CI_Lower', 'CI_Upper', 'Cohens_d', 'Model_Status' ...
% };

% roi_col_names = { ...
%     'Baseline_Type', 'Task_Contrast', 'Timescale', 'Timescale_Num', ...
%     'Chromophore', 'ROI', 'N_Obs', 'Beta_TeamPerf', 'SE', 'T_Stat', 'DF', ...
%     'P_Val', 'CI_Lower', 'CI_Upper', 'Cohens_d', 'Model_Status' ...
% };

% (8A) Track 1: Channel-Level Models for RQ1
% fprintf('Evaluating Track 1: Precision-weighted channel models across 41 channels and %d tasks...\n', ...
%     length(rq1_tasks));

% for c = 1:length(chroms)
    % chrom_str = chroms{c};
    
    % for ch_idx = 1:length(channels)
    %     chan_num = channels(ch_idx);
    % 
    %     for t = 1:length(rq1_tasks)
    %         task_str = rq1_tasks{t};
            
            % sub_idx = Track1_Channel_Long_Table.Baseline_Type == primary_baseline & ...
            %           Track1_Channel_Long_Table.Chromophore == chrom_str & ...
            %           Track1_Channel_Long_Table.Channel == chan_num & ...
            %           Track1_Channel_Long_Table.Task_Contrast == task_str;
            
            % meta_idx = find(sub_idx, 1, 'first');
            % if isempty(meta_idx), continue; end
            
            % sub_tbl = Track1_Channel_Long_Table(sub_idx, :);
            % req_vars = {'Beta', 'SE', 'Team_Perf_Dummy', 'Age_Centered', 'Gender_Dummy', 'Second_Dest_Dummy', 'Session_ID'};
            % sub_tbl  = sub_tbl(:, intersect(req_vars, sub_tbl.Properties.VariableNames));
            % sub_tbl  = rmmissing(sub_tbl);
            
            % base_meta_ch = { ...
            %     string(primary_baseline), string(task_str), ...
            %     string(Track1_Channel_Long_Table.Timescale(meta_idx)), ...
            %     string(chrom_str), chan_num, ...
            %     Track1_Channel_Long_Table.Source(meta_idx), ...
            %     Track1_Channel_Long_Table.Detector(meta_idx), ...
            %     string(Track1_Channel_Long_Table.ROI(meta_idx)), height(sub_tbl) ...
            % };
            
            % try
            %     if height(sub_tbl) == 0
            %         error('No valid observations remaining after rmmissing.');
            %     end
            %     if numel(unique(sub_tbl.Team_Perf_Dummy)) < 2
            %         error('Single outcome level (Team_Perf_Dummy has < 2 levels).');
            %     end
            % 
            %     raw_w = 1 ./ max(sub_tbl.SE .^ 2, 1e-6);
            %     w_vec = raw_w / mean(raw_w);
                
                % sub_tbl.Gender_Dummy      = removecats(categorical(sub_tbl.Gender_Dummy));
                % sub_tbl.Second_Dest_Dummy = removecats(categorical(sub_tbl.Second_Dest_Dummy));
                % sub_tbl.Session_ID        = removecats(categorical(sub_tbl.Session_ID));
                
                % if numel(categories(sub_tbl.Second_Dest_Dummy)) > 1
                %     formula_str = 'Beta ~ 1 + Team_Perf_Dummy + Age_Centered + Gender_Dummy + Second_Dest_Dummy + (1 | Session_ID)';
                % else
                %     formula_str = 'Beta ~ 1 + Team_Perf_Dummy + Age_Centered + Gender_Dummy + (1 | Session_ID)';
                % end
                
                % lme = fitlme(sub_tbl, formula_str, 'Weights', w_vec);
                
                % team_idx = find(strcmp(lme.CoefficientNames, 'Team_Perf_Dummy'));
                % if isempty(team_idx)
                %     error('Team_Perf_Dummy dropped due to collinearity.');
                % end
                
                % b1       = lme.Coefficients.Estimate(team_idx);
                % se1      = lme.Coefficients.SE(team_idx);
                % tstat    = lme.Coefficients.tStat(team_idx);
                % pval     = lme.Coefficients.pValue(team_idx);
                % df       = lme.Coefficients.DF(team_idx);
                % ci       = lme.coefCI;
                % ci_l     = ci(team_idx, 1);
                % ci_u     = ci(team_idx, 2);
                % cohens_d = tstat / sqrt(height(sub_tbl));
                
                % rq1_chan_full_rows = extract_lme_full_terms(lme, base_meta_ch, rq1_chan_full_rows, "OK");
                % rq1_chan_rows(end+1, 1:19) = { ...
                %     string(primary_baseline), string(task_str), ...
                %     string(Track1_Channel_Long_Table.Timescale(meta_idx)), ...
                %     Track1_Channel_Long_Table.Timescale_Num(meta_idx), ...
                %     string(chrom_str), chan_num, ...
                %     Track1_Channel_Long_Table.Source(meta_idx), ...
                %     Track1_Channel_Long_Table.Detector(meta_idx), ...
                %     string(Track1_Channel_Long_Table.ROI(meta_idx)), height(sub_tbl), ...
                %     b1, se1, tstat, df, pval, ci_l, ci_u, cohens_d, "OK" ...
                % };
            % catch ME
            %     status_msg = "Skipped: " + string(ME.message);
                % rq1_chan_rows(end+1, 1:19) = { ...
                %     string(primary_baseline), string(task_str), ...
                %     string(Track1_Channel_Long_Table.Timescale(meta_idx)), ...
                %     Track1_Channel_Long_Table.Timescale_Num(meta_idx), ...
                %     string(chrom_str), chan_num, ...
                %     Track1_Channel_Long_Table.Source(meta_idx), ...
                %     Track1_Channel_Long_Table.Detector(meta_idx), ...
                %     string(Track1_Channel_Long_Table.ROI(meta_idx)), height(sub_tbl), ...
                %     NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, status_msg ...
                % };
                % rq1_chan_full_rows(end+1, 1:21) = [base_meta_ch, { ...
                %     "Unestimated", "N/A", NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, status_msg ...
                % }];
%             end
%         end
%     end
% end

% if isempty(rq1_chan_rows)
%     Table_RQ1_Channels = cell2table(cell(0, length(chan_col_names)), 'VariableNames', chan_col_names);
% else
%     Table_RQ1_Channels = cell2table(rq1_chan_rows, 'VariableNames', chan_col_names);
% end
% fprintf('Track 1 RQ1 Channels complete: %d channel models evaluated.\n', height(Table_RQ1_Channels));

% % (8B) Track 2: ROI-Level Models for RQ1
% fprintf('Evaluating Track 2: Precision-weighted ROI models across %d ROIs, %d tasks, and %d chromophores...\n', ...
%     length(rois), length(rq1_tasks), length(chroms));
% 
% for c = 1:length(chroms)
%     chrom_str = chroms{c};
% 
%     for r = 1:length(rois)
%         roi_str = rois{r};
        
        % for t = 1:length(rq1_tasks)
        %     task_str = rq1_tasks{t};
        % 
        %     sub_idx = Track2_ROI_Long_Table.Baseline_Type == primary_baseline & ...
        %               Track2_ROI_Long_Table.Chromophore == chrom_str & ...
        %               Track2_ROI_Long_Table.ROI == roi_str & ...
        %               Track2_ROI_Long_Table.Task_Contrast == task_str;
            
            % meta_idx = find(sub_idx, 1, 'first');
            % if isempty(meta_idx), continue; end
            
            % sub_tbl = Track2_ROI_Long_Table(sub_idx, :);
            % req_vars = {'Beta_ROI', 'SE_ROI', 'Team_Perf_Dummy', 'Age_Centered', 'Gender_Dummy', 'Second_Dest_Dummy', 'Session_ID'};
            % sub_tbl  = sub_tbl(:, intersect(req_vars, sub_tbl.Properties.VariableNames));
            % sub_tbl  = rmmissing(sub_tbl);
            
            % base_meta = { ...
            %     string(primary_baseline), string(task_str), ...
            %     string(Track2_ROI_Long_Table.Timescale(meta_idx)), ...
            %     string(chrom_str), string(roi_str), height(sub_tbl) ...
            % };
            % 
            % try
            %     if height(sub_tbl) == 0
            %         error('No valid observations remaining after rmmissing.');
            %     end
                % if numel(unique(sub_tbl.Team_Perf_Dummy)) < 2
                %     error('Single outcome level (Team_Perf_Dummy has < 2 levels).');
                % end
                
                % raw_w = 1 ./ max(sub_tbl.SE_ROI .^ 2, 1e-6);
                % w_vec = raw_w / mean(raw_w);
                
                % sub_tbl.Gender_Dummy      = removecats(categorical(sub_tbl.Gender_Dummy));
                % sub_tbl.Second_Dest_Dummy = removecats(categorical(sub_tbl.Second_Dest_Dummy));
                % sub_tbl.Session_ID        = removecats(categorical(sub_tbl.Session_ID));
                
                % if numel(categories(sub_tbl.Second_Dest_Dummy)) > 1
                %     formula_str = 'Beta_ROI ~ 1 + Team_Perf_Dummy + Age_Centered + Gender_Dummy + Second_Dest_Dummy + (1 | Session_ID)';
                % else
                %     formula_str = 'Beta_ROI ~ 1 + Team_Perf_Dummy + Age_Centered + Gender_Dummy + (1 | Session_ID)';
                % end
                
                % lme = fitlme(sub_tbl, formula_str, 'Weights', w_vec);
                
                % team_idx = find(strcmp(lme.CoefficientNames, 'Team_Perf_Dummy'));
                % if isempty(team_idx)
                %     error('Team_Perf_Dummy dropped due to collinearity.');
                % end
                
                % b1       = lme.Coefficients.Estimate(team_idx);
                % se1      = lme.Coefficients.SE(team_idx);
                % tstat    = lme.Coefficients.tStat(team_idx);
                % pval     = lme.Coefficients.pValue(team_idx);
                % df       = lme.Coefficients.DF(team_idx);
                % ci       = lme.coefCI;
                % ci_l     = ci(team_idx, 1);
                % ci_u     = ci(team_idx, 2);
                % cohens_d = tstat / sqrt(height(sub_tbl));
                
                % rq1_roi_full_rows = extract_lme_full_terms(lme, base_meta, rq1_roi_full_rows, "OK");
                % rq1_roi_rows(end+1, 1:16) = { ...
                %     string(primary_baseline), string(task_str), ...
                %     string(Track2_ROI_Long_Table.Timescale(meta_idx)), ...
                %     Track2_ROI_Long_Table.Timescale_Num(meta_idx), ...
                %     string(chrom_str), string(roi_str), height(sub_tbl), ...
                %     b1, se1, tstat, df, pval, ci_l, ci_u, cohens_d, "OK" ...
                % };
            % catch ME
            %     status_msg = "Skipped: " + string(ME.message);
            %     rq1_roi_rows(end+1, 1:16) = { ...
            %         string(primary_baseline), string(task_str), ...
            %         string(Track2_ROI_Long_Table.Timescale(meta_idx)), ...
            %         Track2_ROI_Long_Table.Timescale_Num(meta_idx), ...
            %         string(chrom_str), string(roi_str), height(sub_tbl), ...
            %         NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, status_msg ...
            %     };
                % rq1_roi_full_rows(end+1, 1:18) = [base_meta, { ...
                %     "Unestimated", "N/A", NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, status_msg ...
                % }];
%             end
%         end
%     end
% end

% if isempty(rq1_roi_rows)
%     Table_RQ1_ROI = cell2table(cell(0, length(roi_col_names)), 'VariableNames', roi_col_names);
% else
%     Table_RQ1_ROI = cell2table(rq1_roi_rows, 'VariableNames', roi_col_names);
% end

% Multiple Comparisons Correction: Benjamini-Hochberg FDR (q < .05)
% Table_RQ1_ROI.P_FDR = nan(height(Table_RQ1_ROI), 1);
% Table_RQ1_ROI.Sig_FDR = false(height(Table_RQ1_ROI), 1);

% if ~isempty(Table_RQ1_ROI)
    % for c = 1:length(chroms)
        % c_idx = Table_RQ1_ROI.Chromophore == string(chroms{c});
        % p_raw = Table_RQ1_ROI.P_Val(c_idx);
        
        % if ~isempty(p_raw)
        %     [p_sorted, sort_order] = sort(p_raw, 'ascend');
            % m = length(p_raw);
            % q_sorted = p_sorted .* (m ./ (1:m)');
            
            % for k = m-1:-1:1
                % q_sorted(k) = min(q_sorted(k), q_sorted(k+1));
            % end
            % q_sorted = min(q_sorted, 1);
            
            % q_adj = zeros(size(p_raw));
            % q_adj(sort_order) = q_sorted;
            
            % Table_RQ1_ROI.P_FDR(c_idx) = q_adj;
            % Table_RQ1_ROI.Sig_FDR(c_idx) = (q_adj < 0.05);
    %     end
    % end
% end
% fprintf('Track 2 RQ1 ROI complete: %d models evaluated.\n', height(Table_RQ1_ROI));

% (8C) Export Deliverables to Mars_fNIRS\Output\GroupLevel
% rq1_chan_csv = fullfile(group_out_dir, 'Table_RQ1_TeamPerformance_Channels.csv');
% rq1_roi_csv = fullfile(group_out_dir, 'Table_RQ1_TeamPerformance_ROI.csv');
% rq1_mat= fullfile(group_out_dir, 'GroupLevel_RQ1_Models.mat');

% writetable(Table_RQ1_Channels, rq1_chan_csv);
% writetable(Table_RQ1_ROI, rq1_roi_csv);
% save(rq1_mat, 'Table_RQ1_Channels', 'Table_RQ1_ROI');
% fprintf('Section F complete. Saved RQ1 deliverables to:\n  -> %s\n  -> %s\n  -> %s\n', ...
%     rq1_chan_csv, rq1_roi_csv, rq1_mat);

% Table_RQ1_Channels_FullTerms = cell2table(rq1_chan_full_rows, 'VariableNames', full_chan_cols);
% writetable(Table_RQ1_Channels_FullTerms, fullfile(group_out_dir, 'Table_RQ1_FullModel_Covariates_Channels.csv'));

% if isempty(rq1_chan_full_rows)
%     Table_RQ1_Channels_FullTerms = cell2table(cell(0, length(full_chan_cols)), 'VariableNames', full_chan_cols);
% else
%     Table_RQ1_Channels_FullTerms = cell2table(rq1_chan_full_rows, 'VariableNames', full_chan_cols);
% end
% writetable(Table_RQ1_Channels_FullTerms, fullfile(group_out_dir, 'Table_RQ1_FullModel_Covariates_Channels.csv'));

% Table_RQ1_ROI_FullTerms = cell2table(rq1_roi_full_rows, 'VariableNames', full_roi_cols);
% writetable(Table_RQ1_ROI_FullTerms, fullfile(group_out_dir, 'Table_RQ1_FullModel_Covariates_ROI.csv'));

% if isempty(rq1_roi_full_rows)
%     Table_RQ1_ROI_FullTerms = cell2table(cell(0, length(full_roi_cols)), 'VariableNames', full_roi_cols);
% else
%     Table_RQ1_ROI_FullTerms = cell2table(rq1_roi_full_rows, 'VariableNames', full_roi_cols);
% end
% writetable(Table_RQ1_ROI_FullTerms, fullfile(group_out_dir, 'Table_RQ1_FullModel_Covariates_ROI.csv'));

% Summary display of uncorrected and FDR-significant ROI findings with CIs
% sig_uncorr = Table_RQ1_ROI(Table_RQ1_ROI.P_Val < 0.05, :);
% sig_fdr = Table_RQ1_ROI(Table_RQ1_ROI.Sig_FDR, :);

% fprintf('\nSummary of Precision-Weighted RQ1 ROI Effects:\n');
% fprintf('  - Significant uncorrected (p < .05): %d / %d\n', height(sig_uncorr), height(Table_RQ1_ROI));
% fprintf('  - Significant FDR-corrected (q < .05): %d / %d\n', height(sig_fdr), height(Table_RQ1_ROI));

% if ~isempty(sig_uncorr)
%     disp(sig_uncorr(:, {'Task_Contrast', 'Chromophore', 'ROI', 'Beta_TeamPerf', 'CI_Lower', 'CI_Upper', 'T_Stat', 'Cohens_d', 'P_Val', 'P_FDR'}));
% end

% PUBLICATION TABLE EXPORT: RQ1 TEAM PERFORMANCE (CHANNELS & ROIS)
% Formatted with Standardization, N-counts, and Brodmann Area Mapping

% 
% fprintf('\n=== Generating Publication Tables for RQ1 ===\n');
% 
% % X. Process Track 1: Channel-Level Table (Table II Style)
% fprintf('Formatting Track 1 Channel Publication Table...\n');
% 
% n_chan_models = height(Table_RQ1_Channels);
% chan_b_std = nan(n_chan_models, 1);
% chan_ci_low = nan(n_chan_models, 1);
% chan_ci_upp = nan(n_chan_models, 1);
% chan_n_dyads = nan(n_chan_models, 1);
% chan_ba_label = strings(n_chan_models, 1);

% for row = 1:n_chan_models
%     s_task = Table_RQ1_Channels.Task_Contrast(row);
%     s_chrom = Table_RQ1_Channels.Chromophore(row);
%     s_ch = Table_RQ1_Channels.Channel(row);
% 
%     % Match slice in Track 1 Long Table
%     idx = Track1_Channel_Long_Table.Baseline_Type == "TaskMatched" & ...
%           Track1_Channel_Long_Table.Task_Contrast == s_task & ...
%           Track1_Channel_Long_Table.Chromophore == s_chrom & ...
%           Track1_Channel_Long_Table.Channel == s_ch;
% 
%     sub = Track1_Channel_Long_Table(idx, {'Beta', 'Team_Perf_Dummy', 'Session_ID'});
%     sub = rmmissing(sub);
% 
%     chan_n_dyads(row) = numel(unique(sub.Session_ID));
% 
%     % Standardization: Scale = SD(X) / SD(Y)
%     if height(sub) > 1
%         sx = std(sub.Team_Perf_Dummy);
%         sy = std(sub.Beta);
%         if sy > 0
%             scale_factor = sx / sy;
%             chan_b_std(row) = Table_RQ1_Channels.Beta_TeamPerf(row) * scale_factor;
%             chan_ci_low(row) = Table_RQ1_Channels.CI_Lower(row) * scale_factor;
%             chan_ci_upp(row) = Table_RQ1_Channels.CI_Upper(row) * scale_factor;
%         end
%     end
    
    % Map Brodmann Area from ROI assignment
%     ch_roi = string(Table_RQ1_Channels.ROI(row));
%     switch ch_roi
%         case "RPFC"
%             chan_ba_label(row) = "BA 10 – Rostral Prefrontal Cortex";
%         case "L_DLPFC"
%             chan_ba_label(row) = "BA 9/46 – Left Dorsolateral Prefrontal Cortex";
%         case "R_DLPFC"
%             chan_ba_label(row) = "BA 9/46 – Right Dorsolateral Prefrontal Cortex";
%         % case "Parietal"
%         %     chan_ba_label(row) = "BA 7/40 – Posterior Parietal Cortex";
%         case "L_Parietal"
%             chan_ba_label(row) = "BA 7/40 – Left Posterior Parietal Cortex";
%         case "R_Parietal"
%             chan_ba_label(row) = "BA 7/40 – Right Posterior Parietal Cortex";
%         otherwise
%             chan_ba_label(row) = ch_roi;
%     end
% end

% Table_RQ1_Channels_Pub = table( ...
%     Table_RQ1_Channels.Task_Contrast, ...
%     Table_RQ1_Channels.Chromophore, ...
%     Table_RQ1_Channels.Channel, ...
%     Table_RQ1_Channels.N_Obs, ...
%     chan_n_dyads, ...
%     Table_RQ1_Channels.Beta_TeamPerf, ...
%     chan_b_std, ...
%     chan_ci_low, ...
%     chan_ci_upp, ...
%     Table_RQ1_Channels.T_Stat, ...
%     Table_RQ1_Channels.DF, ...
%     Table_RQ1_Channels.P_Val, ...
%     chan_ba_label, ...
%     'VariableNames', { ...
%         'Condition_Contrast', 'Chromophore', 'Channel', 'N_Participants', 'N_Dyads', ...
%         'Beta_Raw', 'Beta_Std', 'CI_Std_Lower', 'CI_Std_Upper', 't', 'df', 'p', 'Brodmann_Area' ...
%     } ...
% );

% TRACK 1 CHANNELS: OPTION B FDR (PER TASK CONTRAST x CHROMOPHORE)
% m <= 41 Channels per Topographic Family
% fprintf('\n--- Computing Option B FDR for Track 1 Channels (Per Task x Chromophore) ---\n');

% chroms = categories(categorical(Table_RQ1_Channels_Pub.Chromophore));
% tasks = categories(categorical(Table_RQ1_Channels_Pub.Condition_Contrast));

% Table_RQ1_Channels_Pub.p_FDR = nan(height(Table_RQ1_Channels_Pub), 1);

% if ~isempty(Table_RQ1_Channels_Pub)
    % for c = 1:length(chroms)
        % c_str = string(chroms{c});
        
        % for t = 1:length(tasks)
            % t_str = tasks{t};
            
            % Family slice: All channels within this specific task and chromophore
            % slice_idx = Table_RQ1_Channels_Pub.Chromophore == c_str & ...
            %             Table_RQ1_Channels_Pub.Condition_Contrast == t_str;
                    
            % p_raw = Table_RQ1_Channels_Pub.p(slice_idx);
            
            % if ~isempty(p_raw)
            %     [p_sorted, sort_order] = sort(p_raw, 'ascend');
            %     m = length(p_raw); % m <= 41
            %     q_sorted = p_sorted .* (m ./ (1:m)');
            % 
            %     % Enforce monotonicity
            %     for k = m-1:-1:1
            %         q_sorted(k) = min(q_sorted(k), q_sorted(k+1));
            %     end
            %     q_sorted = min(q_sorted, 1);
            % 
            %     q_adj = zeros(size(p_raw));
            %     q_adj(sort_order) = q_sorted;
            % 
            %     Table_RQ1_Channels_Pub.p_FDR(slice_idx) = q_adj;
            % end
%         end
%     end
% end

% % Keep column ordering clean
% pub_vars = { ...
%     'Condition_Contrast', 'Chromophore', 'Channel', 'N_Participants', 'N_Dyads', ...
%     'Beta_Raw', 'Beta_Std', 'CI_Std_Lower', 'CI_Std_Upper', 't', 'df', 'p', 'p_FDR', 'Brodmann_Area' ...
% };
% Table_RQ1_Channels_Pub = Table_RQ1_Channels_Pub(:, pub_vars);

% Update CSV Exports in Output/GroupLevel and RQ_Sig
% chan_pub_csv = fullfile(group_out_dir, 'Table_RQ1_Publication_Channels.csv');
% sig_chan_csv = fullfile(group_out_dir, 'RQ_Sig', 'Table_RQ1_Significant_Channels.csv');

% writetable(Table_RQ1_Channels_Pub, chan_pub_csv);

% Filter channels with uncorrected p < .05
% sig_chan_tbl = Table_RQ1_Channels_Pub(Table_RQ1_Channels_Pub.p < 0.05, :);
% sig_chan_tbl = sortrows(sig_chan_tbl, {'Condition_Contrast', 'Chromophore', 'p'}, {'ascend', 'ascend', 'ascend'});
% writetable(sig_chan_tbl, sig_chan_csv);

% fprintf('Deliverables updated successfully:\n');
% fprintf('  -> Master Table (All Channels): %s\n', chan_pub_csv);
% fprintf('  -> Significant Channels (p < .05): %s (%d rows)\n', sig_chan_csv, height(sig_chan_tbl));

% % Inspect Channels Surviving Topographic FDR (q < .05)
% fdr_survivors = Table_RQ1_Channels_Pub(Table_RQ1_Channels_Pub.p_FDR < 0.05, :);
% fprintf('\n========================================================================================\n');
% fprintf('CHANNELS SURVIVING TOPOGRAPHIC FDR CORRECTION (q < .05): %d / %d\n', ...
%     height(fdr_survivors), height(Table_RQ1_Channels_Pub));
% fprintf('========================================================================================\n');

% if isempty(fdr_survivors)
%     disp('No individual channels survived FDR correction at q < .05.');
% else
%     disp(fdr_survivors(:, {'Condition_Contrast', 'Chromophore', 'Channel', 'N_Participants', ...
%                            'Beta_Std', 't', 'p', 'p_FDR', 'Brodmann_Area'}));
% end

% 2. Process Track 2: ROI-Level Table
% fprintf('Formatting Track 2 ROI Publication Table...\n');
% 
% n_roi_models = height(Table_RQ1_ROI);
% roi_b_std = nan(n_roi_models, 1);
% roi_ci_low = nan(n_roi_models, 1);
% roi_ci_upp = nan(n_roi_models, 1);
% roi_n_dyads = nan(n_roi_models, 1);
% roi_ba_label = strings(n_roi_models, 1);

% for row = 1:n_roi_models
%     s_task = Table_RQ1_ROI.Task_Contrast(row);
%     s_chrom = Table_RQ1_ROI.Chromophore(row);
%     s_roi = Table_RQ1_ROI.ROI(row);
    
    % idx = Track2_ROI_Long_Table.Baseline_Type == "TaskMatched" & ...
    %       Track2_ROI_Long_Table.Task_Contrast == s_task & ...
    %       Track2_ROI_Long_Table.Chromophore == s_chrom & ...
    %       Track2_ROI_Long_Table.ROI == s_roi;
    % 
    % sub = Track2_ROI_Long_Table(idx, {'Beta_ROI', 'Team_Perf_Dummy', 'Session_ID'});
    % sub = rmmissing(sub);
    % 
    % roi_n_dyads(row) = numel(unique(sub.Session_ID));
    % 
    % if height(sub) > 1
    %     sx = std(sub.Team_Perf_Dummy);
    %     sy = std(sub.Beta_ROI);
    %     if sy > 0
    %         scale_factor = sx / sy;
    %         roi_b_std(row) = Table_RQ1_ROI.Beta_TeamPerf(row) * scale_factor;
    %         roi_ci_low(row) = Table_RQ1_ROI.CI_Lower(row) * scale_factor;
    %         roi_ci_upp(row) = Table_RQ1_ROI.CI_Upper(row) * scale_factor;
    %     end
    % end
    
%     switch string(s_roi)
%         case "RPFC"
%             roi_ba_label(row) = "BA 10 – Rostral Prefrontal Cortex";
%         case "L_DLPFC"
%             roi_ba_label(row) = "BA 9/46 – Left Dorsolateral Prefrontal Cortex";
%         case "R_DLPFC"
%             roi_ba_label(row) = "BA 9/46 – Right Dorsolateral Prefrontal Cortex";
%         % case "Parietal"
%         %     roi_ba_label(row) = "BA 7/40 – Posterior Parietal Cortex";
%         case "L_Parietal"
%             roi_ba_label(row) = "BA 7/40 – Left Posterior Parietal Cortex";
%         case "R_Parietal"
%             roi_ba_label(row) = "BA 7/40 – Right Posterior Parietal Cortex";
%         otherwise
%             roi_ba_label(row) = string(s_roi);
%     end
% end

% Table_RQ1_ROI_Pub = table( ...
%     Table_RQ1_ROI.Task_Contrast, ...
%     Table_RQ1_ROI.Chromophore, ...
%     Table_RQ1_ROI.ROI, ...
%     Table_RQ1_ROI.N_Obs, ...
%     % roi_n_dyads, ...
%     Table_RQ1_ROI.Beta_TeamPerf, ...
%     % roi_b_std, ...
%     % roi_ci_low, ...
%     % roi_ci_upp, ...
%     Table_RQ1_ROI.T_Stat, ...
%     Table_RQ1_ROI.DF, ...
%     Table_RQ1_ROI.P_Val, ...
%     Table_RQ1_ROI.P_FDR, ...
%     % roi_ba_label, ...
%     'VariableNames', { ...
%         'Condition_Contrast', 'Chromophore', 'ROI', 'N_Participants', 'N_Dyads', ...
%         'Beta_Raw', 'Beta_Std', 'CI_Std_Lower', 'CI_Std_Upper', 't', 'df', 'p', 'p_FDR', 'Brodmann_Area' ...
%     } ...
% );

% Save Final CSV Files
% chan_pub_csv = fullfile(group_out_dir, 'Table_RQ1_Publication_Channels.csv');
% roi_pub_csv = fullfile(group_out_dir, 'Table_RQ1_Publication_ROI.csv');
% writetable(Table_RQ1_Channels_Pub, chan_pub_csv);
% writetable(Table_RQ1_ROI_Pub, roi_pub_csv);

% fprintf('\nDeliverables exported successfully:\n  -> %s\n  -> %s\n', chan_pub_csv, roi_pub_csv);

% Print Summary Display of Significant Findings (p < .05)
% fprintf('\n========================================================================================\n');
% fprintf('TABLE: ROI-BASED COMPARISONS OF TEAM PERFORMANCE (CORRECT VS. DECOY)\n');
% fprintf('========================================================================================\n');
% sig_roi_pub = Table_RQ1_ROI_Pub(Table_RQ1_ROI_Pub.p < 0.05, :);
% if isempty(sig_roi_pub)
%     disp('No ROI effects reached uncorrected p < .05.');
% else
%     disp(sig_roi_pub(:, {'Condition_Contrast', 'Chromophore', 'ROI', 'N_Participants', 'N_Dyads', ...
%                          'Beta_Raw', 'Beta_Std', 'CI_Std_Lower', 'CI_Std_Upper', 't', 'p', 'p_FDR', 'Brodmann_Area'}));
% end

% fprintf('\n========================================================================================\n');
% fprintf('TABLE: CHANNEL-BASED COMPARISONS (OPTODE RESOLUTION) OF TEAM PERFORMANCE (p < .05)\n');
% fprintf('========================================================================================\n');
% sig_chan_pub = Table_RQ1_Channels_Pub(Table_RQ1_Channels_Pub.p < 0.05, :);
% if isempty(sig_chan_pub)
%     disp('No channel effects reached uncorrected p < .05.');
% else
%     disp(sig_chan_pub(1:min(15, height(sig_chan_pub)), ...
%         {'Condition_Contrast', 'Chromophore', 'Channel', 'N_Participants', 'N_Dyads', ...
%          'Beta_Raw', 'Beta_Std', 't', 'p', 'Brodmann_Area'}));
% end

% EXPORT SIGNIFICANT RQ1 EFFECTS TO DEDICATED DIRECTORY ('RQ_Sig')
% fprintf('\n--- Exporting Significant RQ1 Tables to RQ_Sig Folder ---\n');

% % 1. Create target output directory
% sig_out_dir = fullfile(group_out_dir, 'RQ_Sig');
% if ~exist(sig_out_dir, 'dir')
%     mkdir(sig_out_dir);
%     fprintf('Created directory: %s\n', sig_out_dir);
% end

% 2. Filter significant Track 1 Channels (p < .05, uncorrected)
% sig_chan_tbl = Table_RQ1_Channels_Pub(Table_RQ1_Channels_Pub.p < 0.05, :);
% % Sort by Task Contrast, Chromophore, and p-value
% sig_chan_tbl = sortrows(sig_chan_tbl, {'Condition_Contrast', 'Chromophore', 'p'}, {'ascend', 'ascend', 'ascend'});

% 3. Filter significant Track 2 ROIs (p < .05, uncorrected)
% sig_roi_tbl = Table_RQ1_ROI_Pub(Table_RQ1_ROI_Pub.p < 0.05, :);
% sig_roi_tbl = sortrows(sig_roi_tbl, {'Condition_Contrast', 'Chromophore', 'p'}, {'ascend', 'ascend', 'ascend'});

% 4. Define destination file paths
% sig_chan_csv = fullfile(sig_out_dir, 'Table_RQ1_Significant_Channels.csv');
% sig_roi_csv = fullfile(sig_out_dir, 'Table_RQ1_Significant_ROI.csv');

% 5. Write to disk
% writetable(sig_chan_tbl, sig_chan_csv);
% writetable(sig_roi_tbl, sig_roi_csv);

% fprintf('Export complete:\n');
% fprintf('  -> Significant Channels (%d rows): %s\n', height(sig_chan_tbl), sig_chan_csv);
% fprintf('  -> Significant ROIs     (%d rows): %s\n', height(sig_roi_tbl), sig_roi_csv);

%% Section G

%  RQ2 - Individual Certainty Group LME Models (Step 9)
%  Precision-Weighted w = 1 / SE^2; FitMethod = 'ML' for Model Selection

% Command prompt
% fprintf('\n--- Section G: Evaluating RQ2 Certainty LME Models (Maximum Likelihood) ---\n');

% primary_baseline = 'TaskMatched';
% rq2_chan_rows = {};
% rq2_chan_full_rows = {};
% rq2_roi_rows = {};
% rq2_roi_full_rows = {};

% chroms = categories(Track1_Channel_Long_Table.Chromophore);
% channels = unique(Track1_Channel_Long_Table.Channel);
% rois = categories(Track2_ROI_Long_Table.ROI);

% % Full 11 task contrasts for RQ2
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

% chan_col_names_rq2 = { ...
%     'Baseline_Type', 'Task_Contrast', 'Timescale', 'Timescale_Num', ...
%     'Chromophore', 'Channel', 'Source', 'Detector', 'ROI', 'N_Obs', ...
%     'Beta_SC', 'SE_SC', 'T_Stat_SC', 'DF_SC', 'P_Val_SC', 'CI_Lower_SC', 'CI_Upper_SC', ...
%     'Beta_Time', 'P_Val_Time', ...
%     'AIC_M1_Signed', 'AIC_M2_Unsigned', 'AIC_M3_Dual', 'Delta_AIC_M2_M1', 'Delta_AIC_M3_M1', 'Model_Status' ...
% };
% 
% roi_col_names_rq2 = { ...
%     'Baseline_Type', 'Task_Contrast', 'Timescale', 'Timescale_Num', ...
%     'Chromophore', 'ROI', 'N_Obs', ...
%     'Beta_SC', 'SE_SC', 'T_Stat_SC', 'DF_SC', 'P_Val_SC', 'CI_Lower_SC', 'CI_Upper_SC', ...
%     'Beta_Time', 'P_Val_Time', ...
%     'AIC_M1_Signed', 'AIC_M2_Unsigned', 'AIC_M3_Dual', 'Delta_AIC_M2_M1', 'Delta_AIC_M3_M1', 'Model_Status' ...
% };

% (9A) Track 1: Channel-Level Models for RQ2 (Optode Resolution)

% fprintf('Evaluating Track 1: Precision-weighted ML channel models across 41 channels and %d tasks...\n', ...
    length(rq2_tasks));

% for c = 1:length(chroms)
%     chrom_str = chroms{c};
% 
%     for ch_idx = 1:length(channels)
%         chan_num = channels(ch_idx);
        
        % for t = 1:length(rq2_tasks)
        %     task_str = rq2_tasks{t};

            % sub_idx = Track1_Channel_Long_Table.Baseline_Type == primary_baseline & ...
            %           Track1_Channel_Long_Table.Chromophore == chrom_str & ...
            %           Track1_Channel_Long_Table.Channel == chan_num & ...
            %           Track1_Channel_Long_Table.Task_Contrast == task_str;
            
            % meta_idx = find(sub_idx, 1, 'first');
            % if isempty(meta_idx), continue; end
            
            % sub_tbl = Track1_Channel_Long_Table(sub_idx, :);
            % req_vars = {'Beta', 'SE', 'SC_Centered', 'Certainty_Centered', 'Time_Centered', ...
            %             'Age_Centered', 'Gender_Dummy', 'Second_Dest_Dummy', 'Session_ID'};
            % sub_tbl  = sub_tbl(:, intersect(req_vars, sub_tbl.Properties.VariableNames));
            % sub_tbl  = rmmissing(sub_tbl);
            
            % base_meta_ch = { ...
            %     string(primary_baseline), string(task_str), ...
            %     string(Track1_Channel_Long_Table.Timescale(meta_idx)), ...
            %     string(chrom_str), chan_num, ...
            %     Track1_Channel_Long_Table.Source(meta_idx), ...
            %     Track1_Channel_Long_Table.Detector(meta_idx), ...
            %     string(Track1_Channel_Long_Table.ROI(meta_idx)), height(sub_tbl) ...
            % };
            
            % try
            %     if height(sub_tbl) == 0
            %         error('No valid observations remaining after rmmissing.');
            %     end
            %     if numel(unique(sub_tbl.SC_Centered)) < 3
            %         error('Fewer than 3 unique SC_Centered values.');
            %     end
                
                % raw_w = 1 ./ max(sub_tbl.SE .^ 2, 1e-6);
                % w_vec = raw_w / mean(raw_w);
                
                % sub_tbl.Gender_Dummy      = removecats(categorical(sub_tbl.Gender_Dummy));
                % sub_tbl.Second_Dest_Dummy = removecats(categorical(sub_tbl.Second_Dest_Dummy));
                % sub_tbl.Session_ID        = removecats(categorical(sub_tbl.Session_ID));
                
                % has_second = numel(categories(sub_tbl.Second_Dest_Dummy)) > 1;
                % if has_second
                %     f1 = 'Beta ~ 1 + SC_Centered + Time_Centered + Age_Centered + Gender_Dummy + Second_Dest_Dummy + (1 | Session_ID)';
                %     f2 = 'Beta ~ 1 + Certainty_Centered + Time_Centered + Age_Centered + Gender_Dummy + Second_Dest_Dummy + (1 | Session_ID)';
                %     f3 = 'Beta ~ 1 + SC_Centered + Certainty_Centered + Time_Centered + Age_Centered + Gender_Dummy + Second_Dest_Dummy + (1 | Session_ID)';
                % else
                %     f1 = 'Beta ~ 1 + SC_Centered + Time_Centered + Age_Centered + Gender_Dummy + (1 | Session_ID)';
                %     f2 = 'Beta ~ 1 + Certainty_Centered + Time_Centered + Age_Centered + Gender_Dummy + (1 | Session_ID)';
                %     f3 = 'Beta ~ 1 + SC_Centered + Certainty_Centered + Time_Centered + Age_Centered + Gender_Dummy + (1 | Session_ID)';
                % end
                
                % Fit all three nested certainty models via Maximum Likelihood ('ML') for AIC comparison
                % MODEL 3 RQ2 for channels
                % lme1 = fitlme(sub_tbl, f1, 'Weights', w_vec, 'FitMethod', 'ML');
                % lme2 = fitlme(sub_tbl, f2, 'Weights', w_vec, 'FitMethod', 'ML');
                % lme3 = fitlme(sub_tbl, f3, 'Weights', w_vec, 'FitMethod', 'ML');
                % 
                % sc_idx = find(strcmp(lme1.CoefficientNames, 'SC_Centered'));
                % if isempty(sc_idx)
                    % error('SC_Centered dropped due to collinearity.');
                % end
                
                % b_sc    = lme1.Coefficients.Estimate(sc_idx);
                % se_sc   = lme1.Coefficients.SE(sc_idx);
                % t_sc    = lme1.Coefficients.tStat(sc_idx);
                % p_sc    = lme1.Coefficients.pValue(sc_idx);
                % df_sc   = lme1.Coefficients.DF(sc_idx);
                % ci_sc   = lme1.coefCI;
                % ci_l_sc = ci_sc(sc_idx, 1);
                % ci_u_sc = ci_sc(sc_idx, 2);
                
                % time_idx = find(strcmp(lme1.CoefficientNames, 'Time_Centered'));
                % if ~isempty(time_idx)
                %     b_time = lme1.Coefficients.Estimate(time_idx);
                %     p_time = lme1.Coefficients.pValue(time_idx);
                % else
                %     b_time = nan; p_time = nan;
                % end
                
                % aic1  = lme1.ModelCriterion.AIC;
                % aic2  = lme2.ModelCriterion.AIC;
                % aic3  = lme3.ModelCriterion.AIC;
                % daic2 = aic2 - aic1;
                % daic3 = aic3 - aic1;
                
                % rq2_chan_full_rows = extract_lme_full_terms(lme1, base_meta_ch, rq2_chan_full_rows, "OK");
                % rq2_chan_rows(end+1, 1:25) = { ...
                %     string(primary_baseline), string(task_str), ...
                %     string(Track1_Channel_Long_Table.Timescale(meta_idx)), ...
                %     Track1_Channel_Long_Table.Timescale_Num(meta_idx), ...
                %     string(chrom_str), chan_num, ...
                %     Track1_Channel_Long_Table.Source(meta_idx), ...
                %     Track1_Channel_Long_Table.Detector(meta_idx), ...
                %     string(Track1_Channel_Long_Table.ROI(meta_idx)), height(sub_tbl), ...
                %     b_sc, se_sc, t_sc, df_sc, p_sc, ci_l_sc, ci_u_sc, ...
                %     b_time, p_time, aic1, aic2, aic3, daic2, daic3, "OK" ...
                % };
            % catch ME
            %     status_msg = "Skipped: " + string(ME.message);
            %     rq2_chan_rows(end+1, 1:25) = { ...
            %         string(primary_baseline), string(task_str), ...
            %         string(Track1_Channel_Long_Table.Timescale(meta_idx)), ...
            %         Track1_Channel_Long_Table.Timescale_Num(meta_idx), ...
            %         string(chrom_str), chan_num, ...
            %         Track1_Channel_Long_Table.Source(meta_idx), ...
            %         Track1_Channel_Long_Table.Detector(meta_idx), ...
            %         string(Track1_Channel_Long_Table.ROI(meta_idx)), height(sub_tbl), ...
            %         NaN, NaN, NaN, NaN, NaN, NaN, NaN, ...
            %         NaN, NaN, NaN, NaN, NaN, NaN, NaN, status_msg ...
            %     };
            %     rq2_chan_full_rows(end+1, 1:21) = [base_meta_ch, { ...
            %         "Unestimated", "N/A", NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, status_msg ...
            %     }];
%             end
%         end
%     end
% end

% if isempty(rq2_chan_rows)
%     Table_RQ2_Channels = cell2table(cell(0, length(chan_col_names_rq2)), 'VariableNames', chan_col_names_rq2);
% else
%     Table_RQ2_Channels = cell2table(rq2_chan_rows, 'VariableNames', chan_col_names_rq2);
% end
% fprintf('Track 1 RQ2 Channels complete: %d channel models evaluated.\n', height(Table_RQ2_Channels));

% (9B) Track 2: ROI-Level Models for RQ2
% fprintf('Evaluating Track 2: Precision-weighted ML ROI models across %d ROIs, %d tasks, and %d chromophores...\n', ...
%     length(rois), length(rq2_tasks), length(chroms));

% for c = 1:length(chroms)
%     chrom_str = chroms{c};
% 
%     for r = 1:length(rois)
%         roi_str = rois{r};
% 
        % for t = 1:length(rq2_tasks)
        %     task_str = rq2_tasks{t};

            % sub_idx = Track2_ROI_Long_Table.Baseline_Type == primary_baseline & ...
            %           Track2_ROI_Long_Table.Chromophore == chrom_str & ...
            %           Track2_ROI_Long_Table.ROI == roi_str & ...
            %           Track2_ROI_Long_Table.Task_Contrast == task_str;
            
            % meta_idx = find(sub_idx, 1, 'first');
            % if isempty(meta_idx), continue; end
            % 
            % sub_tbl = Track2_ROI_Long_Table(sub_idx, :);
            % req_vars = {'Beta_ROI', 'SE_ROI', 'SC_Centered', 'Certainty_Centered', 'Time_Centered', ...
            %             'Age_Centered', 'Gender_Dummy', 'Second_Dest_Dummy', 'Session_ID'};
            % sub_tbl  = sub_tbl(:, intersect(req_vars, sub_tbl.Properties.VariableNames));
            % sub_tbl  = rmmissing(sub_tbl);
            
            % base_meta = { ...
            %     string(primary_baseline), string(task_str), ...
            %     string(Track2_ROI_Long_Table.Timescale(meta_idx)), ...
            %     string(chrom_str), string(roi_str), height(sub_tbl) ...
            % };
            
            % try
            %     if height(sub_tbl) == 0
            %         error('No valid observations remaining after rmmissing.');
            %     end
            %     if numel(unique(sub_tbl.SC_Centered)) < 3
            %         error('Fewer than 3 unique SC_Centered values.');
            %     end
            % 
            %     raw_w = 1 ./ max(sub_tbl.SE_ROI .^ 2, 1e-6);
            %     w_vec = raw_w / mean(raw_w);
                
                % sub_tbl.Gender_Dummy      = removecats(categorical(sub_tbl.Gender_Dummy));
                % sub_tbl.Second_Dest_Dummy = removecats(categorical(sub_tbl.Second_Dest_Dummy));
                % sub_tbl.Session_ID        = removecats(categorical(sub_tbl.Session_ID));
                
                % has_second = numel(categories(sub_tbl.Second_Dest_Dummy)) > 1;
                % if has_second
                %     f1 = 'Beta_ROI ~ 1 + SC_Centered + Time_Centered + Age_Centered + Gender_Dummy + Second_Dest_Dummy + (1 | Session_ID)';
                %     f2 = 'Beta_ROI ~ 1 + Certainty_Centered + Time_Centered + Age_Centered + Gender_Dummy + Second_Dest_Dummy + (1 | Session_ID)';
                %     f3 = 'Beta_ROI ~ 1 + SC_Centered + Certainty_Centered + Time_Centered + Age_Centered + Gender_Dummy + Second_Dest_Dummy + (1 | Session_ID)';
                % else
                %     f1 = 'Beta_ROI ~ 1 + SC_Centered + Time_Centered + Age_Centered + Gender_Dummy + (1 | Session_ID)';
                %     f2 = 'Beta_ROI ~ 1 + Certainty_Centered + Time_Centered + Age_Centered + Gender_Dummy + (1 | Session_ID)';
                %     f3 = 'Beta_ROI ~ 1 + SC_Centered + Certainty_Centered + Time_Centered + Age_Centered + Gender_Dummy + (1 | Session_ID)';
                % end
                % 
                % lme1 = fitlme(sub_tbl, f1, 'Weights', w_vec, 'FitMethod', 'ML');
                % lme2 = fitlme(sub_tbl, f2, 'Weights', w_vec, 'FitMethod', 'ML');
                % lme3 = fitlme(sub_tbl, f3, 'Weights', w_vec, 'FitMethod', 'ML');
                
                % sc_idx = find(strcmp(lme1.CoefficientNames, 'SC_Centered'));
                % if isempty(sc_idx)
                %     error('SC_Centered dropped due to collinearity.');
                % end
                
                % b_sc    = lme1.Coefficients.Estimate(sc_idx);
                % se_sc   = lme1.Coefficients.SE(sc_idx);
                % t_sc    = lme1.Coefficients.tStat(sc_idx);
                % p_sc    = lme1.Coefficients.pValue(sc_idx);
                % df_sc   = lme1.Coefficients.DF(sc_idx);
                % ci_sc   = lme1.coefCI;
                % ci_l_sc = ci_sc(sc_idx, 1);
                % ci_u_sc = ci_sc(sc_idx, 2);
                
                % time_idx = find(strcmp(lme1.CoefficientNames, 'Time_Centered'));
                % if ~isempty(time_idx)
                %     b_time = lme1.Coefficients.Estimate(time_idx);
                %     p_time = lme1.Coefficients.pValue(time_idx);
                % else
                %     b_time = nan; p_time = nan;
                % end
                
                % aic1  = lme1.ModelCriterion.AIC;
                % aic2  = lme2.ModelCriterion.AIC;
                % aic3  = lme3.ModelCriterion.AIC;
                % daic2 = aic2 - aic1;
                % daic3 = aic3 - aic1;
                
                % rq2_roi_full_rows = extract_lme_full_terms(lme1, base_meta, rq2_roi_full_rows, "OK");
                % rq2_roi_rows(end+1, 1:22) = { ...
                %     string(primary_baseline), string(task_str), ...
                %     string(Track2_ROI_Long_Table.Timescale(meta_idx)), ...
                %     Track2_ROI_Long_Table.Timescale_Num(meta_idx), ...
                %     string(chrom_str), string(roi_str), height(sub_tbl), ...
                %     b_sc, se_sc, t_sc, df_sc, p_sc, ci_l_sc, ci_u_sc, ...
                %     b_time, p_time, aic1, aic2, aic3, daic2, daic3, "OK" ...
                % };
            % catch ME
            %     status_msg = "Skipped: " + string(ME.message);
            %     rq2_roi_rows(end+1, 1:22) = { ...
            %         string(primary_baseline), string(task_str), ...
            %         string(Track2_ROI_Long_Table.Timescale(meta_idx)), ...
            %         Track2_ROI_Long_Table.Timescale_Num(meta_idx), ...
            %         string(chrom_str), string(roi_str), height(sub_tbl), ...
            %         NaN, NaN, NaN, NaN, NaN, NaN, NaN, ...
            %         NaN, NaN, NaN, NaN, NaN, NaN, NaN, status_msg ...
            %     };
            %     rq2_roi_full_rows(end+1, 1:18) = [base_meta, { ...
            %         "Unestimated", "N/A", NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, status_msg ...
            %     }];
%             end
%         end
%     end
% end

% if isempty(rq2_roi_rows)
%     Table_RQ2_ROI = cell2table(cell(0, length(roi_col_names_rq2)), 'VariableNames', roi_col_names_rq2);
% else
%     Table_RQ2_ROI = cell2table(rq2_roi_rows, 'VariableNames', roi_col_names_rq2);
% end
% fprintf('Track 2 RQ2 ROI complete: %d models evaluated.\n', height(Table_RQ2_ROI));

%% -------------------------------------------------------------------------
%% 9C. Multiple Comparisons Correction (FDR q < .05)
%% -------------------------------------------------------------------------
% Track 2 ROIs: FDR per chromophore family (m = 28)
% Table_RQ2_ROI.P_FDR_SC = nan(height(Table_RQ2_ROI), 1);

% if ~isempty(Table_RQ2_ROI)
    % for c = 1:length(chroms)
        % c_idx = Table_RQ2_ROI.Chromophore == string(chroms{c});
        % p_raw = Table_RQ2_ROI.P_Val_SC(c_idx);
        % if ~isempty(p_raw)
        %     [p_sorted, sort_order] = sort(p_raw, 'ascend');
        %     m = length(p_raw);
        %     q_sorted = p_sorted .* (m ./ (1:m)');
        %     for k = m-1:-1:1, q_sorted(k) = min(q_sorted(k), q_sorted(k+1)); end
        %     q_sorted = min(q_sorted, 1);
        %     q_adj = zeros(size(p_raw));
        %     q_adj(sort_order) = q_sorted;
        %     Table_RQ2_ROI.P_FDR_SC(c_idx) = q_adj;
        % end
%     end
% end

% Track 1 Channels: Option B Topographic FDR per task x chromophore (m <= 41)
% Table_RQ2_Channels.P_FDR_SC = nan(height(Table_RQ2_Channels), 1);
% tasks_ch = categories(categorical(Table_RQ2_Channels.Task_Contrast));

% if ~isempty(Table_RQ2_Channels)
    % for c = 1:length(chroms)
        % c_str = string(chroms{c});
        % for t = 1:length(tasks_ch)
            % t_str = tasks_ch{t};
            % slice_idx = Table_RQ2_Channels.Chromophore == c_str & ...
            %             Table_RQ2_Channels.Task_Contrast == t_str;
            % p_raw = Table_RQ2_Channels.P_Val_SC(slice_idx);
            % if ~isempty(p_raw)
            %     [p_sorted, sort_order] = sort(p_raw, 'ascend');
            %     m = length(p_raw);
            %     q_sorted = p_sorted .* (m ./ (1:m)');
            %     for k = m-1:-1:1, q_sorted(k) = min(q_sorted(k), q_sorted(k+1)); end
            %     q_sorted = min(q_sorted, 1);
            %     q_adj = zeros(size(p_raw));
            %     q_adj(sort_order) = q_sorted;
            %     Table_RQ2_Channels.P_FDR_SC(slice_idx) = q_adj;
            % end
        % end
    % end
% end

%% -------------------------------------------------------------------------
%% 9D. Format Publication Tables (Standardization, N-Counts, Brodmann Areas)
%% -------------------------------------------------------------------------
% 1. Channel Publication Table
% n_ch_m = height(Table_RQ2_Channels);
% ch_b_std = nan(n_ch_m, 1);
% ch_ci_l = nan(n_ch_m, 1);
% ch_ci_u = nan(n_ch_m, 1);
% ch_n_d = nan(n_ch_m, 1);
% ch_ba = strings(n_ch_m, 1);

% for row = 1:n_ch_m
%     s_task = Table_RQ2_Channels.Task_Contrast(row);
%     s_chrom = Table_RQ2_Channels.Chromophore(row);
%     s_ch = Table_RQ2_Channels.Channel(row);
% 
%     idx = Track1_Channel_Long_Table.Baseline_Type == "TaskMatched" & ...
%           Track1_Channel_Long_Table.Task_Contrast == s_task & ...
%           Track1_Channel_Long_Table.Chromophore == s_chrom & ...
%           Track1_Channel_Long_Table.Channel == s_ch;
% 
%     sub = Track1_Channel_Long_Table(idx, {'Beta', 'SC_Centered', 'Session_ID'});
%     sub = rmmissing(sub);
%     ch_n_d(row) = numel(unique(sub.Session_ID));
% 
%     if height(sub) > 1
%         sx = std(sub.SC_Centered);
%         sy = std(sub.Beta);
%         if sy > 0
%             sc = sx / sy;
%             ch_b_std(row) = Table_RQ2_Channels.Beta_SC(row) * sc;
%             ch_ci_l(row) = Table_RQ2_Channels.CI_Lower_SC(row) * sc;
%             ch_ci_u(row) = Table_RQ2_Channels.CI_Upper_SC(row) * sc;
%         end
%     end
% 
%     switch string(Table_RQ2_Channels.ROI(row))
%         case "RPFC",    ch_ba(row) = "BA 10 – Rostral Prefrontal Cortex";
%         case "L_DLPFC", ch_ba(row) = "BA 9/46 – Left Dorsolateral Prefrontal Cortex";
%         case "R_DLPFC", ch_ba(row) = "BA 9/46 – Right Dorsolateral Prefrontal Cortex";
%         % case "Parietal",ch_ba(row) = "BA 7/40 – Posterior Parietal Cortex";
%         case "L_Parietal", ch_ba(row) = "BA 7/40 – Left Posterior Parietal Cortex";
%         case "R_Parietal", ch_ba(row) = "BA 7/40 – Right Posterior Parietal Cortex";
%         otherwise,      ch_ba(row) = string(Table_RQ2_Channels.ROI(row));
%     end
% end

% Table_RQ2_Channels_Pub = table( ...
%     Table_RQ2_Channels.Task_Contrast, ...
%     Table_RQ2_Channels.Chromophore, ...
%     Table_RQ2_Channels.Channel, ...
%     Table_RQ2_Channels.N_Obs, ...
%     % ch_n_d, ...
%     Table_RQ2_Channels.Beta_SC, ...
%     % ch_b_std, ch_ci_l, ch_ci_u, ...
%     Table_RQ2_Channels.T_Stat_SC, ...
%     Table_RQ2_Channels.DF_SC, ...
%     Table_RQ2_Channels.P_Val_SC, ...
%     Table_RQ2_Channels.P_FDR_SC, ...
%     Table_RQ2_Channels.Delta_AIC_M2_M1, ...
%     Table_RQ2_Channels.Delta_AIC_M3_M1, ...
%     % ch_ba, ...
%     'VariableNames', { ...
%         'Condition_Contrast', 'Chromophore', 'Channel', 'N_Participants', 'N_Dyads', ...
%         'Beta_SC_Raw', 'Beta_SC_Std', 'CI_Std_Lower', 'CI_Std_Upper', 't_SC', 'df', ...
%         'p_SC', 'p_FDR_SC', 'Delta_AIC_Unsigned', 'Delta_AIC_Dual', 'Brodmann_Area' ...
%     } ...
% );

% % 2. ROI Publication Table
% n_roi_m = height(Table_RQ2_ROI);
% roi_b_std = nan(n_roi_m, 1);
% roi_ci_l = nan(n_roi_m, 1);
% roi_ci_u = nan(n_roi_m, 1);
% roi_n_d = nan(n_roi_m, 1);
% roi_ba = strings(n_roi_m, 1);

% for row = 1:n_roi_m
%     s_task = Table_RQ2_ROI.Task_Contrast(row);
%     s_chrom = Table_RQ2_ROI.Chromophore(row);
%     s_roi = Table_RQ2_ROI.ROI(row);
% 
%     idx = Track2_ROI_Long_Table.Baseline_Type == "TaskMatched" & ...
%           Track2_ROI_Long_Table.Task_Contrast == s_task & ...
%           Track2_ROI_Long_Table.Chromophore == s_chrom & ...
%           Track2_ROI_Long_Table.ROI == s_roi;
% 
%     sub = Track2_ROI_Long_Table(idx, {'Beta_ROI', 'SC_Centered', 'Session_ID'});
%     sub = rmmissing(sub);
%     roi_n_d(row) = numel(unique(sub.Session_ID));
% 
%     if height(sub) > 1
%         sx = std(sub.SC_Centered);
%         sy = std(sub.Beta_ROI);
%         if sy > 0
%             sc = sx / sy;
%             roi_b_std(row) = Table_RQ2_ROI.Beta_SC(row) * sc;
%             roi_ci_l(row) = Table_RQ2_ROI.CI_Lower_SC(row) * sc;
%             roi_ci_u(row) = Table_RQ2_ROI.CI_Upper_SC(row) * sc;
%         end
%     end
% 
%     switch string(s_roi)
%         case "RPFC",    roi_ba(row) = "BA 10 – Rostral Prefrontal Cortex";
%         case "L_DLPFC", roi_ba(row) = "BA 9/46 – Left Dorsolateral Prefrontal Cortex";
%         case "R_DLPFC", roi_ba(row) = "BA 9/46 – Right Dorsolateral Prefrontal Cortex";
%         % case "Parietal",roi_ba(row) = "BA 7/40 – Posterior Parietal Cortex";
%         case "L_Parietal", roi_ba(row) = "BA 7/40 – Left Posterior Parietal Cortex";
%         case "R_Parietal", roi_ba(row) = "BA 7/40 – Right Posterior Parietal Cortex";
%         otherwise,      roi_ba(row) = string(s_roi);
%     end
% end

% Table_RQ2_ROI_Pub = table( ...
%     Table_RQ2_ROI.Task_Contrast, ...
%     Table_RQ2_ROI.Chromophore, ...
%     Table_RQ2_ROI.ROI, ...
%     Table_RQ2_ROI.N_Obs, ...
%     % roi_n_d, ...
%     Table_RQ2_ROI.Beta_SC, ...
%     % roi_b_std, roi_ci_l, roi_ci_u, ...
%     Table_RQ2_ROI.T_Stat_SC, ...
%     Table_RQ2_ROI.DF_SC, ...
%     Table_RQ2_ROI.P_Val_SC, ...
%     Table_RQ2_ROI.P_FDR_SC, ...
%     Table_RQ2_ROI.Delta_AIC_M2_M1, ...
%     Table_RQ2_ROI.Delta_AIC_M3_M1, ...
%     % roi_ba, ...
%     'VariableNames', { ...
%         'Condition_Contrast', 'Chromophore', 'ROI', 'N_Participants', 'N_Dyads', ...
%         'Beta_SC_Raw', 'Beta_SC_Std', 'CI_Std_Lower', 'CI_Std_Upper', 't_SC', 'df', ...
%         'p_SC', 'p_FDR_SC', 'Delta_AIC_Unsigned', 'Delta_AIC_Dual', 'Brodmann_Area' ...
%     } ...
% );

%% -------------------------------------------------------------------------
%% 9E. Export Deliverables & Update RQ_Sig
%% -------------------------------------------------------------------------
% rq2_chan_csv = fullfile(group_out_dir, 'Table_RQ2_Publication_Channels.csv');
% rq2_roi_csv = fullfile(group_out_dir, 'Table_RQ2_Publication_ROI.csv');
% rq2_mat = fullfile(group_out_dir, 'GroupLevel_RQ2_Models.mat');

% writetable(Table_RQ2_Channels_Pub, rq2_chan_csv);
% writetable(Table_RQ2_ROI_Pub, rq2_roi_csv);
% save(rq2_mat, 'Table_RQ2_Channels', 'Table_RQ2_ROI', 'Table_RQ2_Channels_Pub', 'Table_RQ2_ROI_Pub');

% In Section G (Step 9E):
% if isempty(rq2_chan_full_rows)
%     Table_RQ2_Channels_FullTerms = cell2table(cell(0, length(full_chan_cols)), 'VariableNames', full_chan_cols);
% else
%     Table_RQ2_Channels_FullTerms = cell2table(rq2_chan_full_rows, 'VariableNames', full_chan_cols);
% end
% writetable(Table_RQ2_Channels_FullTerms, fullfile(group_out_dir, 'Table_RQ2_FullModel_Covariates_Channels.csv'));

% if isempty(rq2_roi_full_rows)
%     Table_RQ2_ROI_FullTerms = cell2table(cell(0, length(full_roi_cols)), 'VariableNames', full_roi_cols);
% else
%     Table_RQ2_ROI_FullTerms = cell2table(rq2_roi_full_rows, 'VariableNames', full_roi_cols);
% end
% writetable(Table_RQ2_ROI_FullTerms, fullfile(group_out_dir, 'Table_RQ2_FullModel_Covariates_ROI.csv'));

% sig_out_dir = fullfile(group_out_dir, 'RQ_Sig');
% if ~exist(sig_out_dir, 'dir'), mkdir(sig_out_dir); end

% sig_chan_rq2 = Table_RQ2_Channels_Pub(Table_RQ2_Channels_Pub.p_SC < 0.05, :);
% sig_chan_rq2 = sortrows(sig_chan_rq2, {'Condition_Contrast', 'Chromophore', 'p_SC'}, {'ascend', 'ascend', 'ascend'});
% 
% sig_roi_rq2 = Table_RQ2_ROI_Pub(Table_RQ2_ROI_Pub.p_SC < 0.05, :);
% sig_roi_rq2 = sortrows(sig_roi_rq2, {'Condition_Contrast', 'Chromophore', 'p_SC'}, {'ascend', 'ascend', 'ascend'});

% sig_chan_csv_rq2 = fullfile(sig_out_dir, 'Table_RQ2_Significant_Channels.csv');
% sig_roi_csv_rq2 = fullfile(sig_out_dir, 'Table_RQ2_Significant_ROI.csv');
% writetable(sig_chan_rq2, sig_chan_csv_rq2);
% writetable(sig_roi_rq2, sig_roi_csv_rq2);

% fprintf('\nSection G complete. Saved RQ2 deliverables to:\n');
% fprintf('  -> Master Channels: %s\n', rq2_chan_csv);
% fprintf('  -> Master ROIs:     %s\n', rq2_roi_csv);
% fprintf('  -> Sig Channels:    %s (%d rows)\n', sig_chan_csv_rq2, height(sig_chan_rq2));
% fprintf('  -> Sig ROIs:        %s (%d rows)\n', sig_roi_csv_rq2, height(sig_roi_rq2));

% %% -------------------------------------------------------------------------
% %% 9F. Summary Displays
% %% -------------------------------------------------------------------------
% fprintf('\n========================================================================================\n');
% fprintf('TABLE: ROI-BASED COMPARISONS OF SIGNED CERTAINTY (p < .05)\n');
% fprintf('========================================================================================\n');
% if isempty(sig_roi_rq2)
%     disp('No ROI certainty effects reached uncorrected p < .05.');
% else
%     disp(sig_roi_rq2(:, {'Condition_Contrast', 'Chromophore', 'ROI', 'N_Participants', 'N_Dyads', ...
%                          'Beta_SC_Std', 't_SC', 'p_SC', 'p_FDR_SC', 'Delta_AIC_Unsigned', 'Brodmann_Area'}));
% end
% 
% fprintf('\n========================================================================================\n');
% fprintf('TABLE: CHANNEL-BASED COMPARISONS OF SIGNED CERTAINTY (p < .05)\n');
% fprintf('========================================================================================\n');
% if isempty(sig_chan_rq2)
%     disp('No channel certainty effects reached uncorrected p < .05.');
% else
%     disp(sig_chan_rq2(1:min(15, height(sig_chan_rq2)), ...
%         {'Condition_Contrast', 'Chromophore', 'Channel', 'N_Participants', 'N_Dyads', ...
%          'Beta_SC_Std', 't_SC', 'p_SC', 'p_FDR_SC', 'Delta_AIC_Unsigned', 'Brodmann_Area'}));
% end



















% Quote from Methods
% "Smaller effects are therefore reported with confidence 
% intervals and interpreted as imprecise rather than absent." 

% AI Summary Quote
% "For Second-Level Modeling: The models for RQ1 and RQ2 will need
% dyad-level clustering (random intercepts for DyadID in an LMM) to 
% handle the 27 paired and 4 single teammates without violating independence."

% Time (elapsed execution time at final status report; included in individual performance models for RQ2)
% Random Effects:
% Random intercept for dyad ((1 | session_id)) across all models
% Random intercept for participant nested within dyad ((1 | session_id/bids_id)) for RQ3



% %% =========================================================================
% %  LOCAL HELPER: Extract Full Covariate & Random-Effect Variance Breakdown
% % =========================================================================
% function rows = extract_lme_full_terms(lme, base_meta, rows, status_str)
%     if nargin < 4
%         status_str = "OK";
%     end
%     coef_tbl = lme.Coefficients;
%     ci = lme.coefCI;
% 
%     % 1. Fixed Effects (Intercept, Primary Predictor, & All Covariates)
%     for k = 1:height(coef_tbl)
%         t_val  = coef_tbl.tStat(k);
%         df_val = coef_tbl.DF(k);
%         np2    = (t_val^2) / (t_val^2 + df_val); % Partial eta-squared
% 
%         rows(end+1, :) = [base_meta, { ...
%             "Fixed", ...
%             string(coef_tbl.Name{k}), ...
%             coef_tbl.Estimate(k), ...
%             coef_tbl.SE(k), ...
%             t_val, ...
%             df_val, ...
%             coef_tbl.pValue(k), ...
%             ci(k, 1), ...
%             ci(k, 2), ...
%             np2, ...
%             NaN, ...
%             status_str ...
%         }];
%     end
% 
%     % 2. Random Effect Variance Component: (1 | Session_ID)
%     [psi, mse] = covarianceParameters(lme);
%     var_dyad   = psi{1}(1, 1);
%     icc_val    = var_dyad / (var_dyad + mse);
% 
%     rows(end+1, :) = [base_meta, { ...
%         "Random", ...
%         "Session_ID (Intercept)", ...
%         NaN, NaN, NaN, NaN, NaN, NaN, NaN, ...
%         var_dyad, ...
%         icc_val, ...
%         status_str ...
%     }];
% end
