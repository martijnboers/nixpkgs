# Compatibility stubs for packages that used the old SDK frameworks.
# TODO(@reckenrode) Make these stubs warn after framework usage has been cleaned up in nixpkgs.
{
  lib,
  callPackage,
  newScope,
  overrideSDK,
  pkgs,
  stdenv,
  stdenvNoCC,
}:

let
  mkStub = callPackage ../apple-sdk/mk-stub.nix { } "12.3";
in
lib.genAttrs [
  "CLTools_Executables"
  "Libsystem"
  "LibsystemCross"
  "darwin-stubs"
  "libnetwork"
  "libpm"
  "libunwind"
  "objc4"
  "sdkRoot"
] mkStub
// {
  frameworks = lib.genAttrs [
    "AGL"
    "AVFAudio"
    "AVFCapture"
    "AVFCore"
    "AVFoundation"
    "AVKit"
    "Accelerate"
    "Accessibility"
    "Accounts"
    "AdServices"
    "AdSupport"
    "AddressBook"
    "AddressBookCore"
    "AppKit"
    "AppTrackingTransparency"
    "AppleScriptKit"
    "AppleScriptObjC"
    "ApplicationServices"
    "AudioToolbox"
    "AudioToolboxCore"
    "AudioUnit"
    "AudioVideoBridging"
    "AuthenticationServices"
    "AutomaticAssessmentConfiguration"
    "Automator"
    "BackgroundTasks"
    "BusinessChat"
    "CFNetwork"
    "CHIP"
    "CalendarStore"
    "CallKit"
    "Carbon"
    "ClassKit"
    "CloudKit"
    "Cocoa"
    "Collaboration"
    "ColorSync"
    "Combine"
    "Contacts"
    "ContactsPersistence"
    "ContactsUI"
    "CoreAudio"
    "CoreAudioKit"
    "CoreAudioTypes"
    "CoreBluetooth"
    "CoreData"
    "CoreDisplay"
    "CoreFoundation"
    "CoreGraphics"
    "CoreHaptics"
    "CoreImage"
    "CoreLocation"
    "CoreMIDI"
    "CoreMIDIServer"
    "CoreML"
    "CoreMedia"
    "CoreMediaIO"
    "CoreMotion"
    "CoreServices"
    "CoreSpotlight"
    "CoreSymbolication"
    "CoreTelephony"
    "CoreText"
    "CoreVideo"
    "CoreWLAN"
    "CreateML"
    "CryptoKit"
    "CryptoTokenKit"
    "DVDPlayback"
    "DataDetection"
    "DebugSymbols"
    "DeveloperToolsSupport"
    "DeviceActivity"
    "DeviceCheck"
    "DirectoryService"
    "DiscRecording"
    "DiscRecordingUI"
    "DiskArbitration"
    "DisplayServices"
    "DriverKit"
    "EventKit"
    "ExceptionHandling"
    "ExecutionPolicy"
    "ExposureNotification"
    "ExternalAccessory"
    "FWAUserLib"
    "FileProvider"
    "FileProviderUI"
    "FinderSync"
    "ForceFeedback"
    "Foundation"
    "GLKit"
    "GLUT"
    "GSS"
    "GameCenterFoundation"
    "GameCenterUI"
    "GameCenterUICore"
    "GameController"
    "GameKit"
    "GameplayKit"
    "GroupActivities"
    "Hypervisor"
    "ICADevices"
    "IMServicePlugIn"
    "IOBluetooth"
    "IOBluetoothUI"
    "IOKit"
    "IOSurface"
    "IOUSBHost"
    "IdentityLookup"
    "ImageCaptureCore"
    "ImageIO"
    "InputMethodKit"
    "InstallerPlugins"
    "InstantMessage"
    "Intents"
    "IntentsUI"
    "JavaNativeFoundation"
    "JavaRuntimeSupport"
    "JavaScriptCore"
    "JavaVM"
    "Kerberos"
    "Kernel"
    "KernelManagement"
    "LDAP"
    "LatentSemanticMapping"
    "LinkPresentation"
    "LocalAuthentication"
    "LocalAuthenticationEmbeddedUI"
    "MLCompute"
    "MailKit"
    "ManagedSettings"
    "MapKit"
    "MediaAccessibility"
    "MediaLibrary"
    "MediaPlayer"
    "MediaToolbox"
    "Message"
    "Metal"
    "MetalKit"
    "MetalPerformanceShaders"
    "MetalPerformanceShadersGraph"
    "MetricKit"
    "ModelIO"
    "MultipeerConnectivity"
    "MultitouchSupport"
    "MusicKit"
    "NaturalLanguage"
    "NearbyInteraction"
    "NetFS"
    "Network"
    "NetworkExtension"
    "NotificationCenter"
    "OSAKit"
    "OSLog"
    "OpenAL"
    "OpenCL"
    "OpenDirectory"
    "OpenGL"
    "PCSC"
    "PDFKit"
    "PHASE"
    "ParavirtualizedGraphics"
    "PassKit"
    "PassKitCore"
    "PencilKit"
    "Photos"
    "PhotosUI"
    "PreferencePanes"
    "PushKit"
    "QTKit"
    "Quartz"
    "QuartzCore"
    "QuickLook"
    "QuickLookThumbnailing"
    "QuickLookUI"
    "QuickTime"
    "RealityFoundation"
    "RealityKit"
    "ReplayKit"
    "Ruby"
    "SafariServices"
    "SceneKit"
    "ScreenCaptureKit"
    "ScreenSaver"
    "ScreenTime"
    "ScriptingBridge"
    "Security"
    "SecurityFoundation"
    "SecurityInterface"
    "SensorKit"
    "ServiceManagement"
    "ShazamKit"
    "SignpostMetrics"
    "SkyLight"
    "Social"
    "SoundAnalysis"
    "Speech"
    "SpriteKit"
    "StoreKit"
    "SwiftUI"
    "SyncServices"
    "System"
    "SystemConfiguration"
    "SystemExtensions"
    "TWAIN"
    "TabularData"
    "Tcl"
    "Tk"
    "UIFoundation"
    "URLFormatting"
    "UniformTypeIdentifiers"
    "UserNotifications"
    "UserNotificationsUI"
    "VideoDecodeAcceleration"
    "VideoSubscriberAccount"
    "VideoToolbox"
    "Virtualization"
    "Vision"
    "WebKit"
    "WidgetKit"
    "iTunesLibrary"
    "vmnet"
  ] mkStub;

  libs = lib.genAttrs [
    "Xplugin"
    "utmp"
    "libDER"
    "xpc"
    "sandbox"
    "simd"
    "utmp"
    "xpc"
  ] mkStub;

  version = "12.3";
}