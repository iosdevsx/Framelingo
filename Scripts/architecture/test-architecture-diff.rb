#!/usr/bin/env ruby

require "minitest/autorun"
require_relative "architecture_diff"

class ArchitectureDiffTest < Minitest::Test
  def test_reports_topology_impact_runtime_and_tests
    base = snapshot(
      modules: [
        package("A", dependencies: ["B"], tests: ["ATests"]),
        package("B", tests: ["BTests"]),
        package("D", dependencies: ["A"], tests: ["DTests"])
      ],
      runtime: [scenario("pipeline", "Pipeline", ["B"])]
    )
    head = snapshot(
      modules: [
        package("A", dependencies: ["B", "C"], tests: ["ATests"]),
        package("B", tests: ["BTests"]),
        package("C", tests: ["CTests"]),
        package("D", dependencies: ["A"], tests: ["DTests"])
      ],
      runtime: [scenario("pipeline", "Pipeline", ["B", "C"])]
    )

    diff = ArchitectureDiff.compare(base, head)

    assert diff.fetch("hasChanges")
    assert_equal ["C"], diff.dig("modules", "added")
    assert_includes diff.dig("edges", "added"), { "source" => "A", "target" => "C" }
    assert_equal ["D"], diff.dig("impact", "affectedModules")
    assert_equal ["Pipeline"], diff.dig("impact", "runtimeScenarios").map { |item| item.fetch("title") }
    assert_equal %w[ATests CTests DTests], diff.dig("impact", "suggestedTests")
  end

  def test_reports_no_changes_and_renders_stable_comment_marker
    input = snapshot(modules: [package("A")], runtime: [])
    diff = ArchitectureDiff.compare(input, input)
    markdown = ArchitectureDiff.markdown(diff, base_label: "main", head_label: "feature")

    refute diff.fetch("hasChanges")
    assert_includes markdown, ArchitectureDiff::COMMENT_MARKER
    assert_includes markdown, "No package topology"
  end

  def test_reports_runtime_only_changes
    base = snapshot(modules: [package("A")], runtime: [scenario("pipeline", "Pipeline", ["A"])])
    head = snapshot(modules: [package("A")], runtime: [scenario("pipeline", "Pipeline", ["A", "A"])])

    diff = ArchitectureDiff.compare(base, head)

    assert diff.fetch("hasChanges")
    assert_equal [{ "id" => "pipeline", "title" => "Pipeline" }], diff.dig("runtime", "changed")
    assert diff.dig("impact", "runtimeScenarios").first.fetch("directlyChanged")
  end

  def test_sanitizes_untrusted_markdown_values
    assert_equal "＠team line ˋcodeˋ", ArchitectureDiff.escape_code("@team\nline `code`")
  end

  private

  def snapshot(modules:, runtime:)
    { "modules" => modules, "runtimeScenarios" => runtime }
  end

  def package(name, dependencies: [], tests: [])
    {
      "name" => name,
      "category" => "Core",
      "dependencies" => dependencies,
      "tests" => tests
    }
  end

  def scenario(id, title, modules)
    {
      "id" => id,
      "title" => title,
      "steps" => modules.map.with_index do |name, index|
        { "id" => "step-#{index}", "module" => name }
      end
    }
  end
end
