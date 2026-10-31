# Kotlin Toolchain: `package -f executable-jar` drops jars whose file names collide

Minimal reproduction of a bug of the [Kotlin Toolchain](https://kotlin-toolchain.org/) 0.13.0 (formerly Amper):
the executable jar of a Compose Multiplatform desktop app fails at startup, while `kotlin run` of the same module
works.

```
Exception in thread "main" java.lang.reflect.InvocationTargetException
Caused by: java.lang.NoClassDefFoundError: androidx/compose/runtime/Composer
Caused by: java.lang.ClassNotFoundException: androidx.compose.runtime.Composer
```

## Reproduce

With a JDK 25 on the `PATH`:

```sh
./reproduce.sh
```

It exits with 1 when the bug is reproduced, 0 when the executable jar works. The [Reproduce](.github/workflows/reproduce.yml)
workflow runs it on Linux, Windows and macOS: a failed job means the bug is reproduced.

What the script does, by hand:

```sh
./kotlin run -m app --no-compose-hot-reload -- --check   # works: loads androidx.compose.runtime.Composer
./kotlin package -m app -f executable-jar
java -jar build/tasks/_app_executableJarJvm/app-jvm-executable.jar --check   # NoClassDefFoundError
```

`--check` only loads a class of `androidx.compose.runtime` and exits, so no display is needed. Without it, the app
opens a Compose window.

The whole project is [app/module.yaml](app/module.yaml):

```yaml
product: jvm/app

dependencies:
  - $compose.desktop.currentOs

settings:
  compose: enabled
  jvm:
    mainClass: MainKt
```

and [app/src/main.kt](app/src/main.kt).

## Cause

The executable jar stores each dependency as `BOOT-INF/lib/<file name>`. Two different artifacts of the runtime
classpath have the same file name, and only one of them is kept: the empty one.

| Artifact | File name | Size | Kept |
|---|---|---|---|
| `org.jetbrains.compose.runtime:runtime-desktop:1.12.1` | `runtime-desktop-1.12.1.jar` | 4.8 KB, KMP redirect, no classes | yes |
| `androidx.compose.runtime:runtime-desktop:1.12.1` | `runtime-desktop-1.12.1.jar` | 1.9 MB, the classes | no |
| `org.jetbrains.compose.runtime:runtime-saveable-desktop:1.12.1` | `runtime-saveable-desktop-1.12.1.jar` | 4.9 KB, KMP redirect | yes |
| `androidx.compose.runtime:runtime-saveable-desktop:1.12.1` | `runtime-saveable-desktop-1.12.1.jar` | 54 KB, the classes | no |

The resolved runtime classpath itself is correct: `kotlin run` puts both jars on the classpath, and so does
`${module.runtimeClasspath}` in a plugin task (`resolvedFiles`, with full paths).

## Expected

Every jar of the runtime classpath ends up in the executable jar, for example under a name that includes the group
(`androidx.compose.runtime-runtime-desktop-1.12.1.jar`), or with a suffix when a name is already taken.

## Tested on

| | |
|---|---|
| OS | Linux Mint 22.3 (based on Ubuntu 24.04 "noble"), x86_64 |
| Kernel | Linux 7.0.0-42-generic |
| Desktop session | X11, Cinnamon (not used by `--check`) |
| JDK | Temurin 25.0.5, for `kotlin run` and `java -jar` |
| Kotlin Toolchain | 0.13.0 (the `kotlin` / `kotlin.bat` wrappers of this repository) |
| Compose Multiplatform | 1.12.1, the default of Kotlin Toolchain 0.13.0 |

Also reproduced by the [Reproduce](.github/workflows/reproduce.yml) workflow on the GitHub-hosted runners
`ubuntu-24.04`, `windows-latest` and `macos-15`, with Temurin 25:
[run 41247017573](https://github.com/brandondurandpro/kotlin-toolchain-executable-jar-collision/actions/runs/41247017573)
(each job fails because the bug is reproduced).

## Workaround

Do not ship the executable jar: package the application from the resolved classpath instead, with a local plugin
task that copies `${module.runtimeClasspath}` (`resolvedFiles`) under unique names and runs `jpackage` on them.
