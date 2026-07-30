# One-shot bootstrap: creates the ChillMateUITests target and registers it with
# the shared scheme. It has already run; this is kept only for rebuilding the
# target from nothing.
#
# It used to hard-code ':ios, "17.2"', so re-running it would have re-created the
# target nine releases below the app's own deployment target. A test bundle
# requiring a different iOS than the app is one of the build-setting drifts 4.2.1
# had to fix, so anything that can be inherited is read from the app target now
# rather than written from memory here.
require 'xcodeproj'

project_path = 'ChillMate.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find main app target
app_target = project.targets.find { |t| t.name == 'ChillMate' }
if app_target.nil?
  puts "Could not find ChillMate target"
  exit 1
end

# Without this, a second run adds a second target of the same name: everything
# then builds and runs twice, and the duplicate carries none of the settings the
# first one has since accumulated.
if project.targets.any? { |t| t.name == 'ChillMateUITests' }
  puts "ChillMateUITests already exists; nothing to do."
  exit 0
end

deployment_target = app_target.build_configurations
                              .map { |config| config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] }
                              .compact
                              .first
if deployment_target.nil?
  puts "Could not read IPHONEOS_DEPLOYMENT_TARGET from the ChillMate target"
  exit 1
end

# Create UI Test target
ui_test_target = project.new_target(:ui_test_bundle, 'ChillMateUITests', :ios, deployment_target, nil, :swift)

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

puts "Successfully added UI Tests target on iOS #{deployment_target} and updated scheme."
