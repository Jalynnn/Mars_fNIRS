function [y, P] = spm_fnirs_read_artinis(F)
% Read optical density data acquired using Artinis Oxymon MKIII system, and
% convert them to variables compatible with SPM-fNIRS toolbox 
% FORMAT [y,P] = spm_fnirs_read_artinis(F) 
% 
% F - Name of Artinis Oxymon MKIII file (.oxy3) 
%
% y - Optical density changes [# channels x # samples x # waves] 
%
% P - information about raw data structure
%--------------------------------------------------------------------------
% P.wav        light wavelengths
% P.fs            sampling frequency
% P.nch          number of channels
% P.ns            number of samples
% P.mask       mask of measurements 
% P.fname     names of raw files and converted file (NIRS.mat) 
% P.base       baseline period [s] 
%__________________________________________________________________________
% Copyright (C) 2015 Wellcome Trust Centre for Neuroimaging

%
% $Id$

%---------------------------------------------------------
if ~nargin
    [F, sts] = spm_select(1, '^*.*\.oxy3$', 'Select Artinis Oxymon MKIII data files');
    if ~sts, y = []; return; end
end

if iscell(F), F = cell2mat(F); end

[pathstr, name, ext] = fileparts(F); 
%---------------------------------------------------------
% read optical density data (*.oxy3) 
hdr = read_artinis_oxy3(F); 
od = read_artinis_oxy3(F, hdr); 

%---------------------------------------------------------
% convert the data to variables compatible with SPM-fNIRS 
P.nch = size(od, 1) ./ 2; 
P.fs = hdr.Fs; 
P.ns = hdr.nSamples; 
P.mask = ones(1, P.nch); 

indx_w1 = 1:2:(hdr.nChans-1); 
indx_w2 = 2:2:hdr.nChans; 

y = zeros(P.ns, P.nch, 2); 
y(:,:,1) = od(indx_w1,:)'; 
y(:,:,2) = od(indx_w2,:)'; 

P.wav = [mean(hdr.opto.wavelength(indx_w1)) mean(hdr.opto.wavelength(indx_w2))]; 
P.fname.raw.Y{1,1} = F;
P.fname.raw.type = 'Optical Density'; 

% channel configuration (a pair of source and detector) 
ch_sd = []; 
for i = 1:P.nch 
    str = hdr.label{i*2,1}; 
    indx_s = strfind(str, 'Tx'); 
    indx_d = strfind(str, 'Rx'); 
    
    num_s = str2num(str(1, indx_s+2)); 
    num_d = 2.*str2num(str(1, indx_d+2)); 
    if strcmp(str(1, indx_d+3), 'a'), num_d = num_d - 1; end 
    
    ch_sd(i,1) = i; % channel 
    ch_sd(i,2) = num_s; % source 
    ch_sd(i,3) = num_d; % detector 
end

%--------------------------------------------------------------------------
% write channel configuration as text file
% note: this file can be used in spatil preprocessing
% of spm-fnirs toolbox
%--------------------------------------------------------------------------
sfname = fullfile(pathstr, 'ch_config.txt');
fid_w = fopen(sfname, 'w');
fprintf(fid_w, '%s\r\n', 'Ch, Source, Detector');
for i = 1:P.nch, fprintf(fid_w, '%s\r\n', [num2str(ch_sd(i,1)) ', ' num2str(ch_sd(i,2)) ', ' num2str(ch_sd(i,3))]); end
fclose(fid_w);


if nargout == 0
    % save converted data as spm-fnirs format ('NIRS.mat')
    P.fname.nirs = fullfile(pathstr, 'NIRS.mat');
    save(P.fname.nirs, 'y', 'P', spm_get_defaults('mat.format')); 
end 

