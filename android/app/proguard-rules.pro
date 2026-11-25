# MediaPipe resolves JNI classes, protobuf fields and logging callers at runtime.
-keep class com.google.mediapipe.** { *; }
-keep class com.google.common.flogger.** { *; }
-keepclassmembers class * extends com.google.protobuf.GeneratedMessageLite {
    <fields>;
}

# Optional graph template and profiler types omitted from the Tasks AAR.
-dontwarn com.google.mediapipe.proto.CalculatorProfileProto$CalculatorProfile
-dontwarn com.google.mediapipe.proto.GraphTemplateProto$CalculatorGraphTemplate
