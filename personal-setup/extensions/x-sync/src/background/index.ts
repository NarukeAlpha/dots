import { syncBookmark, testConnection } from "../lib/api";
import { getActiveEnvironmentSettings } from "../lib/storage";
import type { ActiveEnvironmentSettings, XBookmarkPayload } from "../lib/types";

const SAVE_BOOKMARK_MESSAGE = "x-sync/save-bookmark";
const TEST_CONNECTION_MESSAGE = "x-sync/test-connection";

type RuntimeMessage =
  | {
      type: typeof SAVE_BOOKMARK_MESSAGE;
      payload: XBookmarkPayload;
    }
  | {
      type: typeof TEST_CONNECTION_MESSAGE;
      payload: ActiveEnvironmentSettings;
    };

function isRuntimeMessage(value: unknown): value is RuntimeMessage {
  return value !== null && typeof value === "object" && !Array.isArray(value) && "type" in value;
}

chrome.runtime.onMessage.addListener((message: unknown, _sender, sendResponse) => {
  if (!isRuntimeMessage(message)) {
    return undefined;
  }

  if (message.type === SAVE_BOOKMARK_MESSAGE) {
    void (async () => {
      const environment = await getActiveEnvironmentSettings();
      sendResponse(await syncBookmark(environment, message.payload));
    })();
    return true;
  }

  if (message.type === TEST_CONNECTION_MESSAGE) {
    void (async () => {
      sendResponse(await testConnection(message.payload));
    })();
    return true;
  }

  return undefined;
});
