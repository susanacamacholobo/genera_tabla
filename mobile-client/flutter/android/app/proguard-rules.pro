# LiteRT-LM's native library looks up this Java/Kotlin API by its original
# class and member names. Keep the complete JNI surface in release builds.
-keep class com.google.ai.edge.litertlm.** { *; }

# Preserve native method declarations and all types in their descriptors.
-keepclasseswithmembernames,includedescriptorclasses class * {
    native <methods>;
}
