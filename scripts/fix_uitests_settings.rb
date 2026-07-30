# One-shot repair for the ChillMateUITests target's build settings, kept as a
# companion to add_uitests.rb.
#
# It used to write 'SWIFT_VERSION' => '5.0' unconditionally. Every target in this
# project is on Swift 6, and a single target left behind on Swift 5 is precisely
# the drift 4.2.1 was released to fix, so re-running this script would have undone
# that release. The version and the deployment target are copied from the app
# target now, which cannot drag anything backwards.
require 'xcodeproj'

project_path = 'ChillMate.xcodeproj'
project = Xcodeproj::Project.open(project_path)

app_target = project.targets.find { |t| t.name == 'ChillMate' }
if app_target.nil?
  puts "Could not find ChillMate target"
  exit 1
end

ui_test_target = project.targets.find { |t| t.name == 'ChillMateUITests' }
if ui_test_target.nil?
  puts "Could not find ChillMateUITests target"
  exit 1
end

def inherited_setting(target, name)
  target.build_configurations
        .map { |config| config.build_settings[name] }
        .compact
        .first
end

swift_version = inherited_setting(app_target, 'SWIFT_VERSION')
deployment_target = inherited_setting(app_target, 'IPHONEOS_DEPLOYMENT_TARGET')
if swift_version.nil? || deployment_target.nil?
  puts "Could not read SWIFT_VERSION / IPHONEOS_DEPLOYMENT_TARGET from the ChillMate target"
  exit 1
end

ui_test_target.build_configurations.each do |config|
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  config.build_settings['SWIFT_VERSION'] = swift_version
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = deployment_target
  config.build_settings['PRODUCT_NAME'] = 'ChillMateUITests'
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.bijthijs.chillmate.uitests'
  config.build_settings['TEST_TARGET_NAME'] = 'ChillMate'
end

project.save
puts "Successfully updated UI Tests target to Swift #{swift_version} / iOS #{deployment_target}."
