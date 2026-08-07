#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "json"
require "minitest/autorun"
require "tmpdir"
require_relative "package_graph"

class PackageGraphReaderTest < Minitest::Test
  def with_repository(manifests)
    Dir.mktmpdir do |directory|
      root = Pathname.new(directory)
      manifests.each do |relative, source|
        package = root.join("AppTarget/Modules", relative)
        FileUtils.mkdir_p(package.join("Sources/Api"))
        package.join("Sources/Api/Test.swift").write("public struct Test {}\n")
        package.join("Package.swift").write(source)
      end
      yield root
    end
  end

  def manifest(name, dependencies: "", tests: "")
    <<~SWIFT
      import PackageDescription
      let package = Package(
        name: "#{name}",
        dependencies: [#{dependencies}],
        targets: [.target(name: "#{name}", path: "Sources/Api")#{tests}]
      )
    SWIFT
  end

  def test_reads_current_literal_manifest_forms_and_sorts_edges
    with_repository(
      "Core/A" => manifest(
        "A",
        dependencies: <<~SWIFT,
          .package(
            url: "https://example.com/Remote.git",
            exact: "1.0.0"
          ),
          .package(path: "../B")
        SWIFT
        tests: ', .testTarget(name: "ATests", dependencies: ["A"])'
      ),
      "Core/B" => manifest("B")
    ) do |root|
      graph = FramelingoArchitecture::PackageGraphReader.new(root).read
      assert_equal %w[A B], graph.local_packages.map { |package| package.fetch("name") }
      assert_equal ["Remote"], graph.external_packages.map { |package| package.fetch("name") }
      assert_equal ["ATests"], graph.package_named("A").fetch("tests")
      assert_equal [
        { "source" => "A", "target" => "Remote", "kind" => "external" },
        { "source" => "A", "target" => "B", "kind" => "local" }
      ], graph.edges
    end
  end

  def test_rejects_duplicate_local_package_names
    with_repository("Core/A" => manifest("Same"), "Core/B" => manifest("Same")) do |root|
      error = assert_raises(FramelingoArchitecture::GraphError) do
        FramelingoArchitecture::PackageGraphReader.new(root).read
      end
      assert_equal "ARCH-GRAPH-002", error.rule_id
    end
  end

  def test_rejects_duplicate_dependency_declarations
    duplicate = '.package(path: "../B"), .package(path: "../B")'
    with_repository("Core/A" => manifest("A", dependencies: duplicate), "Core/B" => manifest("B")) do |root|
      error = assert_raises(FramelingoArchitecture::GraphError) do
        FramelingoArchitecture::PackageGraphReader.new(root).read
      end
      assert_equal "ARCH-GRAPH-005", error.rule_id
    end
  end

  def test_rejects_unresolved_local_dependency
    with_repository("Core/A" => manifest("A", dependencies: '.package(path: "../Missing")')) do |root|
      error = assert_raises(FramelingoArchitecture::GraphError) do
        FramelingoArchitecture::PackageGraphReader.new(root).read
      end
      assert_equal "ARCH-GRAPH-003", error.rule_id
    end
  end

  def test_rejects_nonliteral_local_dependency
    with_repository("Core/A" => manifest("A", dependencies: ".package(path: dependencyPath)")) do |root|
      error = assert_raises(FramelingoArchitecture::GraphError) do
        FramelingoArchitecture::PackageGraphReader.new(root).read
      end
      assert_equal "ARCH-GRAPH-004", error.rule_id
    end
  end

  def test_snapshot_does_not_change_when_swift_source_files_change
    with_repository("Core/A" => manifest("A")) do |root|
      reader = FramelingoArchitecture::PackageGraphReader.new(root)
      before = reader.read.snapshot_modules

      extra_source = root.join("AppTarget/Modules/Core/A/Sources/Api/Extra.swift")
      extra_source.write("public struct Extra {}\n")

      assert_equal before, reader.read.snapshot_modules
      refute before.fetch(0).key?("sourceFiles")
    end
  end

  def test_repository_snapshot_modules_are_semantically_unchanged
    root = Pathname.new(__dir__).join("../..").realpath
    graph = FramelingoArchitecture::PackageGraphReader.new(root).read
    snapshot = JSON.parse(root.join("docs/architecture/framelingo-architecture.json").read)
    assert_equal snapshot.fetch("modules"), graph.snapshot_modules
  end
end
