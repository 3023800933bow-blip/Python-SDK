%统一大小


clear;
clc;
close all;

%% =========================================
% 读取第一帧
% ==========================================
% img = imread('D:\pycharm\pic\MER2-302-56U3M(FDU23020201)\MER2-302-56U3M(FDU23020201)_2026-10-28_15_40_40_038-0.bmp');
% img = imread('C:\Users\lenovo\PyCharmMiscProject\PNG_20261008_172356\000020_20261008_172400_872098.png');
% img = imread('C:\Users\lenovo\PyCharmMiscProject\IR_20261009_155430\000001_20261009_155444_199301.png');
% img = imread('C:\Users\lenovo\PyCharmMiscProject\IR_20261010_140922\000001_20261010_140935_959207.png');
% img = imread('C:\Users\lenovo\PyCharmMiscProject\IR_20261010_143704\000001_20261010_143717_774495.png');
% img = imread('C:\Users\lenovo\PyCharmMiscProject\IR_20261010_154141\000001_20261010_154154_630141.png');
% img = imread('C:\Users\lenovo\PyCharmMiscProject\IR_20261010_160611\000001_20261010_160624_732412.png');
% img = imread('C:\Users\lenovo\PyCharmMiscProject\IR_20261010_164607\000001_20261010_164621_277446.png');
% img = imread('C:\Users\lenovo\PyCharmMiscProject\IR_20261010_171808\000001_20261010_171821_652548.png');
% img = imread('C:\Users\lenovo\PyCharmMiscProject\IR_20261010_173644\000001_20261010_173657_915047.png');
% img = imread('C:\Users\lenovo\PyCharmMiscProject\IR_20261010_173502\000001_20261010_173516_330196.png');
% img = imread('C:\Users\lenovo\PyCharmMiscProject\IR_20261010_173323\000001_20261010_173337_479774.png');
% img = imread('C:\Users\lenovo\PyCharmMiscProject\IR_20261010_180609\000001_20261010_180622_662698.png');
% img = imread('C:\Users\lenovo\PyCharmMiscProject\IR_20261010_180442\000001_20261010_180456_262875.png');
% img = imread('C:\Users\lenovo\PyCharmMiscProject\IR_20261010_180309\000001_20261010_180323_248263.png');
% img = imread('C:\Users\lenovo\PyCharmMiscProject\IR_20261010_180143\000001_20261010_180157_408513.png');
% img = imread('C:\Users\lenovo\PyCharmMiscProject\IR_20261013_140737\000001_20261013_140751_666689.png');
% img = imread('C:\Users\lenovo\PyCharmMiscProject\IR_20261013_140439\000001_20261013_140453_355750.png');
% img = imread('C:\Users\lenovo\PyCharmMiscProject\IR_20261013_145646\000001_20261013_145701_128091.png');
% img = imread('C:\Users\lenovo\PyCharmMiscProject\IR_20261013_155229\000001_20261013_155243_033388.png');
% img = imread('C:\Users\lenovo\PyCharmMiscProject\IR_20261020_172617\000001_20261020_172627_943385.png');
% img = imread('C:\Users\lenovo\PyCharmMiscProject\IR_20261020_172434\000001_20261020_172445_052939.png');
% img = imread('C:\Users\lenovo\PyCharmMiscProject\IR_20261020_174046\000001_20261020_174056_638381.png');
% img = imread('C:\Users\lenovo\PyCharmMiscProject\IR_20261020_175533\000001_20261020_175543_845713.png');
% img = imread('C:\Users\lenovo\PyCharmMiscProject\IR_20261020_182130\000001_20261020_182140_552113.png');
% img = imread('E:\Galaxy_SDK\pic\Capture_20261021_161846_749382\20261021_161856_829293_00001_FID0000000300.png');
% img = imread('E:\Galaxy_SDK\pic\Capture_20261021_165047_421679\20261021_165057_512773_00001_FID0000000300.png');

