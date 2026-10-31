/**
 * Yönetim: mail şablonları ve kampanyaları (`/api/admin/mail/*`, docs/ADMIN_API.md "Mail şablonları ve kampanyaları").
 * Tipler bu dosyada tutulur (başka web ajanlarıyla types.ts çakışmasın diye).
 */
import { api } from './client';
import { guardHeaders, type GuardOpts } from './guard';
import type { Page } from './types';

const P = '/admin/mail';

export type MailLang = 'tr' | 'en' | 'ar';
export const MAIL_LANGS: MailLang[] = ['tr', 'en', 'ar'];

export type TemplateStatus = 'DRAFT' | 'PUBLISHED' | 'ARCHIVED';
export type CampaignStatus = 'DRAFT' | 'SCHEDULED' | 'SENDING' | 'PAUSED' | 'DONE' | 'CANCELLED' | 'FAILED';
export type RecipientStatus = 'PENDING' | 'QUEUED' | 'SKIPPED' | 'FAILED' | 'CANCELLED';

export interface MailVariable {
  name: string;
  placeholder: string;
  description: string;
  automatic: boolean;
}
export interface MailVariables {
  variables: MailVariable[];
  maxHtmlLength: number;
  maxSubjectLength: number;
}

export interface MailContent {
  subject: string;
  html: string;
  text?: string | null;
}

export interface TemplateRow {
  id: number;
  name: string;
  description: string | null;
  category: string;
  status: TemplateStatus;
  version: number;
  languages: MailLang[];
  updatedAt: string;
}
export interface TemplateView extends TemplateRow {
  tr: MailContent;
  en: MailContent | null;
  ar: MailContent | null;
  variablesUsed: string[];
  createdBy: number;
  createdAt: string;
}
export interface TemplateRequest {
  name: string;
  description: string;
  tr: MailContent;
  en: MailContent | null;
  ar: MailContent | null;
}
export interface TemplateVersion {
  version: number;
  createdBy: number;
  createdAt: string;
}
export interface PreviewView {
  lang: MailLang;
  usedLang: MailLang;
  fallback: boolean;
  subject: string;
  html: string;
  text: string;
  sampleVariables: Record<string, string>;
}
export interface TestSendView {
  queued: boolean;
  lang: MailLang;
  usedLang: MailLang;
  to: string;
}

export interface AudienceFilter {
  faculty?: string | null;
  department?: string | null;
  classYear?: number | null;
  role?: 'USER' | 'ADMIN' | null;
  language?: MailLang | null;
  communityId?: number | null;
}
export type AudienceType = 'ALL' | 'FILTER' | 'USERS' | 'EMAILS';
export interface MailAudience {
  type: AudienceType;
  filter?: AudienceFilter;
  userIds?: number[];
  emails?: string[];
}
export interface AudiencePreview {
  total: number;
  willSend: number;
  skipped: number;
  skippedByReason: Record<string, number>;
  unmatched: number;
  languages: Record<string, number>;
  languageFallback: number;
}
export interface CampaignCounters {
  target: number;
  pending: number;
  queued: number;
  skipped: number;
  failed: number;
  cancelled: number;
  skippedByReason: Record<string, number>;
  languages: Record<string, number>;
  languageFallback: number;
  progressPercent: number;
}
export interface MailCampaignView {
  id: number;
  name: string;
  templateId: number;
  templateName: string;
  templateVersion: number | null;
  status: CampaignStatus;
  audience: MailAudience & { userCount?: number | null; unmatched?: number };
  scheduledAt: string | null;
  resolvedAt: string | null;
  startedAt: string | null;
  finishedAt: string | null;
  createdBy: number;
  createdAt: string;
  updatedAt: string;
  error: string | null;
  counters: CampaignCounters;
}
export interface CampaignRequest {
  name: string;
  templateId: number;
  audience: MailAudience;
  scheduledAt?: string | null;
  requestKey?: string;
}
export interface RecipientRow {
  userId: number;
  status: RecipientStatus;
  skipReason: string | null;
  errorCode: string | null;
  lang: MailLang | null;
  langFallback: boolean;
  email: string;
  updatedAt: string;
}

