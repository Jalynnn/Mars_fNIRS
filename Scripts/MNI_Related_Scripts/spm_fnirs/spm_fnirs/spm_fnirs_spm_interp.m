function [SPM] = spm_fnirs_spm_interp(SPM)
% Interpolate GLM parameters over surfaces of rendered brain 
% FORMAT [SPM] = spm_fnirs_spm_interp(SPM) 
%
% SPM       GLM parameters for measurements of fNIRS channels 
%
%--------------------------------------------------------------------------
% In this code, 
% interpolated GLM parameters are saved as *.mat files, 
% whose names are saved in fields of SPM structure: 
%
% Vbeta.mat         Interpolated betas 
% VResMS.mat      Interpolated variance scaled by tr(RV)
% VRpv.mat          Resels per voxel 
% mask.mat           Mask for interpolated data 
%
% SPM.Vbeta         Filehandle - Beta 
% SPM.VResMS      Filehandle - ResMS 
% SPM.xVol.VRpv  Filehandle - Rpv (resels per voxel) 
% SPM.VM             Filehandle - mask 
%__________________________________________________________________________
% Copyright (C) 2015 Wellcome Trust Centre for Neuroimaging

%
% $Id$

fprintf('--------------------------------------------------------- \n'); 
fprintf('Interpolate GLM parameters over brain surfaces... \n'); 
fprintf('--------------------------------------------------------- \n'); 

%--------------------------------------------------------------------------
% load SPM file 
if ~nargin, 
    [SPM sts] = spm_select(1, '^SPM*.*.\.mat$', 'Select a SPM file for fNIRS');
    if ~sts, SPM = []; return; end
end

if ischar(SPM), load(SPM); end

%--------------------------------------------------------------------------
% load GLM parameters for measurements of fNIRS channels 
fprintf('Load channel-wise parameters... \n'); 

beta = SPM.beta;
ResSS = SPM.ResSS; 
res = SPM.res;
ns = SPM.nscan;
erdf = spm_SpUtil('trRV',SPM.xX.xKXs);  % error df

nSres = min(ns, spm_get_defaults('stats.maxres'));
indx_res = round(linspace(1, ns, nSres))';
res = res(indx_res, :);

% load channel positions
load(SPM.xY.VY, 'P');
load(P.fname.pos); clear P;

mask = SPM.xM; 
ch_nroi = find(mask == 0 | mask == -1); 
xy = R.ch.xy; 
for i = 1:6, xy{i}(:, ch_nroi) = 0; end 

% identify voxels to be interpolated
[xy_i] = spm_fnirs_xy_interp(xy, R.rend);

fprintf('Completed. \n\n'); 

%--------------------------------------------------------------------------
% interpolate GLM parameters over surfaces of rendered brain

fprintf('Interpolate parameters & estimate smoothness... \n'); 
% initialize parameters
nviews = 6;
Vbeta = cell(1, nviews);
VResMS = cell(1, nviews); 
VResI = cell(1, nviews); % standardised residual values
VM = cell(1, nviews); % mask
s = cell(1, nviews);

imethod = 'natural'; % interpolation method

FWHM = cell(1, nviews); % estimated FWHM
VRpv = cell(1, nviews); % resels per voxel
Rc = cell(1, nviews); % vector of resel counts

% interpolate parameters over each view of brain surface (eg, dorsal view) 
for i = 1:nviews
    if ~isempty(xy_i{i})
        indx = find(sum(xy{i}) ~= 0);
        xy_c = xy{i}(:, indx); 
        
        indx_c = R.ch.label(indx);
        
        s{i} = size(R.rend{i}.ren);
        nc = size(beta, 1); % number of contrasts
        nvox = s{i}(1) * s{i}(2);
        
        nch_v = size(xy_c, 2); % number of channels on a view of brain
        nvox_i = size(xy_i, 2); % number of interpolated voxels 
        
        % estimate interpolation matrix 
        emtx = eye(nch_v); 
        kern = zeros(nch_v, nvox); 
        for j = 1:nch_v 
            F = scatteredInterpolant(xy_c', emtx(:,j), imethod, 'none'); 
            kern(j, sub2ind(s{i}, xy_i{i}(1,:), xy_i{i}(2,:))) = F(xy_i{i}'); 
        end 
        indx_nan = find(isnan(kern) == 1); kern(indx_nan) = 0; 
        
        % compute interpolated beta 
        Vbeta{i} = zeros(nc, nvox); 
        Vbeta{i} = beta(:, indx_c) * kern; 
        
        % get mask 
        mask = zeros(s{i}); 
        indx_m = find(Vbeta{i}(1,:) ~= 0); 
        mask(indx_m) = 1; 
        VM{i} = mask;
        S{i} = nnz(mask); % number of non-zero elements
        
        % compute interpolated residual SSQ 
        [y x] = meshgrid(indx_c, indx_c); 
        indx_s = sub2ind(size(ResSS), x, y); 
        iResSS = zeros(s{i}); 
        VResMS{i} = zeros(s{i});
        
        iResSS(indx_m) = diag(kern(:, indx_m)' * ResSS(indx_s) * kern(:, indx_m)); 
        VResMS{i} = iResSS./ SPM.xX.trRV; 
        
        % interpolate standardised residuals
        VResI{i} = NaN(nSres, nvox);
        for j = 1:nSres
            iRes = reshape(res(j, indx_c) * kern, s{i}); 
            VResI{i}(j,indx_m) = iRes(indx_m)./sqrt(iResSS(indx_m)/erdf); 
        end 
        
        % estimate smoothness based on residual images 
        [FWHM{i}, VRpv{i}, Rc{i}] = spm_fnirs_est_smoothness(VResI{i}, VM{i}, [ns erdf]);
    end
end

fprintf('Completed. \n\n'); 
%--------------------------------------------------------------------------
% save estimated (interpolated) parameters
SPM.Vbeta = fullfile(SPM.swd, 'Vbeta');
save(SPM.Vbeta, 'Vbeta', spm_get_defaults('mat.format'));

SPM.VResMS = fullfile(SPM.swd, 'VResMS');
save(SPM.VResMS, 'VResMS', spm_get_defaults('mat.format'));

SPM.xVol.VRpv = fullfile(SPM.swd, 'VRpv');
save(SPM.xVol.VRpv, 'VRpv', spm_get_defaults('mat.format'));

SPM.VM = fullfile(SPM.swd, 'mask');
save(SPM.VM, 'VM', spm_get_defaults('mat.format'));

SPM.xVol.FWHM = FWHM; % Smoothness data
SPM.xVol.R = Rc; % Resel counts
SPM.xVol.S = S; % non-zero voxels

fprintf('Save SPM.mat... \n');
save(fullfile(SPM.swd, 'SPM.mat'), 'SPM', spm_get_defaults('mat.format'));
fprintf('Completed. \n\n');

fprintf('--------------------------------------------------------- \n'); 
fprintf('%-40s: %30s\n','Completed.',spm('time')); 
fprintf('--------------------------------------------------------- \n'); 

