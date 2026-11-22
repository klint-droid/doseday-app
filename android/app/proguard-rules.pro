# Keep flutter_local_notifications models, receivers, and Gson TypeTokens for release builds
-keepattributes Signature, InnerClasses, EnclosingMethod, *Annotation*

-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keepnames class com.dexterous.flutterlocalnotifications.** { *; }

-keep class com.google.gson.** { *; }
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken { *; }

# Prevent stripping of raw sound and mipmap resources
-keepclassmembers class **.R$* {
    public static <fields>;
}
