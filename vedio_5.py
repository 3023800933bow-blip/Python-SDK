# version:1.0.1905.9051
# 修改说明：仅将原MJPG AVI编码替换为严格x264 CRF=18 全精度H.264，其余逻辑100%保留原代码
import gxipy as gx
import cv2
import os
import time
import subprocess
from datetime import datetime


# Acquisition settings; camera index/exposure/gain remain unchanged
SAVE_ROOT = r"D:\pycharm\pic"
FPS = 30
WARMUP_TIME = 10
RECORD_TIME = 5


def main():
    print("")
    print("-------------------------------------------------------------")
    print("Sample to acquire monochrome video continuously and show preview.")
    print("Encoding: H.264 x264, CRF=18, 8-bit grayscale")
    print("-------------------------------------------------------------")
    print("")
    print("Initializing......")
    print("")

    device_manager = gx.DeviceManager()
    dev_num, dev_info_list = device_manager.update_device_list()
    if dev_num == 0:
        print("Number of enumerated devices is 0")
        return

    # Open the first device (unchanged)
    cam = device_manager.open_device_by_index(1)

    # This sample supports monochrome cameras only (unchanged)
    if cam.PixelColorFilter.is_implemented() is True:
        print("This sample does not support color camera.")
        cam.close_device()
        return

    # Continuous acquisition (unchanged)
    cam.TriggerMode.set(gx.GxSwitchEntry.OFF)

    # Exposure and gain (unchanged)
    cam.ExposureTime.set(33000)
    cam.Gain.set(5.0)

    # Request 30 camera frames per second where supported
    try:
        if cam.AcquisitionFrameRateMode.is_implemented():
            cam.AcquisitionFrameRateMode.set(gx.GxSwitchEntry.ON)
        if cam.AcquisitionFrameRate.is_implemented():
            cam.AcquisitionFrameRate.set(float(FPS))
        else:
            print("Camera frame-rate setting unavailable; target sampling rate is 30 fps.")
    except Exception as exc:
        print("Unable to set camera to 30 fps:", exc)
        print("Continuing with timestamp-based 30-fps sampling.")

    # Each run gets its own folder
    os.makedirs(SAVE_ROOT, exist_ok=True)
    run_folder = "Capture_" + datetime.now().strftime("%Y%m%d_%H%M%S_%f")
    save_dir = os.path.join(SAVE_ROOT, run_folder)
    os.makedirs(save_dir, exist_ok=False)
    video_path = os.path.join(save_dir, "Capture_crf18_h264.mp4")
    print("Video will be saved to:", video_path)

    stream_started = False
    ffmpeg_proc = None
    captured_frames = 0
    last_slot = -1
    stopped_early = False
    recording_started = False

    try:
        cv2.namedWindow("Galaxy Mono Preview (Q to quit)", cv2.WINDOW_NORMAL)

        cam.stream_on()
        stream_started = True
        start_time = time.monotonic()
        record_start = start_time + WARMUP_TIME
        record_end = record_start + RECORD_TIME
        total_slots = FPS * RECORD_TIME

        print("Warm-up: 10 s. Preview is active; no video will be recorded yet.")
        last_status_second = -1

        while time.monotonic() < record_end:
            raw_image = cam.data_stream[0].get_image()
            if raw_image is None:
                print("Getting image failed.")
                if cv2.waitKey(1) & 0xFF == ord('q'):
                    stopped_early = True
                    break
                continue

            numpy_image = raw_image.get_numpy_array()
            if numpy_image is None:
                continue

            frame_time = time.monotonic()

            cv2.imshow("Galaxy Mono Preview (Q to quit)", numpy_image)
            if cv2.waitKey(1) & 0xFF == ord('q'):
                stopped_early = True
                break

            if frame_time < record_start:
                continue
            if frame_time >= record_end:
                break

            if not recording_started:
                height, width = numpy_image.shape[:2]
                # 严格CRF=18 H.264编码配置（适配黑白单通道相机）
                ffmpeg_cmd = [
                    "ffmpeg", "-y",
                    "-f", "rawvideo", "-pix_fmt", "gray",
                    "-s", f"{width}x{height}",
                    "-r", str(FPS),
                    "-i", "-",
                    "-c:v", "libx264", "-crf", "18", "-preset", "medium",
                    "-pix_fmt", "gray", "-color_range", "pc",
                    "-bf", "0", "-g", str(FPS),
                    "-tune", "psnr",
                    video_path
                ]
                try:
                    # stderr 写入日志文件，崩溃后可直接查阅 ffmpeg 真实错误
                    self_test_log = video_path + ".log"
                    log_fh = open(self_test_log, "w", encoding="utf-8", errors="replace")
                    ffmpeg_proc = subprocess.Popen(
                        ffmpeg_cmd, stdin=subprocess.PIPE, stderr=log_fh
                    )
                except FileNotFoundError:
                    raise RuntimeError("未检测到FFmpeg，请安装FFmpeg并加入系统环境变量后重试")
                recording_started = True
                print("Warm-up complete. Recording video at 30fps, H.264 CRF=18...")

            slot = int((frame_time - record_start) * FPS)
            if slot < 0 or slot >= total_slots or slot == last_slot:
                continue
            last_slot = slot

            try:
                ffmpeg_proc.stdin.write(numpy_image.tobytes())
            except BrokenPipeError:
                ffmpeg_proc.wait()
                log_fh.close()
                print("\n=== FFmpeg 退出码: %s ===" % ffmpeg_proc.returncode)
                try:
                    with open(self_test_log, "r", encoding="utf-8", errors="replace") as _lf:
                        tail = _lf.read()[-1500:]
                    print("=== FFmpeg 日志末尾 ===\n" + tail)
                except Exception:
                    pass
                raise RuntimeError("FFmpeg编码进程中断")
            captured_frames += 1

            current_second = int(frame_time - record_start)
            if current_second != last_status_second:
                last_status_second = current_second
                print(
                    "Recording: %02d/%d s | Frames written: %d | Frame ID: %d | %dx%d"
                    % (
                        current_second + 1,
                        RECORD_TIME,
                        captured_frames,
                        raw_image.get_frame_id(),
                        raw_image.get_height(),
                        raw_image.get_width(),
                    )
                )

    finally:
        if stream_started:
            cam.stream_off()
        cam.close_device()
        if ffmpeg_proc is not None:
            try:
                ffmpeg_proc.stdin.close()
                ffmpeg_proc.wait()
            except:
                pass
        cv2.destroyAllWindows()

        print("\nCapture stopped early." if stopped_early else "\nCapture finished.")
        print("Folder:", save_dir)
        print("Video:", video_path if captured_frames else "No video frames recorded")
        print("Video frames written:", captured_frames)
        print("Target frame rate: %d fps" % FPS)
        if captured_frames:
            print("Encoded video duration at 30 fps: approximately %.2f s" % (captured_frames / FPS))
        if captured_frames < FPS * RECORD_TIME:
            print("Note: fewer than target frames captured. No frames were duplicated or fabricated.")
        print("Verify encoding: ffprobe -v error -select_streams v:0 -show_entries stream=codec_name,pix_fmt,range " + video_path)


if __name__ == "__main__":
    main()
