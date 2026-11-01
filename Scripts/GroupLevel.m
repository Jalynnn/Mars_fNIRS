% GroupLevel.m
% Jalynn Nicoly September 29th, 2026
% This is script 3/4 with a focus on linear mixed-effects models
% Input: FirstLevel_Cohort_Stats.mat
% Output: Group-level statistical models; ROI summaries; FDR-correct
% hypothesis table



% This is script 3/4 for general linear-mixed effects model
% GLM analysis across participants - goal is looking at performance
% Moderator performance too; fdr correction; j.job / j.formula here; Hbo
% and Hbr analysis
% Input: all subject level files from singlelevel.m; subj performance
% scores; demogrpahic info; roi mapping
% Output: stats model tables; moderation results; saved group summary files

% Quote from Methods
% Sensitivity analyses estimated the smallest effects detectable with 
% the available sample of 58 participants in 31 dyads (two-sided alpha 
% = .05, 80% power, before FDR correction). Because the degree to which 
% teammates’ responses resemble each other was unknown, estimates were 
% computed across the full range of possible intraclass correlations (0 
% to 1). Because team performance varies only between dyads, RQ1 (18 
% correct vs. 13 decoy dyads) could reliably detect standardized team 
% differences of approximately d = 0.76 to 1.06. For RQ2, the smallest 
% detectable person-level association was approximately r = .36 to .48, 
% equivalent to d = 0.77 to 1.11, so the two RQs have similar sensitivity 
% once expressed on a common scale. Both are sensitive only to large 
% effects. These estimates also assume reliable hemodynamic measures; 
% because event-related betas are estimated from few events per 
% participant, measurement error will further attenuate observed 
% associations. Smaller effects are therefore reported with confidence 
% intervals and interpreted as imprecise rather than absent." 

% AI Summary Quote
% "For Second-Level Modeling: The models for RQ1 and RQ2 will need
% dyad-level clustering (random intercepts for DyadID in an LMM) to 
% handle the 27 paired and 4 single teammates without violating independence."

% Quote from Method
% "HbO and HbR results are reported separately."

% Quote from Method
% "Channel positions were registered to MNI coordinates 
% using digitization for spatial registration and assigned a priori to 
% regions of interest (ROIs): rostral prefrontal cortex (RPFC; BA 10), 
% left and right dorsolateral prefrontal cortex (DLPFC; BA 9/46), and 
% parietal cortex (BA 7/40)."

% Quote from Method
% "Smaller effects are therefore reported with confidence intervals and
% interpreted as imprecise rather than absent."

% 4. Items for GroupLevel.m (Documented in the Text)
% These specifications do not block FirstLevel.m, but are explicitly required for the second-level script:
% 
% ROIs to Define:
% 
% Rostral PFC (RPFC; BA 10)
% 
% Left & Right DLPFC (BA 9/46)
% 
% Parietal Cortex (BA 7/40)
% 
% Covariates to Include in All Group Models:
% 
% Age (mean-centered)
% 
% Sex (dummy-coded: 0 = female, 1 = male)
% 
% Second (binary: 1 = visited a second destination, 0 = did not)
% 
% Time (elapsed execution time at final status report; included in individual performance models for RQ2)
% 
% Random Effects:
% 
% Random intercept for dyad ((1 | session_id)) across all models
% 
% Random intercept for participant nested within dyad ((1 | session_id/bids_id)) for RQ3











Section A

Step 1. Environment setup, paths, and ingestion

- initialize the environment with clear and warnings removed
- include the matlab paths

Step 2. Load .mat file from FirstLevel

- Load .mat file
- Verify participant qualities
- verify ptp demographics are still attached to raw_cleaned and Hb




Section B

Spatial registeration, channel filtering, and ROI definition

Step 3. Defining ROIs

- Identify and isolate 41 long channels
- Exclude the 8 short separation channels
- Define the four ROI components
- map the specific optode pairs to each roi name
- Fact check that all channels are properly categorized and none overlap across ROIs



Section C - Unsure about this section

Step 4. Individual performance metrics computation

- Signed and unsigned certainty
	* the survey scores
	* this is already provided - just use demographics csv

Step 5. Predictor centering and coding

- Mean-center age? Should say in Method doc
- dummy code gender 0 and 1 and 2 ? 
- Dummy code second destination ?
- mean center execution time ? Should say in Method doc
- Team performance dummy code?



Section D

Step 6. Setup two tracks for group-level analysis

- Note firstLevel contrasts were already performed
- Track 1: Channel Level Long Table construction
	* Extract channel-wise contrast betas, SEs, t-stats, and p-val for long channels
	* Separate tables for HbO and HbR
	* Merge with ptp demo, dyad pair ids, and performance metrics
- Track 2: ROI Averaged Table construction
	* Contrast estimates were additionally averaged across channels within an ROI
	* Is said in methods with ROIs
	* Label timescale per condition
		* sustained t = 0; transient t = 1



Section E

Step 7. LME Models

- Method doc mentions ROI contrasts test against zero using intercept-only LME with random intercept
- Use formula model from Method doc
- Run this model for both ROI-averaged and individual channels tracks across all task contrasts
- FIR impulse shape validation
	* "inspect curves to confirm canonical hemodynamic peaking without anticipation"



Section F

Step 8. Team performance RQ1

- RQ1 how do sustained and transients differ based on team decision
- mention formula equation
- Primary tests difference between correct and decoy
- Run across:
	* Track 1 ROI
	* Track 2 Individual channels



Section G

Step 9. Individual performance RQ2

- RQ2 how do sustained and transients differ based on individual performance
- mention formula equation
- Primary test difference between correct and decoy
- Run across:
	* Track 1 ROI
	* Track 2 Individual channels



Section H

Step 10. Cross Timescale RQ3

- RQ3 difference across timescales and levels (team and individual)
- Z-score contrasts betas across ptps 
- Dataset stacking
	* sustained with t = 0 and transient t = 1
- Stack models with nested random effects
- Parameter extraction:
	* Sustained slope = b2
	* Transient slope = b2 + b3
	* Divergence test = b3 interaction term (95% CI)



Section I

Step 11. FDR Correction and Export

- Apply FDR correction across ROIs and contrasts
- Apply FDR correction across individual channels
- Save master results table and model objects to a new folder
  * GroupLevel_Models.mat
  * Table_Validation_ManipulationChecks.csv
  * Table_RQ1_TeamPerformance_ROI.csv
  * Table_RQ1_TeamPerformance_Channels.csv
  * Table_RQ2_IndividualPerformance_ROI.csv
  * Table_RQ2_IndividualPerformance_Channels.csv
  * Table_RQ2_AIC_Heading_Comparison.csv
  * Table_RQ3_CrossTimescale_Stacked.csv
