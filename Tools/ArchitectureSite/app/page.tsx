"use client";

import { useEffect, useMemo, useState } from "react";
import {
  categories,
  modules,
  runtimeScenarios,
  type ModuleCategory,
  type ModuleRecord,
} from "./dependency-data";

type ViewName = "map" | "impact" | "runtime";

const categoryLabel: Record<ModuleCategory, string> = {
  Composition: "Composition",
  Features: "Features",
  Workflows: "Workflows",
  Core: "Core",
  Infrastructure: "Infrastructure",
  UI: "UI",
  External: "External",
};

const views: { id: ViewName; label: string; note: string }[] = [
  { id: "map", label: "Package map", note: "Topology" },
  { id: "impact", label: "Impact explorer", note: "Change radius" },
  { id: "runtime", label: "Runtime pipeline", note: "Execution path" },
];

const moduleByName = new Map(modules.map((module) => [module.name, module]));
const localModules = modules.filter((module) => module.category !== "External");
const edgeCount = modules.reduce((sum, module) => sum + module.dependencies.length, 0);

const appTarget: ModuleRecord = {
  name: "Framelingo.app",
  category: "Composition",
  dependencies: modules.filter((module) => module.category === "Composition").map((module) => module.name),
  tests: [],
  sourceFiles: null,
};
const graphNodes = [appTarget, ...modules];
const graphModuleByName = new Map(graphNodes.map((module) => [module.name, module]));

const graphLayout = (() => {
  const width = 1040;
  const cardWidth = 176;
  const cardHeight = 46;
  const columnGap = 18;
  const rowGap = 12;
  const contentX = 166;
  const columns = 4;
  const positions = new Map<string, { x: number; y: number }>();
  const groups: { id: string; label: string; category: ModuleCategory; y: number; height: number; count: number }[] = [];
  const definitions = [
    { id: "app", label: "APP TARGET", category: "Composition" as const, records: [appTarget] },
    ...categories.map((category) => ({
      id: category.toLowerCase(),
      label: category.toUpperCase(),
      category,
      records: modules.filter((module) => module.category === category),
    })),
  ];
  let cursorY = 52;

  definitions.forEach(({ id, label, category, records }) => {
    if (records.length === 0) return;
    const rows = Math.ceil(records.length / columns);
    const groupHeight = rows * cardHeight + Math.max(0, rows - 1) * rowGap;
    groups.push({ id, label, category, y: cursorY, height: groupHeight, count: records.length });
    records.forEach((module, index) => {
      const row = Math.floor(index / columns);
      const rowStart = row * columns;
      const rowCount = Math.min(columns, records.length - rowStart);
      const centeredX = contentX + ((columns - rowCount) * (cardWidth + columnGap)) / 2;
      positions.set(module.name, {
        x: centeredX + (index % columns) * (cardWidth + columnGap),
        y: cursorY + row * (cardHeight + rowGap),
      });
    });
    cursorY += groupHeight + 54;
  });

  const edges = graphNodes.flatMap((module) =>
    module.dependencies
      .filter((dependency) => positions.has(dependency))
      .map((dependency) => ({ source: module.name, target: dependency })),
  );

  return { width, height: cursorY + 8, cardWidth, cardHeight, positions, groups, edges };
})();

function graphLabelLines(name: string) {
  if (name.length <= 18) return [name];
  const breaks = [...name].flatMap((character, index) =>
    index > 0 && character >= "A" && character <= "Z" ? [index] : [],
  );
  if (breaks.length === 0) return [name];
  const splitAt = breaks.reduce((best, candidate) =>
    Math.abs(candidate - name.length / 2) < Math.abs(best - name.length / 2) ? candidate : best,
  );
  return [name.slice(0, splitAt), name.slice(splitAt)];
}

function uniqueSorted(values: string[]) {
  return [...new Set(values)].sort((left, right) => left.localeCompare(right));
}

function getDirectDependents(name: string) {
  return modules
    .filter((module) => module.dependencies.includes(name))
    .map((module) => module.name)
    .sort((left, right) => left.localeCompare(right));
}

