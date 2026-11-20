%% select_roi_ir_full_auto_safe.m
% 红外图像：全自动检测正面人脸 + 4 个避开眼睛/眉毛的 ROI（不使用神经网络）
%
% 从原版 select_roi_uniform.m 改写，保留：
%   Snum=4；四个 ROI 同宽高；ROI(j,:)=[top down left right]；
%   保存 ROI_selected_731.mat。
%
% 全自动：运行时不出现文件选择框、不调用 input/ginput、不要求鼠标确认。
% 检测顺序：
%   A. 传统 Viola-Jones 级联检测（CART/Haar、LBP），在不同红外增强图上尝试；
%   B. 检测失败时，尝试传统“亮度分割 + 形态学 + 连通域”估计脸部位置。
% 如果仍无法可靠定位，明确报错、不生成虚假的 ROI。
%
% 依赖：
%   A 路径需 Computer Vision Toolbox (vision.CascadeObjectDetector)
%   B 路径需 Image Processing Toolbox (imclose/imfill/regionprops)
%   使用任一路径成功即可；不需要 Deep Learning Toolbox。
%   ROI 纹理避让采用 MATLAB 基础矩阵运算，无需额外工具箱。
%
% 注意：本算法适用于近红外/红外灰度图中“正面、单个人脸、脸部相对
% 背景较亮”的常见拍摄条件。传统模型并非专门在热红外数据上训练，
% 对低对比度、侧脸、遮挡、多人或背景很亮等场景可能失败。
% B 路径是亮度轮廓的几何估计，不等同于经过训练的人脸检测器。
%
% 使用前只需要确认下方 cfg.imagePath 是实际文件路径。
% MATLAB R2016b 或更新版本支持此脚本末尾的本地函数。

clear;
clc;
close all;

%% ====================== 用户配置区 ======================
cfg.imagePath = "E:\Galaxy_SDK\pic\Capture_20261110_184205_906732\Capture_000.avi";

% 不存在上述文件时：true=自动选当前工作目录下按名称排序的第一张图；
% false=报错，防止误处理其他文件。若有多张图像，建议明确填写路径。
cfg.autoFindImageInPwd = false;

% 默认选择最显著的一张正面人脸。
% ROI 编号：1 额头皮肤；2 两眉之间偏下的鼻根/眉心皮肤；
%           3 图像左侧中脸脸颊；4 图像右侧中脸脸颊。
% [u,v] 是在人脸框中的相对中心坐标，不是固定像素。
% 与旧版不同：脸颊下移并向两侧外移，避开眼睛与鼻翼；眉心避开眉毛。
cfg.roiUV_Cascade = [0.50 0.16; ... % ROI 1：额头（避开眉毛）
                     0.50 0.10; ... % ROI 2：眉心/鼻根之间（不压眉毛）
                     0.21 0.69; ... % ROI 3：图像左脸颊，更靠外侧，避开鼻翼
                     0.75 0.65];    % ROI 4：图像右脸颊，更靠外侧，避开鼻翼
cfg.roiUV_Segmentation = [0.50 0.20; ... % 亮度分割脸框的顶部定义略不同
                          0.50 0.42; ...
                          0.21 0.70; ...
                          0.79 0.70];

% 安全搜索范围 [中心u最小 中心u最大 中心v最小 中心v最大]。
% 范围有意保守：脸颊限制在眼睛下方且远离鼻翼的外侧区域；眉心仅在中间搜索。
% 此范围按正面近红外单人人脸设置，不等于精确眼睛/眉毛分割。
cfg.safeCenterBands = [0.47 0.53 0.12 0.23; ... % 额头
                       0.47 0.53 0.37 0.49; ... % 眉心偏下
                       0.18 0.26 0.64 0.78; ... % 图像左脸颊：限制在外侧皮肤区
                       0.74 0.82 0.64 0.78];    % 图像右脸颊：限制在外侧皮肤区