% img = imread('D:\pycharm\pic\Capture_20261021_172104_118950\20261021_172114_213270_Frame_300.png');
% img = imread('D:\pycharm\pic\Capture_20261021_173001_018168\20261021_173011_108216_Frame_300.png');
% img = imread('D:\pycharm\pic\Capture_20261021_173129_781820\20261021_173139_867524_Frame_300.png');
% img = imread('D:\pycharm\pic\Capture_20261021_174446_098635\20261021_174456_187740_Frame_300.png');
% img = imread('D:\pycharm\pic\Capture_20261021_180843_652772\20261021_180853_741477_Frame_300.png');

% img = imread('D:\pycharm\pic\Capture_20261023_183038_421091\20261023_183048_507424_Frame_300.png');
% img = imread('D:\pycharm\pic\Capture_20261023_182900_218762\20261023_182910_306944_Frame_300.png');

% img = imread('D:\pycharm\pic\Capture_20261026_180806_832208\20261026_180816_924692_Frame_300.png');
% img = imread('D:\pycharm\pic\Capture_20261026_181443_569878\20261026_181453_661255_Frame_300.png');%840
% img = imread('D:\pycharm\pic\Capture_20261026_180634_732074\20261026_180644_827062_Frame_300.png');
% img = imread('D:\pycharm\pic\Capture_20261026_180457_166353\20261026_180507_275449_Frame_300.png');%**

% img = imread('D:\pycharm\bpm\MER2-302-56U3M(FDU23020201)\MER2-302-56U3M(FDU23020201)_2026-10-28_17_58_48_671-0.bmp');
% img = imread('D:\pycharm\pic\MER2-302-56U3M(FDU23020201)\MER2-302-56U3M(FDU23020201)_2026-10-28_18_01_47_320-1811.bmp');


% img = imread('D:\pycharm\pic\Capture_20261028_180716_917036\20261028_180727_015883_Frame_300.png');%840

% img = imread('D:\pycharm\pic\Capture_20261029_182125_608480\20261029_182135_696722_Frame_300.png');
% img = imread('D:\pycharm\pic\Capture_20261029_183844_464767\20261029_183854_555285_Frame_300.png');


% img = imread('E:\Galaxy_SDK\pic\Capture_20261029_185044_864786\20261029_185054_962572_Frame_300.png');% 0
% img = imread('E:\Galaxy_SDK\pic\Capture_20261029_184729_138097\20261029_184739_237657_Frame_300.png');% 0
% img = imread('D:\pycharm\pic\Capture_20261029_181816_389393\20261029_181826_479522_Frame_300.png');% 0
% img = imread('E:\Galaxy_SDK\pic\Capture_20261029_184914_161861\20261029_184924_268668_Frame_300.png');% 0


% img = imread('E:\Galaxy_SDK\pic\Capture_20261029_184431_486865\20261029_184441_580708_Frame_300.png');% 22
% img = imread('E:\Galaxy_SDK\pic\Capture_20261029_184253_994899\20261029_184304_102366_Frame_300.png');% 22
% img = imread('D:\pycharm\pic\Capture_20261029_183844_464767\20261029_183854_555285_Frame_300.png');% 22


% img = imread('D:\pycharm\pic\Capture_20261103_171444_474484\frames\frame_00001.png');% 22

% img = imread('C:\Users\lenovo\Documents\MATLAB\video_bmp\frame-1.bmp');
% img = imread('D:\pycharm\pic\Capture_20261104_183827_002809\frames\frame_00001.png');%*
% img = imread('D:\pycharm\pic\Capture_20261104_183540_047970\frames\frame_00001.png');
% img = imread('D:\pycharm\pic\Capture_20261104_183200_388214\frames\frame_00001.png');%*

% img = imread('E:\Galaxy_SDK\pic\Capture_20261105_183120_811731\frames\frame_00001.png');%*


% img =
% imread('E:\Galaxy_SDK\pic\Capture_20261110_184205_906732\frames\frame_00001.png');%23
% img = imread('E:\Galaxy_SDK\pic\Capture_20261110_184015_084097\frames\frame_00001.png');%*21
img = imread('E:\Galaxy_SDK\pic\Capture_20261110_183145_879901\frames\frame_00001.png');%*
%% =========================================
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
save('ROI_selected_901.mat','ROI');

fprintf('\n============================\n');
fprintf('ROI选择完成！\n');
fprintf('已保存');
fprintf('============================\n');
