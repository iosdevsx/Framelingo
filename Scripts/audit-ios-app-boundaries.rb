#!/usr/bin/env ruby
# frozen_string_literal: true

ROOT = File.expand_path("..", __dir__)
IOS_PACKAGE = File.join(ROOT, "AppTarget/Modules/Composition/IOSApp")
MANIFEST = File.join(IOS_PACKAGE, "Package.swift")
EXECUTABLE = File.join(ROOT, "AppTargetIOS/FramelingoIOSApp.swift")

FORBIDDEN_CONCRETE_PRODUCTS = %w[
  MacApp
  HomeFeatureImpl
  PlayerFeatureImpl
  ProjectFeatureImpl
  SubtitleEditorFeatureImpl
  TimelineImpl
  TimelineFeatureImpl
  ShortsImpl
  ShortsFeatureImpl
  VideoExportImpl
  ExportFeatureImpl
  SettingsImpl
  SettingsFeatureImpl
  SpeechToTextImpl
  VideoRenderingImpl
].freeze

SELECTED_SOURCE_ROOTS = %w[
  AppTarget/Modules/Composition/IOSApp/Sources
  AppTarget/Modules/Core/Project/Sources
  AppTarget/Modules/Core/Shorts/Sources/Api
  AppTarget/Modules/Core/SpeakerAnalysis/Sources/Api
  AppTarget/Modules/Core/Subtitles/Sources/Api
  AppTarget/Modules/Core/Timeline/Sources/Api
  AppTarget/Modules/Features/HomeFeature/Sources/Api
  AppTarget/Modules/Features/PlayerFeature/Sources/Api
  AppTarget/Modules/Features/SubtitleEditorFeature/Sources/Api
  AppTarget/Modules/Infrastructure/SpeechToText/Sources/Api
  AppTarget/Modules/Infrastructure/VideoExport/Sources/Api
  AppTarget/Modules/Infrastructure/VideoRendering/Sources/Api
  AppTarget/Modules/Workflows/ProjectPreparation/Sources/Api
  AppTarget/Modules/Workflows/ProjectSession/Sources
  AppTarget/Modules/Workflows/TranscriptionPipeline/Sources/Api
  AppTarget/Modules/Workflows/TranslationPipeline/Sources/Api
].freeze

FORBIDDEN_SOURCE_PATTERNS = {
  /^\s*import\s+AppKit\s*$/ => "AppKit import",
  /^\s*import\s+MacApp\s*$/ => "MacApp import",
  /^\s*import\s+MacFeature(?:Impl)?\s*$/ => "MacFeature import",
  /\bNSViewRepresentable\b/ => "NSViewRepresentable usage"
}.freeze

DUPLICATED_AUTHORITY_PATTERNS = {
  /\b(?:class|struct)\s+IOS?ProjectViewModel\b/ => "duplicated project ViewModel",
  /\b(?:class|struct)\s+ProjectViewModel\b/ => "duplicated ProjectViewModel",
  /\b(?:class|struct)\s+DefaultProjectSession\b/ => "duplicated project session",
  /\b(?:struct|class)\s+Project\s*[:{]/ => "duplicated Project domain model",
  /\b(?:enum|struct)\s+ProcessingStatus\b/ => "duplicated processing model",
  /\bprotocol\s+ProjectRepository\b/ => "duplicated persistence contract"
}.freeze

failures = []
manifest = File.read(MANIFEST, encoding: Encoding::UTF_8)

FORBIDDEN_CONCRETE_PRODUCTS.each do |product|
  if manifest.match?(/\.product\s*\(\s*name:\s*"#{Regexp.escape(product)}"/)
    failures << "Package.swift selects forbidden concrete product #{product}"
  end
end

%w[ProjectImpl ProjectSessionImpl].each do |required|
  unless manifest.match?(/\.product\s*\(\s*name:\s*"#{required}"/)
    failures << "Package.swift is missing required shared implementation #{required}"
  end
end

SELECTED_SOURCE_ROOTS.each do |relative_root|
  absolute_root = File.join(ROOT, relative_root)
  Dir.glob(File.join(absolute_root, "**/*.swift")).sort.each do |path|
    source = File.read(path, encoding: Encoding::UTF_8)
    label = path.delete_prefix("#{ROOT}/")
    FORBIDDEN_SOURCE_PATTERNS.each do |pattern, description|
      failures << "#{label}: #{description}" if source.match?(pattern)
    end
  end
end

Dir.glob(File.join(IOS_PACKAGE, "Sources/**/*.swift")).sort.each do |path|
  source = File.read(path, encoding: Encoding::UTF_8)
  label = path.delete_prefix("#{ROOT}/")
  DUPLICATED_AUTHORITY_PATTERNS.each do |pattern, description|
    failures << "#{label}: #{description}" if source.match?(pattern)
  end

  next unless source.match?(/\bpublic\b/)

  assembly_path = "AppTarget/Modules/Composition/IOSApp/Sources/Assembly/IOSAppAssembly.swift"
  failures << "#{label}: public product surface must live only in IOSAppAssembly" unless label == assembly_path
end


assembly = File.read(
  File.join(IOS_PACKAGE, "Sources/Assembly/IOSAppAssembly.swift"),
  encoding: Encoding::UTF_8
)
public_declarations = assembly.lines.grep(/\bpublic\b/).map(&:strip)
expected_public_declarations = [
  "public enum IOSAppAssembly {",
  "public static func makeRootView() -> AnyView {"
]
unless public_declarations == expected_public_declarations
  failures << "IOSAppAssembly public surface changed: #{public_declarations.join(' | ')}"
end

executable_imports = File.read(EXECUTABLE, encoding: Encoding::UTF_8)
  .scan(/^\s*import\s+(\w+)\s*$/)
  .flatten
unexpected_imports = executable_imports - %w[IOSApp SwiftUI]
unless unexpected_imports.empty?
  failures << "iOS executable imports capability modules: #{unexpected_imports.join(', ')}"
end

if failures.empty?
  puts "IOSApp boundary audit passed"
  exit 0
end

warn failures.join("\n")
exit 1
