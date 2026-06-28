export interface User {
  id: string;
  email: string;
  name: string;
  createdAt: Date;
  updatedAt: Date;
}

export interface AuthToken {
  accessToken: string;
  refreshToken?: string;
  expiresAt: Date;
}

export interface SyncSession {
  userId: string;
  lastSyncedAt: Date;
  pendingChanges: number;
}
