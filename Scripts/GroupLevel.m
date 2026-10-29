% GroupLevel.m
% Jalynn Nicoly September 29th, 2026
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
