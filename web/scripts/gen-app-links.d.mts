export const BUNDLE_ID: string;
export const PLACEHOLDER: string;
export function normalizeTeamId(raw: string | undefined | null): string | null;
export function normalizeFingerprints(raw: string | undefined | null): string[];
export function aasa(teamId: string): {
  applinks: { apps: string[]; details: { appIDs: string[]; paths: string[] }[] };
};
export function assetlinks(fingerprints: string[]): {
  relation: string[];
  target: { namespace: string; package_name: string; sha256_cert_fingerprints: string[] };
}[];
export function generate(opts: {
  dist: string;
  teamId?: string;
  sha256?: string;
  log?: { log: (m: string) => void; warn: (m: string) => void };
}): { aasa: boolean; assetlinks: boolean };
