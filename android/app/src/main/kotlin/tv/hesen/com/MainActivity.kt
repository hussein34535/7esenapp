package tv.hesen.com

import io.flutter.embedding.android.FlutterActivity
import android.os.Bundle // Required for onCreate
// import com.unity3d.ads.IUnityAdsInitializationListener
// import com.unity3d.ads.IUnityAdsLoadListener
// import com.unity3d.ads.UnityAds

// Change FlutterActivity to PipCallbackHelperActivityWrapper
class MainActivity: FlutterActivity() { // Removed IUnityAdsInitializationListener

    // private val UNITY_GAME_ID = "5862917" // Replace with your Game ID
    // private val AD_UNIT_ID_INTERSTITIAL = "Interstitial_Android" // Replace with your Ad Unit ID
    // private val TEST_MODE = false // Set to false for production

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Initialize Unity Ads (Disabled temporarily)
        // UnityAds.initialize(applicationContext, UNITY_GAME_ID, TEST_MODE, this)
    }

    // Implement IUnityAdsInitializationListener methods (Disabled temporarily)
    /*
    override fun onInitializationComplete() {
        // Unity Ads is initialized, now load an ad
        UnityAds.load(AD_UNIT_ID_INTERSTITIAL, object : IUnityAdsLoadListener {
            override fun onUnityAdsAdLoaded(placementId: String) {
                // Ad loaded successfully
                // You can optionally show the ad immediately or store a reference to show later
                // For example, to show immediately (not recommended for app start):
                // UnityAds.show(this@MainActivity, AD_UNIT_ID_INTERSTITIAL, object : IUnityAdsShowListener { ... })
            }

            override fun onUnityAdsFailedToLoad(placementId: String, error: UnityAds.UnityAdsLoadError, message: String) {
                // Ad failed to load
            }
        })
    }

    override fun onInitializationFailed(error: UnityAds.UnityAdsInitializationError, message: String) {
        // Unity Ads initialization failed
    }
    */
}