% 在上述区域内自动比较候选皮肤块的亮度、纹理、深色像素，
% 优先选择平滑皮肤，减少误选眉毛、眼睫毛与阴影。
% 仅用传统图像处理，不用神经网络，也不需要人工交互。
cfg.refineByTexture = true;
cfg.searchGridSize = 7; % 每个方向评估 7 个候选中心点

% ROI 大小相对人脸框的比例，所有 ROI 保证一致。
cfg.roiWidthRatio  = 0.09;
cfg.roiHeightRatio = 0.065;

% 可选：固定 ROI 像素宽高（例如 [54 46]）；默认 [] 依人脸尺寸自动设置。
cfg.fixedRoiSize = [];

% 自动保存 MAT 文件、标注预览 PNG 到当前 MATLAB 工作目录。
cfg.saveDir = pwd;
cfg.matName = 'ROI_selected_000.mat';
cfg.previewName = 'ROI_auto_IR_preview.png';
cfg.showFigure = true;  % true=显示结果，但不会等待点击确认

%% ====================== 1. 加载红外图像 ======================
imagePath = cfg.imagePath;
if exist(imagePath, 'file') ~= 2
    if cfg.autoFindImageInPwd
        imagePath = findFirstImage(pwd);
    else
        error('没有找到红外图像：%s\n请在代码开头修改 cfg.imagePath。', imagePath);
    end
end
if exist(cfg.saveDir, 'dir') ~= 7
    error('输出目录不存在：%s', cfg.saveDir);
end
img = imread(imagePath);
[imgHeight, imgWidth, ~] = size(img);
if imgHeight < 100 || imgWidth < 100
    error('图像过小（%d x %d），无法可靠地自动定位人脸。', imgWidth, imgHeight);
end

% 红外图片可能为 uint8、uint16 或 double，也可能是伪彩色。
% 检测只用灰度归一化图；ROI 位置和保存的原图像素坐标不改变。
rawGray = toGrayDouble(img);
img8 = robustToUint8(rawGray);
if double(max(img8(:))) - double(min(img8(:))) < 12
    error('图像几乎无灰度对比度，无法自动检测人脸。');
end

%% ====================== 2. 自动寻找人脸 ======================
faceBox = [];
detectionMethod = '';
detectionInfo = struct('method','','cascadeVotes',0, ...
    'segmentationScore',NaN,'note','');

% 优先使用非神经网络的 Viola-Jones (Haar/CART/LBP) 级联。
if exist('vision.CascadeObjectDetector', 'class') == 8
    [faceBox, nVotes] = detectFaceCascadeIR(img8);
    if ~isempty(faceBox)
        detectionMethod = 'Viola-Jones cascade (Haar/CART/LBP), IR-enhanced';
        detectionInfo.cascadeVotes = nVotes;
    end
else
    warning('未安装 Computer Vision Toolbox，跳过传统级联人脸检测。');
end

% 若传统级联未检出，尝试“亮脸/暗背景”的传统亮度连通域分割。
if isempty(faceBox)
    [faceBox, segScore] = detectFaceFromIRSilhouette(img8);
    if ~isempty(faceBox)
        detectionMethod = 'IR threshold + morphology + connected component (heuristic)';
        detectionInfo.segmentationScore = segScore;
        detectionInfo.note = '启发式轮廓估计，准确性弱于人脸分类器，请核查预览图';
        warning('级联未检测到人脸，改用红外亮度轮廓进行自动估计，请核查 ROI 预览。');
    end
end

if isempty(faceBox)
    error(['自动定位失败：传统级联检测及红外亮度分割均未得到可信人脸。\n' ...
           '为了避免错误 ROI，程序没有写入 MAT 文件。\n' ...
           '请检查人脸正面朝向、背景对比度，或提供原始红外帧以便调整算法。']);
end
faceBox = clipFaceBox(faceBox, imgWidth, imgHeight);
detectionInfo.method = detectionMethod;

%% ====================== 3. 自动生成四个同尺寸 ROI ======================
Snum = 4;
ROI = zeros(Snum, 4);          % 顺序 [top down left right]，与旧版完全一致
roiLabels = {'额头中央'; '眉心(两眉之间)'; '图像左脸颊'; '图像右脸颊'};

