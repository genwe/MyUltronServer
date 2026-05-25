Pod::Spec.new do |s|
  s.name             = 'MyUltronServer'
  s.version          = '0.1.5'
  s.summary          = 'MyUltronServer — an embeddable TCP debug server for iOS apps.'
  s.description      = <<-DESC
MyUltronServer enables real-time two-way communication between a host iOS application
and the MyUltron desktop client via a custom TCP binary protocol.

Features:
- Auto-starting TCP socket server on a configurable port
- Custom usbmux-compatible binary packet protocol (Ping/Pong/JSON/Binary)
- Message-type-based routing system for extensible business modules
- Built-in modules: handshake (version exchange) and appInfo (metadata reporting)
- Lightweight: only Foundation + CocoaAsyncSocket dependency
- Background/foreground resilience

Integration: add `pod 'MyUltronServer'` to your Podfile, then in your AppDelegate
call `[[MyUltronManager sharedInstance] start]` — the server auto-starts on +load.
                       DESC

  s.homepage         = 'https://github.com/genwe/MyUltronServer'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'genwe' => 'weareroot@163.com' }
  s.source           = { :git => 'https://github.com/genwe/MyUltronServer.git', :tag => s.version.to_s }

  s.ios.deployment_target = '13.0'

  s.source_files = 'Sources/MyUltronServer/**/*.{h,m,mm}'

  s.public_header_files = [
    'Sources/MyUltronServer/include/MyUltronServer.h',
    'Sources/MyUltronServer/Manager/MyUltronManager.h',
  ]

  s.frameworks = 'Foundation', 'UIKit'

  s.dependency 'CocoaAsyncSocket', '~> 7.6'

  s.pod_target_xcconfig = {
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++14',
    'OTHER_CFLAGS' => '-fobjc-arc',
  }
end
