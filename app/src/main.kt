import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composer
import androidx.compose.ui.window.Window
import androidx.compose.ui.window.application

fun main(args: Array<String>) {
    // `--check` only loads a class of androidx.compose.runtime and exits: no display needed (CI).
    println("Loaded ${Composer::class.java.name} from ${Composer::class.java.protectionDomain.codeSource?.location}")
    if ("--check" in args) return
    application {
        Window(onCloseRequest = ::exitApplication, title = "Executable jar collision") {
            BasicText("Hello from Compose")
        }
    }
}
