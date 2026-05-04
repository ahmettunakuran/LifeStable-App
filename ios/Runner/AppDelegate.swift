import UIKit
import Flutter
import GoogleMaps // Kritik: Bu satırı unutma

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Google Maps API Key — loaded from MapSecrets.plist (gitignored)
    if let path = Bundle.main.path(forResource: "MapSecrets", ofType: "plist"),
       let secrets = NSDictionary(contentsOfFile: path),
       let mapsKey = secrets["GoogleMapsAPIKey"] as? String {
      GMSServices.provideAPIKey(mapsKey)
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}