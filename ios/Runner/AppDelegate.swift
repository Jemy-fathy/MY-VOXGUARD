import UIKit
import Flutter
import GoogleMaps // 1. تأكد من وجود السطر ده

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 2. ضيف السطر ده وحط الـ API Key بتاعك مكان النجوم
    GMSServices.provideAPIKey("YOUR_API_KEY_HERE")
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}