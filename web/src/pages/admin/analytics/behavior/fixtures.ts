// Davranış analizi testleri için sahte yanıtlar (sözleşme biçimiyle birebir). Üretim kodu içe aktarmaz.
import type {
  BehaviorActions,
  BehaviorFlows,
  BehaviorOverview,
  BehaviorUserDetail,
  BehaviorUserRow,
  Paged,
  ScreenStat,
} from '../../../../api/analyticsBehavior';

export const overviewFixture: BehaviorOverview = {
  sessions: 1240,
  users: 310,
  avgSessionMs: 134_000,
  medianSessionMs: 62_000,
  avgScreensPerSession: 4.6,
  sessionsPerUser: 4,
  bounceRate: 0.182,
  quickCloseRate: 0.094,
  byDay: [
    { day: '2026-10-28', sessions: 160, avgSessionMs: 120_000, bounceRate: 0.2 },
    { day: '2026-10-29', sessions: 175, avgSessionMs: 131_000, bounceRate: 0.18 },
    { day: '2026-10-30', sessions: 190, avgSessionMs: 140_000, bounceRate: 0.17 },
    { day: '2026-10-31', sessions: 150, avgSessionMs: 128_000, bounceRate: 0.19 },
    { day: '2026-11-01', sessions: 120, avgSessionMs: 150_000, bounceRate: 0.15 },
    { day: '2026-11-02', sessions: 210, avgSessionMs: 133_000, bounceRate: 0.2 },
    { day: '2026-11-03', sessions: 235, avgSessionMs: 136_000, bounceRate: 0.18 },
  ],
  durationBuckets: [
    { label: '<5sn', sessions: 117 },
    { label: '5-30sn', sessions: 260 },
    { label: '30sn-2dk', sessions: 400 },
    { label: '2-10dk', sessions: 380 },
    { label: '10dk+', sessions: 83 },
  ],
};

const screens = [
  '/home',
  '/news_detail',
  'EventDetailPage',
  '/yeni-ekran-x',
  '/menu',
  '/chat_detail',
  '/clubs',
];

export function screensFixture(page = 0, size = 20, total = 45): Paged<ScreenStat> {
  const items: ScreenStat[] = Array.from(
    { length: Math.min(size, Math.max(0, total - page * size)) },
    (_, i) => {
      const n = page * size + i;
      return {
        screen: n < screens.length ? screens[n] : `/ekran_${n}`,
        views: 5000 - n * 90,
        users: 300 - n * 5,
        avgDwellMs: 20_000 + n * 3_000,
        medianDwellMs: 12_000 + n * 1_500,
        p90DwellMs: 70_000 + n * 4_000,
        exitRate: Math.max(0.02, 0.4 - n * 0.006),
        bounceRate: Math.max(0.01, 0.25 - n * 0.004),
        sharePct: Math.max(0.2, 18 - n * 0.4),
      };
    },
  );
  return { items, page, size, total };
}

export const flowsFixture: BehaviorFlows = {
  topTransitions: [
    { from: '/home', to: '/news_detail', count: 820 },
    { from: '/home', to: '/menu', count: 640 },
    { from: '/news_detail', to: '/home', count: 410 },
    { from: '/home', to: '/events', count: 330 },
  ],
  entryScreens: [
    { screen: '/home', sessions: 980 },
    { screen: '/notifications', sessions: 120 },
    { screen: '/menu', sessions: 90 },
  ],
  exitScreens: [
    { screen: '/home', sessions: 450 },
    { screen: '/news_detail', sessions: 300 },
    { screen: '/chat_detail', sessions: 180 },
  ],
  dropOff: [
    { screen: '/news_detail', entered: 1200, left: 300, leftRate: 0.25 },
    { screen: '/menu', entered: 800, left: 120, leftRate: 0.15 },
  ],
};

export const actionsFixture: BehaviorActions = {
  items: [
    {
      kind: 'like',
      count: 940,
      users: 180,
      perScreen: [
        { screen: '/home', count: 600 },
        { screen: '/post_detail', count: 340 },
      ],
    },
    { kind: 'send_message', count: 520, users: 120, perScreen: [{ screen: '/chat_detail', count: 520 }] },
    { kind: 'rsvp', count: 60, users: 40, perScreen: [] },
  ],
};

