// check-admin-contract.mjs için tür bildirimi (vitest birim testi içe aktarır).
export const API_PREFIX: string;
export interface ContractCall {
  method: string;
  path: string | null;
  line: number;
  dynamic: boolean;
}
export interface ContractOperation {
  method: string;
  path: string;
}
export function normalizePath(p: string): string;
export function extractCalls(src: string): ContractCall[];
export function buildOperations(openapi: { paths?: Record<string, Record<string, unknown>> }): ContractOperation[];
export function matchCall(call: { method: string; path: string }, ops: ContractOperation[]): boolean;
export interface ContractReport {
  matched: number;
  unmatched: { file: string; line: number; method: string; path: string }[];
  dynamic: { file: string; line: number; method: string }[];
  total: number;
  operations: number;
}
export function checkSources(openapi: { paths?: Record<string, Record<string, unknown>> }, files: { rel: string; src: string }[]): ContractReport;
export function checkContract(o: { openapiPath: string; apiDir?: string }): ContractReport;
