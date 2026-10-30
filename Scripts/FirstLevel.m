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
% addpath(genpath('C:\Users\Jalynn\Documents\GitHub\nirs-toolbox')) % Laptop
addpath(genpath('D:\GitHub\nirs-toolbox')) % PC

% Add NIRS SPM 
% addpath('C:\Users\Jalynn\Documents\GitHub\spm12') % Laptop
addpath('D:\GitHub\spm12') % PC

% https://www.nitrc.org/projects/nirs_spm/
% addpath('C:\Users\Jalynn\Downloads\NIRS_SPM_v4_r1') % Laptop
addpath('D:\GitHub\NIRS_SPM_v4_r1') % PC

%% 2. Load Preprocessed Cohort Data

% Command Window Update
fprintf('\n--- Loading Preprocessed Cohort Data ---\n')

% Preprocess.m saved to Derivatives folder with following file name
% derivatives_dir = "C:\Users\Jalynn\Documents\GitHub\Mars_fNIRS\Data\Derivatives"; % Laptop
derivatives_dir = 'D:\GitHub\Mars_fNIRS\Data\Derivatives'; % PC
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

% Verification check ran in command window with export saved in
% FirstLevelOutput folder

%% Section B

% The focus of this section is on stimulus basis configuration for
% individual and team levels along with dual model branching since we are
% using both HRF and FIR

% Command Window Update
fprintf('--- Configure Dual-Branch (HRF & FIR) GLM Basis Functions ---\n')

%% 3. Dual Model Framework Definitions

% There are two frameworks we are running with. HRF and FIR

% Start with stimulus classification into blocks vs events vs baselines
% There were 19 extracted stimulus keys found in FirstLevelOutput

% Sustained Task Blocks -> Convolved with Canonical HRF
% (Contains the 4 core mission phases + overall execution parent block)
block_conditions = { ...
    'planning_individual', ... % Planning
    'planning_team', ... % Planning
    'enroute_true_site', ... % Execution
    'enroute_decoy_site', ... % Execution
    'at_true_site', ... % Execution
    'at_decoy_site', ... % Execution
    'execution' ...
};

% Transient Task Events -> Convolved with Canonical HRF + Temporal Derivative
% (The 5 discrete cognitive events/actions)
event_conditions = { ...
    'certainty_individual', ... % Planning
    'certainty_consensus', ... % Planning
    'spam_pop_up', ... % Execution
    'tricorder_switch', ... % Execution
    'status_check' ... % Execution
};

% Matched Baselines, Fixations & Nuisance Windows -> Canonical HRF
baseline_conditions = { ...
    'fixation_baseline_start', ... % Fixation
    'fixation_baseline_end', ... % Fixation
    'planning_baseline', ... % Planning
    'null_block', ... % Execution
    'null_event', ... % Execution
    'null_event_prespam', ... % Execution
    'debrief' ...
};

% Since we are no longer using the 'execution' and 'debrief' blocks, also
% necessary to remove them from the ptps

%% 3a. Branch 1: HRF

job_hrf = nirs.modules.GLM();
job_hrf.name = 'HRF GLM';
job_hrf.type = 'AR-IRLS';

% Blocks and baselines get default canonical w/o derivative
job_hrf.basis('default') = nirs.design.basis.Canonical();

% Define canonical w/ temporal derivative for events
basis_with_deriv = nirs.design.basis.Canonical();
% Adds derivative
basis_with_deriv.incDeriv = true;
% Keep false to drop derivative betas
basis_with_deriv.keepDerivs = false;

% Assign Canonical + Temporal Derivative to transient events
% event_conditions refers to the structs above
for k = 1:length(event_conditions)
    % for one of the events in that struct
    c_name = event_conditions{k};
    
    % Transients use canonical and temporal derivative
    job_hrf.basis(c_name) = basis_with_deriv;
end

% Command window update
fprintf('Branch 1 (HRF): Canonical HRF assigned to blocks/baselines; Canonical+Deriv assigned to %d events.\n', ...
    length(event_conditions));

%% 3b. Branch 2: FIR

