% SingleLevel.m
% Jalynn Nicoly September 29th, 2026
% This is script 2/4 to create epochs
% Timestamps to break one long file into conditions; save as .fif? save
% variables too; baseline correction; Contrasts 
% Input: Output from preprocess.m; event markers; bad channels from
% preprocess.m
% Output: epochs 3d matrics - channels x timepoints x trials

% Quote from Methods
% "Short-separation channel time-series were included as first-level
% nuisance regressors to additionally control for superficial systemic 
% artifacts."