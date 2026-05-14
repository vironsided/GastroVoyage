export interface Profile {
  id: string;
  displayName: string;
  avatarUrl: string | null;
  homeCity: string | null;
  bio: string | null;
  createdAt: string;
  updatedAt: string;
}

export type UserRole = 'user' | 'admin';
