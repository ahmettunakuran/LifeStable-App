import UIKit
import Flutter
import GoogleMaps // Kritik: Bu satırı unutma

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Google Maps API Key Kaydı
    GMSServices.provideAPIKey(Bundle.main.object(forInfoDictionaryKey: "GoogleMapsAPIKey") as! String)

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}