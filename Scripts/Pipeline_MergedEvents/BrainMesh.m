%% =========================================================================
%  BrainMesh.m
%  Created with Gemini 
%  Renders 3-angle cortical mesh figures (Front, Left, Right) with t-statistics
%  projected onto Colin27 for Significant Channels and ROIs.
%  =========================================================================
clc;

% Define paths
project_root = 'D:\GitHub\Mars_fNIRS';
sig_dir      = fullfile(project_root, 'Output', 'Pipeline_MergedEvents', 'GroupLevel', 'RQ_Sig');
fig_dir      = fullfile(project_root, 'Output', 'Pipeline_MergedEvents', 'Cortical_Plots');
if ~exist(fig_dir, 'dir'), mkdir(fig_dir); end

% Load Master Atlas Table with MNI coordinates
atlas_file = fullfile(project_root, 'Output', 'Pipeline_MergedEvents', 'GroupLevel', 'Master_Atlas_Key.mat');
% if ~exist(atlas_file, 'file')
%     atlas_file = fullfile(project_root, 'Output', 'GroupLevel', 'Master_Atlas_Key.mat');
% end
load(atlas_file, 'Master_Atlas_Table');

% The 4 Significant Deliverable Tables
sig_files = { ...
    'Table_RQ1_Significant_Channels.csv', ...
    'Table_RQ1_Significant_ROI.csv', ...
    'Table_RQ2_Significant_Channels.csv', ...
    'Table_RQ2_Significant_ROI.csv'  ...
};

%% Load Canonical Cortical Mesh
% 1. Ensure SPM12 is on path for gifti and canonical surfaces
if isempty(which('gifti'))
    addpath('D:\GitHub\spm12');
end

% 2. Locate canonical cortical surface
surf_file = which('cortex_20484.surf.gii');
if isempty(surf_file)
    surf_file = 'D:\GitHub\spm12\canonical\cortex_20484.surf.gii';
end

if ~exist(surf_file, 'file')
    error('Canonical mesh not found at: %s. Verify SPM12 path.', surf_file);
end

% 3. Extract mesh geometry
g = gifti(surf_file);
faces = g.faces;
nodes = g.vertices; % 20484 x 3 MNI coordinates