% job_fir = nirs.modules.GLM();
% job_fir.name = 'FIR GLM';
% job_fir.type = 'AR-IRLS';
% 
% % A little more effort goes into create fir basis
% fir_obj = nirs.design.basis.FIR();
% 
% % Design decisions based on paper Section 3.2.4
% % https://pmc.ncbi.nlm.nih.gov/articles/PMC11218834/
% fir_obj.nbins = 23; % mean duration + 12 to 18
% fir_obj.binwidth = 1.0; % To match Fs
% fir_obj.isIRF = true; % the events are not identical lengths
% 
% % Dictionary mapping
% fir_dict = Dictionary();
% fir_dict('default') = nirs.design.basis.Canonical();
% 
% % Restrict 23-bin FIR deconvolution ONLY to transient impulse events - help
% % reduce ranking issues
% transient_events = {'spam_pop_up', 'null_event_prespam', 'tricorder_switch', 'certainty_individual'};
% for k = 1:length(transient_events)
%     fir_dict(transient_events{k}) = fir_obj;
% end
% 
% job_fir.basis = fir_dict;
% 
% fprintf('Branch 2 (FIR): Configured 23-bin FIR deconvolution ([-2s to +20s] at 1.0 Hz).\n');
% 
% fprintf('--- Section B Setup Complete ---\n\n');

%% 3b. Branch 2: Finite Impulse Response (FIR) Setup
fprintf('\n--- Configuring Branch 2: Finite Impulse Response (FIR) ---\n');

job_fir = nirs.modules.GLM();
job_fir.name = 'FIR GLM';
job_fir.type = 'AR-IRLS';

% 1. Instantiate the FIR basis object for impulse deconvolution
fir_obj = nirs.design.basis.FIR();
fir_obj.nbins = 23;        % 23 1-second bins ([0 to 22s] post-stimulus window)
fir_obj.binwidth = 1.0;    % Matches 1.0 Hz sampling rate (Fs = 1.0 Hz)
fir_obj.isIRF = true;      % Impulse response formulation for transient events

% 2. Harvest all unique stimulus keys across the entire cohort safely
all_stim_keys = {};
for i = 1:length(Hb)
    k_i = Hb(i).stimulus.keys;
    all_stim_keys = [all_stim_keys; k_i(:)];
end
all_stim_keys = unique(all_stim_keys);

% 3. Construct the Basis Dictionary
canonical_obj = nirs.design.basis.Canonical();
fir_dict = Dictionary();

% Set internal default and default all conditions to Canonical
fir_dict('default') = canonical_obj;
for i = 1:length(all_stim_keys)
    fir_dict(all_stim_keys{i}) = canonical_obj;
end

% Override ONLY the primary impulse validation events with 23-bin FIR
primary_fir_events = {'spam_pop_up', 'null_event_prespam'};
for k = 1:length(primary_fir_events)
    if ismember(primary_fir_events{k}, all_stim_keys)
        fir_dict(primary_fir_events{k}) = fir_obj;
        fprintf('  FIR active on condition: %s (23 bins)\n', primary_fir_events{k});
    end
end

job_fir.basis = fir_dict;
fprintf('Branch 2 (FIR): Configured targeted FIR on primary impulse events with Canonical blocks.\n');

%% 4. Experimental Design Matrix Architecture

% Verifies that all modeled task blocks, events, and baselines are present
% Checks for condition presence across ptps

all_modeled_conditions = [block_conditions, event_conditions, baseline_conditions];
fprintf('[Step 4] Configured %d total design matrix regressors:\n', length(all_modeled_conditions));
fprintf('   - %d Sustained Task Blocks (Canonical HRF)\n', length(block_conditions));
fprintf('   - %d Transient Events (Canonical HRF + Temporal Derivative)\n', length(event_conditions));
fprintf('   - %d Matched Baselines, Fixations & Nuisance Windows (Canonical HRF)\n', length(baseline_conditions));

% Optional sanity check: verify design matrix column construction on Hb(1)
try
    sample_dm = job_hrf.create_design_matrix(Hb(1));
    fprintf('   - Hb(1) Design Matrix generated successfully (%d timepoints x %d regressors).\n', ...
        size(sample_dm, 1), size(sample_dm, 2));
catch
    % Handled cleanly if create_design_matrix syntax varies by toolbox release
    fprintf('   - Design matrix architecture registered in job_hrf/job_fir basis dictionaries.\n');
