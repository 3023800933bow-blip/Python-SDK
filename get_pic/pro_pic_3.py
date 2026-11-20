# version:1.0.1905.9051
# Based on Daheng Galaxy SDK official sample: GxSingleCamMono.py
# 仅增加：30 FPS目标、10秒预热、60秒采集、实时预览、时间命名、独立文件夹、异步无损PNG保存及采集统计。
# 不补帧，不插帧，不重采样，不对保存图像进行缩放/裁剪/滤波/亮度调整。

import gxipy as gx
from PIL import Image
import cv2
import csv
import os
import queue
import threading
import time
from datetime import datetime


# ==================== 可修改参数 ====================
SAVE_ROOT = r"D:\pycharm\pic"
CAMERA_INDEX = 1      # 与原始例程一致
TARGET_FPS = 30
WARMUP_SECONDS = 10
RECORD_SECONDS = 60
EXPOSURE_US = 10000    # 与原始例程一致
GAIN = 10.0           # 与原始例程一致
QUEUE_SIZE = 120      # 最多缓存120张真实帧；满时丢弃当前帧，不补帧
PREVIEW_INTERVAL = 0.1  # 每0.1秒刷新一次显示，减少预览开销
SAVE_TIMESTAMPS_CSV = True  # 同文件夹额外保存时间戳记录，便于检查实际帧间隔
PREVIEW_TITLE = "Daheng Mono Camera - Press Q to stop"
# ====================================================


def try_set_camera_fps(cam):
    """尽量由相机硬件限制输出帧率；不通过软件复制/合成帧。"""
    try:
        mode = getattr(cam, "AcquisitionFrameRateMode", None)
        if mode is not None and mode.is_implemented():
            mode.set(gx.GxSwitchEntry.ON)

        rate = getattr(cam, "AcquisitionFrameRate", None)
        if rate is not None and rate.is_implemented():
            rate.set(float(TARGET_FPS))
            try:
                print("相机帧率设置值: %.3f FPS" % rate.get())
            except Exception:
                print("已请求相机输出: %d FPS" % TARGET_FPS)
        else:
            print("警告：相机未提供 AcquisitionFrameRate，无法保证输出30 FPS。")
    except Exception as exc:
        print("警告：设置硬件帧率失败：%s" % exc)
        print("仍然采集真实到达的帧，不进行人为补帧或时间槽抽帧。")


def save_worker(image_queue, save_dir, saved_names, stats):
    """仅在此线程保存PNG，降低磁盘写入阻塞取图的风险。"""
    while True:
        item = image_queue.get()
        try:
            if item is None:
                return
            filename, pixels = item
            path = os.path.join(save_dir, filename)
            try:
                # 自动保留uint8/uint16灰度像素位深，不改变像素值。
                Image.fromarray(pixels).save(path, format="PNG", compress_level=0)
                saved_names.add(filename)
                stats["saved"] += 1
            except Exception as exc:
                stats["failed"] += 1
                print("图片保存失败: %s (%s)" % (filename, exc))
                # 保存中断可能留下不完整文件，尽力删除。
                try:
                    if os.path.exists(path):
                        os.remove(path)
                except OSError:
                    pass
        finally:
            image_queue.task_done()


def export_timestamps(save_dir, rows, saved_names):
    csv_path = os.path.join(save_dir, "frame_timestamps.csv")
    with open(csv_path, "w", newline="", encoding="utf-8-sig") as f:
        writer = csv.writer(f)
        writer.writerow([
            "sequence", "receive_time", "relative_time_s", "frame_id",
            "filename", "save_status"
        ])
        for sequence, stamp, relative_time, frame_id, filename, queued in rows:
            if not queued:
                status = "queue_full"
            elif filename in saved_names:
                status = "saved"
            else:
                status = "save_failed"
            writer.writerow([
                sequence, stamp, "%.6f" % relative_time,
                frame_id, filename, status
            ])
    return csv_path


