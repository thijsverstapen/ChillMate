require 'xcodeproj'

project_path = 'ChillMate.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find main app target
app_target = project.targets.find { |t| t.name == 'ChillMate' }
if app_target.nil?
  puts "Could not find ChillMate target"
  exit 1
end

# Create UI Test target
ui_test_target = project.new_target(:ui_test_bundle, 'ChillMateUITests', :ios, '17.2', nil, :swift)

# Link it to the app target
ui_test_target.add_dependency(app_target)

# Add files to the target
group = project.main_group.find_subpath('ChillMateUITests', true)
group.set_source_tree('<group>')
group.set_path('ChillMateUITests')

file_ref1 = group.new_file('ChillMateUITests.swift')
file_ref2 = group.new_file('SnapshotHelper.swift')

ui_test_target.source_build_phase.add_file_reference(file_ref1)
ui_test_target.source_build_phase.add_file_reference(file_ref2)

# Enable Testability
app_target.build_configurations.each do |config|
  config.build_settings['ENABLE_TESTABILITY'] = 'YES'
end

project.save

# Now update the scheme to include this target for testing
scheme_path = Xcodeproj::XCScheme.shared_data_dir(project_path) + '/ChillMate.xcscheme'
scheme = Xcodeproj::XCScheme.new(scheme_path)

test_action = scheme.test_action
testable_ref = Xcodeproj::XCScheme::TestAction::TestableReference.new(ui_test_target)
test_action.add_testable(testable_ref)

scheme.save_as(project_path, 'ChillMate', true)

puts "Successfully added UI Tests target and updated scheme."
