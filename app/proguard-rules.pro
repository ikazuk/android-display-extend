-dontobfuscate

# Shizuku UserService (instantiated by Shizuku in a separate process by name)
-keep class io.github.jqssun.displayextend.shizuku.UserService { *; }
-keep class io.github.jqssun.displayextend.shizuku.IUserService { *; }
-keep class io.github.jqssun.displayextend.shizuku.IUserService$Stub { *; }

# AIDL generated
-keep class * implements android.os.IInterface { *; }

# Shizuku
-keep class rikka.shizuku.** { *; }
