#
# Be sure to run `pod lib lint AsyncCoreData.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'AsyncCoreData'
  s.version          = '1.2.1'
  s.summary          = 'Thread safe And Memory cached models for core data usage'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
高效、便捷、安全的CoreData数据库管理类，再也没有线程安全的苦恼了
Thread safe And Memory cached models for core data usage
                       DESC

  s.homepage         = 'https://github.com/Roen-Ro/AsyncCoreData'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { '罗亮富' => 'zxllf23@163.com' }
  s.source           = { :git => 'https://github.com/Roen-Ro/AsyncCoreData.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '8.0'
  s.macos.deployment_target = '10.8'
  
  s.source_files = 'AsyncCoreData/Classes/**/*'
  
  # s.resource_bundles = {
  #   'AsyncCoreData' => ['AsyncCoreData/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
end
