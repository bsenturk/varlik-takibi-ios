#!/usr/bin/env ruby
# encoding: UTF-8
#
# Syncs every .swift file under MyGolds/ into the MyGolds Xcode target.
# - Mirrors folder structure into PBXGroups
# - Adds missing PBXFileReferences
# - Adds missing files to the Sources build phase
# Idempotent: files already in the project are left untouched.
#
# Usage: ruby scripts/sync_xcode_files.rb

require "xcodeproj"
require "set"
require "pathname"

PROJECT_PATH = File.expand_path(File.join(__dir__, "..", "MyGolds.xcodeproj"))
SOURCE_ROOT  = "MyGolds"
TARGET_NAME  = "MyGolds"

project = Xcodeproj::Project.open(PROJECT_PATH)
target  = project.targets.find { |t| t.name == TARGET_NAME }
raise "Target #{TARGET_NAME} not found" unless target

# Collect file paths already referenced in the project (by real path).
existing_paths = Set.new
project.files.each do |f|
  rp = f.real_path.to_s rescue nil
  existing_paths << rp if rp
end

root_group = project.main_group[SOURCE_ROOT]
raise "Group #{SOURCE_ROOT} not found" unless root_group

# --- Prune references to files that no longer exist on disk ---
removed = []
project.files.dup.each do |f|
  next unless f.path && f.path.end_with?(".swift")
  rp = (f.real_path.to_s rescue nil)
  next if rp.nil?
  next unless rp.include?("/#{SOURCE_ROOT}/")
  unless File.exist?(rp)
    f.remove_from_project
    removed << rp
  end
end

# Find or create a nested group matching a relative directory path.
def group_for(project, root_group, source_root, rel_dir)
  return root_group if rel_dir == "." || rel_dir.empty?
  group = root_group
  rel_dir.split("/").each do |segment|
    child = group.children.find { |c| c.display_name == segment && c.isa == "PBXGroup" }
    child ||= group.new_group(segment, segment)
    group = child
  end
  group
end

added = []
Dir.glob(File.join(File.dirname(PROJECT_PATH), SOURCE_ROOT, "**", "*.swift")).sort.each do |abs|
  abs_real = Pathname.new(abs).realpath.to_s
  next if existing_paths.include?(abs_real)

  rel_to_root = Pathname.new(abs).relative_path_from(
    Pathname.new(File.join(File.dirname(PROJECT_PATH), SOURCE_ROOT))
  ).to_s
  rel_dir  = File.dirname(rel_to_root)
  filename = File.basename(rel_to_root)

  group = group_for(project, root_group, SOURCE_ROOT, rel_dir)
  file_ref = group.new_reference(filename)
  target.add_file_references([file_ref])
  added << rel_to_root
end

project.save

unless removed.empty?
  puts "✓ Removed #{removed.size} dangling reference(s):"
  removed.each { |f| puts "   - #{f.sub(File.dirname(PROJECT_PATH) + '/', '')}" }
end

if added.empty?
  puts "✓ No new files to add — project already in sync."
else
  puts "✓ Added #{added.size} file(s) to target #{TARGET_NAME}:"
  added.each { |f| puts "   + #{f}" }
end
