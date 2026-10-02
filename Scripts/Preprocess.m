% Preprocess.m
% Jalynn Nicoly September 29th, 2026
% This is script 1/4 to load and clean the fNIRS data
% Load; Digitize; BLL; Bandpass; Check Quality; Export as .fif? Save
% variables too; Motion artifact corrects (TDDR?); Short separation
% channels
% Input: Raw .nirs data; digitization .txt files;
% Output: Cleaned time series .mat? .fif?; File of excluded bad channels;
% Signal to noise ratio values for quality diagnostics

% Clear Terminal
clear, clc

% Silence naming conflict warnings
warning('off', 'MATLAB:dispatcher:nameConflict');

%% Set MATLAB Paths

% Add NIRS Toolbox to MATLAB Path
% https://github.com/huppertt/nirs-toolbox.git
addpath(genpath('D:\GitHub\nirs-toolbox'))

% Add NIRS SPM 
% https://github.com/spm/spm12.git
addpath('D:\GitHub\spm12')

% https://www.nitrc.org/projects/nirs_spm/
addpath('D:\GitHub\NIRS_SPM_v4_r1')

%% Load NIRS Files

% Add Data Directory
Directory = 'D:\GitHub\Mars_fNIRS\Data\fNIRS';

% NIRS File for Ptp1:
% filePath = 'D:\GitHub\Mars_fNIRS\Data\fNIRS\2025-10-26-P1\2025-10-26_001.nirs';
% info = whos('-file', filePath);
% disp(table({info.name}', {info.size}', {info.class}', 'VariableNames', {'Name', 'Size', 'Class'}));
    %  Name          Size           Class   
    % _______    _____________    __________
    % 
    % {'SD' }    {[      1 1]}    {'struct'}
    % {'aux'}    {[20960 4 3]}    {'double'}
    % {'d'  }    {[ 20960 98]}    {'double'}
    % {'s'  }    {[ 20960 66]}    {'double'}
    % {'t'  }    {[  20960 1]}    {'double'}
    % Number of time samples: 20960
    % Number of sensors/ports: 4
    % Number of measure axes: 3
    % Number of raw intensities: 98 (49 x 2)
    % Provides Number of Channels: 49
    % Provided by Number of Wavelengths: 2
    % Number of trigger channels: 66
    % Montage metadata: 1 1 struct; source-detector setup

% Search for all .nirs/.snirf files
% Assigns the first subfolder the subj ID
% Raw is an array of nirs.core.Data objects
% 'Subject ID' is added to raw dictionary per folder/subj
raw = nirs.io.loadDirectory(Directory, {'Subject'});

%% Visual of .nirs File

% Uses built-in GUI
% This version simply outputs the 49 channels x 2 wavelengths
% Along with the received LSL stimulus in the legend
raw(1).draw();

% Use the Visualize_Events.m script for the visual with the 
% events provided by the CSV file

%% Extract Events

% Load Events File
event_csv_path = 'D:\GitHub\Mars_fNIRS\Data\Events\spy_events_all_sessions(in).csv';
event_table = readtable(event_csv_path);

% Event data will be grouped by ptp stored in a struct
events_by_ptp = struct();

% Goal is to search through csv and assign events
% to the corresponding ptp in both (1) the struct and 
% (2) in the "raw" variable
% Loop through all participants
for i = 1:length(raw)

    % Subject was assigned when raw was created
    % Subject refers to the name of the folder/the ptp
    subj_id = raw(i).demographics('Subject');

    % Search events_table for only this subj_id
    % Save only the events for this subj
    subj_events = event_table(strcmp(event_table.fnirs_folder, subj_id), :);

    % Confirm there are events
    % if empty end, else continue
    if isempty(subj_events), continue; end

    % Store the subj_events for each subj_id
    % Uses the struct defined above
    % The folder names are not appropraite for matlab conventions
    events_by_ptp.(matlab.lang.makeValidName(['ptp_' subj_id])) = subj_events;

    % While the events are saved in a separate struct...
    % We can assign all of the events to each individual
    % Using their position in raw
    % E.g. Ptp 1 is raw(1)
    fs = 1 / mean(diff(raw(i).time));
    individual_events = unique(subj_events.event);

end

% Load Conditions
% All ptps analyzed under 'Spy' condition

% (For later)
% raw = nirs.util.addDemographics(raw, demo_table);