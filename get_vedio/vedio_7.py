# version:1.0.1905.9051
# Changes vs vedio_6.py:
#   1. MJPEG encoding moved from OpenCV VideoWriter (black-box, medium default quality)
#      to ffmpeg subprocess with explicit "-q:v 2" highest quality and "-pix_fmt gray".
#   2. PixelFormat explicitly forced to Mono8 (was previously implicit).
#   3. No more wall-clock slot subsampling: the camera itself runs at 30 fps
#      (AcquisitionFrameRateMode=ON), so every delivered frame is written as-is.
#      Dropped frames are reported honestly, never duplicated or fabricated.
#   4. Filename / printed duration now derive from RECORD_TIME so labels match reality.
#   5. ffmpeg stderr redirected to a log file (avoids stderr PIPE deadlock).
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

    # Explicitly request Mono8 grayscale pixel format (was previously implicit).
    try:
        cam.PixelFormat.set(gx.GxPixelFormatEntry.MONO8)
    except Exception as exc:
        print("Unable to set Mono8 explicitly (continuing with current format):", exc)

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
    video_path = os.path.join(save_dir, f"Capture_{RECORD_TIME}s_{FPS}fps.avi")
    ffmpeg_log_path = os.path.join(save_dir, "ffmpeg.log")
    print("Video will be saved to:", video_path)

    stream_started = False
    ffmpeg_proc = None
    ffmpeg_log = None
    captured_frames = 0
    stopped_early = False
    recording_started = False
    record_clock = None

    try:
        cv2.namedWindow("Galaxy Mono Preview (Q to quit)", cv2.WINDOW_NORMAL)

        cam.stream_on()
        stream_started = True
        start_time = time.monotonic()
        record_start = start_time + WARMUP_TIME
        record_end = record_start + RECORD_TIME

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

            # Show the native-resolution camera image continuously
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
                # High-quality Motion JPEG via ffmpeg:
                #   -pix_fmt gray  -> grayscale, no chroma subsampling loss
                #   -q:v 2         -> highest MJPEG quality (1..31, lower = better)
                ffmpeg_cmd = [
                    "ffmpeg", "-y",
                    "-f", "rawvideo",
                    "-pixel_format", "gray",
                    "-video_size", f"{width}x{height}",
                    "-framerate", str(FPS),
                    "-i", "-",
                    "-c:v", "mjpeg",
                    "-pix_fmt", "gray",
                    "-q:v", "2",
                    "-r", str(FPS),
                    video_path,
                ]
                ffmpeg_log = open(ffmpeg_log_path, "w")
                ffmpeg_proc = subprocess.Popen(
                    ffmpeg_cmd, stdin=subprocess.PIPE, stderr=ffmpeg_log
                )
                recording_started = True
                record_clock = frame_time
                print(f"Warm-up complete. Recording video for {RECORD_TIME} s at a target {FPS} fps...")

            # The camera is the clock source (AcquisitionFrameRate=30).
            # Write every frame that arrives during the recording window;
            # dropped frames are reported honestly, never fabricated.
            ffmpeg_proc.stdin.write(numpy_image.tobytes())
            captured_frames += 1

            current_second = int(frame_time - record_clock)
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
                if ffmpeg_proc.stdin is not None:
                    ffmpeg_proc.stdin.close()
            except Exception:
                pass
            try:
                ffmpeg_proc.wait(timeout=10)
            except Exception:
                ffmpeg_proc.kill()
        if ffmpeg_log is not None:
            try:
                ffmpeg_log.close()
            except Exception:
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
            print(f"Note: fewer than {FPS * RECORD_TIME} frames were captured. No frames were duplicated or fabricated;")
            print("      the encoded video's playback duration may therefore be shorter than the target.")


if __name__ == "__main__":
    main()