if ~isempty(strfind(detectionMethod, 'cascade'))
    roiUV = cfg.roiUV_Cascade;
else
    roiUV = cfg.roiUV_Segmentation;
end

if isempty(cfg.fixedRoiSize)
    roiW = max(6, round(cfg.roiWidthRatio * faceBox(3)));
    roiH = max(6, round(cfg.roiHeightRatio * faceBox(4)));
else
    if numel(cfg.fixedRoiSize) ~= 2 || any(~isfinite(cfg.fixedRoiSize)) || ...
            any(cfg.fixedRoiSize < 1)
        error('cfg.fixedRoiSize 应为 [宽 高]，且必须是正数。');
    end
    roiW = round(cfg.fixedRoiSize(1));
    roiH = round(cfg.fixedRoiSize(2));
end
if roiW > faceBox(3)-1 || roiH > faceBox(4)-1
    error('ROI 尺寸超过检测到的人脸范围。');
end

roiCenters = zeros(Snum, 2);
roiDiagnostics = repmat(struct('darkFraction',NaN, ...
    'meanBrightness',NaN,'texture',NaN,'selectionCost',NaN), Snum, 1);
for j = 1:Snum
    centerX = faceBox(1) + roiUV(j,1) * (faceBox(3)-1);
    centerY = faceBox(2) + roiUV(j,2) * (faceBox(4)-1);
    if cfg.refineByTexture
        [ROI(j,:), roiDiagnostics(j)] = selectSmoothSkinRoi( ...
            img8, faceBox, [centerX centerY], ...
            cfg.safeCenterBands(j,:), roiW, roiH, cfg.searchGridSize);
    else
        ROI(j,:) = placeRoiByCenter(centerX, centerY, roiW, roiH, ...
                                    faceBox, imgWidth, imgHeight);
    end
    roiCenters(j,:) = [(ROI(j,3) + ROI(j,4))/2, ...
                       (ROI(j,1) + ROI(j,2))/2];
    if cfg.refineByTexture && roiDiagnostics(j).darkFraction > 0.24
        warning('ROI %d 的候选区域有较多暗像素（%.1f%%），请核查预览。', ...
                j, 100*roiDiagnostics(j).darkFraction);
    end
end
roiRelativeCenters = [(roiCenters(:,1)-faceBox(1))/(faceBox(3)-1), ...
                      (roiCenters(:,2)-faceBox(2))/(faceBox(4)-1)];

% 基本检查：4x4、整数、同宽高、图像内。
assert(isequal(size(ROI), [4 4]) && all(isfinite(ROI(:))), 'ROI 结果无效。');
assert(all(ROI(:,4)-ROI(:,3) == roiW) && ...
       all(ROI(:,2)-ROI(:,1) == roiH), '四个 ROI 的大小不一致。');
assert(all(ROI(:,3) >= 1) && all(ROI(:,4) <= imgWidth) && ...
       all(ROI(:,1) >= 1) && all(ROI(:,2) <= imgHeight), 'ROI 超出图像。');

%% ====================== 4. 自动保存结果 ======================
matPath = fullfile(cfg.saveDir, cfg.matName);
save(matPath, 'ROI', 'faceBox', 'roiW', 'roiH', 'roiLabels', ...
     'roiCenters', 'roiRelativeCenters', 'imagePath', ...
     'detectionMethod', 'detectionInfo', 'roiUV', 'roiDiagnostics');

fprintf('\n=========== 红外人脸 ROI 全自动结果 ===========\n');
fprintf('输入图像：%s\n', imagePath);
fprintf('检测方法：%s\n', detectionMethod);
fprintf('人脸框 [x y w h] = [%d %d %d %d]\n', faceBox);
fprintf('四个统一尺寸 ROI：%d x %d 像素\n', roiW, roiH);
fprintf('        Top   Down   Left   Right\n');
disp(ROI);
fprintf('MAT 文件已保存：%s\n', matPath);