function getTransitiveDependents(name: string) {
  const visited = new Set<string>();
  const queue = [...getDirectDependents(name)];

  while (queue.length > 0) {
    const current = queue.shift();
    if (!current || current === name || visited.has(current)) continue;
    visited.add(current);
    queue.push(...getDirectDependents(current));
  }

  return [...visited].sort((left, right) => left.localeCompare(right));
}

function CategoryDot({ category }: { category: ModuleCategory }) {
  return <span className="category-dot" data-category={category} aria-hidden="true" />;
}

function ModuleButton({
  name,
  selected,
  onSelect,
}: {
  name: string;
  selected?: boolean;
  onSelect: (name: string) => void;
}) {
  const module = moduleByName.get(name);
  if (!module) return null;

  return (
    <button
      type="button"
      className="module-button"
      data-selected={selected ? "true" : "false"}
      onClick={() => onSelect(name)}
    >
      <CategoryDot category={module.category} />
      <span>{name}</span>
    </button>
  );
}

export default function Home() {
  const [view, setView] = useState<ViewName>("impact");
  const [selectedName, setSelectedName] = useState("Subtitles");
  const [query, setQuery] = useState("");
  const [copied, setCopied] = useState(false);
  const [mapFocus, setMapFocus] = useState("");
  const [scenarioId, setScenarioId] = useState(runtimeScenarios[2]?.id ?? runtimeScenarios[0].id);
  const [runtimeStepId, setRuntimeStepId] = useState(runtimeScenarios[2]?.steps[0]?.id ?? runtimeScenarios[0].steps[0].id);

  useEffect(() => {
    const hash = window.location.hash.replace("#", "");
    if (hash === "map" || hash === "impact" || hash === "runtime") setView(hash);
  }, []);

  const setActiveView = (nextView: ViewName) => {
    setView(nextView);
    window.history.replaceState(null, "", `#${nextView}`);
  };

  const selected = moduleByName.get(selectedName) ?? modules[0];
  const directDependents = useMemo(
    () => getDirectDependents(selected.name),
    [selected.name],
  );
  const transitiveDependents = useMemo(
    () => getTransitiveDependents(selected.name),
    [selected.name],
  );
  const downstreamOnly = transitiveDependents.filter(
    (name) => !directDependents.includes(name),
  );
  const affectedRecords = [selected.name, ...transitiveDependents]
    .map((name) => moduleByName.get(name))
    .filter((module): module is NonNullable<typeof module> => Boolean(module));
  const affectedFeatures = affectedRecords
    .filter((module) => module.category === "Features")
    .map((module) => module.name);
  const affectedCompositions = affectedRecords
    .filter((module) => module.category === "Composition")
    .map((module) => module.name);
  const affectedTests = uniqueSorted(affectedRecords.flatMap((module) => module.tests));
  const localImpact = transitiveDependents.filter(
    (name) => moduleByName.get(name)?.category !== "External",
  ).length;
  const impactPercent = Math.round((localImpact / Math.max(1, localModules.length - 1)) * 100);

  const filteredModules = modules.filter((module) =>
    module.name.toLowerCase().includes(query.trim().toLowerCase()),
  );
  const runtimeScenario = runtimeScenarios.find((scenario) => scenario.id === scenarioId) ?? runtimeScenarios[0];
  const runtimeStep = runtimeScenario.steps.find((step) => step.id === runtimeStepId) ?? runtimeScenario.steps[0];
  const runtimeAsyncCount = runtimeScenario.steps.filter((step) => step.asyncBoundary).length;
  const runtimeErrorCount = uniqueSorted(runtimeScenario.steps.flatMap((step) => step.errors)).length;
  const mapSelected = mapFocus ? graphModuleByName.get(mapFocus) : undefined;
  const mapDependencies = mapSelected?.dependencies ?? [];
  const mapDependents = mapSelected
    ? graphNodes.filter((module) => module.dependencies.includes(mapSelected.name)).map((module) => module.name)
    : [];

  const selectScenario = (nextScenarioId: string) => {
    const nextScenario = runtimeScenarios.find((scenario) => scenario.id === nextScenarioId);
    if (!nextScenario) return;
    setScenarioId(nextScenario.id);
    setRuntimeStepId(nextScenario.steps[0].id);
  };

  const copyTests = async () => {
    try {
      await navigator.clipboard.writeText(affectedTests.join("\n"));
      setCopied(true);
      window.setTimeout(() => setCopied(false), 1600);
    } catch {
      setCopied(false);
    }
  };

  return (
    <main className="architecture-shell">
      <header className="site-header">
        <div className="brand-lockup">
          <span className="brand-mark" aria-hidden="true">
            <span />
            <span />
            <span />
          </span>
          <div>
            <p className="eyebrow">Framelingo / Architecture lab</p>
            <h1>Trace the change before you make it.</h1>
          </div>
        </div>
        <div className="snapshot-meta" aria-label="Architecture snapshot summary">
          <span><strong>{localModules.length}</strong> local packages</span>
          <span><strong>{edgeCount}</strong> declared edges</span>
          <span><strong>{runtimeScenarios.length}</strong> runtime paths</span>
          <span className="snapshot-state"><i /> Workspace snapshot</span>
        </div>
      </header>

      <nav className="view-switcher" aria-label="Architecture views">
        <span className="switcher-track" aria-hidden="true" />
        {views.map((item) => (
          <button
            key={item.id}
            type="button"
            className="view-tab"
            aria-pressed={view === item.id}
            onClick={() => setActiveView(item.id)}
          >
            <span className="view-tab-indicator" aria-hidden="true" />
            <span className="view-tab-copy">
              <strong>{item.label}</strong>
              <small>{item.note}</small>
            </span>
          </button>
        ))}
        <span className="switcher-future">More views can dock here</span>
      </nav>

      {view === "map" ? (
        <section className="map-view" aria-labelledby="map-heading">
          <div className="section-heading">
            <div>
              <p className="section-kicker">Live package snapshot</p>
              <h2 id="map-heading">Package topology</h2>
            </div>
            <a
              className="text-link"
              href="/framelingo-dependency-graph.html"
              target="_blank"
              rel="noreferrer"
            >
              Open legacy force graph <span aria-hidden="true">↗</span>
            </a>
          </div>
          <div className="topology-layout">
            <div className="topology-board">
              <div className="topology-legend graph-layer-legend" aria-label="Package categories">
                <span data-category="Composition"><i /> Composition / app</span>
                <span data-category="Features"><i /> Features</span>
                <span data-category="Workflows"><i /> Workflows</span>
                <span data-category="Core"><i /> Core</span>
                <span data-category="Infrastructure"><i /> Infrastructure</span>
                <span data-category="UI"><i /> UI / external</span>
              </div>
              <div className="graph-canvas">
                <svg
                  viewBox={`0 0 ${graphLayout.width} ${graphLayout.height}`}
                  role="img"
                  aria-label="Interactive Framelingo package dependency graph"
                >
                  <g className="graph-edges" aria-hidden="true">
                    {graphLayout.edges.map((edge) => {
                      const source = graphLayout.positions.get(edge.source);
                      const target = graphLayout.positions.get(edge.target);
                      if (!source || !target) return null;
                      const sourceX = source.x + graphLayout.cardWidth / 2;
                      const sourceY = source.y + graphLayout.cardHeight / 2;
                      const targetX = target.x + graphLayout.cardWidth / 2;
                      const targetY = target.y + graphLayout.cardHeight / 2;
                      const bend = Math.max(34, Math.abs(targetY - sourceY) * 0.42);
                      const direction = targetY >= sourceY ? 1 : -1;
                      const relation = edge.source === mapSelected?.name
                        ? "input"
                        : edge.target === mapSelected?.name
                          ? "output"
                          : mapSelected ? "idle" : "all";
                      return (
                        <path
                          key={`${edge.source}-${edge.target}`}
                          data-relation={relation}
                          d={`M ${sourceX} ${sourceY} C ${sourceX} ${sourceY + bend * direction}, ${targetX} ${targetY - bend * direction}, ${targetX} ${targetY}`}
                        />
                      );
                    })}
                  </g>
                  {graphLayout.groups.map((group) => (
                    <g className="graph-group-label" key={group.id} data-category={group.category}>
                      <text x="34" y={group.y + 20}>{group.label}</text>
                    </g>
                  ))}
                  <g className="graph-nodes">
                    {graphNodes.map((module) => {
                      const position = graphLayout.positions.get(module.name);
                      if (!position) return null;
                      const relation = module.name === mapSelected?.name
                        ? "origin"
                        : mapDependencies.includes(module.name)
                          ? "input"
                          : mapDependents.includes(module.name)
                            ? "output"
                            : mapSelected ? "idle" : "all";
                      return (
                        <g
                          key={module.name}
                          className="graph-node"
                          data-category={module.category}
                          data-relation={relation}
                          role="button"
                          tabIndex={0}
                          aria-label={`Focus ${module.name}`}
                          aria-pressed={mapFocus === module.name}
                          onClick={() => setMapFocus((current) => current === module.name ? "" : module.name)}
                          onKeyDown={(event) => {
                            if (event.key === "Enter" || event.key === " ") {
                              event.preventDefault();
                              setMapFocus((current) => current === module.name ? "" : module.name);
                            }
                          }}
                          transform={`translate(${position.x} ${position.y})`}
                        >
                          <rect width={graphLayout.cardWidth} height={graphLayout.cardHeight} rx="8" />
                          <text
                            x={graphLayout.cardWidth / 2}
                            y={graphLabelLines(module.name).length > 1 ? 18 : 28}
                            textAnchor="middle"
                            className="graph-node-name"
                          >
                            {graphLabelLines(module.name).map((line, index) => (
                              <tspan x={graphLayout.cardWidth / 2} dy={index === 0 ? 0 : 13} key={line}>{line}</tspan>
                            ))}
                          </text>
                        </g>
                      );
                    })}
                  </g>
                </svg>
              </div>
            </div>
          </div>
        </section>
      ) : view === "impact" ? (
        <section className="impact-view" aria-labelledby="impact-heading">
          <aside className="module-rail">
            <div className="rail-heading">
              <div>
                <p className="section-kicker">Change origin</p>
                <h2 id="impact-heading">Pick a module</h2>
              </div>
              <span>{filteredModules.length}</span>
            </div>
            <label className="module-search">
              <span className="sr-only">Filter modules</span>
              <span aria-hidden="true">⌕</span>
              <input
                type="search"
                value={query}
                onChange={(event) => setQuery(event.target.value)}
                placeholder="Filter modules"
              />
            </label>
            <div className="module-groups">
              {categories.map((category) => {
                const categoryModules = filteredModules.filter(
                  (module) => module.category === category,
                );
                if (categoryModules.length === 0) return null;
                return (
                  <div className="module-group" key={category}>
                    <p>
                      <CategoryDot category={category} />
                      {categoryLabel[category]}
                    </p>
                    <div>
                      {categoryModules.map((module) => (
                        <ModuleButton
                          key={module.name}
                          name={module.name}
                          selected={selected.name === module.name}
                          onSelect={setSelectedName}
                        />
                      ))}
                    </div>
                  </div>
                );
              })}
            </div>
          </aside>

          <div className="impact-canvas">
            <header className="module-hero" data-category={selected.category}>
              <div className="module-identity">
                <div className="module-orbit" aria-hidden="true">
                  <span />
                  <i />
                </div>
                <div>
                  <p><CategoryDot category={selected.category} /> {selected.category}</p>
                  <h2>{selected.name}</h2>
                  <span className="module-description">
                    {selected.sourceFiles === null
                      ? "External package"
                      : `${selected.sourceFiles} Swift source files`}
                  </span>
                </div>
              </div>
              <div className="radius-meter" aria-label={`${impactPercent}% of local packages are downstream`}>
                <span style={{ "--impact": `${impactPercent}%` } as React.CSSProperties} />
                <div><strong>{impactPercent}%</strong><small>of local graph downstream</small></div>
              </div>
            </header>

            <div className="impact-stats" aria-label="Impact summary">
              <div><span>Direct dependents</span><strong>{directDependents.length}</strong></div>
              <div><span>Total blast radius</span><strong>{transitiveDependents.length}</strong></div>
              <div><span>Feature surfaces</span><strong>{affectedFeatures.length}</strong></div>
              <div><span>Suggested test bundles</span><strong>{affectedTests.length}</strong></div>
            </div>

            <section className="propagation-panel" aria-labelledby="propagation-heading">
              <div className="panel-heading">
                <div>
                  <p className="section-kicker">Propagation trace</p>
                  <h3 id="propagation-heading">Where this change travels</h3>
                </div>
                <span className="direction-key">dependency → consumer</span>
              </div>
              <div className="trace-grid">
                <div className="trace-column trace-origin">
                  <p><span>Origin</span><strong>1</strong></p>
                  <ModuleButton name={selected.name} selected onSelect={setSelectedName} />
                </div>
                <div className="trace-connector" aria-hidden="true"><span>→</span></div>
                <div className="trace-column">
                  <p><span>Direct</span><strong>{directDependents.length}</strong></p>
                  <div className="trace-chips">
                    {directDependents.length > 0 ? directDependents.map((name) => (
                      <ModuleButton key={name} name={name} onSelect={setSelectedName} />
                    )) : <span className="empty-copy">No direct consumers</span>}
                  </div>
                </div>
                <div className="trace-connector" aria-hidden="true"><span>→</span></div>
                <div className="trace-column">
                  <p><span>Downstream</span><strong>{downstreamOnly.length}</strong></p>
                  <div className="trace-chips">
                    {downstreamOnly.length > 0 ? downstreamOnly.map((name) => (
                      <ModuleButton key={name} name={name} onSelect={setSelectedName} />
                    )) : <span className="empty-copy">No further propagation</span>}
                  </div>
                </div>
              </div>
            </section>

            <div className="detail-grid">
              <section className="detail-panel">
                <div className="panel-heading compact">
                  <div>
                    <p className="section-kicker">Product reach</p>
                    <h3>Affected surfaces</h3>
                  </div>
                  <strong>{affectedFeatures.length + affectedCompositions.length}</strong>
                </div>
                <div className="surface-block">
                  <span>Features</span>
                  <div className="token-list">
                    {affectedFeatures.length > 0
                      ? affectedFeatures.map((name) => <button type="button" key={name} onClick={() => setSelectedName(name)}>{name}</button>)
                      : <em>No feature package downstream</em>}
                  </div>
                </div>
                <div className="surface-block">
                  <span>Compositions</span>
                  <div className="token-list">
                    {affectedCompositions.length > 0
                      ? affectedCompositions.map((name) => <button type="button" key={name} onClick={() => setSelectedName(name)}>{name}</button>)
                      : <em>No app composition downstream</em>}
                  </div>
                </div>
                <div className="surface-block">
                  <span>Dependencies to inspect</span>
                  <div className="token-list neutral">
                    {selected.dependencies.length > 0
                      ? selected.dependencies.map((name) => <button type="button" key={name} onClick={() => setSelectedName(name)}>{name}</button>)
                      : <em>Leaf module — no package dependencies</em>}
                  </div>
                </div>
              </section>

              <section className="detail-panel tests-panel">
                <div className="panel-heading compact">
                  <div>
                    <p className="section-kicker">Verification set</p>
                    <h3>Suggested test bundles</h3>
                  </div>
                  <button type="button" className="copy-button" onClick={copyTests} disabled={affectedTests.length === 0}>
                    {copied ? "Copied" : "Copy names"}
                  </button>
                </div>
                <div className="test-list">
                  {affectedTests.length > 0 ? affectedTests.map((test, index) => (
                    <div key={test}>
                      <span>{String(index + 1).padStart(2, "0")}</span>
                      <code>{test}</code>
                    </div>
                  )) : <p className="empty-copy">No local test bundle is declared for this package.</p>}
                </div>
              </section>
            </div>
          </div>
        </section>
      ) : (
        <section className="runtime-view" aria-labelledby="runtime-heading">
          <div className="runtime-toolbar">
            <div>
              <p className="section-kicker">Scenario transport</p>
              <h2 id="runtime-heading">Follow one user action through the stack</h2>
            </div>
            <span className="runtime-live"><i /> Documented from source</span>
          </div>

          <div className="scenario-strip" aria-label="Runtime scenarios">
            {runtimeScenarios.map((scenario, index) => (
              <button
                type="button"
                key={scenario.id}
                aria-pressed={runtimeScenario.id === scenario.id}
                onClick={() => selectScenario(scenario.id)}
              >
                <span>{String(index + 1).padStart(2, "0")}</span>
                <strong>{scenario.title}</strong>
                <small>{scenario.steps.length} stages</small>
              </button>
            ))}
          </div>

          <div className="runtime-console">
            <header className="runtime-hero">
              <div>
                <p>{runtimeScenario.subtitle}</p>
                <h2>{runtimeScenario.title}</h2>
              </div>
              <div className="runtime-counters" aria-label="Pipeline summary">
                <span><strong>{runtimeScenario.steps.length}</strong> stages</span>
                <span><strong>{runtimeAsyncCount}</strong> async boundaries</span>
                <span><strong>{runtimeErrorCount}</strong> error signals</span>
              </div>
            </header>

            <div className="pipeline-viewport">
              <div className="pipeline-track" role="list" aria-label={`${runtimeScenario.title} stages`}>
                {runtimeScenario.steps.map((step, index) => (
                  <button
                    type="button"
                    role="listitem"
                    key={step.id}
                    className="runtime-step"
                    data-category={step.category}
                    data-selected={runtimeStep.id === step.id ? "true" : "false"}
                    onClick={() => setRuntimeStepId(step.id)}
                  >
                    <span className="step-index">{String(index + 1).padStart(2, "0")}</span>
                    <span className="step-kind">{step.kind}</span>
                    <strong>{step.label}</strong>
                    <small><CategoryDot category={step.category} /> {step.module}</small>
                    {step.asyncBoundary && <i className="async-flag">async</i>}
                  </button>
                ))}
              </div>
            </div>

            <div className="runtime-detail-grid">
              <section className="runtime-detail">
                <div className="runtime-detail-heading" data-category={runtimeStep.category}>
                  <span className="runtime-playhead" aria-hidden="true" />
                  <div>
                    <p><CategoryDot category={runtimeStep.category} /> {runtimeStep.kind} · {runtimeStep.module}</p>
                    <h3>{runtimeStep.component}</h3>
                  </div>
                </div>
                <dl className="contract-grid">
                  <div><dt>Contract</dt><dd>{runtimeStep.contract}</dd></div>
                  <div><dt>Implementation</dt><dd>{runtimeStep.implementation}</dd></div>
                  <div><dt>Boundary</dt><dd>{runtimeStep.asyncBoundary ? "Suspending / async" : "Synchronous"}</dd></div>
                </dl>
              </section>

              <section className="signal-panel">
                <div className="signal-block state-signal">
                  <span>State write</span>
                  <p>{runtimeStep.stateMutation}</p>
                </div>
                <div className="signal-block error-signal">
                  <span>Error surface</span>
                  {runtimeStep.errors.length > 0 ? (
                    <div>{runtimeStep.errors.map((error) => <em key={error}>{error}</em>)}</div>
                  ) : <p>No explicit failure at this stage.</p>}
                </div>
                <div className="source-signal">
                  <span>Source</span>
                  <code>{runtimeStep.source}</code>
                </div>
              </section>
            </div>

            <footer className="runtime-outcome">
              <span>Outcome</span>
              <p>{runtimeScenario.outcome}</p>
            </footer>
          </div>
        </section>
      )}

      <footer className="site-footer">
        <span>Framelingo architecture workspace</span>
        <span>Package manifests · composition roots · documented runtime paths</span>
      </footer>
    </main>
  );
}
