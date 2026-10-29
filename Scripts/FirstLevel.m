% FirstLevel.m
% Jalynn Nicoly September 29th, 2026
% This is script 2/4 with a focus on analyzing individuals ptps
% Input: Output from preprocess.m; raw objects; bad channels from
% preprocess.m from saved csv
% Task: Running continuous GLM
% Output: Array of ChannelStats / SubjStats with Beta and HbO/HbR

%% Section A

% The purpose of this section is to setup MATLAB paths in case Preprocess.m
% is not run prior to FirstLevel.m

% Command Window Update
fprintf('--- Starting fNIRS FirstLevel.m ---\n')

% Clear Terminal
clear, clc

% Silence naming conflict warnings
warning('off', 'MATLAB:dispatcher:nameConflict');

%% 1. Set MATLAB Paths

% Add NIRS Toolbox to MATLAB Path
addpath(genpath('C:\Users\Jalynn\Documents\GitHub\nirs-toolbox')) % Laptop

% Add NIRS SPM 
addpath('C:\Users\Jalynn\Documents\GitHub\spm12') % Laptop

% https://www.nitrc.org/projects/nirs_spm/
addpath('C:\Users\Jalynn\Downloads\NIRS_SPM_v4_r1') % Laptop

%% 2. Load Preprocessed Cohort Data

% Command Window Update
fprintf('\n--- Loading Preprocessed Cohort Data ---\n')

% Preprocess.m saved to Derivatives folder with following file name
derivatives_dir = "C:\Users\Jalynn\Documents\GitHub\Mars_fNIRS\Data\Derivatives";
load_file = fullfile(derivatives_dir, "Hb_preprocessed_cohort.mat");

% Error checking if file exists yet
if ~exist(load_file, 'file')
    error('Please run Preprocess.m first.');
end

% Command window update
fprintf('Loading: %s ...\n', load_file);

% Load preprocessed data and QA table
loaded_data = load(load_file, 'Hb', 'qa_table');

% Assign columns to variables
Hb = loaded_data.Hb;
qa_table = loaded_data.qa_table;

% Collect the length of Hb - The num of ptps
num_ptps = length(Hb);

% Command window update
fprintf('Successfully loaded %d participant recordings.\n', num_ptps);



%% Section B

% The focus of this section is on stimulus basis configuration for
% individual and team levels along with dual model branching since we are
% using both HRF and FIR

%% 3. Dual Model Framework Definitions

% epochs 3d matrics - channels x timepoints x trials (?)

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

% REcall that only th ecanonical hrf params carried forward
% AI summary: 
% "While you convolve event regressors with
% nirs.design.basis.CanonicalWithDeriv(), the first-level GLM will produce 
% two $\beta$ weights for each event condition:
% cond_name:canonical
% cond_name:derivative
% When you construct your first-level baseline contrasts (Section D), you 
% must contrast only the :canonical estimates and ignore the :derivative 
% weights so that only the canonical $\beta$ values enter the second-level 
% group models."

% AI Summary: 
% Sorting Stimulus by Block vs. Event (How It Actually Works)
% In NIRS-Toolbox, the toolbox does not automatically know whether a 
% stimulus key in raw.stimulus is a sustained block or a transient event. 
% You must configure the basis model explicitly by condition name:
% %% Section B: Configure Basis Functions (Block vs. Event)
% j_glm = nirs.modules.GLM();
% % Default: Canonical HRF for sustained blocks & baselines
% j_glm.basis('default') = nirs.design.basis.Canonical();
% % Explicitly assign Canonical + Temporal Derivative to transient events:
% transient_events = {
%     'Individual_Survey', ...
%     'Consensus_Survey', ...
%     'Spam_Popup', ...
%     'First_Detector_Switch', ...
%     'First_Status_Report', ...
%     'Planning_Null_Event', ...
%     'Nav_Baseline_Event', ...
%     'Inter_Report_Null_Event'
% };
% for k = 1:length(transient_events)
%     j_glm.basis(transient_events{k}) = nirs.design.basis.CanonicalWithDeriv();
% end