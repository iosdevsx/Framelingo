#!/usr/bin/env ruby
# frozen_string_literal: true

PRODUCT_COMPOSERS = ["MacFeatureImpl"].freeze
MODULES_RELATIVE_ROOT = "AppTarget/Modules".freeze
APPLICATION_RETIREMENT_PATTERNS = {
  /^\s*(?:@testable\s+)?import\s+Application(?:Impl)?\s*$/ => "removed Application module import",
  /\.package\s*\(\s*path:\s*"\.\.\/Application"/ => "removed Application package dependency",
  /\.product\s*\(\s*name:\s*"Application(?:Impl)?"/ => "removed Application product dependency",
  /\bAppState\b/ => "removed AppState symbol",
  /\bAppStateDependencies\b/ => "removed AppStateDependencies symbol",
  /\bApplicationAssembly\b/ => "removed ApplicationAssembly symbol",
  /\bApplicationWorkflowAssembly\b/ => "removed ApplicationWorkflowAssembly symbol",
  /Modules\/Application/ => "removed Application Xcode reference"
}.freeze

MAC_PRODUCT_PLATFORM_SYMBOLS = %w[NSWorkspace NSPasteboard].freeze
SUBTITLE_PICKER_CONSUMER_ROOTS = [
  "#{MODULES_RELATIVE_ROOT}/ProjectFeature/",
  "#{MODULES_RELATIVE_ROOT}/SubtitleEditorFeature/"
].freeze
APPLICATION_PROCESSING_SYMBOLS = %w[
  ProjectProcessingEvent
  ProjectProcessingEventHandler
  ProjectTranslationRequest
  ProjectTranslationOutput
  ProjectTranslationError
  ProjectTranslationWorkflow
  DefaultProjectTranslationWorkflow
  ApplicationWorkflowAssembly
].freeze
EXTRACTED_PIPELINES = %w[
  ProjectPreparation
  TranscriptionPipeline
  TranslationPipeline
].freeze
PROJECT_SESSION_FORBIDDEN_IMPORTS = %w[SwiftUI AppKit UIKit].freeze

def read_utf8(path)
  File.read(path, encoding: Encoding::UTF_8)
end

def target_blocks(manifest)
  blocks = []
  offset = 0

  while (match = manifest.match(/\.target\s*\(/, offset))
    start = match.begin(0)
    index = match.end(0)
    depth = 1
    quoted = false
    escaped = false

    while index < manifest.length && depth.positive?
      character = manifest[index]
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

    blocks << manifest[start...index]
    offset = index
  end

  blocks
end

def audit_manifest(contents, label)
  package_name = contents[/name:\s*"([^"]+)"/, 1]
  failures = []

  target_blocks(contents).each do |block|
    target_name = block[/name:\s*"([^"]+)"/, 1]
    path = block[/path:\s*"([^"]+)"/, 1]
    next unless target_name

    impl_dependencies = block.scan(
      /\.product\s*\(\s*name:\s*"([^"]*Impl)"\s*,\s*package:\s*"([^"]+)"/
    )

    if path == "Sources/Api"
      impl_dependencies.each do |product, _package|
        failures << "#{label}: API target #{target_name} depends on Impl product #{product}"
      end
    elsif path == "Sources/Impl" && !PRODUCT_COMPOSERS.include?(target_name)
      impl_dependencies.each do |product, dependency_package|
        next if dependency_package == package_name

        failures << "#{label}: ordinary Impl target #{target_name} depends on foreign Impl product #{product}"
      end
    end
  end

  failures
end

def audit_import(source, label, role, target_name)
  source.scan(/^\s*(?:@testable\s+)?import\s+([A-Za-z0-9_]*Impl)\s*$/).each_with_object([]) do |match, failures|
    imported = match.first
    next if role == :impl && PRODUCT_COMPOSERS.include?(target_name)

    failures << "#{label}: #{role == :api ? 'API' : 'ordinary Impl'} target #{target_name} imports #{imported}"
  end
end

def audit_application_retirement(source, label)
  APPLICATION_RETIREMENT_PATTERNS.each_with_object([]) do |(pattern, description), failures|
    failures << "#{label}: #{description}" if source.match?(pattern)
  end
end

def audit_broad_dependency_bag(source, label)
  return [] if label.start_with?("#{MODULES_RELATIVE_ROOT}/MacFeature/")

  groups = [
    source.match?(/\bSettingsAccess\b/),
    source.match?(/\bProjectCatalogManaging\b/),
    %w[ProjectPreparing TranscribingProject TranslatingProject].all? { |name| source.match?(/\b#{name}\b/) },
    source.match?(/\bVideoExportQueue\b/),
    source.match?(/\b(?:SubtitleDocumentPicker|OutputReveal|DiagnosticCopy)\b/)
  ]
  return [] unless source.match?(/\bstruct\s+\w*Dependencies\b/) && groups.all?

  ["#{label}: ordinary feature dependency bag combines settings, catalog, all pipelines, export, and platform ports"]
end

def audit_application_processing_surface(source, label)
  APPLICATION_PROCESSING_SYMBOLS.each_with_object([]) do |symbol, failures|
    if source.match?(/\b#{Regexp.escape(symbol)}\b/)
      failures << "#{label}: removed Application processing workflow symbol #{symbol} returned"
    end
  end
end

def audit_pipeline_independence(contents, label, pipeline)
  (EXTRACTED_PIPELINES - [pipeline]).each_with_object([]) do |other_pipeline, failures|
    imports_runtime_module = contents.match?(/^\s*import\s+#{Regexp.escape(other_pipeline)}(?:Impl)?\s*$/)
    depends_on_package = contents.match?(/\.package\s*\(\s*path:\s*"\.\.\/#{Regexp.escape(other_pipeline)}"/)
    if imports_runtime_module || depends_on_package
      failures << "#{label}: #{pipeline} must not depend on extracted sibling #{other_pipeline}"
    end
  end
end

def audit_project_session_source(source, label, role)
  failures = []
  PROJECT_SESSION_FORBIDDEN_IMPORTS.each do |framework|
    if source.match?(/^\s*import\s+#{framework}\s*$/)
      failures << "#{label}: ProjectSession must not import #{framework}"
    end
  end
  if source.match?(/^\s*(?:@testable\s+)?import\s+\w+FeatureImpl\s*$/)
    failures << "#{label}: ProjectSession must not import a sibling FeatureImpl"
  end
  if role == :api && source.match?(/(?:inout\s+Project|\(\s*Project\s*\)\s*->\s*Project|replaceProject|installProject|mutateProject)/)
    failures << "#{label}: ProjectSession API exposes generic Project mutation authority"
  end
  failures
end

def audit_project_session_production_wiring(source, label)
  return [] unless label.start_with?("#{MODULES_RELATIVE_ROOT}/ProjectFeature/")
  return [] unless source.match?(/\bProjectSession(?:Impl|Assembly|Dependencies)?\b|\.package\s*\(\s*path:\s*"\.\.\/ProjectSession"/)

  ["#{label}: ProjectFeature must not construct or depend on ProjectSession before the editing migration"]
end

def run_self_test
  fixtures = {
    "accepted API-only dependency" => [
      <<~SWIFT,
        let package = Package(name: "Consumer", targets: [
          .target(name: "Consumer", dependencies: [.product(name: "TimelineFeature", package: "TimelineFeature")], path: "Sources/Api")
        ])
      SWIFT
      0
    ],
    "rejected API-to-Impl dependency" => [
      <<~SWIFT,
        let package = Package(name: "Consumer", targets: [
          .target(name: "Consumer", dependencies: [.product(name: "TimelineFeatureImpl", package: "TimelineFeature")], path: "Sources/Api")
        ])
      SWIFT
      1
    ],
    "rejected nested Impl dependency" => [
      <<~SWIFT,
        let package = Package(name: "Consumer", targets: [
          .target(name: "ConsumerImpl", dependencies: [.product(name: "TimelineFeatureImpl", package: "TimelineFeature")], path: "Sources/Impl")
        ])
      SWIFT
      1
    ],
    "accepted registered product composer" => [
      <<~SWIFT,
        let package = Package(name: "MacFeature", targets: [
          .target(name: "MacFeatureImpl", dependencies: [.product(name: "TimelineFeatureImpl", package: "TimelineFeature")], path: "Sources/Impl")
        ])
      SWIFT
      0
    ]
  }

  failures = fixtures.each_with_object([]) do |(name, (manifest, expected_count)), results|
    actual_count = audit_manifest(manifest, name).count
    results << "#{name}: expected #{expected_count} failure(s), got #{actual_count}" unless actual_count == expected_count
  end

  import_cases = [
    ["API import", "import TimelineFeatureImpl\n", :api, "Consumer", 1],
    ["ordinary Impl import", "import TimelineFeatureImpl\n", :impl, "ConsumerImpl", 1],
    ["composer import", "import TimelineFeatureImpl\n", :impl, "MacFeatureImpl", 0]
  ]
  import_cases.each do |name, source, role, target, expected_count|
    actual_count = audit_import(source, name, role, target).count
    failures << "#{name}: expected #{expected_count} failure(s), got #{actual_count}" unless actual_count == expected_count
  end


  retirement_cases = [
    ["focused API", "import TranscriptionPipeline\n", 0],
    ["Application import", "import Application\n", 1],
    ["ApplicationImpl import", "@testable import ApplicationImpl\n", 1],
    ["Application path", ".package(path: \"../Application\")\n", 1],
    ["AppState resurrection", "let state: AppState\n", 1],
    ["Xcode reference", "Modules/Application,\n", 1]
  ]
  retirement_cases.each do |name, source, expected_count|
    actual_count = audit_application_retirement(source, name).count
    failures << "#{name}: expected #{expected_count} failure(s), got #{actual_count}" unless actual_count == expected_count
  end

  broad_dependency_cases = [
    ["focused dependency", "struct EditingDependencies { let picker: SubtitleDocumentPicker }\n", 0],
    ["broad replacement", <<~SWIFT, 1]
      struct FeatureDependencies {
        let settings: SettingsAccess
        let catalog: ProjectCatalogManaging
        let preparation: ProjectPreparing
        let transcription: TranscribingProject
        let translation: TranslatingProject
        let exports: VideoExportQueue
        let picker: SubtitleDocumentPicker
      }
    SWIFT
  ]
  broad_dependency_cases.each do |name, source, expected_count|
    actual_count = audit_broad_dependency_bag(source, "#{MODULES_RELATIVE_ROOT}/Feature/#{name}.swift").count
    failures << "#{name}: expected #{expected_count} failure(s), got #{actual_count}" unless actual_count == expected_count
  end

  application_processing_cases = [
    ["clean focused surface", "public final class ActivityTracker {}\n", 0],
    ["workflow surface regression", "public protocol ProjectTranslationWorkflow {}\n", 1]
  ]
  application_processing_cases.each do |name, source, expected_count|
    actual_count = audit_application_processing_surface(source, name).count
    failures << "#{name}: expected #{expected_count} failure(s), got #{actual_count}" unless actual_count == expected_count
  end

  pipeline_independence_cases = [
    ["independent pipeline", "import Project\n", "TranslationPipeline", 0],
    ["pipeline source regression", "import TranscriptionPipeline\n", "TranslationPipeline", 1],
    ["pipeline manifest regression", ".package(path: \"../ProjectPreparation\")\n", "TranslationPipeline", 1]
  ]
  pipeline_independence_cases.each do |name, source, pipeline, expected_count|
    actual_count = audit_pipeline_independence(source, name, pipeline).count
    failures << "#{name}: expected #{expected_count} failure(s), got #{actual_count}" unless actual_count == expected_count
  end

  project_session_cases = [
    ["cross-platform core", "import Combine\nimport Project\n", :impl, 0],
    ["platform UI import", "import SwiftUI\n", :impl, 1],
    ["feature implementation import", "import TimelineFeatureImpl\n", :impl, 1],
    ["generic public mutation", "public func mutateProject(_ body: (inout Project) -> Void) {}\n", :api, 1]
  ]
  project_session_cases.each do |name, source, role, expected_count|
    actual_count = audit_project_session_source(source, name, role).count
    failures << "#{name}: expected #{expected_count} failure(s), got #{actual_count}" unless actual_count == expected_count
  end

  production_wiring_cases = [
    ["existing production owner", "import Project\n", 0],
    ["shadow session", "import ProjectSessionImpl\nlet session = ProjectSessionAssembly.makeSession\n", 1]
  ]
  production_wiring_cases.each do |name, source, expected_count|
    actual_count = audit_project_session_production_wiring(
      source,
      "#{MODULES_RELATIVE_ROOT}/ProjectFeature/#{name}.swift"
    ).count
    failures << "#{name}: expected #{expected_count} failure(s), got #{actual_count}" unless actual_count == expected_count
  end

  abort failures.join("\n") unless failures.empty?
  puts "Module-boundary audit self-tests passed."
end

repository_root = File.expand_path("..", __dir__)
modules_root = File.join(repository_root, MODULES_RELATIVE_ROOT)
run_self_test if ARGV.delete("--self-test")

failures = []
Dir.glob(File.join(modules_root, "*", "Package.swift")).sort.each do |manifest_path|
  failures.concat(audit_manifest(read_utf8(manifest_path), manifest_path.delete_prefix("#{repository_root}/")))
end

Dir.glob(File.join(modules_root, "*", "Sources", "{Api,Impl}", "**", "*.swift")).sort.each do |source_path|
  relative = source_path.delete_prefix("#{repository_root}/")
  module_relative = source_path.delete_prefix("#{modules_root}/")
  parts = module_relative.split(File::SEPARATOR)
  package_name = parts[0]
  role = parts[2] == "Api" ? :api : :impl
  target_name = role == :api ? package_name : "#{package_name}Impl"
  source = read_utf8(source_path)
  failures.concat(audit_import(source, relative, role, target_name))
  failures.concat(audit_broad_dependency_bag(source, relative))

  if package_name == "ProjectSession"
    failures.concat(audit_project_session_source(source, relative, role))
  end
  failures.concat(audit_project_session_production_wiring(source, relative))

  MAC_PRODUCT_PLATFORM_SYMBOLS.each do |symbol|
    next unless source.match?(/\b#{Regexp.escape(symbol)}\b/)
    next if relative.start_with?("#{MODULES_RELATIVE_ROOT}/MacFeature/Sources/Impl/")

    failures << "#{relative}: #{symbol} platform implementation must live in MacFeatureImpl"
  end


  if source_path.end_with?(".swift") && source.match?(/\bNSOpenPanel\b/) &&
     SUBTITLE_PICKER_CONSUMER_ROOTS.any? { |root| relative.start_with?(root) }
    failures << "#{relative}: subtitle document picker implementation must live in MacFeatureImpl"
  end
end

project_feature_manifest = File.join(modules_root, "ProjectFeature", "Package.swift")
failures.concat(
  audit_project_session_production_wiring(
    read_utf8(project_feature_manifest),
    project_feature_manifest.delete_prefix("#{repository_root}/")
  )
)


retirement_scan_paths = Dir.glob(File.join(modules_root, "**", "*.swift"))
retirement_scan_paths.concat(Dir.glob(File.join(modules_root, "*", "Package.swift")))
retirement_scan_paths << File.join(repository_root, "Framelingo.xcodeproj", "project.pbxproj")
retirement_scan_paths.sort.each do |path|
  relative = path.delete_prefix("#{repository_root}/")
  failures.concat(audit_application_retirement(read_utf8(path), relative))
end

anonymous_picker_paths = [
  "#{MODULES_RELATIVE_ROOT}/MacFeature/Sources/Api/MacFeatureDependencies.swift",
  "#{MODULES_RELATIVE_ROOT}/ProjectFeature/Sources/Impl/Assembly/ProjectFeatureDependencies.swift"
]
anonymous_picker_paths.each do |relative|
  path = File.join(repository_root, relative)
  next unless read_utf8(path).match?(/\bpickSubtitleFile\b/)

  failures << "#{relative}: anonymous subtitle picker authority returned"
end

Dir.glob(File.join(modules_root, "Application", "Sources", "**", "*.swift")).sort.each do |path|
  relative = path.delete_prefix("#{repository_root}/")
  failures.concat(audit_application_processing_surface(read_utf8(path), relative))
end

EXTRACTED_PIPELINES.each do |pipeline|
  package_root = File.join(modules_root, pipeline)
  manifest_path = File.join(package_root, "Package.swift")
  failures.concat(
    audit_pipeline_independence(
      read_utf8(manifest_path),
      manifest_path.delete_prefix("#{repository_root}/"),
      pipeline
    )
  )
  Dir.glob(File.join(package_root, "Sources", "**", "*.swift")).sort.each do |path|
    failures.concat(
      audit_pipeline_independence(
        read_utf8(path),
        path.delete_prefix("#{repository_root}/"),
        pipeline
      )
    )
  end
end

unless failures.empty?
  warn "Module-boundary audit failed:"
  failures.each { |failure| warn "- #{failure}" }
  exit 1
end

puts "Module-boundary audit passed (product composers: #{PRODUCT_COMPOSERS.join(', ')})."