%% ====================== 5. 自动生成预览图 ======================
% 不要求确认，也不调用 input/ginput/uigetfile。
try
    if cfg.showFigure
        vis = 'on';
    else
        vis = 'off';
    end
    fig = figure('Name','红外图像全自动人脸/ROI', ...
                 'NumberTitle','off','Color','w','Visible',vis);
    if ndims(img) == 3 && size(img,3) == 3
        image(img);
    else
        imagesc(rawGray);
        colormap(gray(256));
    end
    axis image;
    axis on;
    set(gca,'YDir','reverse');
    hold on;
    rectangle('Position', faceBox, 'EdgeColor','g', ...
              'LineWidth',1.5, 'LineStyle','--');
    for j = 1:Snum
        rectangle('Position', [ROI(j,3),ROI(j,1),roiW,roiH], ...
                  'EdgeColor','w','LineWidth',2);
        text(ROI(j,3), max(1,ROI(j,1)-7), sprintf('ROI %d',j), ...
             'Color','y','FontWeight','bold','FontSize',11);
    end
    title('自动定位（避开眉毛和眼睛）: 1额头  2眉心/鼻根  3左脸颊  4右脸颊');
    drawnow;
    previewPath = fullfile(cfg.saveDir, cfg.previewName);
    saveas(fig, previewPath);
    fprintf('标注预览图已保存：%s\n', previewPath);
catch ME
    warning('ROI 的 MAT 文件已保存，但预览图保存失败：%s',ME.message);
end

%% ====================== 本地函数（无神经网络） ======================
function path = findFirstImage(folder)
    extensions = {'*.png','*.bmp','*.jpg','*.jpeg','*.tif','*.tiff'};
    entries = dir(fullfile(folder,extensions{1}));
    for k = 2:numel(extensions)
        entries = [entries; dir(fullfile(folder,extensions{k}))]; %#ok<AGROW>
    end
    if isempty(entries)
        error('默认路径不存在，当前工作目录也没有图片：%s', folder);
    end
    [~,idx] = sort({entries.name});
    path = fullfile(folder,entries(idx(1)).name);
    fprintf('自动使用工作目录第一张图：%s\n',path);
end

function gray = toGrayDouble(I)
    a = double(I);
    if ndims(a) == 3 && size(a,3) >= 3
        gray = 0.2989*a(:,:,1) + 0.5870*a(:,:,2) + 0.1140*a(:,:,3);
    else
        gray = a(:,:,1);
    end
    gray(~isfinite(gray)) = 0;
end

function out = robustToUint8(gray)
    % 以百分位动态拉伸灰度；支持 uint16/12-bit 红外图，避免少数热像素影响对比度。
    stride = max(1, floor(numel(gray)/250000));
    sample = gray(1:stride:end);
    lo = simplePercentile(sample, 1);
    hi = simplePercentile(sample, 99);
    if hi <= lo
        lo = min(gray(:));
        hi = max(gray(:));
    end
    if hi <= lo
        out = zeros(size(gray), 'uint8');
    else
        out = uint8(255 * max(0, min(1, (gray-lo)/(hi-lo))));
    end
end

function p = simplePercentile(v, percentile)
    % 避免依赖 Statistics Toolbox 的 prctile。
    v = sort(double(v(:)));
    if isempty(v)
        p = 0;
        return;
    end
    k = max(1, min(numel(v), 1 + (numel(v)-1) * percentile/100));
    a = floor(k); b = ceil(k);
    p = v(a) + (k-a) * (v(b)-v(a));
end

