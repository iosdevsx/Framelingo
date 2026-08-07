#!/usr/bin/env ruby

require "fileutils"
require "json"
require "open3"
require "pathname"
require "rbconfig"
require "tempfile"
require "tmpdir"
require "uri"

module DocumentationAudit
  module_function

  REQUIRED_AGENT_HEADINGS = [
    "## Start here",
    "## Architectural invariants",
    "## Swift concurrency",
    "## Verification"
  ].freeze

  def package_name(manifest)
    source = File.read(manifest)
    source[/Package\(\s*name:\s*"([^"]+)"/m, 1]
  end

  def validate_agent_guidance(root)
    errors = []
    agents = root.join("AGENTS.md")
    claude = root.join("CLAUDE.md")

    errors << "AGENTS.md is missing" unless agents.file?
    errors << "CLAUDE.md duplicates repository guidance; remove it" if claude.exist?
    return errors unless agents.file?

    _output, ignore_status = Open3.capture2e(
      "git", "check-ignore", "-q", "AGENTS.md", chdir: root.to_s
    )
    errors << "AGENTS.md is ignored by Git" if ignore_status.success?

    source = agents.read
    line_count = source.lines.length
    errors << "AGENTS.md has #{line_count} lines; keep always-on guidance at or below 200" if line_count > 200
    REQUIRED_AGENT_HEADINGS.each do |heading|
      errors << "AGENTS.md is missing required heading #{heading.inspect}" unless source.include?(heading)
    end
    errors
  end

  def validate_package_readme(manifest, root)
    package_dir = manifest.dirname
    relative_dir = package_dir.relative_path_from(root).to_s
    name = package_name(manifest)
    readme = package_dir.join("README.md")
    errors = []

    return ["#{relative_dir}: Package.swift has no readable package name"] unless name
    return ["#{relative_dir}: README.md is missing"] unless readme.file?

    source = readme.read
    first_heading = source.lines.find { |line| line.start_with?("# ") }&.strip
    expected_heading = "# #{name}"
    unless first_heading == expected_heading
      errors << "#{relative_dir}/README.md: first H1 must be #{expected_heading.inspect}"
    end
    unless source.lines.any? { |line| line.strip == "## Тесты" }
      errors << "#{relative_dir}/README.md: missing '## Тесты' section"
    end

    expected_command = "swift test --package-path #{relative_dir}"
    unless source.include?(expected_command)
      errors << "#{relative_dir}/README.md: missing test command `#{expected_command}`"
    end
    errors
  end

  def markdown_targets(source)
    inline = source.scan(/!?\[[^\]]*\]\(([^)]+)\)/).flatten
    references = source.scan(/^\s*\[[^\]]+\]:\s*(\S+)/).flatten
    (inline + references).each_with_object([]) do |raw, targets|
      target = raw.strip
      target = target[1...target.index("> ")] if target.start_with?("<") && target.include?("> ")
      target = target[1..-2] if target.start_with?("<") && target.end_with?(">")
      target = target.split(/\s+["']/, 2).first
      next if target.empty? || target.start_with?("#")
      next if target.match?(/\A[a-z][a-z0-9+.-]*:/i) || target.start_with?("//")

      targets << URI::DEFAULT_PARSER.unescape(target.split(/[?#]/, 2).first)
    end
  end

  def validate_markdown_links(markdown, root)
    relative_source = markdown.relative_path_from(root)
    markdown_targets(markdown.read).each_with_object([]) do |target, errors|
      resolved = if target.start_with?("/")
        root.join(target.delete_prefix("/"))
      else
        markdown.dirname.join(target)
      end.cleanpath

      next if resolved.exist?

      errors << "#{relative_source}: unresolved link target #{target.inspect}"
    end
  end

  def markdown_files(root)
    stdout, status = Open3.capture2(
      "git", "ls-files", "-z", "--cached", "--others", "--exclude-standard", "--", "*.md",
      chdir: root.to_s
    )
    raise "Could not enumerate Markdown files with git ls-files" unless status.success?

    stdout.split("\0").reject(&:empty?).map { |path| root.join(path) }
  end

  def validate_architecture_snapshot(root)
    exporter = root.join("Scripts/architecture/export-site-data.rb")
    canonical = root.join("docs/architecture/framelingo-architecture.json")
    site = root.join("Tools/ArchitectureSite/app/architecture-data.json")
    errors = []

    return ["Architecture exporter is missing: #{exporter.relative_path_from(root)}"] unless exporter.file?
    return ["Canonical architecture snapshot is missing: #{canonical.relative_path_from(root)}"] unless canonical.file?
    return ["Architecture Site snapshot is missing: #{site.relative_path_from(root)}"] unless site.file?

    Tempfile.create(["framelingo-architecture", ".json"]) do |temporary|
      stdout, stderr, status = Open3.capture3(
        RbConfig.ruby,
        exporter.to_s,
        "--output",
        temporary.path,
        chdir: root.to_s
      )
      unless status.success?
        errors << "Architecture export failed: #{[stdout, stderr].join.strip}"
        next
      end

      expected = File.read(temporary.path, encoding: Encoding::UTF_8)
      unless equivalent_json?(canonical.read(encoding: Encoding::UTF_8), expected)
        errors << "docs/architecture/framelingo-architecture.json is stale; run `mise run architecture:export`"
      end
      unless equivalent_json?(site.read(encoding: Encoding::UTF_8), expected)
        errors << "Tools/ArchitectureSite/app/architecture-data.json is stale; run `mise run architecture:export`"
      end
    end
    errors
  end

  def equivalent_json?(left, right)
    JSON.parse(left) == JSON.parse(right)
  rescue JSON::ParserError
    false
  end

  def run(root)
    errors = []
    errors.concat(validate_agent_guidance(root))

    manifests = Dir.glob(root.join("AppTarget/Modules/**/Package.swift")).map { |path| Pathname(path) }
    manifests.reject! { |path| path.each_filename.include?(".build") }
    manifests.sort.each { |manifest| errors.concat(validate_package_readme(manifest, root)) }

    markdown_files(root).each { |markdown| errors.concat(validate_markdown_links(markdown, root)) }
    errors.concat(validate_architecture_snapshot(root))
    errors
  end
end

def run_self_tests
  require "minitest/autorun"

  Class.new(Minitest::Test) do
    define_method(:test_markdown_target_extraction) do
      source = '[local](docs/guide.md#part) [web](https://example.com) ![image](assets/a.png)'
      assert_equal ["docs/guide.md", "assets/a.png"], DocumentationAudit.markdown_targets(source)
    end

    define_method(:test_link_validation_reports_only_missing_targets) do
      Dir.mktmpdir do |directory|
        root = Pathname(directory)
        FileUtils.mkdir_p(root.join("docs"))
        root.join("docs/existing.md").write("# Existing\n")
        root.join("README.md").write("[ok](docs/existing.md) [missing](docs/missing.md)\n")
        errors = DocumentationAudit.validate_markdown_links(root.join("README.md"), root)
        assert_equal ['README.md: unresolved link target "docs/missing.md"'], errors
      end
    end

    define_method(:test_package_readme_contract) do
      Dir.mktmpdir do |directory|
        root = Pathname(directory)
        package = root.join("AppTarget/Modules/Core/Example")
        FileUtils.mkdir_p(package)
        package.join("Package.swift").write('let package = Package(name: "Example")')
        package.join("README.md").write(<<~MARKDOWN)
          # Example

          ## Тесты

          `swift test --package-path AppTarget/Modules/Core/Example`
        MARKDOWN
        assert_empty DocumentationAudit.validate_package_readme(package.join("Package.swift"), root)
      end
    end

    define_method(:test_json_equivalence_ignores_serialization_formatting) do
      compact = '{"modules":[{"name":"Example"}]}'
      pretty = <<~JSON
        {
          "modules": [
            {
              "name": "Example"
            }
          ]
        }
      JSON

      assert DocumentationAudit.equivalent_json?(compact, pretty)
      refute DocumentationAudit.equivalent_json?(compact, '{"modules":[]}')
      refute DocumentationAudit.equivalent_json?(compact, "not json")
    end
  end
end

if ARGV == ["--self-test"]
  ARGV.clear
  run_self_tests
else
  repository_root = Pathname(__dir__).join("..").realpath
  errors = DocumentationAudit.run(repository_root)
  if errors.empty?
    puts "Documentation audit passed"
  else
    warn "Documentation audit failed with #{errors.length} issue#{errors.length == 1 ? "" : "s"}:"
    errors.each { |error| warn "  - #{error}" }
    exit 1
  end
end
