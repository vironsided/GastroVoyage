import type { Region } from './country';

export interface Badge {
  code: string;
  title: string;
  description: string;
  region: Region | null;
  threshold: number | null;
  icon: string | null;
  sortOrder: number;
}

export interface UserBadge {
  userId: string;
  badgeCode: string;
  earnedAt: string;
}
