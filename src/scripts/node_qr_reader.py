#!/usr/bin/env python3.7
import rospy
import threading
import time
from helpers.image_converter import msg_to_cv2
import detector.qr_detector as qr_detector
from std_msgs.msg import String
from konenako.msg import image, qr_observation, polygon, boundingbox, point64
from konenako.srv import new_frequency, new_frequencyResponse


class QRReader:
    # Frequency in hertz
    qr_run_frequency = 10
    qr_period = 1.0 / qr_run_frequency

    last_detect = 0  # Last time detect() was called
    detect_lock = threading.Lock(
    )  # Locked, while detect() is being run, we detect() only 1 image at time

    frequency_change_lock = threading.Lock()

    def change_frequency(self, new_frequency):
        with self.frequency_change_lock:
            self.qr_run_frequency = new_frequency.data
            self.qr_period = 1.0 / self.qr_run_frequency
            return new_frequencyResponse(
                "QR detector freq set to {}, period {}".format(
                    self.qr_run_frequency, self.qr_period))

    def receive_img(self, msg: image):
        # Detect from this image, if not already detecting from another image and within period time constraints
        if self.detect_on and (
                time.time() - self.last_detect
        ) > self.qr_period and self.detect_lock.acquire(False):
            self.detect(msg)

    def __init__(self, on: bool = False):
        self.detect_on = on

        # Results are published as qr_observation.msg ROS messages.
        self.pub = rospy.Publisher("qr_results", qr_observation, queue_size=50)

        # Camera feed is read from ros messages
        self.input_sub = rospy.Subscriber("camera_feed", image,
                                          self.receive_img)

        # ROS service for changing detection frequency.
        frequency_service = rospy.Service('qr_frequency', new_frequency,
                                          self.change_frequency)

    def detect(self, msg: image):
        # For tracking the frequency
        self.last_detect = time.time()
        period = self.qr_period

        # Convert image from Image message to numpy ndarray
        img = msg_to_cv2(msg)

        # Detect QR codes with qr_detector.py
        observations = qr_detector.detect(img)
        for o in observations:
            obs = qr_observation(
                str(o["data"]),
                boundingbox(o["bbox"]["top"], o["bbox"]["right"],
                            o["bbox"]["bottom"], o["bbox"]["left"]),
                polygon(len(o["polygon"]), [
                    point64(o["polygon"][0]["x"], o["polygon"][0]["y"]),
                    point64(o["polygon"][1]["x"], o["polygon"][1]["y"]),
                    point64(o["polygon"][2]["x"], o["polygon"][2]["y"]),
                    point64(o["polygon"][3]["x"], o["polygon"][3]["y"])
                ]))
            self.pub.publish(obs)

        processing_time = time.time() - self.last_detect
        if processing_time > period:
            print("Detecting QR-code took {}, while the period was set to {}!".
                  format(processing_time,
                         period))  # TODO: Announce "warnings" to topic

        # Ready to detect the next image
        self.detect_lock.release()


if __name__ == "__main__":
    qr_reader = QRReader(True)
    rospy.init_node("qr_node")
    rospy.spin()