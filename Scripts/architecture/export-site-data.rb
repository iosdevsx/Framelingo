#!/usr/bin/env ruby

require "fileutils"
require "json"
require "optparse"
require "pathname"
require "tempfile"

SCRIPT_DIRECTORY = Pathname.new(__dir__).realpath
REPOSITORY_ROOT = SCRIPT_DIRECTORY.join("../..").realpath
DEFAULT_OUTPUT = REPOSITORY_ROOT.join("docs/architecture/framelingo-architecture.json")
SITE_OUTPUT = REPOSITORY_ROOT.join("Tools/ArchitectureSite/app/architecture-data.json")
RUNTIME_SCENARIOS = SCRIPT_DIRECTORY.join("runtime-scenarios.json")
CATEGORY_ORDER = %w[Composition Features Workflows Core Infrastructure UI External].freeze

options = { outputs: [DEFAULT_OUTPUT, SITE_OUTPUT] }
OptionParser.new do |parser|
  parser.banner = "Usage: export-site-data.rb [--output PATH]"
  parser.on("--output PATH", "Write the architecture snapshot to PATH") do |path|
    options[:outputs] = [Pathname.new(path).expand_path]
  end
end.parse!

def package_category(package_file)
  relative = package_file.relative_path_from(REPOSITORY_ROOT.join("AppTarget/Modules"))
  relative.each_filename.first
end

def package_name(source, package_file)
  match = source.match(/Package\(\s*name:\s*"([^"]+)"/m)
  raise "Could not read package name from #{package_file}" unless match

  match[1]
end

def package_dependencies(source)
  local = source.scan(/\.package\(\s*path:\s*"([^"]+)"/m).flatten.map do |path|
    File.basename(path)
  end
  remote = source.scan(/\.package\(\s*url:\s*"([^"]+)"/m).flatten.map do |url|
    File.basename(url, ".git")
  end
  (local + remote).uniq.sort
end

def test_targets(source)
  source.scan(/\.testTarget\(\s*name:\s*"([^"]+)"/m).flatten.uniq.sort
end

package_files = Dir.glob(REPOSITORY_ROOT.join("AppTarget/Modules/**/Package.swift")).map do |path|
  Pathname.new(path)
end.reject { |path| path.each_filename.include?(".build") }

modules = package_files.map do |package_file|
  source = package_file.read
  package_directory = package_file.dirname
  {
    "name" => package_name(source, package_file),
    "category" => package_category(package_file),
    "dependencies" => package_dependencies(source),
    "tests" => test_targets(source),
    "sourceFiles" => Dir.glob(package_directory.join("Sources/**/*.swift")).length
  }
end

known_names = modules.map { |record| record.fetch("name") }
external_names = modules.flat_map { |record| record.fetch("dependencies") }.uniq - known_names
external_names.each do |name|
  modules << {
    "name" => name,
    "category" => "External",
    "dependencies" => [],
    "tests" => [],
    "sourceFiles" => nil
  }
end

modules.sort_by! do |record|
  [CATEGORY_ORDER.index(record.fetch("category")) || CATEGORY_ORDER.length, record.fetch("name")]
end

runtime_scenarios = JSON.parse(RUNTIME_SCENARIOS.read)
unless runtime_scenarios.is_a?(Array) && runtime_scenarios.all? { |scenario| scenario["steps"].is_a?(Array) }
  raise "#{RUNTIME_SCENARIOS} must contain an array of scenarios with steps"
end

runtime_scenarios.each do |scenario|
  scenario.fetch("id")
  scenario.fetch("title")
  raise "Runtime scenario #{scenario.fetch("id")} has no steps" if scenario.fetch("steps").empty?

  scenario.fetch("steps").each do |step|
    %w[id label module category kind source].each { |key| step.fetch(key) }
    source_path = REPOSITORY_ROOT.join(step.fetch("source"))
    raise "Runtime source does not exist: #{source_path}" unless source_path.file?
  end
end

snapshot = {
  "schemaVersion" => 1,
  "source" => "Framelingo package manifests and documented composition paths",
  "modules" => modules,
  "runtimeScenarios" => runtime_scenarios
}

payload = "#{JSON.pretty_generate(snapshot)}\n"
options.fetch(:outputs).each do |output|
  FileUtils.mkdir_p(output.dirname)
  Tempfile.create([output.basename.to_s, ".tmp"], output.dirname) do |temporary|
    temporary.write(payload)
    temporary.flush
    temporary.fsync
    File.rename(temporary.path, output)
  end
end

puts "Exported #{modules.length} packages and #{runtime_scenarios.length} runtime scenarios"
options.fetch(:outputs).each { |output| puts "  -> #{output}" }
