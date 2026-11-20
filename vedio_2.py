# version:1.0.1905.9051
import gxipy as gx
import cv2
import os
import time
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
    video_path = os.path.join(save_dir, "Capture_60s_30fps.avi")
    print("Video will be saved to:", video_path)

    stream_started = False
    video_writer = None
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
                # MJPG in AVI is widely supported; grayscale frames are preserved.
                fourcc = cv2.VideoWriter_fourcc(*"MJPG")
                video_writer = cv2.VideoWriter(
                    video_path, fourcc, float(FPS), (width, height), isColor=False
                )
                if not video_writer.isOpened():
                    raise RuntimeError(
                        "Could not open video writer. Check OpenCV video codec support and output path."
                    )
                recording_started = True
                print("Warm-up complete. Recording video for 60 s at a target 30 fps...")

            # Sample at most one genuine camera frame per 1/30-second time slot.
            # Missing slots are not filled with duplicated or synthetic frames.
            slot = int((frame_time - record_start) * FPS)
            if slot < 0 or slot >= total_slots or slot == last_slot:
                continue
            last_slot = slot

            # Write the original monochrome frame to the video.
            video_writer.write(numpy_image)
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
        if video_writer is not None:
            video_writer.release()
        cv2.destroyAllWindows()

        print("\nCapture stopped early." if stopped_early else "\nCapture finished.")
        print("Folder:", save_dir)
        print("Video:", video_path if captured_frames else "No video frames recorded")
        print("Video frames written:", captured_frames)
        print("Target frame rate: %d fps" % FPS)
        if captured_frames:
            print("Encoded video duration at 30 fps: approximately %.2f s" % (captured_frames / FPS))
        if captured_frames < FPS * RECORD_TIME:
            print("Note: fewer than 1800 frames were captured. No frames were duplicated or fabricated;")
            print("      the encoded video's playback duration may therefore be shorter than 60 s.")


if __name__ == "__main__":
    main()
