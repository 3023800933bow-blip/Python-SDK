"""
rPPG 专用视频录制脚本
功能：10秒预热 + 固定60分钟30fps录制，支持手动调曝光/增益/存储路径，3种编码格式可选
注意：写入视频的帧为摄像头原始输出，无任何滤镜/裁剪/颜色修改，仅本地监控窗口显示提示
依赖：pip install opencv-python
"""
import cv2
import time
import os

# ================================== 可手动修改的参数区 ==================================
SAVE_PATH = "C:/rppg_data/recording_001.mp4"  # 视频保存绝对地址
CAMERA_INDEX = 0                               # 摄像头序号（默认0是电脑自带摄像头）
TARGET_FPS = 30                                # 固定录制帧率
RECORD_DURATION_MIN = 60                       # 正式录制总时长（分钟）
PREHEAT_SECONDS = 10                            # 传感器预热时间（秒，等曝光稳定后再开始录）
MANUAL_EXPOSURE = -6                           # 手动曝光值（范围通常-11~0，数值越小画面越暗）
MANUAL_GAIN = 0                                 # 手动增益值（范围通常0~1023，数值越大画面越亮，过高会带噪点）
# 编码格式3选1（对应之前推荐的精度档位）：
# "avc1" = H.264 视觉无损版（最推荐，精度最高、体积适中，适合rPPG数据存储）
# "mjpg" = Motion JPEG 兼容版（纯帧内压缩，无帧间误差，兼容性最好，体积稍大）
# "mp4v" = MPEG-4 轻量版（文件最小，适合长时间预录粗采）
CODEC = "avc1"
# ========================================================================================

if __name__ == "__main__":
    # 检查保存路径
    save_dir = os.path.dirname(SAVE_PATH)
    if not os.path.exists(save_dir):
        os.makedirs(save_dir)
    if os.path.exists(SAVE_PATH):
        print(f"警告：文件 {SAVE_PATH} 已存在，继续运行将覆盖原文件！")
        time.sleep(2)

    # 初始化摄像头（用DSHOW后端，Windows下对曝光/增益的控制最稳定）
    cap = cv2.VideoCapture(CAMERA_INDEX, cv2.CAP_DSHOW)
    if not cap.isOpened():
        print("错误：无法打开摄像头，请检查摄像头是否被其他软件占用！")
        exit()

    # 固定摄像头参数，关闭自动调节
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1920)    # 固定1080p分辨率，需要更高可改2560x1440
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 1080)
    cap.set(cv2.CAP_PROP_FPS, TARGET_FPS)
    cap.set(cv2.CAP_PROP_AUTO_EXPOSURE, 0.75) # 强制关闭自动曝光，切换为手动模式
    cap.set(cv2.CAP_PROP_EXPOSURE, MANUAL_EXPOSURE)
    cap.set(cv2.CAP_PROP_GAIN, MANUAL_GAIN)
    print(f"摄像头初始化完成：分辨率 {int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))}x{int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))}, 实际帧率 {cap.get(cv2.CAP_PROP_FPS)}")

    # -------------------------- 10秒预热阶段：只显示画面，不写视频 --------------------------
    print(f"开始{PREHEAT_SECONDS}秒传感器预热，请勿移动人脸，请勿调整光线...")
    preheat_start = time.time()
    while time.time() - preheat_start < PREHEAT_SECONDS:
        ret, frame = cap.read()
        if not ret:
            continue
        # 仅在本地显示副本上画提示，不修改原始帧
        display_frame = frame.copy()
        remain = PREHEAT_SECONDS - (time.time() - preheat_start)
        cv2.putText(display_frame, f"预热倒计时: {remain:.1f}s | 请勿移动",
                    (50, 50), cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 0), 2)
        cv2.imshow("rPPG Recording Monitor", display_frame)
        if cv2.waitKey(1) & 0xFF == ord('q'):
            cap.release()
            cv2.destroyAllWindows()
            exit()

    # -------------------------- 正式录制阶段 --------------------------
    total_frames = int(RECORD_DURATION_MIN * 60 * TARGET_FPS)  # 总需要采集的帧数
    fourcc = cv2.VideoWriter_fourcc(*CODEC)
    out = cv2.VideoWriter(
        SAVE_PATH, fourcc, TARGET_FPS,
        (int(cap.get(cv2.CAP_PROP_FRAME_WIDTH)), int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT)))
    )
    if not out.isOpened():
        print(f"错误：编码 {CODEC} 初始化失败，请更换CODEC选项（比如换mjpg）后重试！")
        cap.release()
        exit()

    print(f"正式开始录制，总时长 {RECORD_DURATION_MIN} 分钟，按q键可提前退出...")
    frame_count = 0
    record_start = time.time()
    while frame_count < total_frames:
        ret, frame = cap.read()
        if not ret:
            print("警告：摄像头采帧中断，提前结束录制")
            break

        # 【关键】写入视频的是完全原始的帧，无任何修改
        out.write(frame)
        frame_count += 1

        # 本地监控窗口的显示副本（不会写入视频）
        display_frame = frame.copy()
        elapsed_sec = frame_count / TARGET_FPS
        remain_sec = total_frames / TARGET_FPS - elapsed_sec
        elp_mm, elp_ss = int(elapsed_sec//60), int(elapsed_sec%60)
        rem_mm, rem_ss = int(remain_sec//60), int(remain_sec%60)
        cv2.putText(display_frame,
                    f"已录: {elp_mm:02d}:{elp_ss:02d} | 剩余: {rem_mm:02d}:{rem_ss:02d} | 曝光:{MANUAL_EXPOSURE} | 增益:{MANUAL_GAIN}",
                    (50, 50), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 255), 2)
        cv2.imshow("rPPG Recording Monitor", display_frame)

        if cv2.waitKey(1) & 0xFF == ord('q'):
            print("用户提前退出录制")
            break

    # 释放资源
    out.release()
    cap.release()
    cv2.destroyAllWindows()
    actual_min = frame_count / TARGET_FPS / 60
    print(f"录制完成！共录 {actual_min:.1f} 分钟视频，已保存至：{SAVE_PATH}")
