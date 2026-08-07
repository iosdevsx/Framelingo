#!/usr/bin/env ruby

require "fileutils"
require "json"
require "optparse"
require "pathname"
require "tempfile"
require_relative "package_graph"

SCRIPT_DIRECTORY = Pathname.new(__dir__).realpath
REPOSITORY_ROOT = SCRIPT_DIRECTORY.join("../..").realpath
DEFAULT_OUTPUT = REPOSITORY_ROOT.join("docs/architecture/framelingo-architecture.json")
SITE_OUTPUT = REPOSITORY_ROOT.join("Tools/ArchitectureSite/app/architecture-data.json")

options = {
  repository_root: REPOSITORY_ROOT,
  runtime_scenarios: nil,
  outputs: nil
}
OptionParser.new do |parser|
  parser.banner = "Usage: export-site-data.rb [options]"
  parser.on("--repository-root PATH", "Read Framelingo sources from PATH") do |path|
    options[:repository_root] = Pathname.new(path).expand_path.realpath
  end
  parser.on("--runtime-scenarios PATH", "Read documented runtime scenarios from PATH") do |path|
    options[:runtime_scenarios] = Pathname.new(path).expand_path
  end
  parser.on("--output PATH", "Write the architecture snapshot to PATH") do |path|
    options[:outputs] = [Pathname.new(path).expand_path]
  end
end.parse!

repository_root = options.fetch(:repository_root)
runtime_scenarios_path = options[:runtime_scenarios] || repository_root.join("Scripts/architecture/runtime-scenarios.json")
outputs = options[:outputs] || if repository_root == REPOSITORY_ROOT
  [DEFAULT_OUTPUT, SITE_OUTPUT]
else
  [repository_root.join("docs/architecture/framelingo-architecture.json")]
end

graph = FramelingoArchitecture::PackageGraphReader.new(repository_root).read
modules = graph.snapshot_modules

runtime_scenarios = JSON.parse(runtime_scenarios_path.read)
unless runtime_scenarios.is_a?(Array) && runtime_scenarios.all? { |scenario| scenario["steps"].is_a?(Array) }
  raise "#{runtime_scenarios_path} must contain an array of scenarios with steps"
end

runtime_scenarios.each do |scenario|
  scenario.fetch("id")
  scenario.fetch("title")
  raise "Runtime scenario #{scenario.fetch("id")} has no steps" if scenario.fetch("steps").empty?

  scenario.fetch("steps").each do |step|
    %w[id label module category kind source].each { |key| step.fetch(key) }
    source_path = repository_root.join(step.fetch("source"))
    raise "Runtime source does not exist: #{source_path}" unless source_path.file?
  end
end

snapshot = {
  "schemaVersion" => 2,
  "source" => "Framelingo package manifests and documented composition paths",
  "modules" => modules,
  "runtimeScenarios" => runtime_scenarios
}

payload = "#{JSON.pretty_generate(snapshot)}\n"
outputs.each do |output|
  FileUtils.mkdir_p(output.dirname)
  Tempfile.create([output.basename.to_s, ".tmp"], output.dirname) do |temporary|
    temporary.write(payload)
    temporary.flush
    temporary.fsync
    File.rename(temporary.path, output)
  end
end

puts "Exported #{modules.length} packages and #{runtime_scenarios.length} runtime scenarios"
outputs.each { |output| puts "  -> #{output}" }
