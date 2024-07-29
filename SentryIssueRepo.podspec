Pod::Spec.new do |s|
  s.name             = "SentryIssueRepo"
  s.version          = "0.0.1"
  s.summary          = "Sentry Issue Demo"
  s.description      = <<-DESC
                       Sentry Issue Demo
                       DESC
  s.homepage         = "https://google.com"
  s.license          = { :type => 'Commercial License', :text => "Copyright 2024" }
  s.authors          = { "Evgenia Gorbacheva" => "https://google.com" }
  s.platforms        = { :ios => "12.4" }
  s.source           = { :http => "https://s3-us-west-1.amazonaws.com/appodeal-ios/SentryIssueRepo/v#{s.version}/SentryIssueRepo.zip" }
  
  # Ensure this path is correct and the xcframework is located there after unzipping
  s.vendored_frameworks = "SentryIssueRepo.xcframework"

  s.swift_versions    = ["4.0", "4.2", "5.0"]
  s.swift_version     = "5.0"

  s.dependencies      = {
                        "Sentry" => "= 8.22.0"
                       }

  s.pod_target_xcconfig = {
    "OTHER_LDFLAGS" => "-lObjC",
    "VALID_ARCHS[sdk=iphoneos*]" => "arm64 armv7",
    "VALID_ARCHS[sdk=iphonesimulator*]" => "x86_64 arm64"
  }

  s.user_target_xcconfig = {
    "OTHER_LDFLAGS" => "-lObjC"
  }
end
