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

% Quote from Methods
% "The activation signal for each of the channels over the session was 
% then fit to an individual design matrix for each participant, using 
% custom scripts calling the estimation functions from NIRS-ToolBox 
% (Ye et al., 2009)."

% Label blocks vs. events for the events
% "In the first-level script (FirstLevel_GLM.m), you will configure how each condition key is modeled:
% Blocks: Convolved with canonical HRF (nirs.design.basis.Canonical()).
% Events: Convolved with canonical HRF plus its temporal derivative (nirs.design.basis.CanonicalWithDeriv()).
% Short Channels: Added as nuisance regressors (AddShortPhysRegressors /
% AddShortSepRegressors)." AI Summary
