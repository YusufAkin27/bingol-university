import type {
  AuditParams,
  BreakdownDimension,
  CommunityStatus,
  DateRange,
  EventStatus,
  FeedbackCategory,
  FeedbackStatus,
  LegalType,
  NewsListParams,
  ReportOrder,
  ReportStatus,
  ReportTargetType,
  TicketStatus,
  UserListParams,
} from './types';

/**
 * react-query anahtar fabrikası. Her alanın `all` anahtarı geçersiz kılma (invalidate) için kullanılır:
 * `queryClient.invalidateQueries({ queryKey: qk.users.all })`.
 */
export const qk = {
  me: ['admin', 'me'] as const,
  appInfo: ['app', 'info'] as const,
  storeLink: (platform: string) => ['app', 'store', platform] as const,
  faculties: ['app', 'faculties'] as const,
  legal: {
    all: ['legal'] as const,
    list: () => ['legal', 'list'] as const,
    doc: (type: LegalType, lang: string) => ['legal', 'doc', type, lang] as const,
    versions: (type: LegalType) => ['legal', 'versions', type] as const,
    acceptance: () => ['legal', 'acceptance'] as const,
  },
  faq: {
    all: ['faq'] as const,
    public: (lang: string) => ['faq', 'public', lang] as const,
    admin: () => ['faq', 'admin'] as const,
  },
  users: {
    all: ['users'] as const,
    list: (p: UserListParams) => ['users', 'list', p] as const,
    detail: (id: number) => ['users', 'detail', id] as const,
    stats: () => ['users', 'stats'] as const,
  },
  analytics: {
    all: ['analytics'] as const,
    overview: () => ['analytics', 'overview'] as const,
    registrations: (r: DateRange) => ['analytics', 'registrations', r] as const,
    activeUsers: (r: DateRange) => ['analytics', 'active-users', r] as const,
    breakdown: (d: BreakdownDimension) => ['analytics', 'breakdown', d] as const,
    engagement: (r: DateRange) => ['analytics', 'engagement', r] as const,
    retention: () => ['analytics', 'retention'] as const,
    support: () => ['analytics', 'support'] as const,
    push: () => ['analytics', 'push'] as const,
    content: (r: DateRange) => ['analytics', 'content', r] as const,
  },
  reports: {
    all: ['reports'] as const,
    list: (status: ReportStatus, order: ReportOrder = 'desc', targetType: ReportTargetType | null = null) =>
      ['reports', 'list', status, order, targetType ?? 'ALL'] as const,
    templates: () => ['reports', 'templates'] as const,
  },
  moderation: {
    all: ['moderation'] as const,
    appeals: (status: string) => ['moderation', 'appeals', status] as const,
    recommendations: (status: string) => ['moderation', 'recommendations', status] as const,
    blocklist: () => ['moderation', 'blocklist'] as const,
  },
  crypto: { status: () => ['crypto', 'status'] as const },
  admission: {
    summary: (eventId: number) => ['admission', 'summary', eventId] as const,
    clubAudit: (communityId: number) => ['club', 'audit', communityId] as const,
  },
  tickets: {
    all: ['tickets'] as const,
    list: (status?: TicketStatus, publicOnly?: boolean) =>
      ['tickets', 'list', status ?? 'ALL', publicOnly ? 'PUBLIC' : 'ALL'] as const,
    detail: (id: number) => ['tickets', 'detail', id] as const,
  },
  feedback: {
    all: ['feedback'] as const,
    list: (status?: FeedbackStatus, category?: FeedbackCategory) =>
      ['feedback', 'list', status ?? 'ALL', category ?? 'ALL'] as const,
  },
  campaigns: {
    all: ['campaigns'] as const,
    list: () => ['campaigns', 'list'] as const,
    detail: (id: number) => ['campaigns', 'detail', id] as const,
    audience: (type: string, value?: string | null) => ['campaigns', 'audience', type, value ?? ''] as const,
  },
  settings: {
    all: ['settings'] as const,
    list: () => ['settings', 'list'] as const,
    sync: () => ['settings', 'sync'] as const,
  },
  communities: {
    all: ['communities'] as const,
    list: (status: CommunityStatus) => ['communities', 'list', status] as const,
  },
  events: { all: ['events'] as const, list: (status: EventStatus) => ['events', 'list', status] as const },
  news: { all: ['news'] as const, list: (p: NewsListParams) => ['news', 'list', p] as const },
  audit: { all: ['audit'] as const, list: (p: AuditParams) => ['audit', 'list', p] as const },
};
