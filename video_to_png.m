%% 视频逐帧导出为 PNG（调用 ffmpeg 加速版）
%  用法：修改下面 videoFile 和 outputFolder，直接运行即可

clear; clc;

%% ===== 配置区（改成你自己的路径）=====
videoFile ="E:\Galaxy_SDK\pic\Capture_20261110_161306_722648\Capture_000.avi";
outputFolder = fullfile(char(fileparts(videoFile)), 'frames');
ffmpegExe = 'E:\ffmpeg\ffmpeg.exe';
% =====================================

if ~exist(outputFolder, 'dir')
    mkdir(outputFolder);
end

% 先获取视频帧数（用于显示进度）
v = VideoReader(videoFile);
totalFrames = floor(v.Duration * v.FrameRate);
fprintf('视频总帧数: %d，开始抽帧...\n', totalFrames);

% 构造 ffmpeg 命令：无损逐帧导出灰度 PNG（单通道，文件更小）
% 注意：ffmpeg 5.1+ 用 -fps_mode 代替旧的 -vsync
cmd = sprintf('"%s" -y -i "%s" -fps_mode passthrough -pix_fmt gray "%s\\frame_%%05d.png"', ...
    ffmpegExe, videoFile, outputFolder);

fprintf('执行: %s\n', cmd);
[status, cmdout] = system(cmd);

if status == 0
    files = dir(fullfile(outputFolder, 'frame_*.png'));
    fprintf('完成！共导出 %d 张 PNG，保存在: %s\n', length(files), outputFolder);
else
    fprintf('出错:\n%s\n', cmdout);
end

close all;
if status == 0
%% =========================================
img = imread(fullfile(outputFolder, 'frame_00001.png'));

% 显示图片
% 不使用 drawrectangle
% ==========================================
figure('Name','ROI选择(统一尺寸)','NumberTitle','off');

image(img);
axis image;
axis on;

title({
    '依次选择4个ROI（大小一致）'
    'ROI 1：点击两个点 左上角 -> 右下角（用于确定统一尺寸）'
    'ROI 2~4：只点击一个点（作为该ROI的左上角）'
    });

hold on;

%% =========================================
% ROI数量
% ==========================================
Snum = 4;

% ROI格式：
% [top down left right]
ROI = zeros(Snum,4);

imgHeight = size(img,1);
imgWidth  = size(img,2);

% 统一尺寸（由 ROI 1 确定）
roiW = 0;   % 宽度 = right - left
roiH = 0;   % 高度 = down  - top

%% =========================================
% 依次选择4个ROI
% ==========================================
for j = 1:Snum

    fprintf('\n============================\n');
    if j == 1
        fprintf('正在选择 ROI 1（基准尺寸）\n');
        fprintf('请先点击左上角，再点击右下角\n');
    else
        fprintf('正在选择 ROI %d\n', j);
        fprintf('请点击该 ROI 的左上角（将使用与 ROI 1 相同的尺寸 %dx%d）\n', roiW, roiH);
    end
    fprintf('============================\n');

    if j == 1
        % -------------------------------------
        % ROI 1：点两个点，确定位置 + 尺寸
        % -------------------------------------
        [x, y] = ginput(2);

        left  = round(min(x));
        right = round(max(x));
        top   = round(min(y));
        down  = round(max(y));

        % 边界截断
        left  = max(1, left);
        right = min(imgWidth, right);
        top   = max(1, top);
        down  = min(imgHeight, down);

        % 记录统一宽高
        roiW = right - left;
        roiH = down  - top;
    else
        % -------------------------------------
        % ROI 2~4：只点一个点（左上角）
        % 宽高沿用 ROI 1
        % -------------------------------------
        [x, y] = ginput(1);

        left = round(x);
        top  = round(y);
        right = left + roiW;
        down  = top  + roiH;

        % 边界截断：若超出图片右/下边界，则整体向左/上平移以保持尺寸不变
        if right > imgWidth
            left  = imgWidth - roiW;
            right = imgWidth;
        end
        if down > imgHeight
            top  = imgHeight - roiH;
            down = imgHeight;
        end
        if left < 1
            left  = 1;
            right = left + roiW;
        end
        if top < 1
            top  = 1;
            down = top + roiH;
        end
    end

    % -------------------------------------
    % 保存ROI  [top, down, left, right]
    % -------------------------------------
    ROI(j,:) = [top, down, left, right];

    % -------------------------------------
    % 画矩形
    % -------------------------------------
    rectangle( ...
        'Position', [left, top, right-left, down-top], ...
        'EdgeColor','r', ...
        'LineWidth',2 ...
    );

    % ROI编号
    text( ...
        left, ...
        top-5, ...
        sprintf('ROI %d',j), ...
        'Color','yellow', ...
        'FontSize',12, ...
        'FontWeight','bold' ...
    );

    fprintf('ROI %d 完成：\n', j);
    fprintf('Left  = %d\n', left);
    fprintf('Right = %d\n', right);
    fprintf('Top   = %d\n', top);
    fprintf('Down  = %d\n', down);
    fprintf('Size  = %d x %d\n', right-left, down-top);

end

%% =========================================
% 最终结果
% ==========================================
disp(' ');
disp('最终4个ROI（大小一致）：');
disp('      Top     Down     Left    Right');
disp(ROI);
fprintf('\n统一尺寸：宽 = %d px，高 = %d px\n', roiW, roiH);

%% =========================================
% 保存ROI
% ==========================================
save('ROI_selected_273.mat','ROI');

fprintf('\n============================\n');
fprintf('ROI选择完成！\n');
fprintf('已保存');
fprintf('============================\n');

end
