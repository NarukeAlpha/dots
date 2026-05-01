import { useEffect, useMemo, useState } from "react";

import { loadStoredSettings, saveSettings } from "../lib/storage";
import type {
  ActiveEnvironmentSettings,
  ConnectionTestResult,
  EnvironmentName,
  SaveSettingsInput,
  StoredSettings
} from "../lib/types";

const TEST_CONNECTION_MESSAGE = "x-sync/test-connection";

interface Notice {
  tone: "success" | "error" | "info";
  message: string;
}

function cloneSettings(settings: StoredSettings): StoredSettings {
  return {
    selectedEnvironment: settings.selectedEnvironment,
    environments: {
      dev: { ...settings.environments.dev },
      prod: { ...settings.environments.prod }
    }
  };
}

function EnvironmentCard({
  environment,
  isActive,
  value,
  storedDeployKey,
  deployKeyDraft,
  clearRequested,
  isTesting,
  onChange,
  onDeployKeyChange,
  onClearKey,
  onTest
}: {
  environment: EnvironmentName;
  isActive: boolean;
  value: StoredSettings["environments"][EnvironmentName];
  storedDeployKey: string;
  deployKeyDraft: string;
  clearRequested: boolean;
  isTesting: boolean;
  onChange: (patch: Partial<StoredSettings["environments"][EnvironmentName]>) => void;
  onDeployKeyChange: (value: string) => void;
  onClearKey: () => void;
  onTest: () => void;
}) {
  const label = environment === "dev" ? "Development" : "Production";
  const deployKeyConfigured = Boolean(storedDeployKey) && !clearRequested;
  const keyPlaceholder = deployKeyConfigured
    ? "Stored locally. Enter a new key to replace it."
    : "Paste key";

  return (
    <section className={`env-card ${isActive ? "env-card--active" : ""}`}>
      <div className="env-card__header">
        <div>
          <p className="eyebrow">Environment</p>
          <h2>{label}</h2>
        </div>
        {isActive ? <span className="pill pill--active">Active</span> : null}
      </div>

      <label className="field">
        <span>Action URL (Convex Site)</span>
        <input
          type="url"
          value={value.convexSiteUrl}
          placeholder="https://your-deployment.convex.site"
          onChange={(event) => onChange({ convexSiteUrl: event.target.value })}
        />
      </label>

      <label className="field">
        <span>Public Site URL</span>
        <input
          type="url"
          value={value.publicSiteUrl}
          placeholder="https://your-blog.com"
          onChange={(event) => onChange({ publicSiteUrl: event.target.value })}
        />
      </label>

      <label className="field">
        <span>Studio Write Key</span>
        <div className="field-row">
          <input
            type="password"
            value={deployKeyDraft}
            placeholder={keyPlaceholder}
            onChange={(event) => onDeployKeyChange(event.target.value)}
          />
          <button type="button" className="button button--ghost" onClick={onClearKey}>
            Clear
          </button>
        </div>
        <p className="field-hint">Stored in this browser profile only. Nothing is baked into the extension bundle.</p>
      </label>

      <div className="env-card__footer">
        <span className={`pill ${deployKeyConfigured ? "pill--ready" : "pill--muted"}`}>
          {deployKeyConfigured ? "Key saved" : "Key missing"}
        </span>
        <button type="button" className="button button--ghost" disabled={isTesting} onClick={onTest}>
          {isTesting ? "Testing..." : "Test Connection"}
        </button>
      </div>
    </section>
  );
}

