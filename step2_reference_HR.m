clc;clear;close all;

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% load Tn_ROImean_1 Tn_ROImean_1;
% Tn_ROImean = Tn_ROImean_1;
% Fs = 50;           % 采样频率 (Hz)
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% load Tn_ROImean_2 Tn_ROImean_2;
% Tn_ROImean = Tn_ROImean_2;
% Fs = 33;           % 采样频率 (Hz)
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% load Tn_ROImean_3 Tn_ROImean_3;
% Tn_ROImean = Tn_ROImean_3;
% Fs = 33;           % 采样频率 (Hz)
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
load Tn_ROImean_4 Tn_ROImean_4;
Tn_ROImean = Tn_ROImean_4;
% Tn_ROImean = Tn_ROImean_4(500:1500,:);
Fs = 30;           % 采样频率 (Hz)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
TnAll = Tn_ROImean(:,:);

Tn_DC0 = zeros(size(TnAll));
TnBpass_real = zeros(size(TnAll));
Fabs = zeros(size(TnAll));


% 设计参数
Wp = [0.1 4];      % 通带频率范围 (Hz)，归一化到[0, Fs/2]
sigma = 0.00001;
fnum = size(TnAll,1); % 采样帧数

[FILTER,x_f] = func_filter_ideal(Fs,Wp,fnum);

Snum = 4;

for i=1:Snum
    Tn = TnAll(:,i);
% 	Tn_DC0(:,i) = Tn;
	Tn_DC0(:,i) = Tn - mean(Tn);

    F = fft(Tn_DC0(:,i));
    Fshift = fftshift(F);
    Fabs(:,i) = abs(Fshift);
    normF(:,i) = Fabs(:,i)./norm(Fabs(:,i));
    logF(:,i) = log(Fabs(:,i));
    
    FBpass = Fshift.*FILTER';
    FBpass = fftshift(FBpass);
    
    TnH = ifft(FBpass);
    TnBpass_real(:,i) = real(TnH);
end

figure;hold on;
title(' ori wave ');
for i=1:Snum
    subplot(2,2,i);
    plot(TnAll(:,i));
    grid on;
end

figure;hold on;
title(' zero wave ');
for i=1:Snum
    subplot(2,2,i);
    plot(Tn_DC0(:,i));
    grid on;
end

figure;hold on;
title(' freq ');
for i=1:Snum
    subplot(2,2,i);hold on;
    plot(x_f,normF(:,i),'r.-');
    grid on;
end

figure;hold on;
for j=1:Snum
    plot(Tn_ROImean(:,j));
%     plot(Tn_ROImean_R(:,j));
%     plot(Tn_ROImean_B(:,j));
end
grid minor