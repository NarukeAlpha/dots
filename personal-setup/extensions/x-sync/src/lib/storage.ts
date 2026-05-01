import type {
  ActiveEnvironmentSettings,
  EnvironmentName,
  EnvironmentSettings,
  PublicSettings,
  SaveSettingsInput,
  StoredSettings
} from "./types";

const STORAGE_KEY = "x-sync-settings";

const DEFAULT_ENVIRONMENT: EnvironmentSettings = {
  convexSiteUrl: "",
  publicSiteUrl: "",
  deployKey: ""
};

const DEFAULT_SETTINGS: StoredSettings = {
  selectedEnvironment: "prod",
  environments: {
    dev: { ...DEFAULT_ENVIRONMENT },
    prod: { ...DEFAULT_ENVIRONMENT }
  }
};

function isRecord(value: unknown): value is Record<string, unknown> {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

function normalizeString(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function normalizeEnvironment(value: unknown): EnvironmentName {
  return value === "dev" ? "dev" : "prod";
}

function normalizeEnvironmentSettings(value: unknown): EnvironmentSettings {
  if (!isRecord(value)) {
    return { ...DEFAULT_ENVIRONMENT };
  }

  return {
    convexSiteUrl: normalizeString(value.convexSiteUrl),
    publicSiteUrl: normalizeString(value.publicSiteUrl),
    deployKey: normalizeString(value.deployKey)
  };
}

function normalizeStoredSettings(value: unknown): StoredSettings {
  if (!isRecord(value)) {
    return {
      selectedEnvironment: DEFAULT_SETTINGS.selectedEnvironment,
      environments: {
        dev: { ...DEFAULT_ENVIRONMENT },
        prod: { ...DEFAULT_ENVIRONMENT }
      }
    };
  }

  return {
    selectedEnvironment: normalizeEnvironment(value.selectedEnvironment),
    environments: {
      dev: normalizeEnvironmentSettings(value.environments && isRecord(value.environments) ? value.environments.dev : undefined),
      prod: normalizeEnvironmentSettings(value.environments && isRecord(value.environments) ? value.environments.prod : undefined)
    }
  };
}

export async function loadStoredSettings(): Promise<StoredSettings> {
  const stored = await chrome.storage.local.get(STORAGE_KEY);
  return normalizeStoredSettings(stored[STORAGE_KEY]);
}

export async function loadPublicSettings(): Promise<PublicSettings> {
  const settings = await loadStoredSettings();

  return {
    selectedEnvironment: settings.selectedEnvironment,
    environments: {
      dev: {
        convexSiteUrl: settings.environments.dev.convexSiteUrl,
        publicSiteUrl: settings.environments.dev.publicSiteUrl,
        deployKeyConfigured: Boolean(settings.environments.dev.deployKey)
      },
      prod: {
        convexSiteUrl: settings.environments.prod.convexSiteUrl,
        publicSiteUrl: settings.environments.prod.publicSiteUrl,
        deployKeyConfigured: Boolean(settings.environments.prod.deployKey)
      }
    }
  };
}

export async function saveSettings(input: SaveSettingsInput): Promise<StoredSettings> {
  const current = await loadStoredSettings();
  const next: StoredSettings = {
    selectedEnvironment: input.selectedEnvironment,
    environments: {
      dev: { ...current.environments.dev },
      prod: { ...current.environments.prod }
    }
  };

  for (const environment of ["dev", "prod"] as const) {
    const patch = input.environments[environment];
    const currentEnvironment = current.environments[environment];
    const nextDeployKey = patch.clearDeployKey
      ? ""
      : typeof patch.deployKey === "string" && patch.deployKey.trim()
        ? patch.deployKey.trim()
        : currentEnvironment.deployKey;

    next.environments[environment] = {
      convexSiteUrl: normalizeString(patch.convexSiteUrl),
      publicSiteUrl: normalizeString(patch.publicSiteUrl),
      deployKey: nextDeployKey
    };
  }

  await chrome.storage.local.set({ [STORAGE_KEY]: next });
  return next;
}

export async function getActiveEnvironmentSettings(): Promise<ActiveEnvironmentSettings> {
  const settings = await loadStoredSettings();
  return {
    environment: settings.selectedEnvironment,
    ...settings.environments[settings.selectedEnvironment]
  };
}
