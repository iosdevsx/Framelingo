#!/usr/bin/env ruby
# frozen_string_literal: true

PRODUCT_COMPOSERS = ["MacFeatureImpl"].freeze
APP_STATE_FORBIDDEN_SURFACE = {
  /@Published\s+public\s+var\s+settings\b/ => "AppState owns global settings",
  /@Published\s+public\s+var\s+recentProjects\b/ => "AppState owns recent projects",
  /public\s+let\s+projectRepository\b/ => "AppState exposes ProjectRepository",
  /\bsaveSettings\b/ => "AppState construction exposes settings persistence"
}.freeze

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

def audit_app_state_surface(source, label)
  APP_STATE_FORBIDDEN_SURFACE.each_with_object([]) do |(pattern, description), failures|
    failures << "#{label}: #{description}" if source.match?(pattern)
  end
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


  app_state_cases = [
    ["reduced AppState", "@Published public var selectedProject: Project?\n", 0],
    ["settings owner regression", "@Published public var settings: AppSettings\n", 1],
    ["recents owner regression", "@Published public var recentProjects: [Project]\n", 1],
    ["repository regression", "public let projectRepository: any ProjectRepository\n", 1],
    ["settings persistence regression", "public var saveSettings: (AppSettings) -> Void\n", 1]
  ]
  app_state_cases.each do |name, source, expected_count|
    actual_count = audit_app_state_surface(source, name).count
    failures << "#{name}: expected #{expected_count} failure(s), got #{actual_count}" unless actual_count == expected_count
  end

  abort failures.join("\n") unless failures.empty?
  puts "Module-boundary audit self-tests passed."
end

repository_root = File.expand_path("..", __dir__)
run_self_test if ARGV.delete("--self-test")

failures = []
Dir.glob(File.join(repository_root, "Modules", "*", "Package.swift")).sort.each do |manifest_path|
  failures.concat(audit_manifest(File.read(manifest_path), manifest_path.delete_prefix("#{repository_root}/")))
end

Dir.glob(File.join(repository_root, "Modules", "*", "Sources", "{Api,Impl}", "**", "*.swift")).sort.each do |source_path|
  relative = source_path.delete_prefix("#{repository_root}/")
  parts = relative.split(File::SEPARATOR)
  package_name = parts[1]
  role = parts[3] == "Api" ? :api : :impl
  target_name = role == :api ? package_name : "#{package_name}Impl"
  failures.concat(audit_import(File.read(source_path), relative, role, target_name))
end


app_state_surface_paths = [
  "Modules/Application/Sources/Api/State/AppState.swift",
  "Modules/Application/Sources/Api/Dependencies/ApplicationDependencies.swift",
  "Modules/Application/Sources/Impl/Assembly/ApplicationAssembly.swift"
]
app_state_surface_paths.each do |relative|
  path = File.join(repository_root, relative)
  failures.concat(audit_app_state_surface(File.read(path), relative))
end

unless failures.empty?
  warn "Module-boundary audit failed:"
  failures.each { |failure| warn "- #{failure}" }
  exit 1
end

puts "Module-boundary audit passed (product composers: #{PRODUCT_COMPOSERS.join(', ')})."
