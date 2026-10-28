% After the montage was applied to participants 
% Organized by source/detector/fiducials and labels/coords
% I wanted to fact check the SSCs to ensure they were correctly identified
% And they were, but I'm providing the output here and code for future
% reference

% This did allow me to uncover an error as raw(1) is currently 14.2 :) 
% I just would prefer it to be initituive for debugging so this is fixed in
% preprocess.m

% Output: 
% --- Channel Verification for 2025-11-02-P14.2 ---
% Total Channels: 49 (Expected: 49)
% Short Channels: 8 (Expected: 8)
% Long Channels:  41 (Expected: 41)
% 
% Identified Short-Separation Channels:
%     Source    Detector    Distance_mm
%     ______    ________    ___________
% 
%        4         16         7.9023   
%        6         17         7.8019   
%        7         18         8.1624   
%        8         19         8.3915   
%       11         20         8.4423   
%       13         21         9.0234   
%       14         22         7.7978   
%       15         23         7.7995   

% Verify short vs. long separation channels for Participant 1
link = raw(1).probe.link;
dist = raw(1).probe.distances; % Distance in mm for each measurement row

% Collapse across wavelengths to inspect physical S-D pairs
[unique_pairs, ia] = unique(link(:, 1:2), 'rows', 'stable');
pair_distances = dist(ia);

% Threshold: NIRSport2 short-separation bundles are ~8 mm (< 15 mm)
short_mask = pair_distances < 15;
long_mask  = ~short_mask;

num_short = sum(short_mask);
num_long  = sum(long_mask);

fprintf('--- Channel Verification for %s ---\n', raw(1).demographics('Subject'));
fprintf('Total Channels: %d (Expected: 49)\n', length(pair_distances));
fprintf('Short Channels: %d (Expected: 8)\n', num_short);
fprintf('Long Channels:  %d (Expected: 41)\n\n', num_long);

% Display the identified short channels and their exact separation distances
short_table = table(unique_pairs.source(short_mask), ...
                    unique_pairs.detector(short_mask), ...
                    pair_distances(short_mask), ...
                    'VariableNames', {'Source', 'Detector', 'Distance_mm'});
disp('Identified Short-Separation Channels:');
disp(short_table);

% Check beyond just one participant: 

% Output:
% Success: All 72 participants have exactly 8 short-separation channels (<15 mm).

% Check cohort consistency across all participants
cohort_short_counts = zeros(length(raw), 1);

for i = 1:length(raw)
    % Extract indices of unique physical pairs (ia = first occurrence index)
    [~, ia] = unique(raw(i).probe.link(:, 1:2), 'rows', 'stable');
    pair_dist = raw(i).probe.distances(ia);
    cohort_short_counts(i) = sum(pair_dist < 15);
end

% Report results
if all(cohort_short_counts == 8)
    fprintf('Success: All %d participants have exactly 8 short-separation channels (<15 mm).\n', length(raw));
else
    mismatches = find(cohort_short_counts ~= 8);
    for m = mismatches(:)'
        fprintf('Check Subject %s: found %d short channels (expected 8)\n', ...
            raw(m).demographics('Subject'), cohort_short_counts(m));
    end
end
