#!/usr/bin/env ruby
# encoding: UTF-8
#
# Removes the SwiftSoup SPM package from the project (it is no longer used —
# the app does zero client-side HTML scraping). Idempotent.
#
# Usage: ruby scripts/remove_swiftsoup_package.rb

require "xcodeproj"

PROJECT_PATH = File.expand_path(File.join(__dir__, "..", "MyGolds.xcodeproj"))

project = Xcodeproj::Project.open(PROJECT_PATH)
removed = []

# 1. Remove product dependencies + their build files from every target.
project.targets.each do |target|
  target.package_product_dependencies.dup.each do |dep|
    next unless dep.product_name == "SwiftSoup"
    # Remove the build file in the Frameworks phase that links this product.
    target.frameworks_build_phase.files.dup.each do |bf|
      if bf.product_ref.equal?(dep)
        bf.remove_from_project
      end
    end
    target.package_product_dependencies.delete(dep)
    dep.remove_from_project
    removed << "product dependency (#{target.name})"
  end
end

# 2. Remove the remote package reference itself.
project.root_object.package_references.dup.each do |ref|
  next unless ref.respond_to?(:repositoryURL) && ref.repositoryURL.to_s.downcase.include?("swiftsoup")
  project.root_object.package_references.delete(ref)
  ref.remove_from_project
  removed << "package reference"
end

project.save

if removed.empty?
  puts "✓ SwiftSoup not present — nothing to remove."
else
  puts "✓ Removed SwiftSoup: #{removed.join(', ')}"
end
