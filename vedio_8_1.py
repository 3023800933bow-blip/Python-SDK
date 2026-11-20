# version:1.0.1905.9051
# 8-hour NIR monochrome rPPG capture using Daheng Galaxy SDK + FFmpeg MJPEG.
# Video is split into 10-minute AVI segments without stopping camera acquisition.
import csv
import cv2
import gxipy as gx
import os
import queue
import shutil
import subprocess
import threading
import time
from datetime import datetime


SAVE_ROOT = r"E:\Galaxy_SDK\text"
FPS = 30
WARMUP_TIME = 10
RECORD_TIME = 60*60*8
SEGMENT_SECONDS = 10 * 60
MJPEG_QSCALE = 5  # Lower means higher quality and larger files; test disk use before a run.
WRITER_QUEUE_FRAMES = 60


def _ffmpeg_writer(proc, frame_queue, writer_errors):
    try:
        while True:
            item = frame_queue.get()
            try:
                if item is None:
                    return
                frame_bytes, _frame_id, _timestamp_ns = item
                if proc.stdin is None:
                    raise RuntimeError("FFmpeg input pipe is unavailable.")
                proc.stdin.write(frame_bytes)
            finally:
                frame_queue.task_done()
    except Exception as exc:
        writer_errors.append(exc)
    finally:
        if proc.stdin is not None:
            try:
                proc.stdin.close()
            except Exception as exc:
                writer_errors.append(exc)


