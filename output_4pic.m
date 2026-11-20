%无chu前后50，图片显示



clear;clc;
close all;

%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ROI区域定义
% 
% ROI_left(1) = 264;
% ROI_right(1) =286;
% ROI_top(1) = 178;
% ROI_down(1) = 196;
% % 
% ROI_left(2) = 296;
% ROI_right(2) = 312;
% ROI_top(2) = 180;
% ROI_down(2) = 197;
% %  
% ROI_left(3) = 243;
% ROI_right(3) = 259;
% ROI_top(3) = 256;
% ROI_down(3) = 276;
% % a
% ROI_left(4) = 314;
% ROI_right(4) = 332;
% ROI_top(4) = 256;
% ROI_down(4) = 276;
% 
% 
% % ROI_left(5) = 1231;
% % ROI_right(5) = 1250;
% % ROI_top(5) = 506;
% % ROI_down(5) = 525;
% 
% % ROI_left(6) = 1441;
% % ROI_right(6) = 1460;
% % ROI_top(6) = 719;
% % ROI_down(6) = 738;
% 
% % ROI_left(7) = 1383;
% % ROI_right(7) = 1402;
% % ROI_top(7) = 221;
% % ROI_down(7) = 240;
% 
% % ROI_left(8) = 1319;
% % ROI_right(8) = 1338;
% % ROI_top(8) = 505;
% % ROI_down(8) = 524;
% 
% ROI = [ROI_top' ROI_down' ROI_left' ROI_right'];
% 
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ROI区域定义（从MAT文件读取）

% ROI文件路径
ROI_file = 'ROI_selected_384.mat';

% 读取MAT文件
ROI_data = load(ROI_file);

% 查看MAT文件中的变量
disp('ROI文件中包含的变量：');
disp(fieldnames(ROI_data));

% 读取ROI坐标
ROI = ROI_data.ROI;

% 自动确定ROI数量
Snum = size(ROI, 1);
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 图片检索

% PNG图片文件夹


% folder = 'E:\Galaxy_SDK\pic\Capture_20261110_184205_906732\frames';%23
% folder = 'E:\Galaxy_SDK\pic\Capture_20261110_184015_084097\frames';%21
% folder = 'E:\Galaxy_SDK\pic\Capture_20261110_183851_404092\frames';%21
% folder = 'E:\Galaxy_SDK\pic\Capture_20261110_183600_750289\frames';%19
% folder = 'E:\Galaxy_SDK\pic\Capture_20261110_183443_038393\frames';%19
% folder = 'E:\Galaxy_SDK\pic\Capture_20261110_183319_369073\frames';%17
% folder = 'E:\Galaxy_SDK\pic\Capture_20261110_183145_879901\frames';%17
% folder = 'E:\Galaxy_SDK\pic\Capture_20261110_182946_350234\frames';%15

% folder = 'E:\Galaxy_SDK\pic_guangyuan\Capture_20261117_182300_776930\frames';%换光源
% folder = 'E:\Galaxy_SDK\pic_guangyuan\Capture_20261117_182444_129268\frames';%换光源
% folder = 'E:\Galaxy_SDK\20_24\Capture_20261117_184246_586020\frames';%main24
% folder = 'E:\Galaxy_SDK\20_24\Capture_20261117_184457_582107\frames';%main24
% folder = 'E:\Galaxy_SDK\20_25\Capture_20261117_184659_116349\frames';%main25-
% folder = 'E:\Galaxy_SDK\20_25\Capture_20261117_184839_743996\frames';%main25-
% folder = 'E:\Galaxy_SDK\20_26\Capture_20261117_185054_765881\frames';%main26-
% folder = 'E:\Galaxy_SDK\20_26\Capture_20261117_185246_558894\frames';%main26-
% folder = 'E:\Galaxy_SDK\20_27\Capture_20261117_185630_829429\frames';%main27
% folder = 'E:\Galaxy_SDK\23_23\Capture_20261117_182735_152989\frames';%time23
% folder = 'E:\Galaxy_SDK\23_23\Capture_20261117_182939_466745\frames';%time23+
% folder = 'E:\Galaxy_SDK\25_23\Capture_20261117_183204_853634\frames';%time25-
% folder = 'E:\Galaxy_SDK\25_23\Capture_20261117_183350_399098\frames';%time25-
% folder = 'E:\Galaxy_SDK\27_23\Capture_20261117_183611_090254\frames';%time27-
% folder = 'E:\Galaxy_SDK\27_23\Capture_20261117_183819_790559\frames';%time27
% folder = 'E:\Galaxy_SDK\29_23\Capture_20261117_184037_176956\frames';%time29