export function usersFixture(page = 0, size = 20, total = 45): Paged<BehaviorUserRow> {
  const items = Array.from({ length: Math.min(size, Math.max(0, total - page * size)) }, (_, i) => {
    const n = page * size + i + 1;
    return {
      userId: n,
      displayName: `Test Kullanıcı ${n}`,
      email: `t***${n}@bingol.edu.tr`,
      department: 'Bilgisayar Mühendisliği',
      grade: '3. sınıf',
      sessions: 40 - i,
      totalMs: 3_600_000 - i * 60_000,
      avgSessionMs: 120_000,
      bounceRate: 0.1,
      quickCloseCount: 2,
      lastSeenAt: '2026-11-03T08:30:00Z',
      topScreens: [
        { screen: '/home', ms: 900_000 },
        { screen: '/news_detail', ms: 400_000 },
        { screen: '/yeni-ekran-x', ms: 90_000 },
      ],
    };
  });
  return { items, page, size, total };
}

export const userDetailFixture: BehaviorUserDetail = {
  insights: {
    from: '2026-11-01',
    to: '2026-11-03',
    eventCount: 20,
    partial: false,
    screens: [
      {
        screen: '/news_detail',
        views: 4,
        measuredVisits: 3,
        totalMs: 90000,
        avgMs: 30000,
        maxMs: 60000,
        share: 0.75,
      },
      {
        screen: '/home',
        views: 2,
        measuredVisits: 2,
        totalMs: 30000,
        avgMs: 15000,
        maxMs: 20000,
        share: 0.25,
      },
    ],
    byDay: [
      { day: '2026-11-01', sessions: 0, totalMs: 0, views: 0, actions: 0 },
      { day: '2026-11-02', sessions: 1, totalMs: 3000, views: 1, actions: 0 },
      { day: '2026-11-03', sessions: 1, totalMs: 170000, views: 5, actions: 2 },
    ],
    byHour: Array.from({ length: 24 }, (_, hour) => ({
      hour,
      views: hour === 11 ? 5 : 0,
      actions: hour === 11 ? 2 : 0,
    })),
    actions: [
      { kind: 'like', count: 1 },
      { kind: 'pull_refresh', count: 1 },
    ],
  },
  user: {
    userId: 1,
    displayName: 'Test Kullanıcı 1',
    email: 't***1@bingol.edu.tr',
    department: 'Bilgisayar Mühendisliği',
    grade: '3. sınıf',
  },
  summary: {
    sessions: 2,
    totalMs: 190_000,
    avgSessionMs: 95_000,
    bounceRate: 0.5,
    quickCloseCount: 1,
    lastSeenAt: '2026-11-03T08:30:00Z',
  },
  sessions: [
    {
      sid: 'abcd1234',
      startedAt: '2026-11-03T08:20:00Z',
      endedAt: '2026-11-03T08:22:50Z',
      durationMs: 170_000,
      bounce: false,
      quickClose: false,
      reason: 'background',
      steps: [
        { type: 'screen', screen: '/home', dwellMs: 20_000, at: '2026-11-03T08:20:00Z' },
        { type: 'action', screen: '/home', kind: 'pull_refresh', at: '2026-11-03T08:20:10Z' },
        { type: 'screen', screen: '/news_detail', dwellMs: 90_000, at: '2026-11-03T08:20:20Z' },
        { type: 'action', screen: '/news_detail', kind: 'like', at: '2026-11-03T08:21:00Z' },
        { type: 'screen', screen: '/yeni-ekran-x', dwellMs: null, at: '2026-11-03T08:21:50Z' },
      ],
    },
    {
      sid: 'efgh5678',
      startedAt: '2026-11-02T18:00:00Z',
      endedAt: '2026-11-02T18:00:03Z',
      durationMs: 3_000,
      bounce: true,
      quickClose: true,
      reason: 'exit',
      steps: [{ type: 'screen', screen: '/home', dwellMs: 3_000, at: '2026-11-02T18:00:00Z' }],
    },
  ],
};