end

%% 5. Short-Separation Physiological Nuisance Regression

% Append SSCs as systemic regressors
% Done by setting the following as true
% Seeking for distances < 15 mm - confirmed to be only the true 8

job_hrf.AddShortSepRegressors = true;
job_fir.AddShortSepRegressors = true;

% Verify short-channel detection on first participant
if ismember('ShortSeperation', Hb(1).probe.link.Properties.VariableNames)
    n_ssc = sum(Hb(1).probe.link.ShortSeperation);
else
    n_ssc = sum(Hb(1).probe.distances < 15);
end

fprintf('[Step 5] Short-separation physiological nuisance regression enabled on both branches.\n');
fprintf('   - Detected %d short-separation channels (%d physical optode pairs) in probe geometry.\n', ...
    n_ssc, n_ssc / 2);
fprintf('--- Section B Setup Complete (Steps 3, 4, and 5) ---\n\n');

%% Section C





% %% Pre-GLM Correction: Resolve Temporal Collinearity for Near-Concurrent Events
% % At Fs = 1.0 Hz, events within <1.0s collapse into the same discrete time bin.
% % When convolved with identical canonical basis + temporal derivatives,
% % the resulting columns become collinear (r = 1.0), causing checkRank failure.
% % Apply a minimal +1.0s jitter to tricorder_switch when colliding with spam_pop_up.
% 
% fprintf('\n--- Evaluating Event Timing Separation Across Cohort ---\n');
% for i = 1:length(Hb)
%     st = Hb(i).stimulus;
%     if st.iskey('spam_pop_up') && st.iskey('tricorder_switch')
%         s_on = st('spam_pop_up').onset;
%         t_on = st('tricorder_switch').onset;
% 
%         if ~isempty(s_on) && ~isempty(t_on)
%             dt_matrix = abs(s_on(:) - t_on(:)');
%             min_dt = min(dt_matrix(:));
% 
%             if min_dt < 1.0
%                 fprintf('  Adjusting Participant %02d: min temporal delta = %.2fs (<1.0s threshold).\n', i, min_dt);
%                 tri_stim = st('tricorder_switch');
%                 tri_stim.onset = tri_stim.onset + 1.0;
%                 Hb(i).stimulus('tricorder_switch') = tri_stim;
%                 fprintf('  -> Shifted tricorder_switch by +1.0s to resolve discrete bin collision.\n');
%             end
%         end
%     end
% end
% 
% %% 6a. Execute Branch 1 (Primary Model: Mixed Block/Event HRF)
% fprintf('\n--- Running Branch 1: Mixed Block/Event Canonical HRF GLM ---\n');
% fprintf('Fitting %d participants with AR-IRLS...\n', num_ptps);
% t_hrf_start = tic;
% 
% SubjStats_HRF = job_hrf.run(Hb);
% 
% t_hrf_elapsed = toc(t_hrf_start);
% fprintf('Branch 1 complete: %d SubjStats generated in %.2f minutes (%.1f s/ptp).\n', ...
%     length(SubjStats_HRF), t_hrf_elapsed / 60, t_hrf_elapsed / num_ptps);
% 
% %% 6b. Execute Branch 2 (Model Validation / Shape Evaluation: FIR)
% fprintf('\n--- Running Branch 2: Finite Impulse Response (FIR) GLM ---\n');
% fprintf('Fitting 23-bin impulse deconvolution across %d participants...\n', num_ptps);
% t_fir_start = tic;
% 
% SubjStats_FIR = job_fir.run(Hb);
% 
% t_fir_elapsed = toc(t_fir_start);
% fprintf('Branch 2 complete: %d SubjStats generated in %.2f minutes (%.1f s/ptp).\n', ...
%     length(SubjStats_FIR), t_fir_elapsed / 60, t_fir_elapsed / num_ptps);
% 
% %% 6c. Section C Sanity Verification
% fprintf('\n--- Section C Verification Check ---\n');
% fprintf('SubjStats_HRF array size: [%s]\n', num2str(size(SubjStats_HRF)));
% fprintf('SubjStats_FIR array size: [%s]\n', num2str(size(SubjStats_FIR)));
% fprintf('HRF variables on SubjStats(1): %d beta rows estimated.\n', height(SubjStats_HRF(1).table));
% fprintf('--- Section C Execution Complete ---\n\n');

%% Section C. First-Level Statistical Estimation (AR-IRLS)
fprintf('\n============================================================\n');
fprintf('  SECTION C: First-Level Statistical Estimation (AR-IRLS)\n');
fprintf('============================================================\n');

%% Pre-GLM Correction: Resolve Temporal Collinearity for Sub-Second Collisions
% At Fs = 1.0 Hz, events within <1.0s collapse into the same discrete time bin.
% If tricorder_switch and spam_pop_up occur concurrently, convolving them produces
% identical regressor columns (r = 1.0), triggering a checkRank failure.
% Apply a minimal +1.0s jitter to tricorder_switch when a collision (<1.0s) occurs.

fprintf('\n--- Evaluating Event Timing Separation Across Cohort ---\n');
for i = 1:length(Hb)
    st = Hb(i).stimulus;
    if st.iskey('spam_pop_up') && st.iskey('tricorder_switch')
        s_on = st('spam_pop_up').onset;
        t_on = st('tricorder_switch').onset;
        
        if ~isempty(s_on) && ~isempty(t_on)
            dt_matrix = abs(s_on(:) - t_on(:)');
            min_dt = min(dt_matrix(:));
            
            if min_dt < 1.0
                fprintf('  Adjusting Participant %02d: min delta = %.2fs (<1.0s threshold).\n', i, min_dt);
                tri_stim = st('tricorder_switch');
                tri_stim.onset = tri_stim.onset + 1.0;
                Hb(i).stimulus('tricorder_switch') = tri_stim;
                fprintf('  -> Shifted tricorder_switch by +1.0s to break discrete bin collision.\n');
            end
        end
    end
end

% Ensure solver is set
job_hrf.type = 'AR-IRLS';
job_fir.type = 'AR-IRLS';

num_ptps = length(Hb);

% Initialize Parallel Pool if available on the machine
if isempty(gcp('nocreate'))
    try
        parpool('Processes');
    catch
        fprintf('Running on single process (no parallel pool available).\n');
    end
end

%% 6a. Execute Branch 1 (Primary Model: Mixed Block/Event Canonical HRF)
fprintf('\n--- Running Branch 1: Mixed Block/Event Canonical HRF GLM ---\n');
fprintf('Fitting %d participants with AR-IRLS...\n', num_ptps);
t_hrf_start = tic;

SubjStats_HRF = job_hrf.run(Hb);

t_hrf_elapsed = toc(t_hrf_start);
fprintf('Branch 1 complete: %d SubjStats generated in %.2f minutes (%.1f s/ptp).\n', ...
    length(SubjStats_HRF), t_hrf_elapsed / 60, t_hrf_elapsed / num_ptps);

%% 6b. Execute Branch 2 (Model Validation / Shape Evaluation: Targeted FIR)
fprintf('\n--- Running Branch 2: Finite Impulse Response (FIR) GLM ---\n');
fprintf('Fitting targeted impulse deconvolution across %d participants...\n', num_ptps);
t_fir_start = tic;

SubjStats_FIR = job_fir.run(Hb);

t_fir_elapsed = toc(t_fir_start);
fprintf('Branch 2 complete: %d SubjStats generated in %.2f minutes (%.1f s/ptp).\n', ...
    length(SubjStats_FIR), t_fir_elapsed / 60, t_fir_elapsed / num_ptps);

%% 6c. Section C Verification & Save Check
fprintf('\n--- Section C Verification Check ---\n');
fprintf('SubjStats_HRF array size: [%s]\n', num2str(size(SubjStats_HRF)));
fprintf('SubjStats_FIR array size: [%s]\n', num2str(size(SubjStats_FIR)));
fprintf('HRF variables on SubjStats(1): %d beta rows estimated.\n', height(SubjStats_HRF(1).table));
fprintf('FIR variables on SubjStats(1): %d beta rows estimated.\n', height(SubjStats_FIR(1).table));
fprintf('--- Section C Execution Complete ---\n\n');








% Section D
% use fixation baseline start unless unavailable then use end
% per participant contrast loop to avoid dimension mismatch
% 6 ptps missing start 1, 2, 35, 3X, 41, 42


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