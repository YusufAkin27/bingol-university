// @types/node kurulu değil; yalnızca testlerin dosya sistemi denetimlerinin (tokens.test.ts, seo/crawl.test.ts) kullandığı işlevler bildirilir.
declare module 'node:fs' {
  export function readFileSync(path: string, encoding: 'utf-8'): string;
  export function readdirSync(path: string): string[];
  export function statSync(path: string): { isDirectory(): boolean };
  export function existsSync(path: string): boolean;
  export function mkdirSync(path: string, options?: { recursive?: boolean }): void;
  export function mkdtempSync(prefix: string): string;
  export function rmSync(path: string, options?: { recursive?: boolean; force?: boolean }): void;
  export function writeFileSync(path: string, data: string): void;
}
declare module 'node:path' {
  export function join(...parts: string[]): string;
  export function dirname(path: string): string;
}
declare module 'node:os' {
  export function tmpdir(): string;
}
declare const process: { cwd(): string };
