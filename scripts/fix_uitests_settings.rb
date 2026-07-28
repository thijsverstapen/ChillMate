require 'xcodeproj'

project_path = 'ChillMate.xcodeproj'
project = Xcodeproj::Project.open(project_path)

ui_test_target = project.targets.find { |t| t.name == 'ChillMateUITests' }
if ui_test_target.nil?
  puts "Could not find ChillMateUITests target"
  exit 1
end

ui_test_target.build_configurations.each do |config|
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['PRODUCT_NAME'] = 'ChillMateUITests'
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.bijthijs.chillmate.uitests'
  config.build_settings['TEST_TARGET_NAME'] = 'ChillMate'
end

project.save
puts "Successfully updated UI Tests target build settings."
