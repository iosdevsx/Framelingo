#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "json"
require "minitest/autorun"
require "open3"
require "pathname"
require "rbconfig"
require "tmpdir"

class ExportSiteDataTest < Minitest::Test
  REPOSITORY_ROOT = Pathname.new(__dir__).join("../..").realpath
  EXPORTER = REPOSITORY_ROOT.join("Scripts/architecture/export-site-data.rb")

  def test_snapshot_does_not_change_when_swift_source_files_change
    Dir.mktmpdir do |directory|
      root = Pathname.new(directory)
      package = root.join("AppTarget/Modules/Core/Example")
      sources = package.join("Sources/Example")
      FileUtils.mkdir_p(sources)
      package.join("Package.swift").write(<<~SWIFT)
        import PackageDescription
        let package = Package(
          name: "Example",
          targets: [.target(name: "Example", path: "Sources/Example")]
        )
      SWIFT
      sources.join("Example.swift").write("public struct Example {}\n")
      scenarios = root.join("runtime-scenarios.json")
      scenarios.write("[]\n")
      output = root.join("architecture.json")

      export(root, scenarios, output)
      before = output.read
      sources.join("Extra.swift").write("public struct Extra {}\n")
      export(root, scenarios, output)

      assert_equal before, output.read
      snapshot = JSON.parse(output.read)
      refute snapshot.fetch("modules").fetch(0).key?("sourceFiles")
    end
  end

  private

  def export(root, scenarios, output)
    _stdout, stderr, status = Open3.capture3(
      RbConfig.ruby,
      EXPORTER.to_s,
      "--repository-root",
      root.to_s,
      "--runtime-scenarios",
      scenarios.to_s,
      "--output",
      output.to_s,
      chdir: REPOSITORY_ROOT.to_s
    )
    assert status.success?, stderr
  end
end
