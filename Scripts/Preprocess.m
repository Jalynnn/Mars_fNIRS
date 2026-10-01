% Preprocess.m
% Jalynn Nicoly September 29th, 2026
% This is script 1/4 to load and clean the fNIRS data
% Load; Digitize; BLL; Bandpass; Check Quality; Export as .fif? Save
% variables too; Motion artifact corrects (TDDR?); Short separation
% channels
% Input: Raw .nirs data; digitization .txt files;
% Output: Cleaned time series .mat? .fif?; File of excluded bad channels;
% Signal to noise ratio values for quality diagnostics

