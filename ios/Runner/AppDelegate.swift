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
    GMSServices.provideAPIKey("AIzaSyAbudXZrK3MD2osUSzLrBq-7_O0ozas7jE")

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}