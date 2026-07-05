#!/usr/bin/env ruby
# encoding: UTF-8
#
# Adds the official supabase-swift SPM package to the MyGolds target.
# Idempotent: does nothing if the package is already present.
#
# Usage: ruby scripts/add_supabase_package.rb

require "xcodeproj"

PROJECT_PATH = File.expand_path(File.join(__dir__, "..", "MyGolds.xcodeproj"))
TARGET_NAME  = "MyGolds"
REPO_URL     = "https://github.com/supabase/supabase-swift"
PRODUCT      = "Supabase"
MIN_VERSION  = "2.0.0"

project = Xcodeproj::Project.open(PROJECT_PATH)
target  = project.targets.find { |t| t.name == TARGET_NAME }
raise "Target #{TARGET_NAME} not found" unless target

# 1. Remote package reference (project level).
existing_ref = project.root_object.package_references.find do |ref|
  ref.respond_to?(:repositoryURL) && ref.repositoryURL.to_s.include?("supabase-swift")
end

if existing_ref
  pkg_ref = existing_ref
  puts "✓ Package reference already present."
else
  pkg_ref = project.new(Xcodeproj::Project::Object::XCRemoteSwiftPackageReference)
  pkg_ref.repositoryURL = REPO_URL
  pkg_ref.requirement = { "kind" => "upToNextMajorVersion", "minimumVersion" => MIN_VERSION }
  project.root_object.package_references << pkg_ref
  puts "✓ Added remote package reference: #{REPO_URL}"
end

# 2. Product dependency on the target.
already_dep = target.package_product_dependencies.any? { |d| d.product_name == PRODUCT }
if already_dep
  puts "✓ Target already depends on product '#{PRODUCT}'."
else
  dep = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  dep.package = pkg_ref
  dep.product_name = PRODUCT
  target.package_product_dependencies << dep

  # 3. Link it in the Frameworks build phase.
  build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
  build_file.product_ref = dep
  target.frameworks_build_phase.files << build_file
  puts "✓ Linked product '#{PRODUCT}' to target #{TARGET_NAME}."
end

project.save
puts "✓ Saved project."
