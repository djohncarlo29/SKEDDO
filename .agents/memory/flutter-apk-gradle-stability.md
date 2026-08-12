---
name: Flutter APK Gradle stability
description: Release APK builds in this environment need bounded, non-daemon Gradle settings because OpenJDK can SIGBUS during compiler or worker fan-out.
---

The Gradle wrapper (`gradlew`) starts a JVM that reads `DEFAULT_JVM_OPTS` from the script itself — **not** from `gradle.properties`. When `org.gradle.daemon=false`, the build runs inside the wrapper JVM, so `org.gradle.jvmargs` in `gradle.properties` is only applied to a forked build process that never actually forks.

**Fix:** Set the perf-data flags directly in `gradlew`:
```bash
DEFAULT_JVM_OPTS="-XX:+PerfDisableSharedMem -XX:-UsePerfData"
```

The `hs_err_pid*.log` crash report will show `jvm_args: -Dorg.gradle.appname=gradlew` as the only arg if the wrapper JVM is the one crashing — confirming that `gradle.properties` flags were never seen.

Additional stability settings in `gradle.properties` (applied to the build process if one is forked):
- `-Xmx2G -XX:TieredStopAtLevel=1 -XX:+UseSerialGC`
- `org.gradle.daemon=false`, `org.gradle.parallel=false`, `org.gradle.workers.max=2`
- `kotlin.compiler.execution.strategy=in-process`

**Why:** The container environment has no swap and the OpenJDK performance monitoring subsystem memory-maps a file in `/tmp` (overlayfs), triggering SIGBUS on write.

**How to apply:** When upgrading Gradle or Flutter SDK, verify `DEFAULT_JVM_OPTS` in `android/gradlew` still has both perf flags. Run the APK build with these limits and keep preview rebuilds separate from APK builds because `flutter clean` removes the shared web build.
