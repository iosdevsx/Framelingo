#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "minitest/autorun"
require "tmpdir"
require_relative "architecture_policy"
require_relative "package_graph"

class ArchitecturePolicyTest < Minitest::Test
  def with_fixture(manifests:, policy: base_policy, today: Date.new(2026, 8, 7))
    Dir.mktmpdir do |directory|
      root = Pathname.new(directory)
      manifests.each do |relative, dependencies|
        package = root.join("AppTarget/Modules", relative)
        FileUtils.mkdir_p(package.join("Sources/Api"))
        name = package.basename.to_s
        package.join("Sources/Api/Test.swift").write("public struct #{name}Value {}\n")
        package.join("Package.swift").write(<<~SWIFT)
          import PackageDescription
          let package = Package(
            name: "#{name}",
            dependencies: [#{dependencies.join(', ')}],
            targets: [.target(name: "#{name}", path: "Sources/Api")]
          )
        SWIFT
      end
      policy_path = root.join("policy.yml")
      policy_path.write(YAML.dump(policy))
      graph = FramelingoArchitecture::PackageGraphReader.new(root).read
      loaded = FramelingoArchitecture::ArchitecturePolicy.load(policy_path, graph: graph, today: today)
      yield FramelingoArchitecture::ArchitecturePolicyEvaluator.new(graph, loaded).evaluate
    end
  end

  def local(path)
    ".package(path: \"#{path}\")"
  end

  def external(url)
    ".package(url: \"#{url}\", exact: \"1.0.0\")"
  end

  def base_policy
    {
      "schema_version" => 1,
      "layers" => {
        "Core" => layer("AppTarget/Modules/Core/*", ["Core"], 2),
        "Features" => layer("AppTarget/Modules/Features/*", ["Core"], 2),
        "Infrastructure" => layer("AppTarget/Modules/Infrastructure/*", ["Core"], 2)
      },
      "packages" => {},
      "exceptions" => []
    }
  end

  def layer(path, directions, limit)
    {
      "paths" => [path],
      "allowed_local" => directions,
      "allowed_external" => [],
      "fan_out" => { "local" => limit, "external" => 0 }
    }
  end

  def test_valid_direction_and_explicit_same_layer_pass
    with_fixture(manifests: { "Features/F" => [local("../../Core/A")], "Core/A" => [] }) do |result|
      assert result.passed?
      assert_equal 2, result.counts.fetch("classifiedPackages")
    end
  end

  def test_forbidden_direction_has_stable_rule
    with_fixture(manifests: { "Core/A" => [local("../../Features/F")], "Features/F" => [] }) do |result|
      assert_equal ["ARCH-DIRECTION-001"], result.violations.map(&:rule_id)
    end
  end

  def test_same_layer_is_forbidden_without_explicit_self_direction
    policy = base_policy
    policy["layers"]["Core"]["allowed_local"] = []
    with_fixture(manifests: { "Core/A" => [local("../B")], "Core/B" => [] }, policy: policy) do |result|
      assert_equal ["ARCH-DIRECTION-001"], result.violations.map(&:rule_id)
    end
  end

  def test_exact_exception_suppresses_only_direction_rule
    policy = base_policy
    policy["exceptions"] = [{ "source" => "A", "target" => "F", "rationale" => "Fixture debt" }]
    with_fixture(manifests: { "Core/A" => [local("../../Features/F")], "Features/F" => [] }, policy: policy) do |result|
      assert result.passed?
    end
  end

  def test_cycle_is_canonical_and_not_suppressed_by_exception
    policy = base_policy
    policy["exceptions"] = [{ "source" => "A", "target" => "B", "rationale" => "Does not suppress cycles" }]
    with_fixture(manifests: { "Core/A" => [local("../B")], "Core/B" => [local("../A")] }, policy: policy) do |result|
      cycle = result.violations.find { |violation| violation.rule_id == "ARCH-CYCLE-001" }
      refute_nil cycle
      assert_equal "A -> B -> A", cycle.observed
    end
  end

  def test_local_fan_out_and_exact_override
    manifests = { "Core/A" => [local("../B"), local("../C")], "Core/B" => [], "Core/C" => [] }
    policy = base_policy
    policy["layers"]["Core"]["fan_out"]["local"] = 1
    with_fixture(manifests: manifests, policy: policy) do |result|
      assert_equal ["ARCH-FANOUT-001"], result.violations.map(&:rule_id)
      assert_equal "2: B, C", result.violations.first.observed
    end
    policy["packages"]["A"] = { "local_fan_out" => 2 }
    with_fixture(manifests: manifests, policy: policy) { |result| assert result.passed? }
  end

  def test_external_permission_and_fan_out_are_distinct
    policy = base_policy
    policy["packages"]["A"] = { "allowed_external" => ["Remote"], "external_fan_out" => 1 }
    with_fixture(manifests: { "Core/A" => [external("https://example.com/Remote.git")] }, policy: policy) do |result|
      assert result.passed?
    end
    policy["packages"]["A"] = { "external_fan_out" => 1 }
    with_fixture(manifests: { "Core/A" => [external("https://example.com/Remote.git")] }, policy: policy) do |result|
      assert_equal ["ARCH-EXTERNAL-001"], result.violations.map(&:rule_id)
    end
  end

  def test_unclassified_and_ambiguous_packages_have_stable_rules
    policy = base_policy
    policy["layers"]["Core"]["paths"] = ["AppTarget/Modules/Unowned/*"]
    with_fixture(manifests: { "Core/A" => [] }, policy: policy) do |result|
      assert_equal ["ARCH-CLASSIFICATION-001"], result.violations.map(&:rule_id)
    end

    policy = base_policy
    policy["layers"]["Other"] = layer("AppTarget/Modules/Core/*", [], 1)
    with_fixture(manifests: { "Core/A" => [] }, policy: policy) do |result|
      assert_equal ["ARCH-CLASSIFICATION-002"], result.violations.map(&:rule_id)
    end
  end

  def test_expired_exception_is_rejected
    policy = base_policy
    policy["exceptions"] = [{
      "source" => "A", "target" => "F", "rationale" => "Temporary", "expires_on" => "2026-08-06"
    }]
    error = assert_raises(FramelingoArchitecture::PolicyError) do
      with_fixture(manifests: { "Core/A" => [], "Features/F" => [] }, policy: policy) { |_result| }
    end
    assert_equal "ARCH-EXCEPTION-001", error.violation.rule_id
  end

  def test_strict_loader_rejects_version_fields_references_limits_and_wildcards
    invalid_policies = []
    policy = base_policy
    policy["schema_version"] = 2
    invalid_policies << [policy, "ARCH-POLICY-001"]
    policy = base_policy
    policy["unexpected"] = true
    invalid_policies << [policy, "ARCH-POLICY-002"]
    policy = base_policy
    policy["layers"]["Core"]["allowed_local"] = ["Missing"]
    invalid_policies << [policy, "ARCH-POLICY-003"]
    policy = base_policy
    policy["layers"]["Core"]["fan_out"]["local"] = -1
    invalid_policies << [policy, "ARCH-POLICY-002"]
    policy = base_policy
    policy["exceptions"] = [{ "source" => "*", "target" => "A", "rationale" => "Too broad" }]
    invalid_policies << [policy, "ARCH-POLICY-002"]

    invalid_policies.each do |invalid, rule_id|
      error = assert_raises(FramelingoArchitecture::PolicyError) do
        with_fixture(manifests: { "Core/A" => [] }, policy: invalid) { |_result| }
      end
      assert_equal rule_id, error.violation.rule_id
    end
  end

  def test_violation_order_and_renderers_are_deterministic
    policy = base_policy
    policy["layers"]["Core"]["allowed_local"] = []
    policy["layers"]["Core"]["fan_out"]["local"] = 0
    with_fixture(manifests: { "Core/Z" => [local("../A")], "Core/A" => [] }, policy: policy) do |result|
      assert_equal %w[ARCH-DIRECTION-001 ARCH-FANOUT-001], result.violations.map(&:rule_id)
      parsed = JSON.parse(FramelingoArchitecture::ResultRenderer.json(result))
      assert_equal false, parsed.fetch("passed")
      assert_includes FramelingoArchitecture::ResultRenderer.text(result), "observed: Z (Core) -> A (Core)"
      assert_includes FramelingoArchitecture::ResultRenderer.github_annotations(result), "::error"
    end
  end
end
