#!/usr/bin/env ruby
# encoding: UTF-8
#
# One-time setup: registers MyGolds/MyGolds.entitlements in the project and
# points CODE_SIGN_ENTITLEMENTS at it for both Debug and Release, enabling
# the Push Notifications (APNs) capability.
#
# Usage: ruby scripts/add_push_entitlements.rb

require "xcodeproj"

PROJECT_PATH = File.expand_path(File.join(__dir__, "..", "MyGolds.xcodeproj"))
TARGET_NAME  = "MyGolds"
ENTITLEMENTS_REL_PATH = "MyGolds/MyGolds.entitlements"

project = Xcodeproj::Project.open(PROJECT_PATH)
target  = project.targets.find { |t| t.name == TARGET_NAME }
raise "Target #{TARGET_NAME} not found" unless target

root_group = project.main_group[TARGET_NAME]
raise "Group #{TARGET_NAME} not found" unless root_group

unless root_group.children.any? { |c| c.display_name == "MyGolds.entitlements" }
  root_group.new_reference("MyGolds.entitlements")
  puts "✓ Added file reference for MyGolds.entitlements"
end

target.build_configurations.each do |config|
  config.build_settings["CODE_SIGN_ENTITLEMENTS"] = ENTITLEMENTS_REL_PATH
end
puts "✓ Set CODE_SIGN_ENTITLEMENTS on #{target.build_configurations.size} configuration(s)"

project.save
