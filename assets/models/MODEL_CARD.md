# YAMNet model provenance

Google YAMNet classification TFLite model, 521 AudioSet classes, Apache-2.0.
Source: https://storage.googleapis.com/download.tensorflow.org/models/tflite/task_library/audio_classification/android/lite-model_yamnet_classification_tflite_1.tflite
Documentation: https://www.tensorflow.org/hub/tutorials/yamnet
SHA256: 10c95ea3eb9a7bb4cb8bddf6feb023250381008177ac162ce169694d05c317de
Retrieved: 2026-10-14 (Asia/Seoul)
Class map: https://github.com/tensorflow/models/blob/master/research/audioset/yamnet/yamnet_class_map.csv
License: LICENSE in this directory; Apache-2.0, TensorFlow Authors.

Input: float32 [15600], 16 kHz normalized mono waveform.
Output: float32 [1,521], multi-label sound event scores.
Dog index 69, Bark index 70, Speech index 0.

Unmodified pretrained weights. No dog emotion fine-tuning performed.
Threshold 0.30 is an app heuristic, not calibrated accuracy or probability.
