# frozen_string_literal: true

require "date"
require "json"
require "yaml"

module FramelingoArchitecture
  Violation = Struct.new(
    :rule_id,
    :path,
    :mod,
    :message,
    :observed,
    :expected,
    :remediation,
    keyword_init: true
  ) do
    def to_h
      {
        "ruleId" => rule_id,
        "severity" => "error",
        "path" => path,
        "module" => mod,
        "message" => message,
        "observed" => observed,
        "expected" => expected,
        "remediation" => remediation
      }
    end
  end

  class EvaluationResult
    attr_reader :counts, :violations

    def initialize(counts:, violations:)
      @counts = counts.freeze
      @violations = violations.sort_by do |violation|
        [violation.rule_id.to_s, violation.path.to_s, violation.mod.to_s, violation.observed.to_s]
      end.freeze
    end

    def passed?
      violations.empty?
    end

    def to_h
      {
        "schemaVersion" => 1,
        "passed" => passed?,
        "counts" => counts,
        "violations" => violations.map(&:to_h)
      }
    end

    def with_violations(additional)
      self.class.new(counts: counts, violations: violations + additional)
    end
  end

  class ResultRenderer
    def self.text(result)
      status = result.passed? ? "passed" : "failed"
      lines = ["Architecture audit #{status}."]
      counts = result.counts
      lines << format(
        "Evaluated policy schema %s: %s local packages, %s external packages, %s local edges, %s external edges, %s layers.",
        counts.fetch("policySchemaVersion", "n/a"),
        counts.fetch("localPackages", 0),
        counts.fetch("externalPackages", 0),
        counts.fetch("localEdges", 0),
        counts.fetch("externalEdges", 0),
        counts.fetch("layers", 0)
      )
      result.violations.each do |violation|
        affected = [violation.mod, violation.path].compact.reject(&:empty?).join(" at ")
        lines << "[#{violation.rule_id}] #{affected.empty? ? 'architecture' : affected}: #{violation.message}"
        lines << "  observed: #{violation.observed}"
        lines << "  expected: #{violation.expected}"
        lines << "  remediation: #{violation.remediation}"
      end
      "#{lines.join("\n")}\n"
    end

    def self.json(result)
      "#{JSON.pretty_generate(result.to_h)}\n"
    end

    def self.github_annotations(result)
      result.violations.map do |violation|
        properties = []
        properties << "file=#{escape_property(violation.path)}" if violation.path && !violation.path.empty?
        properties << "title=#{escape_property(violation.rule_id)}"
        message = [violation.message, "Observed: #{violation.observed}", "Expected: #{violation.expected}", violation.remediation].join(". ")
        "::error #{properties.join(',')}::#{escape_message(message)}"
      end.join("\n")
    end

    def self.escape_property(value)
      value.to_s.gsub("%", "%25").gsub("\r", "%0D").gsub("\n", "%0A").gsub(":", "%3A").gsub(",", "%2C")
    end
    private_class_method :escape_property

    def self.escape_message(value)
      value.to_s.gsub("%", "%25").gsub("\r", "%0D").gsub("\n", "%0A")
    end
    private_class_method :escape_message
  end

  class PolicyError < StandardError
    attr_reader :violation

    def initialize(violation)
      super(violation.message)
      @violation = violation
    end
  end

  class ArchitecturePolicy
    SUPPORTED_SCHEMA_VERSION = 1
    ROOT_KEYS = %w[schema_version layers packages exceptions].freeze
    LAYER_KEYS = %w[paths allowed_local allowed_external fan_out].freeze
    FAN_OUT_KEYS = %w[local external].freeze
    PACKAGE_KEYS = %w[allowed_external local_fan_out external_fan_out].freeze
    EXCEPTION_KEYS = %w[source target rationale expires_on].freeze

    attr_reader :schema_version, :layers, :package_overrides, :exceptions, :path

    def initialize(schema_version:, layers:, package_overrides:, exceptions:, path:)
      @schema_version = schema_version
      @layers = layers.freeze
      @package_overrides = package_overrides.freeze
      @exceptions = exceptions.freeze
      @path = path
    end

    def self.load(path, graph:, today: Date.today)
      source = File.read(path, encoding: Encoding::UTF_8)
      raw = YAML.safe_load(source, permitted_classes: [], permitted_symbols: [], aliases: false)
      Loader.new(raw, path.to_s, graph, today).load
    rescue Psych::Exception => error
      violation = Violation.new(
        rule_id: "ARCH-POLICY-002",
        path: path.to_s,
        mod: nil,
        message: "Architecture policy YAML is malformed: #{error.message}",
        observed: error.class.name,
        expected: "Valid YAML using only the documented policy schema",
        remediation: "Correct the YAML syntax and rerun the architecture check."
      )
      raise PolicyError, violation
    end

    class Loader
      def initialize(raw, path, graph, today)
        @raw = raw
        @path = path
        @graph = graph
        @today = today
      end

      def load
        root = hash!(@raw, "policy root")
        strict_keys!(root, ROOT_KEYS, "policy root")
        required_keys!(root, ROOT_KEYS, "policy root")
        version = root.fetch("schema_version")
        unless version == SUPPORTED_SCHEMA_VERSION
          fail_policy!(
            "ARCH-POLICY-001",
            "Unsupported architecture policy schema version",
            version.inspect,
            SUPPORTED_SCHEMA_VERSION.to_s,
            "Migrate the policy to the supported schema version."
          )
        end

        layers = load_layers(root.fetch("layers"))
        packages = load_packages(root.fetch("packages"))
        exceptions = load_exceptions(root.fetch("exceptions"))
        validate_references!(layers, packages, exceptions)
        ArchitecturePolicy.new(
          schema_version: version,
          layers: layers,
          package_overrides: packages,
          exceptions: exceptions,
          path: @path
        )
      end

      private

      def load_layers(raw_layers)
        layers = hash!(raw_layers, "layers")
        fail_policy!("ARCH-POLICY-002", "Policy declares no layers", "0 layers", "At least one layer", "Add path-based layer definitions.") if layers.empty?
        layers.each_with_object({}) do |(name, raw_layer), result|
          string!(name, "layer name")
          layer = hash!(raw_layer, "layer #{name}")
          strict_keys!(layer, LAYER_KEYS, "layer #{name}")
          required_keys!(layer, LAYER_KEYS, "layer #{name}")
          paths = string_array!(layer.fetch("paths"), "#{name}.paths")
          fail_policy!("ARCH-POLICY-002", "Layer #{name} has no path classifiers", "empty paths", "One or more exact path patterns", "Add a repository-relative package path pattern.") if paths.empty?
          allowed_local = string_array!(layer.fetch("allowed_local"), "#{name}.allowed_local")
          allowed_external = exact_string_array!(layer.fetch("allowed_external"), "#{name}.allowed_external")
          fan_out = hash!(layer.fetch("fan_out"), "#{name}.fan_out")
          strict_keys!(fan_out, FAN_OUT_KEYS, "#{name}.fan_out")
          required_keys!(fan_out, FAN_OUT_KEYS, "#{name}.fan_out")
          result[name] = {
            "paths" => paths.sort,
            "allowed_local" => allowed_local.sort,
            "allowed_external" => allowed_external.sort,
            "fan_out" => {
              "local" => limit!(fan_out.fetch("local"), "#{name}.fan_out.local"),
              "external" => limit!(fan_out.fetch("external"), "#{name}.fan_out.external")
            }
          }
        end
      end

      def load_packages(raw_packages)
        packages = hash!(raw_packages, "packages")
        packages.each_with_object({}) do |(name, raw_override), result|
          string!(name, "package override name")
          override = hash!(raw_override, "package override #{name}")
          strict_keys!(override, PACKAGE_KEYS, "package override #{name}")
          fail_policy!("ARCH-POLICY-002", "Package override #{name} is empty", "empty override", "At least one documented override", "Remove the override or add an allowed field.") if override.empty?
          normalized = {}
          if override.key?("allowed_external")
            normalized["allowed_external"] = exact_string_array!(override.fetch("allowed_external"), "#{name}.allowed_external").sort
          end
          normalized["local_fan_out"] = limit!(override.fetch("local_fan_out"), "#{name}.local_fan_out") if override.key?("local_fan_out")
          normalized["external_fan_out"] = limit!(override.fetch("external_fan_out"), "#{name}.external_fan_out") if override.key?("external_fan_out")
          result[name] = normalized
        end
      end

      def load_exceptions(raw_exceptions)
        array!(raw_exceptions, "exceptions").map.with_index do |raw_exception, index|
          exception = hash!(raw_exception, "exception #{index + 1}")
          strict_keys!(exception, EXCEPTION_KEYS, "exception #{index + 1}")
          required_keys!(exception, %w[source target rationale], "exception #{index + 1}")
          source = exact_string!(exception.fetch("source"), "exception source")
          target = exact_string!(exception.fetch("target"), "exception target")
          rationale = string!(exception.fetch("rationale"), "exception rationale")
          fail_policy!("ARCH-POLICY-002", "Architecture exception has an empty rationale", "#{source} -> #{target}", "A non-empty reviewable rationale", "Explain why this exact edge is temporarily or permanently necessary.") if rationale.strip.empty?
          expires_on = exception["expires_on"]
          if expires_on
            exact_string!(expires_on, "exception expires_on")
            begin
              expiration = Date.iso8601(expires_on)
            rescue ArgumentError
              fail_policy!("ARCH-POLICY-002", "Architecture exception has an invalid expiration", expires_on, "An ISO 8601 date (YYYY-MM-DD)", "Correct or remove expires_on.")
            end
            if expiration < @today
              fail_policy!(
                "ARCH-EXCEPTION-001",
                "Architecture direction exception has expired",
                "#{source} -> #{target}, expired #{expires_on}",
                "An unexpired exact exception or a policy-compliant edge",
                "Remove the dependency, renew the exception with review, or update the architecture."
              )
            end
          end
          { "source" => source, "target" => target, "rationale" => rationale, "expires_on" => expires_on }
        end.sort_by { |exception| [exception.fetch("source"), exception.fetch("target")] }
      end

      def validate_references!(layers, packages, exceptions)
        layer_names = layers.keys
        external_names = @graph.external_packages.map { |package| package.fetch("name") }
        local_names = @graph.local_packages.map { |package| package.fetch("name") }
        layers.each do |name, layer|
          unknown_layers = layer.fetch("allowed_local") - layer_names
          invalid_reference!("layer #{name}", unknown_layers, "declared layers") unless unknown_layers.empty?
          unknown_external = layer.fetch("allowed_external") - external_names
          invalid_reference!("layer #{name}", unknown_external, "discovered external packages") unless unknown_external.empty?
        end
        unknown_packages = packages.keys - local_names
        invalid_reference!("package overrides", unknown_packages, "discovered local packages") unless unknown_packages.empty?
        packages.each do |name, override|
          next unless override.key?("allowed_external")
          unknown_external = override.fetch("allowed_external") - external_names
          invalid_reference!("package override #{name}", unknown_external, "discovered external packages") unless unknown_external.empty?
        end
        exceptions.each do |exception|
          unknown = [exception.fetch("source"), exception.fetch("target")] - local_names
          invalid_reference!("direction exception", unknown, "discovered local packages") unless unknown.empty?
        end
      end

      def invalid_reference!(context, values, expected)
        fail_policy!("ARCH-POLICY-003", "Unknown architecture policy reference in #{context}", values.sort.join(", "), expected, "Correct the exact reference or add the corresponding graph identity.")
      end

      def strict_keys!(hash, allowed, context)
        unknown = hash.keys - allowed
        return if unknown.empty?
        fail_policy!("ARCH-POLICY-002", "Unknown field in #{context}", unknown.map(&:to_s).sort.join(", "), allowed.join(", "), "Remove unsupported fields or migrate the schema version.")
      end

      def required_keys!(hash, required, context)
        missing = required - hash.keys
        return if missing.empty?
        fail_policy!("ARCH-POLICY-002", "Missing required field in #{context}", missing.join(", "), required.join(", "), "Add every required field using the documented schema.")
      end

      def hash!(value, context)
        return value if value.is_a?(Hash) && value.keys.all? { |key| key.is_a?(String) }
        fail_policy!("ARCH-POLICY-002", "Malformed #{context}", value.class.name, "A mapping with string keys", "Use the documented YAML mapping shape.")
      end

      def array!(value, context)
        return value if value.is_a?(Array)
        fail_policy!("ARCH-POLICY-002", "Malformed #{context}", value.class.name, "An array", "Use the documented YAML list shape.")
      end

      def string_array!(value, context)
        array!(value, context).map { |item| string!(item, context) }.uniq
      end

      def exact_string_array!(value, context)
        string_array!(value, context).map { |item| exact_string!(item, context) }
      end

      def string!(value, context)
        return value if value.is_a?(String) && !value.empty?
        fail_policy!("ARCH-POLICY-002", "Malformed #{context}", value.inspect, "A non-empty string", "Use a non-empty quoted string.")
      end

      def exact_string!(value, context)
        string!(value, context)
        if value.match?(/[\*\?\[]/)
          fail_policy!("ARCH-POLICY-002", "Wildcard is not allowed in #{context}", value, "An exact package or dependency name", "Replace the wildcard with an exact identity.")
        end
        value
      end

      def limit!(value, context)
        return value if value.is_a?(Integer) && value >= 0
        fail_policy!("ARCH-POLICY-002", "Malformed fan-out limit #{context}", value.inspect, "A non-negative integer", "Choose an evidence-based integer threshold.")
      end

      def fail_policy!(rule_id, message, observed, expected, remediation)
        raise PolicyError, Violation.new(
          rule_id: rule_id,
          path: @path,
          mod: nil,
          message: message,
          observed: observed,
          expected: expected,
          remediation: remediation
        )
      end
    end
  end

  class ArchitecturePolicyEvaluator
    def initialize(graph, policy)
      @graph = graph
      @policy = policy
    end

    def evaluate
      violations = []
      layer_by_package = classify_packages(violations)
      exception_edges = @policy.exceptions.map { |exception| [exception.fetch("source"), exception.fetch("target")] }
      violations.concat(direction_violations(layer_by_package, exception_edges))
      violations.concat(external_violations(layer_by_package))
      violations.concat(cycle_violations)
      violations.concat(fan_out_violations(layer_by_package))
      EvaluationResult.new(counts: counts(layer_by_package), violations: violations)
    end

    private

    def classify_packages(violations)
      @graph.local_packages.each_with_object({}) do |package, result|
        matches = @policy.layers.select do |_name, layer|
          layer.fetch("paths").any? do |pattern|
            File.fnmatch?(pattern, package.fetch("path"), File::FNM_PATHNAME | File::FNM_EXTGLOB)
          end
        end.keys.sort
        if matches.empty?
          violations << violation(
            "ARCH-CLASSIFICATION-001", package, "Package is not classified by architecture policy",
            package.fetch("path"), "Exactly one matching layer path", "Add a single path classifier for this package."
          )
        elsif matches.length > 1
          violations << violation(
            "ARCH-CLASSIFICATION-002", package, "Package matches multiple architecture layers",
            matches.join(", "), "Exactly one matching layer", "Make the layer path patterns mutually exclusive."
          )
        else
          result[package.fetch("name")] = matches.first
        end
      end
    end

    def direction_violations(layer_by_package, exceptions)
      @graph.local_edges.each_with_object([]) do |edge, violations|
        source_layer = layer_by_package[edge.fetch("source")]
        target_layer = layer_by_package[edge.fetch("target")]
        next unless source_layer && target_layer
        next if @policy.layers.fetch(source_layer).fetch("allowed_local").include?(target_layer)
        next if exceptions.include?([edge.fetch("source"), edge.fetch("target")])
        package = @graph.package_named(edge.fetch("source"))
        violations << violation(
          "ARCH-DIRECTION-001", package, "Forbidden local dependency direction",
          "#{edge.fetch('source')} (#{source_layer}) -> #{edge.fetch('target')} (#{target_layer})",
          "#{source_layer} may depend on #{@policy.layers.fetch(source_layer).fetch('allowed_local').join(', ')}",
          "Depend on an allowed API layer, move responsibility, or add a reviewed exact exception."
        )
      end
    end

    def external_violations(layer_by_package)
      @graph.external_edges.each_with_object([]) do |edge, violations|
        layer_name = layer_by_package[edge.fetch("source")]
        next unless layer_name
        override = @policy.package_overrides.fetch(edge.fetch("source"), {})
        allowed = if override.key?("allowed_external")
          override.fetch("allowed_external")
        else
          @policy.layers.fetch(layer_name).fetch("allowed_external")
        end
        next if allowed.include?(edge.fetch("target"))
        package = @graph.package_named(edge.fetch("source"))
        violations << violation(
          "ARCH-EXTERNAL-001", package, "External package dependency is not permitted",
          "#{edge.fetch('source')} -> #{edge.fetch('target')}",
          "Allowed external packages: #{allowed.empty? ? 'none' : allowed.join(', ')}",
          "Remove the dependency or add an exact reviewed external permission."
        )
      end
    end

    def cycle_violations
      canonical_cycles.map do |cycle|
        package = @graph.package_named(cycle.first)
        violation(
          "ARCH-CYCLE-001", package, "Local package dependency cycle detected",
          cycle.join(" -> "), "An acyclic local package graph",
          "Invert or extract one dependency; direction exceptions cannot suppress cycles."
        )
      end
    end

    def canonical_cycles
      names = @graph.local_packages.map { |package| package.fetch("name") }.sort
      adjacency = names.to_h { |name| [name, []] }
      @graph.local_edges.each { |edge| adjacency.fetch(edge.fetch("source")) << edge.fetch("target") }
      adjacency.each_value(&:sort!)
      cycles = {}
      names.each do |start|
        find_cycles(start, start, adjacency, [start], { start => true }, cycles)
      end
      cycles.keys.sort.map { |key| cycles.fetch(key) }
    end

    def find_cycles(start, current, adjacency, path, visited, cycles)
      adjacency.fetch(current).each do |neighbor|
        next if neighbor < start
        if neighbor == start
          closed = path + [start]
          cycles[closed.join("\0")] = closed
        elsif !visited[neighbor]
          visited[neighbor] = true
          find_cycles(start, neighbor, adjacency, path + [neighbor], visited, cycles)
          visited.delete(neighbor)
        end
      end
    end

    def fan_out_violations(layer_by_package)
      @graph.local_packages.each_with_object([]) do |package, violations|
        name = package.fetch("name")
        layer_name = layer_by_package[name]
        next unless layer_name
        layer_limits = @policy.layers.fetch(layer_name).fetch("fan_out")
        override = @policy.package_overrides.fetch(name, {})
        { "local" => "ARCH-FANOUT-001", "external" => "ARCH-FANOUT-002" }.each do |kind, rule_id|
          dependencies = @graph.edges.select do |edge|
            edge.fetch("source") == name && edge.fetch("kind") == kind
          end.map { |edge| edge.fetch("target") }.uniq.sort
          override_key = "#{kind}_fan_out"
          limit = override.key?(override_key) ? override.fetch(override_key) : layer_limits.fetch(kind)
          next unless dependencies.length > limit
          violations << violation(
            rule_id, package, "Direct #{kind} dependency fan-out exceeds policy",
            "#{dependencies.length}: #{dependencies.join(', ')}", "At most #{limit} distinct direct #{kind} dependencies",
            "Remove or consolidate direct dependencies, or justify an exact package override."
          )
        end
      end
    end

    def counts(layer_by_package)
      {
        "policySchemaVersion" => @policy.schema_version,
        "policyEvaluations" => 1,
        "layers" => @policy.layers.length,
        "classifiedPackages" => layer_by_package.length,
        "localPackages" => @graph.local_packages.length,
        "externalPackages" => @graph.external_packages.length,
        "localEdges" => @graph.local_edges.length,
        "externalEdges" => @graph.external_edges.length
      }
    end

    def violation(rule_id, package, message, observed, expected, remediation)
      Violation.new(
        rule_id: rule_id,
        path: package && package["path"],
        mod: package && package["name"],
        message: message,
        observed: observed,
        expected: expected,
        remediation: remediation
      )
    end
  end
end
