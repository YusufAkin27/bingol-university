/** Yönetim paneli araması: genel arayüz (kayıt defteri, motor, kancalar). Kılavuz: README.md */
export { registeredEntries } from './registry';
export { buildSearchEntries } from './build';
export { createSearcher, groupHits, highlight, type Hit, type HitGroup, type Searchable, type Searcher, type Segment } from './engine';
export { fold, tokenize } from './fold';
export { groupByPage, useAdminSearch, type AdminSearch, type MenuMatch } from './useAdminSearch';
export { SearchAnchor, useSearchAnchorFocus, useSearchReveal } from './anchor';
export { Highlight } from './Highlight';
export { readRecent, pushRecent, clearRecent } from './recent';
export type { ResolvedEntry, SearchClass, SearchEntry, SearchKind } from './types';
