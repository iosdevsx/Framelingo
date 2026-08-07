# frozen_string_literal: true

require "pathname"
require "uri"

module FramelingoArchitecture
  class GraphError < StandardError
    attr_reader :rule_id, :path, :observed, :expected, :remediation

    def initialize(rule_id:, path:, message:, observed:, expected:, remediation:)
      super(message)
      @rule_id = rule_id
      @path = path
      @observed = observed
      @expected = expected
      @remediation = remediation
    end
  end

  class PackageGraph
    CATEGORY_ORDER = %w[Composition Features Workflows Core Infrastructure UI External].freeze

    attr_reader :packages, :edges

    def initialize(packages:, edges:)
      @packages = packages.sort_by { |package| package.fetch("identity") }.freeze
      @edges = edges.sort_by do |edge|
        [edge.fetch("source"), edge.fetch("kind"), edge.fetch("target")]
      end.freeze
    end

    def local_packages
      packages.select { |package| package.fetch("kind") == "local" }
    end

    def external_packages
      packages.select { |package| package.fetch("kind") == "external" }
    end

    def local_edges
      edges.select { |edge| edge.fetch("kind") == "local" }
    end

    def external_edges
      edges.select { |edge| edge.fetch("kind") == "external" }
    end

    def package_named(name)
      packages.find { |package| package.fetch("name") == name }
    end

    def snapshot_modules
      modules = packages.map do |package|
        dependencies = edges.map do |edge|
          edge.fetch("target") if edge.fetch("source") == package.fetch("name")
        end.compact.sort
        {
          "name" => package.fetch("name"),
          "category" => package.fetch("category"),
          "dependencies" => dependencies,
          "tests" => package.fetch("tests")
        }
      end
      modules.sort_by do |record|
        [CATEGORY_ORDER.index(record.fetch("category")) || CATEGORY_ORDER.length, record.fetch("name")]
      end
    end
  end

  class PackageGraphReader
    PACKAGE_CALL = /\.package\s*\(/.freeze
    PACKAGE_NAME = /Package\s*\(\s*name:\s*"([^"]+)"/m.freeze
    TEST_TARGET = /\.testTarget\s*\(\s*name:\s*"([^"]+)"/m.freeze

    def initialize(repository_root)
      @repository_root = Pathname.new(repository_root).expand_path
      @modules_root = @repository_root.join("AppTarget/Modules")
    end

    def read
      manifest_paths = Dir.glob(@modules_root.join("**/Package.swift")).map { |path| Pathname.new(path) }
      manifest_paths.reject! { |path| path.each_filename.include?(".build") }
      manifest_paths.sort!

      locals = manifest_paths.map { |manifest| read_local_package(manifest) }
      validate_unique_local_identities!(locals)
      local_by_directory = locals.to_h { |package| [package.fetch("directory"), package] }

      external_by_identity = {}
      edges = []
      locals.each do |package|
        declarations = dependency_declarations(package.fetch("source"), package.fetch("manifest"))
        validate_unique_declarations!(package, declarations)
        declarations.each do |declaration|
          if declaration.fetch("kind") == "local"
            target_directory = Pathname.new(package.fetch("directory")).join(declaration.fetch("value")).cleanpath.expand_path.to_s
            target = local_by_directory[target_directory]
            unless target
              graph_error!(
                "ARCH-GRAPH-003",
                package.fetch("path"),
                "Local dependency #{declaration.fetch('value').inspect} does not resolve to one discovered package",
                declaration.fetch("value"),
                "A literal path to exactly one Package.swift under AppTarget/Modules",
                "Correct the path or add the missing package manifest."
              )
            end
            edges << edge(package.fetch("name"), target.fetch("name"), "local")
          else
            external = external_package(declaration.fetch("value"), package.fetch("path"))
            existing = external_by_identity[external.fetch("identity")]
            external_by_identity[external.fetch("identity")] = external unless existing
            edges << edge(package.fetch("name"), external.fetch("name"), "external")
          end
        end
      end

      validate_unique_external_names!(external_by_identity.values)
      packages = locals.map do |package|
        package.reject { |key, _value| %w[source directory manifest].include?(key) }
      end
      packages.concat(external_by_identity.values)
      PackageGraph.new(packages: packages, edges: edges.uniq)
    end

    private

    def read_local_package(manifest)
      source = manifest.read(encoding: Encoding::UTF_8)
      name = source[PACKAGE_NAME, 1]
      unless name && !name.empty?
        graph_error!(
          "ARCH-GRAPH-001",
          relative(manifest),
          "Could not read a literal package name",
          "missing Package(name: \"...\")",
          "A non-empty literal SwiftPM package name",
          "Declare the package name directly in Package(...)."
        )
      end
      package_directory = manifest.dirname.expand_path
      package_path = relative(package_directory)
      category = package_directory.relative_path_from(@modules_root).each_filename.first
      {
        "identity" => "local:#{package_path}",
        "kind" => "local",
        "name" => name,
        "path" => package_path,
        "category" => category,
        "tests" => source.scan(TEST_TARGET).flatten.uniq.sort,
        "source" => source,
        "directory" => package_directory.to_s,
        "manifest" => manifest
      }
    end

    def dependency_declarations(source, manifest)
      call_blocks(source, PACKAGE_CALL).map do |block|
        path_keyword = block.match?(/\bpath\s*:/)
        url_keyword = block.match?(/\burl\s*:/)
        path = block[/\bpath\s*:\s*"([^"]+)"/m, 1]
        url = block[/\burl\s*:\s*"([^"]+)"/m, 1]
        if path && !url_keyword
          { "kind" => "local", "value" => path }
        elsif url && !path_keyword
          { "kind" => "external", "value" => url }
        else
          graph_error!(
            "ARCH-GRAPH-004",
            relative(manifest),
            "Unsupported SwiftPM package dependency declaration",
            block.lines.first.to_s.strip,
            "Exactly one literal path: or url: package declaration",
            "Use .package(path: \"...\") or .package(url: \"...\", requirement: ...)."
          )
        end
      end
    end

    def call_blocks(source, pattern)
      blocks = []
      offset = 0
      while (match = source.match(pattern, offset))
        start = match.begin(0)
        index = match.end(0)
        depth = 1
        quoted = false
        escaped = false
        while index < source.length && depth.positive?
          character = source[index]
          if quoted
            if escaped
              escaped = false
            elsif character == "\\"
              escaped = true
            elsif character == '"'
              quoted = false
            end
          elsif character == '"'
            quoted = true
          elsif character == "("
            depth += 1
          elsif character == ")"
            depth -= 1
          end
          index += 1
        end
        if depth.positive?
          graph_error!(
            "ARCH-GRAPH-004",
            "Package.swift",
            "Unterminated package dependency declaration",
            source[start..].lines.first.to_s.strip,
            "A balanced .package(...) declaration",
            "Close the declaration parentheses."
          )
        end
        blocks << source[start...index]
        offset = index
      end
      blocks
    end

    def validate_unique_local_identities!(packages)
      duplicate = packages.group_by { |package| package.fetch("name") }.find { |_name, matches| matches.length > 1 }
      return unless duplicate

      name, matches = duplicate
      graph_error!(
        "ARCH-GRAPH-002",
        matches.map { |package| package.fetch("path") }.sort.join(", "),
        "Duplicate local package name #{name}",
        matches.map { |package| package.fetch("path") }.sort.join(", "),
        "Unique local package names",
        "Rename or remove the duplicate package declaration."
      )
    end

    def validate_unique_declarations!(package, declarations)
      duplicate = declarations.group_by { |item| [item.fetch("kind"), item.fetch("value")] }
        .find { |_identity, matches| matches.length > 1 }
      return unless duplicate

      kind_and_value, = duplicate
      graph_error!(
        "ARCH-GRAPH-005",
        package.fetch("path"),
        "Duplicate package dependency declaration",
        kind_and_value.last,
        "One declaration per direct package dependency",
        "Remove the duplicate dependency declaration."
      )
    end

    def validate_unique_external_names!(packages)
      duplicate = packages.group_by { |package| package.fetch("name") }.find { |_name, matches| matches.length > 1 }
      return unless duplicate

      name, matches = duplicate
      graph_error!(
        "ARCH-GRAPH-006",
        "AppTarget/Modules",
        "External package name #{name} resolves to multiple URLs",
        matches.map { |package| package.fetch("url") }.sort.join(", "),
        "One canonical URL for each external package name",
        "Use a single upstream package identity or distinct unambiguous names."
      )
    end

    def external_package(url, source_path)
      uri = URI.parse(url)
      basename = File.basename(uri.path.to_s, ".git")
      raise URI::InvalidURIError if basename.empty? || basename == "/"

      normalized = url.sub(/\.git\z/, "")
      {
        "identity" => "external:#{normalized}",
        "kind" => "external",
        "name" => basename,
        "url" => normalized,
        "path" => nil,
        "category" => "External",
        "tests" => []
      }
    rescue URI::InvalidURIError
      graph_error!(
        "ARCH-GRAPH-004",
        source_path,
        "Invalid external package URL",
        url,
        "An absolute package URL with a stable basename",
        "Correct the literal url: dependency declaration."
      )
    end

    def edge(source, target, kind)
      { "source" => source, "target" => target, "kind" => kind }
    end

    def relative(path)
      Pathname.new(path).relative_path_from(@repository_root).to_s
    end

    def graph_error!(rule_id, path, message, observed, expected, remediation)
      raise GraphError.new(
        rule_id: rule_id,
        path: path,
        message: message,
        observed: observed,
        expected: expected,
        remediation: remediation
      )
    end
  end
end