export const mailKeys = {
  all: ['adminMail'] as const,
  variables: () => ['adminMail', 'variables'] as const,
  templates: (p: object) => ['adminMail', 'templates', p] as const,
  template: (id: number) => ['adminMail', 'template', id] as const,
  versions: (id: number) => ['adminMail', 'versions', id] as const,
  campaigns: (p: object) => ['adminMail', 'campaigns', p] as const,
  campaign: (id: number) => ['adminMail', 'campaign', id] as const,
  recipients: (id: number, p: object) => ['adminMail', 'recipients', id, p] as const,
};

export const getMailVariables = () => api.get<MailVariables>(`${P}/variables`);

export interface TemplateListParams {
  status?: TemplateStatus;
  q?: string;
  page?: number;
  size?: number;
}
export const listTemplates = (p: TemplateListParams = {}) =>
  api.get<Page<TemplateRow>>(`${P}/templates`, { ...p });
export const getTemplate = (id: number) => api.get<TemplateView>(`${P}/templates/${id}`);
export const createTemplate = (r: TemplateRequest) => api.post<TemplateView>(`${P}/templates`, r);
export const updateTemplate = (id: number, r: TemplateRequest) =>
  api.put<TemplateView>(`${P}/templates/${id}`, r);
export const publishTemplate = (id: number) => api.post<TemplateView>(`${P}/templates/${id}/publish`);
export const archiveTemplate = (id: number) => api.post<TemplateView>(`${P}/templates/${id}/archive`);
export const deleteTemplate = (id: number) => api.del(`${P}/templates/${id}`);
export const previewDraft = (lang: MailLang, content: MailContent) =>
  api.post<PreviewView>(`${P}/templates/preview`, { lang, content });
export const previewSaved = (id: number, body: { lang?: MailLang; version?: number } = {}) =>
  api.post<PreviewView>(`${P}/templates/${id}/preview`, body);
export const sendTestMail = (id: number, lang?: MailLang) =>
  api.post<TestSendView>(`${P}/templates/${id}/test`, lang ? { lang } : {});
export const listTemplateVersions = (id: number) =>
  api.get<TemplateVersion[]>(`${P}/templates/${id}/versions`);

export interface CampaignListParams {
  status?: CampaignStatus;
  q?: string;
  page?: number;
  size?: number;
}
export const listMailCampaigns = (p: CampaignListParams = {}) =>
  api.get<Page<MailCampaignView>>(`${P}/campaigns`, { ...p });
export const getMailCampaign = (id: number) => api.get<MailCampaignView>(`${P}/campaigns/${id}`);
export const listRecipients = (id: number, p: { status?: RecipientStatus; page?: number; size?: number }) =>
  api.get<Page<RecipientRow>>(`${P}/campaigns/${id}/recipients`, { ...p });
export const previewAudience = (audience: MailAudience, templateId?: number) =>
  api.post<AudiencePreview>(`${P}/campaigns/audience/preview`, { audience, templateId });
// W1-B (T-013): olusturma / zamanlama / iptal gerekce ister (>= 5 karakter, X-Admin-Reason).
export const createMailCampaign = (r: CampaignRequest, o?: GuardOpts) =>
  api.post<MailCampaignView>(`${P}/campaigns`, r, guardHeaders(o));
export const updateMailCampaign = (id: number, r: CampaignRequest) =>
  api.put<MailCampaignView>(`${P}/campaigns/${id}`, r);
export const scheduleMailCampaign = (id: number, scheduledAt?: string | null, o?: GuardOpts) =>
  api.post<MailCampaignView>(`${P}/campaigns/${id}/schedule`, scheduledAt ? { scheduledAt } : {}, guardHeaders(o));
export const pauseMailCampaign = (id: number) => api.post<MailCampaignView>(`${P}/campaigns/${id}/pause`);
export const resumeMailCampaign = (id: number) => api.post<MailCampaignView>(`${P}/campaigns/${id}/resume`);
export const cancelMailCampaign = (id: number, o?: GuardOpts) =>
  api.post<MailCampaignView>(`${P}/campaigns/${id}/cancel`, undefined, guardHeaders(o));
