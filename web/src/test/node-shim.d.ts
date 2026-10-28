// @types/node kurulu değil; yalnızca tokens.test.ts'nin dosya sistemi denetimlerinin kullandığı işlevler bildirilir.
declare module 'node:fs' {
  export function readFileSync(path: string, encoding: 'utf-8'): string;
  export function readdirSync(path: string): string[];
  export function statSync(path: string): { isDirectory(): boolean };
  export function existsSync(path: string): boolean;
}
declare module 'node:path' {
  export function join(...parts: string[]): string;
}
declare const process: { cwd(): string };
