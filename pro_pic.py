
import gxipy as gx
import cv2
import os
import time
import queue
import threading
from datetime import datetime

# =====================================
# 1. 参数设置
# =====================================

SAVE_ROOT = r"E:\Galaxy_SDK\pic"

FPS = 30
WARMUP_TIME = 10
RECORD_TIME = 60

EXPOSURE = 10000
GAIN = 10.0

# 最多缓存120帧，避免无限占用内存
QUEUE_SIZE = 120

# 预览每秒刷新约10次
PREVIEW_INTERVAL = 0.1

folder_name = datetime.now().strftime(
    "Capture_%Y%m%d_%H%M%S_%f"
)

SAVE_DIR = os.path.join(SAVE_ROOT, folder_name)
os.makedirs(SAVE_DIR, exist_ok=False)

image_queue = queue.Queue(maxsize=QUEUE_SIZE)

saved_count = 0
failed_count = 0
queue_drop_count = 0


# =====================================
# 2. 独立PNG保存线程
# =====================================

def save_worker():

    global saved_count, failed_count

    while True:

        item = image_queue.get()

        try:
            if item is None:
                break

            filename, frame = item

            path = os.path.join(
                SAVE_DIR,
                filename
            )

            # 无损PNG，压缩级别0以减少CPU开销
            success = cv2.imwrite(
                path,
                frame,
                [cv2.IMWRITE_PNG_COMPRESSION, 0]
            )

            if success:
                saved_count += 1
            else:
                failed_count += 1
                print("Save failed:", filename)

        except Exception as e:
            failed_count += 1
            print("Save error:", e)

        finally:
            image_queue.task_done()


# =====================================
# 3. 相机连接
# =====================================

def main():

    global queue_drop_count

    device_manager = gx.DeviceManager()

    dev_num, dev_info_list = (
        device_manager.update_device_list()
    )

    if dev_num == 0:
        print("No camera detected.")
        return

    cam = device_manager.open_device_by_index(1)

    streaming = False
    writer = None

    received_count = 0
    first_frame_id = None
    last_frame_id = None
    prev_frame_id = None
    frame_id_gaps = 0

    try:

        if cam.PixelColorFilter.is_implemented():
            print("Only mono cameras are supported.")
            return

        # 连续采集
        cam.TriggerMode.set(gx.GxSwitchEntry.OFF)

        # 保持之前的曝光与增益
        cam.ExposureTime.set(EXPOSURE)
        cam.Gain.set(GAIN)

        # 设置30 FPS
        if cam.AcquisitionFrameRateMode.is_implemented():
            cam.AcquisitionFrameRateMode.set(
                gx.GxSwitchEntry.ON
            )

        if cam.AcquisitionFrameRate.is_implemented():
            cam.AcquisitionFrameRate.set(FPS)

        cam.stream_on()
        streaming = True

        # 开启图片保存线程
        writer = threading.Thread(
            target=save_worker
        )
        writer.start()

        cv2.namedWindow(
            "Daheng Mono Camera",
            cv2.WINDOW_NORMAL
        )

        last_preview = 0

        # =====================================
        # 4. 预热10秒
        # =====================================

        print("Warmup: 10 seconds")

        warmup_start = time.perf_counter()

        while time.perf_counter() - warmup_start < WARMUP_TIME:

            raw_image = cam.data_stream[0].get_image(
                timeout=1000
            )

            if raw_image is None:
                continue

            frame = raw_image.get_numpy_array()

            if frame is None:
                continue

            now = time.perf_counter()

            if now - last_preview >= PREVIEW_INTERVAL:
                cv2.imshow("Daheng Mono Camera", frame)
                cv2.waitKey(1)
                last_preview = now

        # =====================================
        # 5. 正式录制60秒
        # =====================================

        print("Recording started.")
        print("Save directory:", SAVE_DIR)

        record_start = time.perf_counter()
        last_preview = record_start

        while time.perf_counter() - record_start < RECORD_TIME:

            raw_image = cam.data_stream[0].get_image(
                timeout=1000
            )

            receive_time = time.perf_counter()
            capture_time = datetime.now()

            if raw_image is None:
                continue

            if receive_time - record_start >= RECORD_TIME:
                break

            frame = raw_image.get_numpy_array()

            if frame is None:
                continue

            # 获取相机帧ID
            frame_id = raw_image.get_frame_id()

            if first_frame_id is None:
                first_frame_id = frame_id

            if prev_frame_id is not None:
                if frame_id > prev_frame_id + 1:
                    frame_id_gaps += (
                        frame_id - prev_frame_id - 1
                    )

            prev_frame_id = frame_id
            last_frame_id = frame_id

            received_count += 1

            # 使用接收时间命名
            image_name = capture_time.strftime(
                "%Y%m%d_%H%M%S_%f"
            ) + ".png"

            # 复制像素数据，不进行图像加工
            # 队列满时丢弃当前帧，不补帧
            try:
                image_queue.put_nowait(
                    (image_name, frame.copy())
                )
            except queue.Full:
                queue_drop_count += 1

            # 每秒仅更新约10次预览
            if receive_time - last_preview >= PREVIEW_INTERVAL:

                cv2.imshow(
                    "Daheng Mono Camera",
                    frame
                )

                cv2.waitKey(1)
                last_preview = receive_time

        record_elapsed = time.perf_counter() - record_start

    finally:

        # =====================================
        # 6. 释放相机
        # =====================================

        if streaming:
            cam.stream_off()

        cam.close_device()
        cv2.destroyAllWindows()

        # 等待队列中的全部图片保存完毕
        if writer is not None:
            image_queue.put(None)
            image_queue.join()
            writer.join()

    # =====================================
    # 7. 输出采集结果
    # =====================================

    print("\n================================")
    print("Acquisition finished.")
    print("Received frames:", received_count)
    print("Saved PNG:", saved_count)
    print("Save failed:", failed_count)
    print("Queue dropped:", queue_drop_count)
    print("Frame ID gaps:", frame_id_gaps)

    if received_count > 0:
        print("First Frame ID:", first_frame_id)
        print("Last Frame ID:", last_frame_id)

    print("Record time: %.2f s" % record_elapsed)

    if record_elapsed > 0:
        print(
            "Receive FPS: %.2f"
            % (received_count / record_elapsed)
        )

    print("Save directory:", SAVE_DIR)
    print("================================")


if __name__ == "__main__":
    main()
