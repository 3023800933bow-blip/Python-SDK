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
ROI_file = 'ROI_selected_214.mat';

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
folder = 'E:\Galaxy_SDK\pic\Capture_20261104_183200_388214\frames';

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
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % % % 
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
% 绘制四组ROI原始灰度信号

figure;
hold on;

for j = 1:Snum

    plot(Tn_ROImean(:,j));

    % plot(Tn_ROImean_R(:,j));
    % plot(Tn_ROImean_B(:,j));

end

grid minor;


%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 保存ROI平均灰度数据

Tn_ROImean_4 = Tn_ROImean;

save Tn_ROImean_4 Tn_ROImean_4;