%% Loop through each significant table and plot top effects
for f = 1:length(sig_files)
    tbl_path = fullfile(sig_dir, sig_files{f});
    if ~exist(tbl_path, 'file')
        fprintf('File not found, skipping: %s\n', sig_files{f});
        continue;
    end
    
    tbl = readtable(tbl_path);
    if isempty(tbl) || height(tbl) == 0
        fprintf('Table is empty: %s\n', sig_files{f});
        continue;
    end
    
    [~, base_name, ~] = fileparts(sig_files{f});
    fprintf('\n--- Generating Meshes for: %s (%d rows) ---\n', base_name, height(tbl));
    
    % Group by Task Contrast and Chromophore to render dedicated brain maps
    if ismember('Condition_Contrast', tbl.Properties.VariableNames)
        task_col = 'Condition_Contrast';
    else
        task_col = 'Task_Contrast';
    end
    
    tasks  = unique(tbl.(task_col));
    chroms = unique(tbl.Chromophore);
    
    for t_idx = 1:length(tasks)
        cur_task = tasks{t_idx};
        
        for c_idx = 1:length(chroms)
            cur_chrom = chroms{c_idx};
            
            % Filter slice
            sub_tbl = tbl(strcmp(tbl.(task_col), cur_task) & strcmp(tbl.Chromophore, cur_chrom), :);
            if isempty(sub_tbl) || height(sub_tbl) == 0, continue; end
            
            % Map t-statistics and coordinates
            if contains(base_name, 'Channels')
                % Channel-Level: exact channel coordinates
                ch_nums = sub_tbl.Channel;
                if ismember('t', sub_tbl.Properties.VariableNames)
                    t_vals = sub_tbl.t;
                else
                    t_vals = sub_tbl.t_SC;
                end
                
                [~, loc] = ismember(ch_nums, Master_Atlas_Table.Channel);
                mni_pts = [Master_Atlas_Table.MNI_X(loc), Master_Atlas_Table.MNI_Y(loc), Master_Atlas_Table.MNI_Z(loc)];
            else
                % ROI-Level: project ROI mean t to all channels belonging to that ROI
                roi_names = sub_tbl.ROI;
                if ismember('t', sub_tbl.Properties.VariableNames)
                    roi_t = sub_tbl.t;
                else
                    roi_t = sub_tbl.t_SC;
                end
                
                mni_pts = [];
                t_vals  = [];
                for r = 1:length(roi_names)
                    matching_ch = strcmp(string(Master_Atlas_Table.ROI), string(roi_names{r}));
                    pts = [Master_Atlas_Table.MNI_X(matching_ch), Master_Atlas_Table.MNI_Y(matching_ch), Master_Atlas_Table.MNI_Z(matching_ch)];
                    mni_pts = [mni_pts; pts];
                    t_vals  = [t_vals; repmat(roi_t(r), size(pts, 1), 1)];
                end
            end
            
            % Interpolate t-values onto the cortical surface nodes (spherical kernel ~25mm)
            surface_t = zeros(size(nodes, 1), 1);
            weights   = zeros(size(nodes, 1), 1);
            radius    = 25; % mm
            
            for p = 1:size(mni_pts, 1)
                dist = sqrt(sum((nodes - mni_pts(p, :)).^2, 2));
                in_range = dist <= radius;
                w = (1 - dist(in_range) / radius);
                surface_t(in_range) = surface_t(in_range) + t_vals(p) .* w;
                weights(in_range)   = weights(in_range) + w;
            end
            
            has_w = weights > 0;
            surface_t(has_w) = surface_t(has_w) ./ weights(has_w);
            surface_t(~has_w) = NaN;
            
            %% Create 3-Panel Figure: Front, Left, Right
            fig = figure('Name', sprintf('%s_%s_%s', base_name, cur_task, cur_chrom), ...
                         'Position', [100, 100, 1500, 480], 'Color', 'w', 'Visible', 'off');
                     
            max_t = max(abs(t_vals));
            if max_t == 0 || isnan(max_t), max_t = 3; end
            c_limits = [-max_t, max_t];
            
            % OLD:
            % views = [ ...
            %       0,  0;   % This looks at Posterior / Occipital!
            %     -90,  0;   
            %      90,  0    
            % ];
            
            % NEW (Correct MNI orientations):
            views = [ ...
                180,  0;   % Anterior (Front / Frontal Pole)
                -90,  0;   % Left Lateral Hemisphere
                 90,  0    % Right Lateral Hemisphere
            ];
            view_titles = {'Anterior (Front)', 'Left Hemisphere', 'Right Hemisphere'};
            
            for v = 1:3
                subplot(1, 3, v);
                cla;
                hold on;
                
                % 1. Base Anatomical Brain (Neutral Gray Underlay)
                patch('Faces', faces, 'Vertices', nodes, ...
                      'FaceColor', [0.82, 0.82, 0.84], ...
                      'EdgeColor', 'none', ...
                      'FaceAlpha', 1.0, ...
                      'SpecularStrength', 0.1, ...
                      'DiffuseStrength', 0.7, ...
                      'AmbientStrength', 0.4);
                
                % 2. Statistical Overlay (Projected t-statistics)
                % Displace vertices 0.3 mm outward along coordinates to prevent z-fighting
                centroid = mean(nodes, 1);
                outward_dir = nodes - centroid;
                nodes_overlay = nodes + 0.003 * outward_dir;
                
                p_patch = patch('Faces', faces, 'Vertices', nodes_overlay, ...
                                'FaceVertexCData', surface_t, ...
                                'FaceColor', 'interp', ...
                                'EdgeColor', 'none', ...
                                'FaceAlpha', 1.0);
                            
                % 3. Optode markers (High-contrast anchors)
                scatter3(mni_pts(:,1), mni_pts(:,2), mni_pts(:,3), ...
                         45, 'k', 'filled', 'MarkerEdgeColor', 'w', 'LineWidth', 1.2);

                % 4. Lighting, Shading, and Perspective
                lighting gouraud;
                camlight('headlight');
                material dull;
                axis equal off;
                view(views(v, 1), views(v, 2));
                camup([0, 0, 1]); % Lock dorsal / superior to the top of the plot
                title(view_titles{v}, 'FontSize', 12, 'FontWeight', 'bold');
                clim(c_limits);
                colormap(jet(256));
            end
            
            % Add unified Colorbar
            cb = colorbar('Position', [0.92, 0.2, 0.015, 0.6]);
            cb.Label.String = 'LME t-statistic';
            cb.Label.FontSize = 11;
            cb.Label.FontWeight = 'bold';
            
            % Title banner
            sgtitle(sprintf('%s | Task: %s | Signal: %s', strrep(base_name, '_', ' '), cur_task, cur_chrom), ...
                'FontSize', 14, 'FontWeight', 'bold', 'Interpreter', 'none');
            
            % Export high-res figure
            out_filename = sprintf('Mesh_%s_%s_%s.png', base_name, cur_task, cur_chrom);
            exportgraphics(fig, fullfile(fig_dir, out_filename), 'Resolution', 300);
            close(fig);
            fprintf('  -> Saved: %s\n', out_filename);
        end
    end
end

fprintf('\nAll cortical mesh visualizations generated in: %s\n', fig_dir);