const SAVE_BOOKMARK_MESSAGE = "x-sync/save-bookmark";
const ARTICLE_SELECTOR = 'article[data-testid="tweet"]';
const BUTTON_ROOT_ATTRIBUTE = "data-x-sync-root";
const BUTTON_STYLE = {
  idle: {
    label: "Sync",
    background: "rgba(18, 20, 36, 0.72)",
    border: "1px solid rgba(100, 220, 255, 0.26)",
    color: "#9ee7ff"
  },
  saving: {
    label: "Saving",
    background: "rgba(34, 38, 62, 0.82)",
    border: "1px solid rgba(120, 160, 255, 0.28)",
    color: "#d9e2ff"
  },
  saved: {
    label: "Saved",
    background: "rgba(16, 54, 40, 0.84)",
    border: "1px solid rgba(84, 214, 154, 0.36)",
    color: "#96f4c5"
  },
  error: {
    label: "Retry",
    background: "rgba(68, 18, 34, 0.88)",
    border: "1px solid rgba(255, 108, 144, 0.34)",
    color: "#ff9ab6"
  }
} as const;

type ButtonState = keyof typeof BUTTON_STYLE;

interface XBookmarkPayload {
  postUrl: string;
  postText: string;
  authorName: string;
  authorHandle: string;
  externalUrl?: string;
}

interface SyncBookmarkResponse {
  ok?: boolean;
  error?: string;
  bookmark?: {
    title?: string;
  };
}

function compactText(value: string) {
  return value.replace(/\s+/g, " ").trim();
}

function toAbsoluteUrl(href: string | null) {
  if (!href) {
    return "";
  }

  try {
    return new URL(href, window.location.origin).toString();
  } catch {
    return "";
  }
}

function isCurrentArticleLink(link: HTMLAnchorElement, article: HTMLElement) {
  return link.closest("article") === article;
}

function isIgnoredXLink(url: URL) {
  const hostname = url.hostname.replace(/^www\./, "").toLowerCase();

  if (hostname !== "x.com" && hostname !== "twitter.com") {
    return false;
  }

  const path = url.pathname.toLowerCase();
  return path.includes("/status/") || path.startsWith("/hashtag/") || path.startsWith("/search") || path.startsWith("/i/");
}

function findPostUrl(article: HTMLElement) {
  const links = Array.from(article.querySelectorAll<HTMLAnchorElement>('a[href*="/status/"]'));
  const candidate = links.find((link) => isCurrentArticleLink(link, article) && (link.querySelector("time") || /\/status\/\d+/.test(link.getAttribute("href") || "")));

  if (!candidate) {
    throw new Error("Could not locate the post URL on this item.");
  }

  const postUrl = toAbsoluteUrl(candidate.getAttribute("href"));

  if (!postUrl) {
    throw new Error("Could not build a valid X post URL.");
  }

  return postUrl;
}

function findExternalUrl(article: HTMLElement) {
  const tweetText = article.querySelector<HTMLElement>('div[data-testid="tweetText"]');
  const roots: ParentNode[] = tweetText ? [tweetText, article] : [article];
  const visited = new Set<string>();

  for (const root of roots) {
    const links = Array.from(root.querySelectorAll<HTMLAnchorElement>("a[href]"));

    for (const link of links) {
      if (!isCurrentArticleLink(link, article)) {
        continue;
      }

      const nextUrl = toAbsoluteUrl(link.getAttribute("href"));

      if (!nextUrl || visited.has(nextUrl)) {
        continue;
      }

      visited.add(nextUrl);

      try {
        const parsed = new URL(nextUrl);
        const hostname = parsed.hostname.replace(/^www\./, "").toLowerCase();

        if (!/^https?:$/.test(parsed.protocol)) {
          continue;
        }

        if (hostname === "t.co") {
          return parsed.toString();
        }

        if (!isIgnoredXLink(parsed) && hostname !== "x.com" && hostname !== "twitter.com") {
          return parsed.toString();
        }
      } catch {
        // Ignore invalid links inside the feed.
      }
    }
  }

  return undefined;
}

function extractAuthor(article: HTMLElement) {
  const userName = article.querySelector<HTMLElement>('div[data-testid="User-Name"]');
  const fullText = compactText(userName?.textContent || "");
  const firstSpan = compactText(userName?.querySelector("span")?.textContent || "");
  const handleMatch = fullText.match(/@([A-Za-z0-9_]{1,15})/);

  return {
    authorName: firstSpan,
    authorHandle: handleMatch ? `@${handleMatch[1]}` : ""
  };
}

