# TeleMed_K ProGuard / R8 rules

# LiteRT-LM JNI callbacks — must not be renamed by R8
-keep class com.google.ai.edge.litertlm.** { *; }
-keepclassmembers class com.google.ai.edge.litertlm.** { *; }
-keepnames class com.google.ai.edge.litertlm.** { *; }
-keep interface com.google.ai.edge.litertlm.** { *; }
-keepclassmembers interface com.google.ai.edge.litertlm.** { *; }

# Preserve JNI callback method signatures
-keepclasseswithmembernames class * {
    native <methods>;
}
-keepclassmembers class * implements
    com.google.ai.edge.litertlm.LiteRtLmJni$JniMessageCallback {
    void onMessage(java.lang.String);
    void onDone();
    void onError(java.lang.String);
}
