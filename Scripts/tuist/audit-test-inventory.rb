#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "open3"

root = File.expand_path("../..", __dir__)
plan_path = File.join(root, "Tuist/TestPlans/FramelingoComplete.xctestplan")
plan = JSON.parse(File.read(plan_path))
plan_targets = plan.fetch("testTargets").map { |entry| entry.fetch("target") }

manifest_containers = {}
manifest_names = Dir.glob(File.join(root, "AppTarget/Modules/*/*/Package.swift")).flat_map do |path|
  manifest = File.read(path)
  next [] unless manifest.include?(".macOS(")

  names = manifest.scan(/\.testTarget\s*\(\s*name:\s*"([^"]+)"/m).flatten
  relative_package_path = File.dirname(path).delete_prefix("#{root}/")
  names.each { |name| manifest_containers[name] = "container:#{relative_package_path}" }
  names
end

expected_names = (["FramelingoTests"] + manifest_names).sort
def validate_plan(label, targets, expected_names, manifest_containers)
  names = targets.map { |target| target.fetch("name") }
  actual_names = names.sort

  duplicates = names.group_by { |name| name }.select { |_name, entries| entries.length > 1 }.keys
  abort "Duplicate targets in #{label}: #{duplicates.join(', ')}" unless duplicates.empty?
  unless actual_names == expected_names
    abort "#{label} differs from package inventory. Missing: #{expected_names - actual_names}; extra: #{actual_names - expected_names}"
  end
  abort "Expected 33 test targets in #{label}, found #{actual_names.length}" unless actual_names.length == 33

  targets.each do |target|
    name = target.fetch("name")
    next if name == "FramelingoTests"

    expected_container = manifest_containers.fetch(name)
    actual_container = target.fetch("containerPath")
    abort "#{label}: #{name} points to #{actual_container}; expected #{expected_container}" unless actual_container == expected_container
  end
end

validate_plan("Tuist test plan", plan_targets, expected_names, manifest_containers)

scheme_path = File.join(root, "Framelingo-Tuist.xcodeproj/xcshareddata/xcschemes/Framelingo-Tuist.xcscheme")
if File.exist?(scheme_path)
  scheme = File.read(scheme_path)
  abort "Generated scheme does not reference FramelingoComplete.xctestplan" unless scheme.include?("Tuist/TestPlans/FramelingoComplete.xctestplan")
end

executed_test_count = nil
if (xcresult_path = ARGV.first)
  absolute_xcresult_path = File.expand_path(xcresult_path, root)
  output, error, status = Open3.capture3(
    "xcrun", "xcresulttool", "get", "test-results", "summary",
    "--path", absolute_xcresult_path
  )
  abort "Could not read xcresult: #{error}" unless status.success?

  summary = JSON.parse(output)
  abort "Generated test run did not pass: #{summary.fetch('result')}" unless summary.fetch("result") == "Passed"
  executed_test_count = summary.fetch("totalTestCount")
end

suffix = executed_test_count ? " and xcresult execution passed (#{executed_test_count} tests)" : ""
puts "Test inventory audit passed (33 targets: 1 shell + 32 package-owned)#{suffix}."