function extractBookmarkPayload(article: HTMLElement): XBookmarkPayload {
  const postUrl = findPostUrl(article);
  const postText = compactText(article.querySelector<HTMLElement>('div[data-testid="tweetText"]')?.textContent || "");
  const { authorName, authorHandle } = extractAuthor(article);
  const externalUrl = findExternalUrl(article);

  return {
    postUrl,
    postText,
    authorName,
    authorHandle,
    ...(externalUrl ? { externalUrl } : {})
  };
}

function applyButtonState(button: HTMLButtonElement, state: ButtonState, title = "") {
  const style = BUTTON_STYLE[state];
  button.textContent = style.label;
  button.style.background = style.background;
  button.style.border = style.border;
  button.style.color = style.color;
  button.disabled = state === "saving";
  button.title = title;
}

async function handleButtonClick(button: HTMLButtonElement, article: HTMLElement) {
  if (button.disabled) {
    return;
  }

  applyButtonState(button, "saving", "Saving bookmark...");

  try {
    const payload = extractBookmarkPayload(article);
    const response = await chrome.runtime.sendMessage({
      type: SAVE_BOOKMARK_MESSAGE,
      payload
    }) as SyncBookmarkResponse | undefined;

    if (!response?.ok) {
      throw new Error(response?.error || "Bookmark sync failed.");
    }

    applyButtonState(button, "saved", response.bookmark?.title || "Bookmark saved.");
    window.setTimeout(() => applyButtonState(button, "idle", "Sync to your personal blog bookmarks."), 1800);
  } catch (error) {
    applyButtonState(button, "error", error instanceof Error ? error.message : "Bookmark sync failed.");
    window.setTimeout(() => applyButtonState(button, "idle", "Sync to your personal blog bookmarks."), 3500);
  }
}

function createButton(article: HTMLElement) {
  const button = document.createElement("button");
  button.type = "button";
  button.setAttribute("aria-label", "Sync bookmark to personal blog");
  button.style.display = "inline-flex";
  button.style.alignItems = "center";
  button.style.justifyContent = "center";
  button.style.height = "28px";
  button.style.minWidth = "56px";
  button.style.padding = "0 11px";
  button.style.borderRadius = "999px";
  button.style.fontSize = "12px";
  button.style.fontWeight = "600";
  button.style.letterSpacing = "0.01em";
  button.style.cursor = "pointer";
  button.style.backdropFilter = "blur(12px) saturate(1.18)";
  button.style.boxShadow = "inset 0 1px 0 rgba(140,130,255,0.08), 0 8px 24px rgba(0,0,0,0.18)";
  button.style.transition = "background 120ms ease, border-color 120ms ease, color 120ms ease, transform 120ms ease";
  button.style.marginRight = "8px";
  applyButtonState(button, "idle", "Sync to your personal blog bookmarks.");
  button.addEventListener("mouseenter", () => {
    if (!button.disabled) {
      button.style.transform = "translateY(-1px)";
    }
  });
  button.addEventListener("mouseleave", () => {
    button.style.transform = "translateY(0)";
  });
  button.addEventListener("click", (event) => {
    event.preventDefault();
    event.stopPropagation();
    void handleButtonClick(button, article);
  });
  return button;
}

function mountButton(article: HTMLElement) {
  if (article.querySelector(`[${BUTTON_ROOT_ATTRIBUTE}]`)) {
    return;
  }

  const root = document.createElement("div");
  root.setAttribute(BUTTON_ROOT_ATTRIBUTE, "true");
  root.style.display = "inline-flex";
  root.style.alignItems = "center";

  const button = createButton(article);
  root.appendChild(button);

  const caretButton = article.querySelector<HTMLButtonElement>('button[data-testid="caret"]');
  const caretContainer = caretButton?.parentElement;
  const actionGroup = caretContainer?.parentElement;

  if (actionGroup) {
    actionGroup.insertBefore(root, actionGroup.firstElementChild);
    return;
  }

  const firstRow = article.querySelector("div");

  if (!firstRow) {
    return;
  }

  article.style.position = article.style.position || "relative";
  root.style.position = "absolute";
  root.style.top = "12px";
  root.style.right = "56px";
  firstRow.appendChild(root);
}

let scanScheduled = false;

function scanArticles() {
  document.querySelectorAll<HTMLElement>(ARTICLE_SELECTOR).forEach((article) => {
    try {
      mountButton(article);
    } catch {
      // Keep the observer resilient against DOM changes in the feed.
    }
  });
}

function scheduleScan() {
  if (scanScheduled) {
    return;
  }

  scanScheduled = true;
  window.requestAnimationFrame(() => {
    scanScheduled = false;
    scanArticles();
  });
}

const observer = new MutationObserver(() => {
  scheduleScan();
});

observer.observe(document.documentElement, {
  childList: true,
  subtree: true
});

scheduleScan();
