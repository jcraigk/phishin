import React, { useCallback, useContext, useEffect, useState } from "react";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faCheck, faRocket, faXmark } from "@fortawesome/free-solid-svg-icons";
import Spinner from "./Spinner";
import IssueList from "./IssueList";
import { EditorContext } from "./AdminShowEditor";
import useJobRunner from "./useJobRunner";
import { adminGet, adminPost } from "./adminApi";
import { formatDate } from "../helpers/utils";
import Modal from "./Modal";

const PUBLISH_STEPS =
  "Publishing computes gaps, applies debut and bustout tags, syncs lore, " +
  "discards leftover staged audio, posts an announcement, and makes the show " +
  "public. There is no unpublish.";

// A Publish button for the show header. Pressing it opens a modal: the list
// of what still blocks publishing, or the typed confirmation when nothing
// does, and then the job's progress until the show is public.
const PublishPanel = () => {
  const { show, reload, gapsStale, setError } = useContext(EditorContext);
  const [readiness, setReadiness] = useState(null);
  const [modal, setModal] = useState(null);
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
      } catch (e) {
        if (isCurrent()) setError(e.message);
      }
    },
    [show.date, setError]
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

  useEffect(() => {
    if (publish.error) {
      setModal(null);
      setError(publish.error);
    }
  }, [publish.error, setError]);

  if (show.published) return null;

  const ready = Boolean(readiness && readiness.ready);
  const issues = (readiness && readiness.issues) || [];

  const close = () => {
    setModal(null);
    setTyped("");
  };

  const open = () => setModal(ready ? "confirm" : "issues");

  const runPublish = () => {
    if (typed.trim() !== show.date) return;
    setTyped("");
    setModal("running");
    publish.run(
      () => adminPost(`/shows/${show.date}/publish`),
      async () => {
        await reload();
        await loadReadiness();
        setModal(null);
      }
    );
  };

  return (
    <>
      <button
        type="button"
        className="admin-publish-button"
        disabled={readiness === null || publish.busy}
        title="Publish this show"
        onClick={open}
      >
        <FontAwesomeIcon icon={faRocket} /> Publish
      </button>

      {modal === "issues" && (
        <Modal title="Not ready to publish" onClose={close}>
          <IssueList issues={issues} />
          <div className="admin-modal-actions">
            <button type="button" onClick={close}>
              <FontAwesomeIcon icon={faCheck} /> OK
            </button>
          </div>
        </Modal>
      )}

      {modal === "confirm" && (
        <Modal title={<>Publish {formatDate(show.date)}?</>} onClose={close}>
          <p className="admin-publish-note">{PUBLISH_STEPS}</p>
          {gapsStale && (
            <p className="admin-publish-note">
              Track edits have not been reflected in gap data. Publishing recomputes
              gaps, so this clears itself.
            </p>
          )}
          <label className="admin-modal-field" htmlFor="admin-publish-confirm">
            <span>Type {show.date} to confirm. This cannot be undone.</span>
            <input
              id="admin-publish-confirm"
              type="text"
              autoComplete="off"
              autoFocus
              value={typed}
              onChange={(e) => setTyped(e.target.value)}
              onKeyDown={(e) => { if (e.key === "Enter") runPublish(); }}
            />
          </label>
          <div className="admin-modal-actions">
            <button
              type="button"
              className="admin-publish-go"
              disabled={typed.trim() !== show.date}
              onClick={runPublish}
            >
              <FontAwesomeIcon icon={faRocket} /> Publish
            </button>
            <button type="button" onClick={close}>
              <FontAwesomeIcon icon={faXmark} /> Cancel
            </button>
          </div>
        </Modal>
      )}

      {modal === "running" && (
        <Modal title={<>Publishing {formatDate(show.date)}</>}>
          <div className="admin-stage-detail">
            <Spinner accent />
            <span>{publish.status || "Starting..."}</span>
          </div>
        </Modal>
      )}
    </>
  );
};

export default PublishPanel;
