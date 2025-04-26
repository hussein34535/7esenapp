package tv.hesen.com

// Remove the default FlutterActivity import if present
// import io.flutter.embedding.android.FlutterActivity

// Import the wrapper class from the android_pip package
import com.thesparks.android_pip.PipCallbackHelperActivityWrapper

// Change FlutterActivity to PipCallbackHelperActivityWrapper
class MainActivity: PipCallbackHelperActivityWrapper() {
}