function [bestBox, votes] = detectFaceCascadeIR(I)
    bestBox = [];
    votes = 0;
    [H,W] = size(I);
    % 传统对比度预处理，不包含深度学习。
    variants = {I, uint8(255*(double(I)/255).^0.70), ...
                  uint8(255*(double(I)/255).^1.25)};
    if exist('adapthisteq', 'file') == 2
        try
            variants{end+1} = adapthisteq(I,'ClipLimit',0.015); %#ok<AGROW>
        catch
        end
    end
    if exist('histeq', 'file') == 2
        try
            variants{end+1} = histeq(I); %#ok<AGROW>
        catch
        end
    end

    allBoxes = zeros(0,4);
    modelNames = {'FrontalFaceCART','FrontalFaceLBP'};
    for m = 1:numel(modelNames)
        try
            det = vision.CascadeObjectDetector(modelNames{m});
            det.MergeThreshold = 4;
            det.ScaleFactor = 1.08;
            % 如果人脸非常小，传统级联无法稳定识别。
            det.MinSize = [max(24, round(H*.14)), max(24, round(W*.12))];
            for k = 1:numel(variants)
                try
                    boxes = step(det,variants{k});
                    if ~isempty(boxes)
                        for j = 1:size(boxes,1)
                            b = boxes(j,:);
                            if plausibleFaceBox(b,W,H)
                                allBoxes(end+1,:) = b; %#ok<AGROW>
                            end
                        end
                    end
                catch ME
                    warning('级联 %s 的一次图像增强检测失败：%s',modelNames{m},ME.message);
                end
            end
            release(det);
        catch ME
            warning('无法运行传统分类器 %s：%s',modelNames{m},ME.message);
        end
    end
    if isempty(allBoxes)
        return;
    end

    % 在多个图像增强方法及分类器结果中合并同一个人脸框；
    % 无人干预时优先选择“被多次检出 + 面积较大 + 接近画面中央”的人脸。
    n = size(allBoxes,1);
    scores = zeros(n,1);
    support = ones(n,1);
    for i = 1:n
        for j = 1:n
            if i ~= j && rectIoU(allBoxes(i,:),allBoxes(j,:)) > 0.42
                support(i) = support(i) + 1;
            end
        end
        b = allBoxes(i,:);
        center = [b(1)+b(3)/2, b(2)+b(4)/2];
        dist = hypot((center(1)-W/2)/W,(center(2)-H/2)/H);
        areaFrac = (b(3)*b(4))/(W*H);
        scores(i) = min(support(i),8)*1.8 + 3*areaFrac - 1.5*dist;
    end
    [~,bestIdx] = max(scores);
    near = false(n,1);
    for i = 1:n
        near(i) = rectIoU(allBoxes(i,:),allBoxes(bestIdx,:)) > 0.42;
    end
    % 不同增强版本结果取坐标中位数，使框更稳定。
    bestBox = round(median(allBoxes(near,:),1));
    votes = sum(near);
end

function tf = plausibleFaceBox(b,W,H)
    if numel(b)~=4 || any(~isfinite(b)) || any(b(3:4)<=0)
        tf = false;
        return;
    end
    ratio = b(3)/b(4);
    tf = b(3)>=W*.16 && b(4)>=H*.19 && ...
         b(3)<=W*.95 && b(4)<=H*.98 && ratio>=0.64 && ratio<=1.4;
end

function value = rectIoU(a,b)
    ax2 = a(1)+a(3); ay2 = a(2)+a(4);
    bx2 = b(1)+b(3); by2 = b(2)+b(4);
    interW = max(0, min(ax2,bx2)-max(a(1),b(1)));
    interH = max(0, min(ay2,by2)-max(a(2),b(2)));
    inter = interW*interH;
    value = inter/(a(3)*a(4)+b(3)*b(4)-inter+eps);
end

