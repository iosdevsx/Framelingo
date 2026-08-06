#!/usr/bin/env ruby

require "digest"
require "json"
require "optparse"
require "pathname"

Declaration = Struct.new(
  :kind,
  :name,
  :path,
  :line,
  :source,
  :normalized_source,
  keyword_init: true
)

options = {
  original: "Framelingo",
  modular: "AppTarget",
  allowlist: "openspec/changes/modularize-codebase-with-spm/parity-allowlist.json",
  format: "text"
}

OptionParser.new do |parser|
  parser.banner = "Usage: Scripts/audit-module-parity.rb [options]"
  parser.on("--original PATH", "Original source root (default: Framelingo)") { |value| options[:original] = value }
  parser.on("--modular PATHS", "Comma-separated modular source roots (default: AppTarget)") { |value| options[:modular] = value }
  parser.on("--allowlist PATH", "Reviewed boundary-adaptation allowlist") { |value| options[:allowlist] = value }
  parser.on("--format FORMAT", %w[text json], "Output format: text or json") { |value| options[:format] = value }
end.parse!

DECLARATION_PATTERN = /\A
  (?:(?:@[A-Za-z_][A-Za-z0-9_]*(?:\([^\n]*\))?)\s+)*
  (?:(?:public|internal|package|private|fileprivate|open)\s+)*
  (?:(?:static|mutating|nonmutating|nonisolated)\s+)*
  (?:(?:final|indirect)\s+)*
  (?<kind>struct|class|enum|protocol|actor|typealias|extension|func)\s+
  (?<name>[A-Za-z_][A-Za-z0-9_\.]*)
/x

def swift_files(root)
  Dir.glob(File.join(root, "**", "*.swift"))
    .reject { |path| path.include?("/.build/") }
    .sort
end

def declaration_end_offset(source, start_offset)
  opening_offset = source.index("{", start_offset)
  line_end = source.index("\n", start_offset) || source.length
  return line_end if opening_offset.nil? || opening_offset > line_end && source[start_offset...line_end].include?("typealias")

  depth = 0
  index = opening_offset
  state = :code
  block_comment_depth = 0
  raw_string_hashes = 0

  while index < source.length
    current = source[index]
    next_character = source[index + 1]

    case state
    when :code
      if current == "/" && next_character == "/"
        state = :line_comment
        index += 1
      elsif current == "/" && next_character == "*"
        state = :block_comment
        block_comment_depth = 1
        index += 1
      elsif current == "\"" && source[index, 3] == "\"\"\""
        state = :multiline_string
        index += 2
      elsif current == "\""
        state = :string
      elsif current == "#"
        hash_count = 0
        hash_count += 1 while source[index + hash_count] == "#"
        quote_offset = index + hash_count
        if source[quote_offset] == "\""
          raw_string_hashes = hash_count
          if source[quote_offset, 3] == "\"\"\""
            state = :raw_multiline_string
            index = quote_offset + 2
          else
            state = :raw_string
            index = quote_offset
          end
        end
      elsif current == "{"
        depth += 1
      elsif current == "}"
        depth -= 1
        return index + 1 if depth.zero?
      end
    when :line_comment
      state = :code if current == "\n"
    when :block_comment
      if current == "/" && next_character == "*"
        block_comment_depth += 1
        index += 1
      elsif current == "*" && next_character == "/"
        block_comment_depth -= 1
        index += 1
        state = :code if block_comment_depth.zero?
      end
    when :string
      if current == "\\"
        index += 1
      elsif current == "\""
        state = :code
      end
    when :multiline_string
      if source[index, 3] == "\"\"\""
        state = :code
        index += 2
      end
    when :raw_string
      terminator = "\"" + ("#" * raw_string_hashes)
      if source[index, terminator.length] == terminator
        state = :code
        index += terminator.length - 1
      end
    when :raw_multiline_string
      terminator = "\"\"\"" + ("#" * raw_string_hashes)
      if source[index, terminator.length] == terminator
        state = :code
        index += terminator.length - 1
      end
    end

    index += 1
  end

  source.length
end

