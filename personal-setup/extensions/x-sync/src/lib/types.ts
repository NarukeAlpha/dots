export type EnvironmentName = "dev" | "prod";

export interface EnvironmentSettings {
  convexSiteUrl: string;
  publicSiteUrl: string;
  deployKey: string;
}

export interface StoredSettings {
  selectedEnvironment: EnvironmentName;
  environments: Record<EnvironmentName, EnvironmentSettings>;
}

export interface PublicEnvironmentSettings {
  convexSiteUrl: string;
  publicSiteUrl: string;
  deployKeyConfigured: boolean;
}

export interface PublicSettings {
  selectedEnvironment: EnvironmentName;
  environments: Record<EnvironmentName, PublicEnvironmentSettings>;
}

export interface SaveEnvironmentSettingsInput {
  convexSiteUrl: string;
  publicSiteUrl: string;
  deployKey?: string;
  clearDeployKey?: boolean;
}

export interface SaveSettingsInput {
  selectedEnvironment: EnvironmentName;
  environments: Record<EnvironmentName, SaveEnvironmentSettingsInput>;
}

export interface ActiveEnvironmentSettings extends EnvironmentSettings {
  environment: EnvironmentName;
}

export interface XBookmarkPayload {
  postUrl: string;
  postText: string;
  authorName: string;
  authorHandle: string;
  externalUrl?: string;
}

export interface BookmarkSyncResult {
  ok: boolean;
  bookmark?: {
    url: string;
    title: string;
  };
  error?: string;
}

export interface ConnectionTestResult {
  ok: boolean;
  error?: string;
}