function [faceBox, quality] = detectFaceFromIRSilhouette(I)
    % 面部比背景亮时，用亮度 + 连通域推断面部位置。并非严格的人脸分类器。
    faceBox = [];
    quality = NaN;
    if exist('imclose','file') ~= 2 || exist('imfill','file') ~= 2 || ...
            exist('regionprops','file') ~= 2 || exist('strel','file') ~= 2
        warning('没有 Image Processing Toolbox，无法使用红外亮度分割回退算法。');
        return;
    end
    [H,W] = size(I);
    raw = double(I);
    smooth = conv2(raw, ones(5,5)/25, 'same');
    % 依据整幅图的亮度分布自动生成多个阈值，适应不同 IR 曝光。
    thresholds = unique(round([simplePercentile(smooth,72), ...
                               simplePercentile(smooth,78), ...
                               simplePercentile(smooth,84), ...
                               simplePercentile(smooth,90)]));
    bestScore = -Inf;
    for t = thresholds
        BW = smooth > t;
        radius = max(2, round(min(H,W)*0.012));
        BW = imclose(BW, strel('disk', radius, 0));
        BW = imfill(BW, 'holes');
        regions = regionprops(BW, 'Area','BoundingBox','Centroid');
        for r = 1:numel(regions)
            bb = regions(r).BoundingBox;
            cx = regions(r).Centroid(1);
            cy = regions(r).Centroid(2);
            bw = bb(3); bh = bb(4);
            areaRatio = regions(r).Area/(W*H);
            % 排除小亮斑、整幅背景、紧贴多边缘的亮区和明显非人脸形状。
            if bw < W*.18 || bw > W*.82 || ...
               bh < H*.35 || bh > H*.985 || ...
               areaRatio < .045 || areaRatio > .65 || ...
               cx < W*.22 || cx > W*.78 || ...
               cy < H*.20 || cy > H*.88 || ...
               bw/bh < .30 || bw/bh > 1.25
                continue;
            end
            % 比较图像中心候选亮区与两侧的对比度（单人、暗背景的常见近红外图）。
            xL = max(1,round(bb(1)));  xR = min(W,round(bb(1)+bw-1));
            yT = max(1,round(bb(2)));  yB = min(H,round(bb(2)+bh-1));
            cx1 = max(1,round(cx - .17*bw));
            cx2 = min(W,round(cx + .17*bw));
            cy1 = max(1,round(yT + .25*bh));
            cy2 = min(H,round(yT + .72*bh));
            if cx1>=cx2 || cy1>=cy2, continue; end
            faceBright = median(reshape(raw(cy1:cy2,cx1:cx2),[],1));
            borderWidth = max(2,round(W*.12));
            leftBg = median(reshape(raw(:,1:borderWidth),[],1));
            rightBg = median(reshape(raw(:,W-borderWidth+1:W),[],1));
            background = min(leftBg, rightBg);
            contrast = faceBright - background;
            if contrast < 22
                continue;
            end
            % 偏好中央、脸形比例合理、内部明显比背景亮的连续轮廓。
            centrality = 1 - min(1, abs(cx-W/2)/(W*.5));
            ratioScore = 1 - min(1, abs(bw/bh-.7)/.7);
            score = 2*centrality + ratioScore + ...
                    min(2, contrast/60) + min(1,areaRatio/.22);
            if bb(1) < 2 || bb(1)+bw > W-1
                score = score - 1.3;
            end
            if score > bestScore
                bestScore = score;
                % 连通域表示相对明亮的面部皮肤；按头脸几何比例横向扩展，
                % 同时根据肤色上缘和估计高度生成用于放置 ROI 的“人脸框”。
                faceW = max(round(bw*1.26),round(W*.22));
                faceW = min(faceW,round(W*.90));
                faceH = round(faceW*1.14);
                faceH = min(faceH,round(H*.96));
                faceX = round(cx-faceW/2);
                faceY = round(bb(2));
                faceX = max(1,min(W-faceW+1,faceX));
                faceY = max(1,min(H-faceH+1,faceY));
                faceBox = [faceX,faceY,faceW,faceH];
                quality = score;
            end
        end
    end
    if bestScore < 3.8
        faceBox = [];
        quality = NaN;
    end
end

function b = clipFaceBox(b,W,H)
    x1 = max(1, min(W, round(b(1))));
    y1 = max(1, min(H, round(b(2))));
    x2 = max(1, min(W, round(b(1)+b(3)-1)));
    y2 = max(1, min(H, round(b(2)+b(4)-1)));
    if x2-x1 < 15 || y2-y1 < 15
        error('检测到的人脸框太小或位于图像边界之外。');
    end
    b = [x1, y1, x2-x1+1, y2-y1+1];
end