% folder = 'E:\Galaxy_SDK\pic_19\f24_24\Capture_20261119_182312_638878\frames';%2424*
% folder = 'E:\Galaxy_SDK\pic_19\f24_25\Capture_20261119_182129_352085\frames';%2425*
% folder = 'E:\Galaxy_SDK\pic_19\f24_26\Capture_20261119_182447_598869\frames';%2426
% folder = 'E:\Galaxy_SDK\pic_19\f26_24\Capture_20261119_183816_459054\frames';%2624
% folder = 'E:\Galaxy_SDK\pic_19\f26_25\Capture_20261119_182834_836025\frames';%2625
% folder = 'E:\Galaxy_SDK\pic_19\f26_26\Capture_20261119_182654_907202\frames';%2626+
% folder = 'E:\Galaxy_SDK\pic_19\f26_26\Capture_20261119_182958_511325\frames';%2626*
% folder = 'E:\Galaxy_SDK\pic_19\f28_24\Capture_20261119_184116_001398\frames';%2824
% folder = 'E:\Galaxy_SDK\pic_19\f28_25\Capture_20261119_183951_305183\frames';%2825-
% folder = 'E:\Galaxy_SDK\pic_19\f28_26\Capture_20261119_183635_412385\frames';%2826-

% folder = 'E:\Galaxy_SDK\pic_19_y\f24_24\Capture_20261119_184511_137544\frames';%2424
% folder = 'E:\Galaxy_SDK\pic_19_y\f24_25\Capture_20261119_184641_036118\frames';%2425
% folder = 'E:\Galaxy_SDK\pic_19_y\f26_24\Capture_20261119_184932_836077\frames';%2624
% folder = 'E:\Galaxy_SDK\pic_19_y\f26_25\Capture_20261119_184808_146308\frames';%2625
% folder = 'E:\Galaxy_SDK\pic_19_y\f28_24\Capture_20261119_185107_821538\frames';%2824+
folder = 'E:\Galaxy_SDK\pic_19_y\f28_25\Capture_20261119_185231_839384\frames';%2825


% 检索全部PNG图片
fileList = dir(fullfile(folder, '*.png'));

if isempty(fileList)
    error('未找到PNG图片，请检查文件夹路径');
end

% 按文件名顺序排序
[~, idx] = sort({fileList.name});
fileList = fileList(idx);

% 自动获取图片数量
frameNum = length(fileList);

% 初始化ROI灰度均值数组
Tn_ROImean = zeros(frameNum, 1);

% Tn_ROImean_R = zeros(frameNum, 1);
% Tn_ROImean_B = zeros(frameNum, 1);

% Snum = 4;


%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 逐帧读取图片并提取ROI平均灰度

for p = 1:frameNum

    i = p - 0;

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % 当前PNG图片完整路径
    fullName = fullfile(folder, fileList(p).name);

    % 显示当前读取的图片文件
    disp(fullName);

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    filename = fullName;

    % 读取PNG图片
    frame = imread(filename);

    for j = 1:Snum

        % 提取ROI区域第一个通道
        temp = frame( ...
            ROI(j,1):ROI(j,2), ...
            ROI(j,3):ROI(j,4), ...
            1);

        % 计算ROI区域平均灰度值
        Tn_ROImean(i,j) = mean(double(temp(:)));

        % 提取ROI局部图片
        ROI_img = frame( ...
            ROI(j,1):ROI(j,2), ...
            ROI(j,3):ROI(j,4), ...
            :);

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % ROI图片显示
        % 与原文件保持一致
        % 需要显示时取消前面的%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % % 
        % figure(1);imshow(ROI_img);
        % 
        % frame(ROI(j,1)-2:ROI(j,2)+2, ...
        %       ROI(j,3)-2:ROI(j,4)+2,:) = 0;
        % 
        % frame(ROI(j,1)-2:ROI(j,2)+2, ...
        %       ROI(j,3)-2:ROI(j,4)+2,1) = 255;
        % 
        % frame(ROI(j,1):ROI(j,2), ...
        %       ROI(j,3):ROI(j,4),:) = ROI_img;
        % 
        % figure(1);imshow(frame);

    end

    % imwrite(frame,'ROI.png');

end


%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 保存ROI平均灰度数据

Tn_ROImean_4 = Tn_ROImean;

save Tn_ROImean_4 Tn_ROImean_4;

clc;clear;close all;

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% load Tn_ROImean_1 Tn_ROImean_1;
% Tn_ROImean = Tn_ROImean_1;
% Fs = 50;           
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% load Tn_ROImean_2 Tn_ROImean_2;
% Tn_ROImean = Tn_ROImean_2;
% Fs = 33;           
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% load Tn_ROImean_3 Tn_ROImean_3;
% Tn_ROImean = Tn_ROImean_3;
% Fs = 33;           
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
load Tn_ROImean_4 Tn_ROImean_4;
Tn_ROImean = Tn_ROImean_4;
% Tn_ROImean = Tn_ROImean_4(500:1500,:);
Fs = 30;          
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
TnAll = Tn_ROImean(:,:);

Tn_DC0 = zeros(size(TnAll));
TnBpass_real = zeros(size(TnAll));
Fabs = zeros(size(TnAll));



Wp = [0.1 4];     %%%[0, Fs/2]
sigma = 0.00001;
fnum = size(TnAll,1); 

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