# Extra keep rules for plugins that are invoked via JNI/reflection rather
# than plain Kotlin/Java calls — R8 can't see those call sites, so without
# an explicit keep it may strip or rename the very methods native code (or
# the framework) calls into by name, at runtime rather than compile time.
# The Flutter Gradle plugin already supplies its own default rules for the
# embedding itself; these cover the plugins this app actually uses on top.

# flutter_webrtc — native/JNI bridge classes.
-keep class org.webrtc.** { *; }
-keep class com.cloudwebrtc.webrtc.** { *; }
-dontwarn org.webrtc.**

# Firebase Messaging + flutter_local_notifications — services/receivers
# started by the framework via manifest entries + reflection.
-keep class com.google.firebase.messaging.** { *; }
-keep class com.dexterous.** { *; }

# Referenced by Flutter's deferred-components support even when this app
# doesn't use split delivery — otherwise R8 warns on the missing classes.
-dontwarn com.google.android.play.core.**
