import React, { useCallback, useContext, useEffect, useState } from "react";
import { EditorContext } from "./AdminShowEditor";
import useJobRunner from "./useJobRunner";
import { adminGet, adminPost } from "./adminApi";

const PUBLISH_STEPS =
  "Publishing computes gaps, applies debut and bustout tags, syncs lore, " +
  "discards leftover staged audio, posts an announcement, and makes the show " +
  "public. There is no unpublish.";

const PublishPanel = () => {
  const { show, reload, gapsStale } = useContext(EditorContext);
  const [readiness, setReadiness] = useState(null);
  const [readinessError, setReadinessError] = useState(null);
  const [confirming, setConfirming] = useState(false);
  const [typed, setTyped] = useState("");
  const publish = useJobRunner();

  // `isCurrent` exists because publishing is irreversible: two edits in quick
  // succession can have their readiness responses land out of order, and the
  // loser would leave a cleared checklist beside an enabled Publish button.
  const loadReadiness = useCallback(
    async (isCurrent = () => true) => {
      try {
        const data = await adminGet(`/shows/${show.date}/readiness`);
        if (!isCurrent()) return;
        setReadiness(data);
        setReadinessError(null);
      } catch (e) {
        if (isCurrent()) setReadinessError(e.message);
      }
    },
    [show.date]
  );

  // `show` rather than `show.date` in the deps: every edit in the editor replaces
  // the show object, and each one can clear or create a readiness issue.
  useEffect(() => {
    let cancelled = false;
    loadReadiness(() => !cancelled);
    return () => {
      cancelled = true;
    };
  }, [loadReadiness, show]);

  if (show.published) return null;

  const ready = Boolean(readiness && readiness.ready);
  const issues = (readiness && readiness.issues) || [];

  const cancel = () => {
    setConfirming(false);
    setTyped("");
  };

  const runPublish = () => {
    if (typed.trim() !== show.date) return;
    cancel();
    publish.run(
      () => adminPost(`/shows/${show.date}/publish`),
      async () => {
        await reload();
        await loadReadiness();
      }
    );
  };

  return (
    <section className="admin-publish-panel">
      <div className="admin-publish-header">
        <h3>Publish</h3>
        {readiness === null && !readinessError && (
          <span className="admin-audio-status">Checking readiness...</span>
        )}
        {ready && !publish.busy && (
          <span className="admin-publish-ready">Ready to publish</span>
        )}
        {publish.busy && <progress className="admin-publish-progress" />}
        {publish.status && (
          <span className="admin-audio-status">{publish.status}</span>
        )}
      </div>

      {readinessError && <p className="admin-error">{readinessError}</p>}
      {publish.error && <p className="admin-error">{publish.error}</p>}

      {issues.length > 0 && (
        <>
          <p className="admin-publish-note">
            {issues.length} item{issues.length === 1 ? "" : "s"} still blocking:
          </p>
          <ul className="admin-publish-issues">
            {issues.map((issue) => (
              <li key={issue}>{issue}</li>
            ))}
          </ul>
        </>
      )}

      {gapsStale && (
        <p className="admin-publish-note">
          Track edits have not been reflected in gap data. Publishing recomputes
          gaps, so this clears itself.
        </p>
      )}

      <p className="admin-publish-note">{PUBLISH_STEPS}</p>

      {confirming ? (
        <div className="admin-publish-confirm">
          <label htmlFor="admin-publish-confirm">
            Type {show.date} to confirm. This cannot be undone.
          </label>
          <input
            id="admin-publish-confirm"
            type="text"
            autoComplete="off"
            value={typed}
            onChange={(e) => setTyped(e.target.value)}
          />
          <button
            type="button"
            className="admin-publish-go"
            disabled={typed.trim() !== show.date}
            onClick={runPublish}
          >
            Publish {show.date}
          </button>
          <button type="button" onClick={cancel}>
            Cancel
          </button>
        </div>
      ) : (
        <button
          type="button"
          className="admin-publish-go"
          disabled={!ready || publish.busy}
          onClick={() => setConfirming(true)}
        >
          {publish.busy ? "Publishing..." : "Publish"}
        </button>
      )}
    </section>
  );
};

export default PublishPanel;
