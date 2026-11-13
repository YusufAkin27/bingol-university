// Yönetici panelinden içerik/hesap oluşturma: kullanıcı ekleme (POST /api/admin/users, yalnız FULL) ve yöneticinin
// kendi hesabıyla gönderi paylaşması (POST /api/posts/media + POST /api/posts; gönderi = 1 fotoğraf VEYA 1 video).
import { api } from './client';

export interface CreateUserBody {
  email: string;
  password: string;
  displayName?: string;
  language?: 'tr' | 'en' | 'ar';
}
export interface CreatedUser {
  id: number;
  email: string;
  displayName: string;
}
export const createUser = (body: CreateUserBody) => api.post<CreatedUser>('/admin/users', body);

export interface UploadedPostMedia {
  id: number;
  kind: string;
}
export const uploadPostMedia = (file: File) => {
  const form = new FormData();
  form.append('file', file);
  return api.postForm<UploadedPostMedia>('/posts/media', form);
};

export interface CreatedPost {
  id: number;
}
export const createPost = (text: string, mediaIds: number[]) =>
  api.post<CreatedPost>('/posts', { text: text.trim() || null, mediaIds });