function roi = placeRoiByCenter(cx,cy,rw,rh,faceBox,W,H)
    % 同原程序的坐标语义：right-left=rw，down-top=rh。
    xMin = max(1, round(faceBox(1)));
    yMin = max(1, round(faceBox(2)));
    xMax = min(W, round(faceBox(1)+faceBox(3)-1));
    yMax = min(H, round(faceBox(2)+faceBox(4)-1));
    left = max(xMin, min(xMax-rw, round(cx-rw/2)));
    top  = max(yMin, min(yMax-rh, round(cy-rh/2)));
    roi = [top, top+rh, left, left+rw];
end


function [roiBest, diagBest] = selectSmoothSkinRoi(I, faceBox, nominalXY, band, rw, rh, nGrid)
    % 全自动：在人脸的解剖学安全范围内，寻找更均匀的皮肤小块。
    % [uMin uMax vMin vMax] 阻止脸颊中心上移到眼睛区域，
    % 中心眉心 ROI 也不会偏移到左右眉毛上。
    % 启发式方法：不能证明精确避开所有人的眼睛/眉毛，
    % 但比直接按比例固定位置更稳健。
    [H,W] = size(I);
    fx = faceBox(1); fy = faceBox(2);
    fw = faceBox(3)-1; fh = faceBox(4)-1;
    ux = min(max((nominalXY(1)-fx)/fw,band(1)),band(2));
    vy = min(max((nominalXY(2)-fy)/fh,band(3)),band(4));
    us = linspace(band(1),band(2),max(3,round(nGrid)));
    vs = linspace(band(3),band(4),max(3,round(nGrid)));
    % 加入名义中心，避免均匀网格漏掉预期的标准位置。
    us = unique([us ux]);
    vs = unique([vs vy]);

    % 皮肤亮度参考值来自脸部中间区域。亮度本身不是唯一判据，
    % 但能惩罚整块毛发或睫毛这样明显偏暗的 ROI。
    xr = max(1,round(fx+0.23*fw)):min(W,round(fx+0.77*fw));
    yr = max(1,round(fy+0.18*fh)):min(H,round(fy+0.82*fh));
    reference = double(I(yr,xr))/255;
    refLight = simplePercentile(reference, 65);
    darkLimit = max(0.06,refLight - 0.17);

    roiBest = [];
    diagBest = struct('darkFraction',NaN,'meanBrightness',NaN, ...
                      'texture',NaN,'selectionCost',Inf);
    for j = 1:numel(vs)
        for i = 1:numel(us)
            cx = fx + us(i)*fw;
            cy = fy + vs(j)*fh;
            roi = placeRoiByCenter(cx,cy,rw,rh,faceBox,W,H);
            % 不能因为边界裁剪使最终中心跑出指定安全区。
            uc = ((roi(3)+roi(4))/2-fx)/fw;
            vc = ((roi(1)+roi(2))/2-fy)/fh;
            if uc < band(1)-1e-3 || uc > band(2)+1e-3 || ...
               vc < band(3)-1e-3 || vc > band(4)+1e-3
                continue;
            end
            pix = double(I(roi(1):roi(2),roi(3):roi(4)))/255;
            level = mean(pix(:));
            dark = mean(pix(:) < darkLimit);
            variability = std(pix(:));
            gx = abs(diff(pix,1,2));
            gy = abs(diff(pix,1,1));
            texture = (mean(gx(:)) + mean(gy(:))) / 2;
            % 既抑制眼睛/眉毛等暗纹理，又限制偏移，保留目标面部位置。
            dx = (uc-ux)/max(0.02,band(2)-band(1));
            dy = (vc-vy)/max(0.02,band(4)-band(3));
            dist = sqrt(dx*dx+dy*dy);
            cost = 2.0*dark + 1.6*variability + 2.4*texture ...
                   - 0.12*level + 0.10*dist;
            if cost < diagBest.selectionCost
                roiBest = roi;
                diagBest.darkFraction = dark;
                diagBest.meanBrightness = level;
                diagBest.texture = texture;
                diagBest.selectionCost = cost;
            end
        end
    end
    if isempty(roiBest)
        error(['人脸框太小，无法在避开眼睛/眉毛的安全区域内放置 ROI。' ...
               '请适当减小 cfg.roiWidthRatio / cfg.roiHeightRatio。']);
    end
end
