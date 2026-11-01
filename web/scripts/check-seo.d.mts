export const PARTIAL_LANG_PATHS: Record<string, string[]>;
export const DYNAMIC_PATH_RES: RegExp[];
export interface RobotsGroup {
  agents: string[];
  rules: { allow: boolean; pattern: string }[];
}
export interface ParsedRobots {
  groups: RobotsGroup[];
  sitemaps: string[];
}
export function parseRobots(text: string): ParsedRobots;
export function robotsAllows(parsed: ParsedRobots, agent: string, path: string): boolean;
export interface SeoIssue {
  where: string;
  msg: string;
  cat: string;
}
export function runChecks(opts: { dist: string; origin: string; adminPath?: string; today?: string }): {
  errors: SeoIssue[];
  warnings: SeoIssue[];
  stats: Record<string, unknown>;
};