def strip_comments(source)
  source
    .gsub(%r{/\*.*?\*/}m, "")
    .gsub(%r{//[^\n]*}, "")
end

def normalized(source)
  strip_comments(source)
    .gsub(/\b(?:public|internal|package|fileprivate|private|open)\b/, "")
    .gsub(/\s+/, "")
end

def declarations_in(path)
  source = File.read(path)
  declarations = []
  offset = 0

  source.each_line.with_index(1) do |line, line_number|
    if (match = DECLARATION_PATTERN.match(line))
      end_offset = declaration_end_offset(source, offset)
      declaration_source = source[offset...end_offset]
      declarations << Declaration.new(
        kind: match[:kind],
        name: match[:name],
        path: path,
        line: line_number,
        source: declaration_source,
        normalized_source: normalized(declaration_source)
      )
    end
    offset += line.length
  end

  declarations
end

original_root = Pathname(options[:original]).expand_path
modular_roots = options[:modular].split(",").map { |path| Pathname(path).expand_path }
repository_root = Pathname.pwd
allowlist_path = Pathname(options[:allowlist])
allowlist = allowlist_path.exist? ? JSON.parse(allowlist_path.read) : {}

original_declarations = swift_files(original_root.to_s).flat_map { |path| declarations_in(path) }
modular_declarations = modular_roots.flat_map do |root|
  swift_files(root.to_s).flat_map { |path| declarations_in(path) }
end
modular_by_identity = modular_declarations.group_by { |declaration| [declaration.kind, declaration.name] }

rows = original_declarations.map do |original|
  matches = modular_by_identity.fetch([original.kind, original.name], [])
  exact_matches = matches.select { |candidate| candidate.normalized_source == original.normalized_source }
  original_location = Pathname(original.path).relative_path_from(repository_root).to_s
  original_fingerprint = Digest::SHA256.hexdigest(original.normalized_source)
  allowance_key = "#{original_location}|#{original.kind}|#{original.name}"
  allowance = allowlist[allowance_key]
  expected_modular_path = allowance&.fetch("modular_path", nil)
  expected_candidate = if expected_modular_path
    matches.find do |candidate|
      Pathname(candidate.path).relative_path_from(repository_root).to_s == expected_modular_path
    end
  end
  reviewed_original_matches = allowance && (
    allowance["original_fingerprint"].nil? ||
    allowance["original_fingerprint"] == original_fingerprint
  )
  reviewed_modular_matches = if allowance&.key?("modular_fingerprint")
    expected_candidate && (
      allowance["modular_fingerprint"] == Digest::SHA256.hexdigest(expected_candidate.normalized_source)
    )
  else
    true
  end
  allowed_match = allowance && reviewed_original_matches && reviewed_modular_matches && (
    expected_modular_path.nil? || !expected_candidate.nil?
  )

  status = if exact_matches.any?
    "mechanical"
  elsif allowed_match
    "boundary"
  elsif matches.any?
    "modified"
  else
    "missing"
  end

  {
    status: status,
    kind: original.kind,
    name: original.name,
    original: "#{original_location}:#{original.line}",
    modular: matches.map { |match| "#{Pathname(match.path).relative_path_from(repository_root)}:#{match.line}" },
    original_fingerprint: original_fingerprint,
    modular_fingerprints: matches.to_h do |match|
      relative_path = Pathname(match.path).relative_path_from(repository_root).to_s
      [relative_path, Digest::SHA256.hexdigest(match.normalized_source)]
    end,
    review_reason: allowance&.fetch("reason", nil)
  }
end

summary = rows.group_by { |row| row[:status] }.transform_values(&:count)
summary = { "mechanical" => 0, "boundary" => 0, "modified" => 0, "missing" => 0 }.merge(summary)

if options[:format] == "json"
  puts JSON.pretty_generate(summary: summary, declarations: rows)
  exit
end

puts "Original declarations: #{rows.count}"
puts "Mechanical: #{summary.fetch("mechanical")}; boundary: #{summary.fetch("boundary")}; modified: #{summary.fetch("modified")}; missing: #{summary.fetch("missing")}"
puts

rows.each do |row|
  destinations = row[:modular].empty? ? "—" : row[:modular].join(", ")
  puts "%-10s %-10s %-42s %-70s %s" % [
    row[:status].upcase,
    row[:kind],
    row[:name],
    row[:original],
    destinations
  ]
  puts "           review: #{row[:review_reason]}" if row[:review_reason]
end
