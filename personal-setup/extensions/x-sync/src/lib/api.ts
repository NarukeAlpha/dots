import type { ActiveEnvironmentSettings, BookmarkSyncResult, ConnectionTestResult, XBookmarkPayload } from "./types";

interface StudioErrorResponse {
  error: string;
}

interface StudioBookmarkResponse {
  url: string;
  title: string;
}

interface StudioBookmarkPublishRequest {
  url: string;
  note: string;
  title: string;
  description: string;
  source: string;
}

class StudioRequestError extends Error {
  status: number;

  constructor(message: string, status: number) {
    super(message);
    this.name = "StudioRequestError";
    this.status = status;
  }
}

function normalizeActionUrl(url: string) {
  return url.trim().replace(/\/$/, "");
}

function compactText(value: string) {
  return value.replace(/\s+/g, " ").trim();
}

function truncateText(value: string, maxLength: number) {
  if (value.length <= maxLength) {
    return value;
  }

  return `${value.slice(0, Math.max(0, maxLength - 3)).trimEnd()}...`;
}

function formatAuthorLabel(authorName: string, authorHandle: string) {
  const name = compactText(authorName);
  const normalizedHandle = compactText(authorHandle).replace(/^@+/, "");

  if (name && normalizedHandle) {
    return `${name} (@${normalizedHandle})`;
  }

  if (normalizedHandle) {
    return `@${normalizedHandle}`;
  }

  if (name) {
    return name;
  }

  return "";
}

function deriveFallbackBookmarkRequest(payload: XBookmarkPayload): StudioBookmarkPublishRequest {
  const bookmarkUrl = payload.externalUrl || payload.postUrl;
  const postText = compactText(payload.postText);
  const authorLabel = formatAuthorLabel(payload.authorName, payload.authorHandle);
  const source = payload.externalUrl
    ? new URL(payload.externalUrl).hostname.replace(/^www\./, "").toLowerCase()
    : "x.com";
  const title = postText
    ? truncateText(postText, 96)
    : authorLabel
      ? `Post by ${authorLabel}`
      : "Saved from X";
  const description = postText
    ? truncateText(postText, 220)
    : payload.externalUrl
      ? authorLabel
        ? `Shared on X by ${authorLabel}.`
        : "Shared on X."
      : authorLabel
        ? `Saved X post by ${authorLabel}.`
        : "Saved X post.";
  const noteLines = ["Saved from X", `Post: ${payload.postUrl}`];

  if (authorLabel) {
    noteLines.push(`Author: ${authorLabel}`);
  }

  if (postText) {
    noteLines.push("", postText);
  }

  return {
    url: bookmarkUrl,
    note: noteLines.join("\n"),
    title,
    description,
    source
  };
}

function parseStudioErrorResponse(value: unknown): StudioErrorResponse | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }

  return value as StudioErrorResponse;
}

function requireConfiguredEnvironment(environment: ActiveEnvironmentSettings) {
  const actionUrl = normalizeActionUrl(environment.convexSiteUrl);
  const deployKey = environment.deployKey.trim();

  if (!actionUrl) {
    throw new Error("Save the Action URL (Convex Site) for the active environment before syncing bookmarks.");
  }

  if (!deployKey) {
    throw new Error("Save the studio write key for the active environment before syncing bookmarks.");
  }

  return {
    actionUrl,
    deployKey
  };
}

async function postStudioEndpoint(environment: ActiveEnvironmentSettings, path: string, body: unknown) {
  const { actionUrl, deployKey } = requireConfiguredEnvironment(environment);
  const response = await fetch(`${actionUrl}${path}`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-studio-write-key": deployKey
    },
    body: JSON.stringify(body)
  });
  const payload = await response.json().catch(() => null);

  if (!response.ok) {
    const message = parseStudioErrorResponse(payload)?.error || `Studio request failed with status ${response.status}.`;
    throw new StudioRequestError(message, response.status);
  }

  return payload;
}

export async function testConnection(environment: ActiveEnvironmentSettings): Promise<ConnectionTestResult> {
  try {
    await postStudioEndpoint(environment, "/studio/overview", {});
    return { ok: true };
  } catch (error) {
    return {
      ok: false,
      error: error instanceof Error ? error.message : "Connection test failed."
    };
  }
}

export async function syncBookmark(environment: ActiveEnvironmentSettings, payload: XBookmarkPayload): Promise<BookmarkSyncResult> {
  try {
    let bookmark: StudioBookmarkResponse;

    try {
      bookmark = await postStudioEndpoint(environment, "/studio/bookmarks/x-sync", payload) as StudioBookmarkResponse;
    } catch (error) {
      if (!(error instanceof StudioRequestError) || error.status !== 404) {
        throw error;
      }

      bookmark = await postStudioEndpoint(environment, "/studio/bookmarks", deriveFallbackBookmarkRequest(payload)) as StudioBookmarkResponse;
    }

    return {
      ok: true,
      bookmark: {
        url: bookmark.url,
        title: bookmark.title
      }
    };
  } catch (error) {
    const message = error instanceof StudioRequestError && error.status === 404
      ? "Bookmark endpoint returned 404. Deploy the latest personal-blog HTTP routes or keep using the existing /studio/bookmarks route."
      : error instanceof Error
        ? error.message
        : "Bookmark sync failed.";

    return {
      ok: false,
      error: message
    };
  }
}
