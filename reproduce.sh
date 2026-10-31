#!/usr/bin/env bash
#
# Reproduces the bug: exits 1 when the executable jar misses androidx.compose.runtime.Composer,
# 0 when it works, 2 when something else fails. Needs a JDK 25 on the PATH (java and jar).
# Works on Linux, macOS and Windows (Git Bash).
set -u
cd "$(dirname "$0")"

# In Git Bash, kotlin.bat runs through cmd, without the tools of Git on the PATH: it must find the tar.exe of
# Windows, not the GNU tar of Git, which reads "C:" as a host name.
case "$(uname -s)" in
  MINGW* | MSYS* | CYGWIN*)
    windows_path="$(printf '%s' "$PATH" | tr ':' '\n' | grep -vE '^/(usr|mingw64|bin)(/|$)' | paste -sd: -)"
    kotlin() { PATH="$windows_path" cmd //c kotlin.bat "$@"; }
    ;;
  *) kotlin() { ./kotlin "$@"; } ;;
esac
jar=build/tasks/_app_executableJarJvm/app-jvm-executable.jar

echo "== 1. kotlin run: the classpath of the module is correct"
kotlin run -m app --no-compose-hot-reload -- --check || exit 2

echo
echo "== 2. kotlin package -f executable-jar"
kotlin package -m app -f executable-jar || exit 2

echo
echo "== 3. Entries of the executable jar named runtime-desktop / runtime-saveable-desktop (size, name)"
jar tvf "$jar" | grep -E "BOOT-INF/lib/runtime(-saveable)?-desktop-" | awk '{print $1, $NF}'

echo
echo "== 4. java -jar"
if java -jar "$jar" --check; then
  echo
  echo "NOT REPRODUCED: the executable jar works."
  exit 0
fi
echo
echo "REPRODUCED: the executable jar misses androidx.compose.runtime.Composer."
echo "BOOT-INF/lib/runtime-desktop-1.12.1.jar is org.jetbrains.compose.runtime:runtime-desktop (a few KB, no"
echo "classes) instead of androidx.compose.runtime:runtime-desktop (1.9 MB), which has the same file name."
exit 1
