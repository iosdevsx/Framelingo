#!/usr/bin/env ruby

require "json"
require "optparse"
require "pathname"
require_relative "architecture_diff"

options = {}
OptionParser.new do |parser|
  parser.banner = "Usage: diff-snapshots.rb --base PATH --head PATH [options]"
  parser.on("--base PATH", "Base architecture snapshot") { |path| options[:base] = Pathname.new(path) }
  parser.on("--head PATH", "Head architecture snapshot") { |path| options[:head] = Pathname.new(path) }
  parser.on("--json PATH", "Write machine-readable diff JSON") { |path| options[:json] = Pathname.new(path) }
  parser.on("--markdown PATH", "Write PR comment Markdown") { |path| options[:markdown] = Pathname.new(path) }
  parser.on("--base-label LABEL", "Label used for the base revision") { |label| options[:base_label] = label }
  parser.on("--head-label LABEL", "Label used for the head revision") { |label| options[:head_label] = label }
end.parse!

base_path = options.fetch(:base) { abort "Missing --base PATH" }
head_path = options.fetch(:head) { abort "Missing --head PATH" }
base_snapshot = JSON.parse(base_path.read)
head_snapshot = JSON.parse(head_path.read)
diff = ArchitectureDiff.compare(base_snapshot, head_snapshot)

if options[:json]
  options.fetch(:json).write("#{JSON.pretty_generate(diff)}\n")
end
if options[:markdown]
  options.fetch(:markdown).write(ArchitectureDiff.markdown(
    diff,
    base_label: options.fetch(:base_label, "base"),
    head_label: options.fetch(:head_label, "head")
  ))
end

puts JSON.generate(diff.fetch("summary").merge("hasChanges" => diff.fetch("hasChanges")))