def main():
    # 保留SDK原始逻辑：寻找相机，打开第一台单色相机，关闭触发，固定曝光/增益。
    print("-------------------------------------------------------------")
    print("Galaxy Mono: 10 s warm-up + 60 s recording @ target 30 FPS")
    print("-------------------------------------------------------------")

    device_manager = gx.DeviceManager()
    dev_num, dev_info_list = device_manager.update_device_list()
    if dev_num == 0:
        print("未发现相机。")
        return

    cam = device_manager.open_device_by_index(CAMERA_INDEX)
    streaming = False
    writer_thread = None
    save_dir = None
    image_queue = queue.Queue(maxsize=QUEUE_SIZE)
    saved_names = set()
    stats = {"saved": 0, "failed": 0, "queue_full": 0, "received": 0,
             "frame_id_gaps": 0, "none_frames": 0}
    rows = []
    first_frame_id = None
    last_frame_id = None
    previous_frame_id = None
    first_receive = None
    last_receive = None
    stopped_early = False
    record_start = None
    record_end = None

    try:
        if cam.PixelColorFilter.is_implemented() is True:
            print("原程序只支持单色相机。")
            return

        cam.TriggerMode.set(gx.GxSwitchEntry.OFF)
        cam.ExposureTime.set(EXPOSURE_US)
        cam.Gain.set(GAIN)
        try_set_camera_fps(cam)

        # 每次启动创建一个新文件夹；到这一步才创建，避免无相机时生成空文件夹。
        os.makedirs(SAVE_ROOT, exist_ok=True)
        folder_name = "Capture_" + datetime.now().strftime("%Y%m%d_%H%M%S_%f")
        save_dir = os.path.join(SAVE_ROOT, folder_name)
        os.makedirs(save_dir, exist_ok=False)
        print("本次保存文件夹：", save_dir)

        cv2.namedWindow(PREVIEW_TITLE, cv2.WINDOW_NORMAL)
        cam.stream_on()
        streaming = True

        writer_thread = threading.Thread(
            target=save_worker,
            args=(image_queue, save_dir, saved_names, stats),
            name="PNGWriter",
            daemon=False
        )
        writer_thread.start()

        # 采用高精度单调时钟控制持续时间；预热中持续取帧但不保存。
        warmup_start = time.perf_counter()
        record_start = warmup_start + WARMUP_SECONDS
        record_end = record_start + RECORD_SECONDS
        last_preview = float("-inf")
        last_progress = -1
        recording_announced = False
        print("开始预热：%d秒，不保存图像；预览窗口中按Q可退出。" % WARMUP_SECONDS)

        while True:
            if time.perf_counter() >= record_end:
                break

            # 保留原始SDK的取图方式，仅增加超时避免长期无响应。
            raw_image = cam.data_stream[0].get_image(timeout=1000)
            receive_clock = time.perf_counter()
            receive_wall = datetime.now()  # 图像抵达程序的时间，非相机硬件曝光时间

            if raw_image is None:
                stats["none_frames"] += 1
                if cv2.waitKey(1) & 0xFF == ord("q"):
                    stopped_early = True
                    break
                continue

            numpy_image = raw_image.get_numpy_array()
            if numpy_image is None:
                stats["none_frames"] += 1
                continue

            # 实时预览单独限频；保存的数据取自未处理的原始numpy数组。
            if receive_clock - last_preview >= PREVIEW_INTERVAL:
                cv2.imshow(PREVIEW_TITLE, numpy_image)
                last_preview = receive_clock
                if cv2.waitKey(1) & 0xFF == ord("q"):
                    stopped_early = True
                    break

            if receive_clock < record_start:
                continue  # 仅预热，不保存
            if receive_clock >= record_end:
                break

            if not recording_announced:
                print("预热结束，开始保存60秒真实采集帧。")
                recording_announced = True

            frame_id = int(raw_image.get_frame_id())
            stats["received"] += 1
            sequence = stats["received"]
            if first_frame_id is None:
                first_frame_id = frame_id
                first_receive = receive_clock
            if previous_frame_id is not None and frame_id > previous_frame_id + 1:
                stats["frame_id_gaps"] += frame_id - previous_frame_id - 1
            previous_frame_id = frame_id
            last_frame_id = frame_id
            last_receive = receive_clock

            # 时间前缀 + 录制序号 + SDK帧ID：按时间排序，且避免文件名重名。
            timestamp = receive_wall.strftime("%Y%m%d_%H%M%S_%f")
            filename = "%s_%05d_FID%010d.png" % (timestamp, sequence, frame_id)
            relative_time = receive_clock - record_start
            queued = False
            try:
                # 只为真实采集帧拷贝一次像素，避免SDK下一帧覆盖缓存。
                # 队列满直接丢弃当前帧，不阻塞主采集、不补帧。
                if image_queue.full():
                    raise queue.Full
                image_queue.put_nowait((filename, numpy_image.copy()))
                queued = True
            except queue.Full:
                stats["queue_full"] += 1

            if SAVE_TIMESTAMPS_CSV:
                rows.append((sequence, receive_wall.isoformat(timespec="microseconds"),
                             relative_time, frame_id, filename, queued))

            elapsed_second = int(relative_time)
            if elapsed_second // 5 != last_progress:
                last_progress = elapsed_second // 5
                print("采集中：%2d/%d秒 | 实收:%d | 队列丢帧:%d" % (
                    min(elapsed_second + 1, RECORD_SECONDS), RECORD_SECONDS,
                    stats["received"], stats["queue_full"]))

    except KeyboardInterrupt:
        stopped_early = True
        print("\n用户中断采集。")
    finally:
        # 保证发生异常或用户提前退出时，也会先停止相机，再写完队列里的图片。
        if streaming:
            try:
                cam.stream_off()
            except Exception as exc:
                print("停止采集异常：", exc)
        try:
            cam.close_device()
        except Exception as exc:
            print("关闭相机异常：", exc)
        try:
            cv2.destroyAllWindows()
        except Exception as exc:
            print("关闭预览窗口异常：", exc)

        if writer_thread is not None:
            image_queue.put(None)  # 如队列满，则等待保存线程腾出空间
            image_queue.join()
            writer_thread.join()

        if save_dir is not None:
            if SAVE_TIMESTAMPS_CSV:
                try:
                    csv_path = export_timestamps(save_dir, rows, saved_names)
                    print("时间戳记录：", csv_path)
                except Exception as exc:
                    print("警告：时间戳CSV保存失败：", exc)

            print("\n================= 采集结果 =================")
            print("状态：", "提前结束" if stopped_early else "采集结束")
            print("预期帧率：%d FPS；预热：%d秒；正式录制：%d秒" % (
                TARGET_FPS, WARMUP_SECONDS, RECORD_SECONDS))
            print("正式采集收到的真实帧：", stats["received"])
            print("成功保存PNG：", stats["saved"])
            print("写文件失败：", stats["failed"])
            print("队列满导致丢帧：", stats["queue_full"])
            print("帧ID正向跳号数：", stats["frame_id_gaps"])
            print("取图失败/无有效数组次数：", stats["none_frames"])
            if stats["received"]:
                print("首帧ID：%s；末帧ID：%s" % (first_frame_id, last_frame_id))
                # 观察到的帧间隔平均值（不把首尾两端的空档当作帧间隔）。
                if stats["received"] > 1 and last_receive > first_receive:
                    measured_fps = (stats["received"] - 1) / (last_receive - first_receive)
                    print("实际接收帧率：%.3f FPS（按首末接收时间计算）" % measured_fps)
            print("图片目录：", save_dir)
            print("没有补帧、插帧、重复帧；PNG保存的灰度像素未加工。")
            print("============================================")


if __name__ == "__main__":
    main()
