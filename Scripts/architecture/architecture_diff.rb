require "json"
require "set"

module ArchitectureDiff
  COMMENT_MARKER = "<!-- framelingo-architecture-diff -->"
  DISPLAY_LIMIT = 24

  module_function

  def compare(base_snapshot, head_snapshot)
    base_modules = index_modules(base_snapshot)
    head_modules = index_modules(head_snapshot)
    base_names = base_modules.keys.to_set
    head_names = head_modules.keys.to_set
    added_modules = (head_names - base_names).to_a.sort
    removed_modules = (base_names - head_names).to_a.sort

    changed_modules = (base_names & head_names).map do |name|
      change = module_change(base_modules.fetch(name), head_modules.fetch(name))
      change.merge("name" => name) unless change.empty?
    end.compact.sort_by { |record| record.fetch("name") }

    base_edges = edge_set(base_modules)
    head_edges = edge_set(head_modules)
    added_edges = sorted_edges(head_edges - base_edges)
    removed_edges = sorted_edges(base_edges - head_edges)
    changed_roots = Set.new(added_modules + removed_modules + changed_modules.map { |record| record.fetch("name") })
    base_runtime = index_runtime_scenarios(base_snapshot)
    head_runtime = index_runtime_scenarios(head_snapshot)
    base_runtime_ids = base_runtime.keys.to_set
    head_runtime_ids = head_runtime.keys.to_set
    added_runtime_ids = (head_runtime_ids - base_runtime_ids).to_a.sort
    removed_runtime_ids = (base_runtime_ids - head_runtime_ids).to_a.sort
    changed_runtime_ids = (base_runtime_ids & head_runtime_ids).select do |id|
      base_runtime.fetch(id) != head_runtime.fetch(id)
    end.to_a.sort
    directly_changed_runtime_ids = Set.new(added_runtime_ids + removed_runtime_ids + changed_runtime_ids)

    affected_modules = changed_roots.to_a.flat_map do |name|
      (transitive_dependents(name, head_modules) | transitive_dependents(name, base_modules)).to_a
    end.to_set.subtract(changed_roots).to_a.sort
    verification_modules = (changed_roots.to_a + affected_modules).to_set
    suggested_tests = verification_modules.flat_map do |name|
      [head_modules[name], base_modules[name]].compact.flat_map { |record| record.fetch("tests", []) }
    end.uniq.sort
    affected_runtime_scenarios = runtime_scenarios(head_snapshot, base_snapshot).map do |scenario|
      touched_steps = scenario.fetch("steps", []).select { |step| verification_modules.include?(step["module"]) }
      next if touched_steps.empty? && !directly_changed_runtime_ids.include?(scenario.fetch("id"))

      {
        "id" => scenario.fetch("id"),
        "title" => scenario.fetch("title"),
        "modules" => touched_steps.map { |step| step.fetch("module") }.uniq.sort,
        "directlyChanged" => directly_changed_runtime_ids.include?(scenario.fetch("id"))
      }
    end.compact

    runtime_added = added_runtime_ids.map { |id| runtime_identity(head_runtime.fetch(id)) }
    runtime_removed = removed_runtime_ids.map { |id| runtime_identity(base_runtime.fetch(id)) }
    runtime_changed = changed_runtime_ids.map { |id| runtime_identity(head_runtime.fetch(id)) }

    {
      "schemaVersion" => 1,
      "hasChanges" => !(
        added_modules.empty? && removed_modules.empty? && changed_modules.empty? &&
        added_runtime_ids.empty? && removed_runtime_ids.empty? && changed_runtime_ids.empty?
      ),
      "summary" => {
        "addedModules" => added_modules.length,
        "removedModules" => removed_modules.length,
        "changedModules" => changed_modules.length,
        "addedEdges" => added_edges.length,
        "removedEdges" => removed_edges.length,
        "affectedModules" => affected_modules.length,
        "addedRuntimeScenarios" => runtime_added.length,
        "removedRuntimeScenarios" => runtime_removed.length,
        "changedRuntimeScenarios" => runtime_changed.length,
        "affectedRuntimeScenarios" => affected_runtime_scenarios.length,
        "suggestedTests" => suggested_tests.length
      },
      "modules" => {
        "added" => added_modules,
        "removed" => removed_modules,
        "changed" => changed_modules
      },
      "edges" => {
        "added" => added_edges,
        "removed" => removed_edges
      },
      "runtime" => {
        "added" => runtime_added,
        "removed" => runtime_removed,
        "changed" => runtime_changed
      },
      "impact" => {
        "changedRoots" => changed_roots.to_a.sort,
        "affectedModules" => affected_modules,
        "runtimeScenarios" => affected_runtime_scenarios,
        "suggestedTests" => suggested_tests
      }
    }
  end

  def markdown(diff, base_label:, head_label:)
    summary = diff.fetch("summary")
    lines = [
      COMMENT_MARKER,
      "## Framelingo Architecture Diff",
      "",
      "`#{escape_code(base_label)}` → `#{escape_code(head_label)}`",
      ""
    ]

    unless diff.fetch("hasChanges")
      return (lines + ["No package topology or documented runtime changes detected.", ""]).join("\n")
    end

    lines.concat([
      "| Modules | Edges | Area of influence | Runtime paths | Suggested tests |",
      "| --- | --- | ---: | ---: | ---: |",
      "| +#{summary.fetch("addedModules")} / −#{summary.fetch("removedModules")} / ~#{summary.fetch("changedModules")} | +#{summary.fetch("addedEdges")} / −#{summary.fetch("removedEdges")} | #{summary.fetch("affectedModules")} | +#{summary.fetch("addedRuntimeScenarios")} / −#{summary.fetch("removedRuntimeScenarios")} / ~#{summary.fetch("changedRuntimeScenarios")} | #{summary.fetch("suggestedTests")} |",
      ""
    ])

    append_list(lines, "Added packages", diff.dig("modules", "added"), prefix: "+")
    append_list(lines, "Removed packages", diff.dig("modules", "removed"), prefix: "−")
    append_changed_modules(lines, diff.dig("modules", "changed"))
    append_edges(lines, "Added dependencies", diff.dig("edges", "added"), prefix: "+")
    append_edges(lines, "Removed dependencies", diff.dig("edges", "removed"), prefix: "−")
    append_runtime(lines, "Added runtime paths", diff.dig("runtime", "added"), prefix: "+")
    append_runtime(lines, "Removed runtime paths", diff.dig("runtime", "removed"), prefix: "−")
    append_runtime(lines, "Changed runtime paths", diff.dig("runtime", "changed"), prefix: "~")
    append_list(lines, "Area of influence", diff.dig("impact", "affectedModules"))

    scenarios = diff.dig("impact", "runtimeScenarios") || []
    unless scenarios.empty?
      lines.concat(["<details>", "<summary>Affected runtime paths (#{scenarios.length})</summary>", ""])
      scenarios.first(DISPLAY_LIMIT).each do |scenario|
        lines << "- `#{escape_code(scenario.fetch("title"))}` via #{scenario.fetch("modules").map { |name| "`#{escape_code(name)}`" }.join(", ")}"
      end
      append_remainder(lines, scenarios.length)
      lines.concat(["", "</details>", ""])
    end

    append_list(lines, "Suggested test bundles", diff.dig("impact", "suggestedTests"))
    lines << "_Generated from Swift package manifests and documented runtime scenarios._"
    lines << ""
    lines.join("\n")
  end

  def index_modules(snapshot)
    snapshot.fetch("modules").to_h { |record| [record.fetch("name"), record] }
  end

  def index_runtime_scenarios(snapshot)
    snapshot.fetch("runtimeScenarios", []).to_h { |record| [record.fetch("id"), record] }
  end

  def runtime_identity(scenario)
    { "id" => scenario.fetch("id"), "title" => scenario.fetch("title") }
  end

  def module_change(base_record, head_record)
    change = {}
    unless base_record["category"] == head_record["category"]
      change["category"] = { "from" => base_record["category"], "to" => head_record["category"] }
    end
    %w[dependencies tests].each do |field|
      before = Set.new(base_record.fetch(field, []))
      after = Set.new(head_record.fetch(field, []))
      added = (after - before).to_a.sort
      removed = (before - after).to_a.sort
      change[field] = { "added" => added, "removed" => removed } unless added.empty? && removed.empty?
    end
    change
  end

  def edge_set(modules)
    modules.each_with_object(Set.new) do |(name, record), edges|
      record.fetch("dependencies", []).each { |dependency| edges << [name, dependency] }
    end
  end

  def sorted_edges(edges)
    edges.to_a.sort.map { |source, target| { "source" => source, "target" => target } }
  end

  def transitive_dependents(name, modules)
    visited = Set.new
    queue = modules.map do |candidate, record|
      candidate if record.fetch("dependencies", []).include?(name)
    end.compact
    until queue.empty?
      candidate = queue.shift
      next if candidate == name || visited.include?(candidate)
      visited << candidate
      queue.concat(modules.map do |dependent, record|
        dependent if record.fetch("dependencies", []).include?(candidate)
      end.compact)
    end
    visited
  end

  def runtime_scenarios(head_snapshot, base_snapshot)
    scenarios = head_snapshot.fetch("runtimeScenarios", []) + base_snapshot.fetch("runtimeScenarios", [])
    scenarios.reverse.to_h { |scenario| [scenario.fetch("id"), scenario] }.values.reverse
  end

  def append_list(lines, title, values, prefix: nil)
    values ||= []
    return if values.empty?
    lines.concat(["<details>", "<summary>#{title} (#{values.length})</summary>", ""])
    values.first(DISPLAY_LIMIT).each do |value|
      bullet = prefix ? "#{prefix} " : ""
      lines << "- #{bullet}`#{escape_code(value)}`"
    end
    append_remainder(lines, values.length)
    lines.concat(["", "</details>", ""])
  end

  def append_changed_modules(lines, changes)
    changes ||= []
    return if changes.empty?
    lines.concat(["<details>", "<summary>Changed packages (#{changes.length})</summary>", ""])
    changes.first(DISPLAY_LIMIT).each do |change|
      fields = change.keys.reject { |key| key == "name" }.join(", ")
      lines << "- `#{escape_code(change.fetch("name"))}` — #{fields}"
    end
    append_remainder(lines, changes.length)
    lines.concat(["", "</details>", ""])
  end

  def append_edges(lines, title, edges, prefix:)
    edges ||= []
    return if edges.empty?
    lines.concat(["<details>", "<summary>#{title} (#{edges.length})</summary>", ""])
    edges.first(DISPLAY_LIMIT).each do |edge|
      lines << "- #{prefix} `#{escape_code(edge.fetch("source"))} → #{escape_code(edge.fetch("target"))}`"
    end
    append_remainder(lines, edges.length)
    lines.concat(["", "</details>", ""])
  end

  def append_runtime(lines, title, scenarios, prefix:)
    scenarios ||= []
    return if scenarios.empty?
    lines.concat(["<details>", "<summary>#{title} (#{scenarios.length})</summary>", ""])
    scenarios.first(DISPLAY_LIMIT).each do |scenario|
      lines << "- #{prefix} `#{escape_code(scenario.fetch("title"))}`"
    end
    append_remainder(lines, scenarios.length)
    lines.concat(["", "</details>", ""])
  end

  def append_remainder(lines, total)
    remainder = total - DISPLAY_LIMIT
    lines << "- …and #{remainder} more" if remainder.positive?
  end

  def escape_code(value)
    value.to_s
      .gsub(/[\r\n\t]+/, " ")
      .gsub("`", "ˋ")
      .gsub("@", "＠")
      .slice(0, 160)
  end
end