export function App() {
  const [isLoading, setIsLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);
  const [draft, setDraft] = useState<StoredSettings | null>(null);
  const [storedSettings, setStoredSettings] = useState<StoredSettings | null>(null);
  const [deployKeyDrafts, setDeployKeyDrafts] = useState<Record<EnvironmentName, string>>({ dev: "", prod: "" });
  const [clearKeyFlags, setClearKeyFlags] = useState<Record<EnvironmentName, boolean>>({ dev: false, prod: false });
  const [testingEnvironment, setTestingEnvironment] = useState<EnvironmentName | null>(null);
  const [notice, setNotice] = useState<Notice | null>(null);

  useEffect(() => {
    void (async () => {
      try {
        const nextSettings = await loadStoredSettings();
        setStoredSettings(nextSettings);
        setDraft(cloneSettings(nextSettings));
      } catch (error) {
        setNotice({
          tone: "error",
          message: error instanceof Error ? error.message : "Failed to load extension settings."
        });
      } finally {
        setIsLoading(false);
      }
    })();
  }, []);

  const activeEnvironment = draft?.selectedEnvironment || "prod";
  const summary = useMemo(() => {
    if (!draft) {
      return "Loading local extension settings.";
    }

    const env = draft.environments[draft.selectedEnvironment];
    return env.convexSiteUrl
      ? `Writes go to ${draft.selectedEnvironment.toUpperCase()} via ${env.convexSiteUrl}.`
      : `Choose ${draft.selectedEnvironment.toUpperCase()} settings, then add the action URL and key.`;
  }, [draft]);

  function patchEnvironment(environment: EnvironmentName, patch: Partial<StoredSettings["environments"][EnvironmentName]>) {
    setDraft((current) => current ? {
      ...current,
      environments: {
        ...current.environments,
        [environment]: {
          ...current.environments[environment],
          ...patch
        }
      }
    } : current);
  }

  function updateDeployKey(environment: EnvironmentName, value: string) {
    setDeployKeyDrafts((current) => ({
      ...current,
      [environment]: value
    }));
    if (value.trim()) {
      setClearKeyFlags((current) => ({
        ...current,
        [environment]: false
      }));
    }
  }

  function clearDeployKey(environment: EnvironmentName) {
    setDeployKeyDrafts((current) => ({
      ...current,
      [environment]: ""
    }));
    setClearKeyFlags((current) => ({
      ...current,
      [environment]: true
    }));
    setNotice({ tone: "info", message: `${environment.toUpperCase()} write key will be cleared on save.` });
  }

  async function handleSave() {
    if (!draft) {
      return;
    }

    setIsSaving(true);
    setNotice(null);

    const payload: SaveSettingsInput = {
      selectedEnvironment: draft.selectedEnvironment,
      environments: {
        dev: {
          convexSiteUrl: draft.environments.dev.convexSiteUrl,
          publicSiteUrl: draft.environments.dev.publicSiteUrl,
          deployKey: deployKeyDrafts.dev,
          clearDeployKey: clearKeyFlags.dev
        },
        prod: {
          convexSiteUrl: draft.environments.prod.convexSiteUrl,
          publicSiteUrl: draft.environments.prod.publicSiteUrl,
          deployKey: deployKeyDrafts.prod,
          clearDeployKey: clearKeyFlags.prod
        }
      }
    };

    try {
      const saved = await saveSettings(payload);
      setStoredSettings(saved);
      setDraft(cloneSettings(saved));
      setDeployKeyDrafts({ dev: "", prod: "" });
      setClearKeyFlags({ dev: false, prod: false });
      setNotice({ tone: "success", message: "Settings saved." });
    } catch (error) {
      setNotice({
        tone: "error",
        message: error instanceof Error ? error.message : "Failed to save settings."
      });
    } finally {
      setIsSaving(false);
    }
  }

  async function handleTest(environment: EnvironmentName) {
    if (!draft || !storedSettings) {
      return;
    }

    setTestingEnvironment(environment);
    setNotice(null);

    const payload: ActiveEnvironmentSettings = {
      environment,
      convexSiteUrl: draft.environments[environment].convexSiteUrl,
      publicSiteUrl: draft.environments[environment].publicSiteUrl,
      deployKey: deployKeyDrafts[environment].trim() || (clearKeyFlags[environment] ? "" : storedSettings.environments[environment].deployKey)
    };

    try {
      const result = await chrome.runtime.sendMessage({
        type: TEST_CONNECTION_MESSAGE,
        payload
      }) as ConnectionTestResult | undefined;

      if (!result?.ok) {
        throw new Error(result?.error || "Connection test failed.");
      }

      setNotice({ tone: "success", message: `${environment.toUpperCase()} connection is live.` });
    } catch (error) {
      setNotice({
        tone: "error",
        message: error instanceof Error ? error.message : "Connection test failed."
      });
    } finally {
      setTestingEnvironment(null);
    }
  }

  if (isLoading || !draft || !storedSettings) {
    return (
      <main className="popup-shell popup-shell--loading">
        <section className="hero-panel">
          <p className="eyebrow">Booting</p>
          <h1>Loading X Sync</h1>
          <p className="hero-copy">Reading your local environment settings.</p>
        </section>
      </main>
    );
  }

  const readyDraft = draft;
  const readyStoredSettings = storedSettings;

  return (
    <main className="popup-shell">
      <div className="stardust-overlay" />
      <section className="hero-panel">
        <div className="hero-header">
          <div>
            <p className="eyebrow">Bookmark Relay</p>
            <h1>X Sync</h1>
          </div>
          <div className="env-switcher" role="tablist" aria-label="Active environment">
            {(["dev", "prod"] as const).map((environment) => (
              <button
                key={environment}
                type="button"
                className={`env-switcher__button ${activeEnvironment === environment ? "env-switcher__button--active" : ""}`}
                onClick={() => setDraft((current) => current ? { ...current, selectedEnvironment: environment } : current)}
              >
                {environment.toUpperCase()}
              </button>
            ))}
          </div>
        </div>

        <p className="hero-copy">{summary}</p>
        {notice ? <p className={`notice notice--${notice.tone}`}>{notice.message}</p> : null}
      </section>

      <section className="panel-stack">
        {(["dev", "prod"] as const).map((environment) => (
          <EnvironmentCard
            key={environment}
            environment={environment}
            isActive={readyDraft.selectedEnvironment === environment}
            value={readyDraft.environments[environment]}
            storedDeployKey={readyStoredSettings.environments[environment].deployKey}
            deployKeyDraft={deployKeyDrafts[environment]}
            clearRequested={clearKeyFlags[environment]}
            isTesting={testingEnvironment === environment}
            onChange={(patch) => patchEnvironment(environment, patch)}
            onDeployKeyChange={(value) => updateDeployKey(environment, value)}
            onClearKey={() => clearDeployKey(environment)}
            onTest={() => void handleTest(environment)}
          />
        ))}
      </section>

      <footer className="footer-bar">
        <p className="footer-copy">Shared links save the outbound URL. Posts without links save the X post itself.</p>
        <button type="button" className="button button--primary" disabled={isSaving} onClick={() => void handleSave()}>
          {isSaving ? "Saving..." : "Save Settings"}
        </button>
      </footer>
    </main>
  );
}
