import snapshot from "./architecture-data.json";

export type ModuleCategory =
  | "Composition"
  | "Features"
  | "Workflows"
  | "Core"
  | "Infrastructure"
  | "UI"
  | "External";

export type ModuleRecord = {
  name: string;
  category: ModuleCategory;
  dependencies: string[];
  tests: string[];
};

export type RuntimeStep = {
  id: string;
  label: string;
  component: string;
  contract: string;
  implementation: string;
  module: string;
  category: ModuleCategory;
  kind: string;
  asyncBoundary: boolean;
  stateMutation: string;
  errors: string[];
  source: string;
};

export type RuntimeScenario = {
  id: string;
  title: string;
  subtitle: string;
  outcome: string;
  steps: RuntimeStep[];
};

export const modules = snapshot.modules as ModuleRecord[];
export const runtimeScenarios = snapshot.runtimeScenarios as RuntimeScenario[];

export const categories: ModuleCategory[] = [
  "Composition",
  "Features",
  "Workflows",
  "Core",
  "Infrastructure",
  "UI",
  "External",
];
