# version:1.0.1905.9051
import gxipy as gx
from PIL import Image

# Added: live preview, timing, per-run folders, and asynchronous lossless saving
import cv2
import os
import time
import queue
import threading
from datetime import datetime


# Added acquisition settings; the original camera index/exposure/gain remain unchanged
SAVE_ROOT = r"E:\Galaxy_SDK\pic"
FPS = 30
WARMUP_TIME = 10
RECORD_TIME = 60
MAX_PENDING_IMAGES = 120


def main():
    # print the demo information
    print("")
    print("-------------------------------------------------------------")
    print("Sample to show how to acquire mono image continuously and show acquired image.")
    print("-------------------------------------------------------------")
    print("")
    print("Initializing......")
    print("")

    # create a device manager
    device_manager = gx.DeviceManager()
    dev_num, dev_info_list = device_manager.update_device_list()
    if dev_num == 0:
        print("Number of enumerated devices is 0")
        return

    # open the first device
    cam = device_manager.open_device_by_index(1)

    # exit when the camera is a color camera
    if cam.PixelColorFilter.is_implemented() is True:
        print("This sample does not support color camera.")
        cam.close_device()
        return

    # set continuous acquisition
    cam.TriggerMode.set(gx.GxSwitchEntry.OFF)

    # set exposure
    cam.ExposureTime.set(10000)

    # set gain
    cam.Gain.set(10)

    # Added: request 30 fps when the camera supports this control.
    # Fall back to sampling at most one real frame per 1/30 s time slot.
    try:
        if cam.AcquisitionFrameRateMode.is_implemented():
            cam.AcquisitionFrameRateMode.set(gx.GxSwitchEntry.ON)
        if cam.AcquisitionFrameRate.is_implemented():
            cam.AcquisitionFrameRate.set(float(FPS))
        else:
            print("Camera frame-rate setting unavailable; using timestamp-based 30-fps limit.")
    except Exception as exc:
        print("Unable to set camera to 30 fps:", exc)
        print("Continuing with timestamp-based 30-fps limit.")

    # Added: each run has its own unique folder.
    os.makedirs(SAVE_ROOT, exist_ok=True)
    run_folder = "Capture_" + datetime.now().strftime("%Y%m%d_%H%M%S_%f")
    save_dir = os.path.join(SAVE_ROOT, run_folder)
    os.makedirs(save_dir, exist_ok=False)
    print("Images will be saved in:", save_dir)

    # Added: write PNG files in a separate thread, to minimize capture delays.
    image_queue = queue.Queue(maxsize=MAX_PENDING_IMAGES)
    counts = {"saved": 0, "failed": 0}

    def image_writer():
        while True:
            item = image_queue.get()
            try:
                if item is None:
                    return
                image_array, image_path = item
                # Same monochrome 8-bit pixels; PNG is lossless, no resize/filter/retouch.
                Image.fromarray(image_array, 'L').save(
                    image_path, format="PNG", compress_level=0
                )
                counts["saved"] += 1
            except Exception as exc:
                counts["failed"] += 1
                print("Failed to save image:", exc)
            finally:
                image_queue.task_done()

    writer_thread = threading.Thread(target=image_writer, daemon=False)
    writer_thread.start()

    stream_started = False
    accepted = 0
    queue_dropped = 0
    last_slot = -1
    stopped_early = False

    try:
        cv2.namedWindow("Galaxy Mono Preview (Q to quit)", cv2.WINDOW_NORMAL)

        # start data acquisition
        cam.stream_on()
        stream_started = True
        start_time = time.monotonic()
        record_start = start_time + WARMUP_TIME
        record_end = record_start + RECORD_TIME
        total_slots = FPS * RECORD_TIME
        print("Warm-up: 10 s. Preview is active; no frames will be saved yet.")
        recording_announced = False
        last_status_second = -1

        while time.monotonic() < record_end:
            # get raw image
            raw_image = cam.data_stream[0].get_image()
            if raw_image is None:
                print("Getting image failed.")
                if cv2.waitKey(1) & 0xFF == ord('q'):
                    stopped_early = True
                    break
                continue

            # create numpy array with data from raw image
            numpy_image = raw_image.get_numpy_array()
            if numpy_image is None:
                continue

            frame_time = time.monotonic()

            # Added: show the real, native-resolution camera image continuously.
            cv2.imshow("Galaxy Mono Preview (Q to quit)", numpy_image)
            if cv2.waitKey(1) & 0xFF == ord('q'):
                stopped_early = True
                break

            if frame_time < record_start:
                continue  # the first 10 seconds are warm-up; save nothing
            if frame_time >= record_end:
                break

            if not recording_announced:
                print("Warm-up complete. Recording real frames for 60 s...")
                recording_announced = True

            # Added: no more than one real camera frame in each 1/30 s slot.
            # Empty slots are skipped, never replaced or filled with fake frames.
            slot = int((frame_time - record_start) * FPS)
            if slot < 0 or slot >= total_slots or slot == last_slot:
                continue
            last_slot = slot

            # Added: time-based filename; frame ID also prevents name collisions.
            capture_time = datetime.now()
            filename = (capture_time.strftime("%Y%m%d_%H%M%S_%f")
                        + "_Frame_" + str(raw_image.get_frame_id()) + ".png")
            image_path = os.path.join(save_dir, filename)

            try:
                # Copy original pixel array before SDK reuses its capture buffer.
                image_queue.put_nowait((numpy_image.copy(), image_path))
                accepted += 1
            except queue.Full:
                queue_dropped += 1  # never synthesize/repeat images to make up a gap

            current_second = int(frame_time - record_start)
            if current_second != last_status_second:
                last_status_second = current_second
                print("Recording: %02d/%d s | Queued: %d | Frame ID: %d | %dx%d"
                      % (current_second + 1, RECORD_TIME, accepted,
                         raw_image.get_frame_id(), raw_image.get_height(),
                         raw_image.get_width()))

    finally:
        # stop data acquisition
        if stream_started:
            cam.stream_off()

        # close device
        cam.close_device()
        cv2.destroyAllWindows()

        # Wait until all genuine captured images have finished saving.
        image_queue.put(None)
        image_queue.join()
        writer_thread.join()

        print("\nCapture stopped early." if stopped_early else "\nCapture finished.")
        print("Folder:", save_dir)
        print("Genuine camera frames queued:", accepted)
        print("PNG images saved:", counts["saved"])
        print("Frames skipped because storage queue was full:", queue_dropped)
        print("Images that failed to save:", counts["failed"])
        print("No frame insertion, duplication, or interpolation was used.")


if __name__ == "__main__":
    main()
