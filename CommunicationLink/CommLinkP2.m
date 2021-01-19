% Ivan Chowdhury, Hanoch Goldfarb
% ECE-300: Communication Theory
% Professor Keene
% Fall 2018
% Designing and Simulating a Communication Link - Part 1

clear all;close all;clc     % Reset workspace

%% Set Simulation Parameters

numIter = 5;  % The number of iterations of the simulation.
nSym = 1000;    % Constraint: Max 1000 symbols per packet

SNR_Vec = 0:2:16;   % Vector that stores the Signal-to-Noise Ratios
lenSNR = length(SNR_Vec);   % Length of SNR Vector
BER_Vec = zeros(numIter, lenSNR);   % Vector that stores the BER computed during each iteration

%% Set BER/Bitrate Experimental Parameters

% Modulation order
% M = 4;      % 4-QAM
M = 16;     % 16-QAM
% M = 32;     % 32-QAM

% Number of equalizer training symbols
% trainlen = 200;
trainlen = 100;
% trainlen = 50;

% Set Equalizer step size
% step = 0.01;      % 4-QAM
step = 0.001;    % 16-QAM

% Results:
% Optimized system: 16 QAM, 100 training symbols, 2.5778 bitrate 
%% Set Communication System Parameters

k = log2(M);    

% Reed-Solomon Parameters
N = 15;  % Codeword length
L = 10;  % Message length
S = 39;  % Shortened message length
cRate = L/N; % Code rate

% Set channel
chan = [1 .2 .4]; % Somewhat invertible channel impulse response, Moderate ISI

%% Create objects
% Equalizer
Equalizer = dfe(5,3,lms(step));    % Decision Feedback / LMS - Best performing equalizer
% Equalizer = lineareq(6,rls(0.99,0.1));  % Linear/RLS - Good performance
% Equalizer = lineareq(8, lms(0.01));   % Linear/LMS - Worst performance, but also meets specifications

% Configure Equalizer
Equalizer.SigConst = qammod(((0:M-1)'),M)'; % Set ideal signal constellation.
Equalizer.ResetBeforeFiltering = 0; % Resets equalizer before use

% Reed-Solomon Encoder and Decoder
rsEncoder = comm.RSEncoder(N,L,'BitInput',true);
rsDecoder = comm.RSDecoder(N,L,'BitInput',true);

%% Run simulation (numIter times)

for i = 1:numIter
    
    bits = randi(2,[nSym*k, 1])-1;  % Generate random binary data for each iteration

    for j = 1:lenSNR % Perform one iteration of the simulation at each SNR Value
        
        encMsg = rsEncoder(bits);                  % RS encode
 
        tx = qammod(encMsg,M,'InputType','bit');    % Modulate signal
        
        % Draw and apply channel
        if isequal(chan,1)
            txChan = tx;
        elseif isa(chan,'channel.rayleigh')
            reset(chan) % Draw a different channel each iteration
            txChan = filter(chan,tx);
        else
            txChan = filter(chan,1,tx);  % Apply the channel to transmitted signal. 
        end

        % Convert EbNo to SNR. Add and scale noise to channel
        txNoisy = awgn(txChan,10*log10(k)+SNR_Vec(j),'measured');     
        
        % Apply Equalizer
        txEq = equalize(Equalizer,txNoisy,tx(1:trainlen)); 

        % Demodulate signal
        rx = qamdemod(txEq,M,'OutputType','bit');

        % RS Decode
        rxDec = rsDecoder(rx);  % Received bits
        
        [zzz BER_Vec(i,j)] = biterr(bits, rxDec);  % Compute and store the BER for this iteration
        
    end  % End SNR iteration
end      % End numIter iteration

%% Compute & plot data

% Compute and plot the mean BER
ber = mean(BER_Vec,1);

figure;
semilogy(SNR_Vec, ber)

% Compute and plot the theoretical BER without error-correction code
berTheory = berawgn(SNR_Vec,'qam',M); % QAM

hold on
semilogy(SNR_Vec,berTheory,'r')

xlabel('SNR')
ylabel('Bit Error Rate (dB)')
legend('Actual BER (Post-ECC)', 'Theoretical BER (No ECC)')
title('Bit Error Rate w/ Error-Correcting Code')
hold off

% Compute the Bit Rate (bits per symbol)
% Bit Rate = (# of source bits) / (# of symbols at output of modulator)
bitRate = (length(bits) - (trainlen * k * cRate))/length(tx);
%% Compute and plot the signal constellation
constellation = scatterplot(txNoisy,1,trainlen,'bx');    % Noisy signal constellation

hold on;
scatterplot(txEq,1,trainlen,'g.',constellation);    % Equalized signal constellation
scatterplot(Equalizer.SigConst,1,0,'k*',constellation); % Ideal signal constellation
title('M-Ary QAM Signal Constellation');
legend('Noisy signal','Equalized signal',...
   'Ideal signal');
hold off;

%% Report Parameters
M           % Modulation Order
trainlen    % Number of training Symbols used
bitRate     % Bit Rate