def main():
    ffmpeg_path = shutil.which("ffmpeg")
    if ffmpeg_path is None:
        raise RuntimeError("FFmpeg was not found. Install FFmpeg and add ffmpeg.exe to PATH.")

    device_manager = gx.DeviceManager()
    dev_num, _dev_info_list = device_manager.update_device_list()
    if dev_num == 0:
        raise RuntimeError("No Daheng camera was found.")

    cam = device_manager.open_device_by_index(1)
    stream_started = False
    ffmpeg_proc = None
    ffmpeg_log = None
    writer_thread = None
    frame_queue = queue.Queue(maxsize=WRITER_QUEUE_FRAMES)
    writer_errors = []
    metadata_file = None
    save_dir = None
    captured_frames = 0
    queued_frames = 0
    queue_drops = 0
    missing_camera_frames = 0
    stopped_early = False
    last_frame_id = None

    try:
        if cam.PixelColorFilter.is_implemented():
            raise RuntimeError("This script is for monochrome/NIR cameras only.")

        # FFmpeg below reads exactly one 8-bit grayscale byte per pixel.
        cam.PixelFormat.set(gx.GxPixelFormatEntry.MONO8)

        cam.TriggerMode.set(gx.GxSwitchEntry.OFF)
        cam.ExposureTime.set(20000)
        cam.Gain.set(15.0)

        if not cam.AcquisitionFrameRateMode.is_implemented():
            raise RuntimeError("Camera frame-rate control is unavailable; cannot guarantee 30 fps.")
        if not cam.AcquisitionFrameRate.is_implemented():
            raise RuntimeError("Camera frame-rate setting is unavailable; cannot guarantee 30 fps.")
        cam.AcquisitionFrameRateMode.set(gx.GxSwitchEntry.ON)
        cam.AcquisitionFrameRate.set(float(FPS))

        os.makedirs(SAVE_ROOT, exist_ok=True)
        run_name = "Capture_" + datetime.now().strftime("%Y%m%d_%H%M%S_%f")
        save_dir = os.path.join(SAVE_ROOT, run_name)
        os.makedirs(save_dir, exist_ok=False)

        video_pattern = os.path.join(save_dir, "Capture_%03d.avi")
        ffmpeg_log_path = os.path.join(save_dir, "ffmpeg.log")
        frames_csv_path = os.path.join(save_dir, "frames.csv")
        metadata_file = open(frames_csv_path, "w", newline="", encoding="utf-8")
        metadata_writer = csv.writer(metadata_file)
        metadata_writer.writerow([
            "capture_index",
            "frame_id",
            "arrival_monotonic_ns",
            "elapsed_from_record_start_s",
            "missing_camera_frames_before",
            "queued_for_encoding",
        ])

        cv2.namedWindow("Galaxy Mono NIR Preview (Q to quit)", cv2.WINDOW_NORMAL)
        cam.stream_on()
        stream_started = True

        stream_start = time.monotonic()
        record_start = stream_start + WARMUP_TIME
        record_end = record_start + RECORD_TIME
        recording_started = False
        last_status_second = -1
        print(f"Warm-up: {WARMUP_TIME} s. Recording target: {RECORD_TIME} s at {FPS} fps.")
        print(f"Output folder: {save_dir}")
        print("Video files will be split every 10 minutes; acquisition remains continuous.")

        while time.monotonic() < record_end:
            if writer_errors:
                raise RuntimeError(f"FFmpeg writer failed: {writer_errors[0]}")
            if ffmpeg_proc is not None and ffmpeg_proc.poll() is not None:
                raise RuntimeError(f"FFmpeg exited early with code {ffmpeg_proc.returncode}.")

            raw_image = cam.data_stream[0].get_image()
            if raw_image is None:
                if cv2.waitKey(1) & 0xFF == ord("q"):
                    stopped_early = True
                    break
                continue

            numpy_image = raw_image.get_numpy_array()
            if numpy_image is None:
                continue

            frame_time = time.monotonic()
            cv2.imshow("Galaxy Mono NIR Preview (Q to quit)", numpy_image)
            if cv2.waitKey(1) & 0xFF == ord("q"):
                stopped_early = True
                break

            if frame_time < record_start:
                continue
            if frame_time >= record_end:
                break

            if numpy_image.ndim != 2 or numpy_image.dtype.name != "uint8":
                raise RuntimeError(
                    "Expected a 2D Mono8 frame. Camera PixelFormat did not produce 8-bit grayscale."
                )

            height, width = numpy_image.shape
            if not recording_started:
                ffmpeg_cmd = [
                    ffmpeg_path,
                    "-hide_banner", "-loglevel", "warning", "-y",
                    "-f", "rawvideo",
                    "-pixel_format", "gray",
                    "-video_size", f"{width}x{height}",
                    "-framerate", str(FPS),
                    "-i", "pipe:0",
                    "-an",
                    "-c:v", "mjpeg",
                    # FFmpeg's MJPEG encoder does not accept gray output directly.
                    # The NIR input is grayscale, so 4:2:0 chroma carries no scene color.
                    "-pix_fmt", "yuvj420p",
                    "-q:v", str(MJPEG_QSCALE),
                    "-f", "segment",
                    "-segment_time", str(SEGMENT_SECONDS),
                    "-reset_timestamps", "1",
                    "-segment_format", "avi",
                    video_pattern,
                ]
                ffmpeg_log = open(ffmpeg_log_path, "wb")
                ffmpeg_proc = subprocess.Popen(
                    ffmpeg_cmd,
                    stdin=subprocess.PIPE,
                    stdout=subprocess.DEVNULL,
                    stderr=ffmpeg_log,
                )
                writer_thread = threading.Thread(
                    target=_ffmpeg_writer,
                    args=(ffmpeg_proc, frame_queue, writer_errors),
                    name="mjpeg-writer",
                    daemon=False,
                )
                writer_thread.start()
                recording_started = True

            frame_id = int(raw_image.get_frame_id())
            arrival_ns = time.monotonic_ns()
            missing_before = 0
            if last_frame_id is not None and frame_id > last_frame_id + 1:
                missing_before = frame_id - last_frame_id - 1
                missing_camera_frames += missing_before
            last_frame_id = frame_id

            captured_frames += 1
            queued = False
            try:
                frame_queue.put_nowait((numpy_image.tobytes(), frame_id, arrival_ns))
                queued = True
                queued_frames += 1
            except queue.Full:
                queue_drops += 1

            elapsed = frame_time - record_start
            metadata_writer.writerow([
                captured_frames,
                frame_id,
                arrival_ns,
                f"{elapsed:.9f}",
                missing_before,
                int(queued),
            ])

            current_second = int(elapsed)
            if last_status_second < 0 or current_second - last_status_second >= 60:
                last_status_second = current_second
                metadata_file.flush()
                print(
                    f"Recording {current_second + 1}/{RECORD_TIME} s | "
                    f"captured={captured_frames} queued={queued_frames} "
                    f"queue_drops={queue_drops} camera_frame_gaps={missing_camera_frames}"
                )

    finally:
        if stream_started:
            try:
                cam.stream_off()
            except Exception as exc:
                print("Warning: camera stream shutdown failed:", exc)
        try:
            cam.close_device()
        except Exception as exc:
            print("Warning: camera close failed:", exc)

        if writer_thread is not None:
            if writer_thread.is_alive():
                while writer_thread.is_alive():
                    try:
                        frame_queue.put(None, timeout=0.5)
                        break
                    except queue.Full:
                        continue
            writer_thread.join()

        ffmpeg_return_code = None
        if ffmpeg_proc is not None:
            # Closing the input pipe lets FFmpeg write the final AVI indexes.
            ffmpeg_return_code = ffmpeg_proc.wait()
        if ffmpeg_log is not None:
            ffmpeg_log.close()
        if metadata_file is not None:
            metadata_file.flush()
            metadata_file.close()
        cv2.destroyAllWindows()

        print("\nCapture stopped early." if stopped_early else "\nCapture finished.")
        if save_dir:
            print("Folder:", save_dir)
        print("Frames captured:", captured_frames)
        print("Frames queued for encoding:", queued_frames)
        print("Frames skipped because the writer queue was full:", queue_drops)
        print("Camera frame-ID gaps detected:", missing_camera_frames)
        if ffmpeg_return_code is not None:
            print("FFmpeg exit code:", ffmpeg_return_code)
        if writer_errors:
            print("FFmpeg writer error:", writer_errors[0])


if __name__ == "__main__":
    main()
