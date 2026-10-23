# Bark Note Next Android delivery

Next uses application ID `com.barknote.bark_note.next` and launcher label `Bark Note Next`. The original app and its records remain installed separately. Records are not automatically transferred.

CI produces a temporary debug-signed APK. Before delivery, run `tool/sign_android_next.ps1` with InputApk, OutputApk, SigningDirectory and AndroidBuildTools. Set JAVA_HOME to JDK 17. The helper creates a local signing identity only on first use, then reuses it for every future Next update. Always preserve the same private signing directory and its password file. Never commit or upload either file. Future updates also require a higher Android version code.
