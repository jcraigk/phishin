import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faExternalLinkAlt, faTrashAlt, faCheck, faXmark } from "@fortawesome/free-solid-svg-icons";
import { formatDate } from "../helpers/utils";
import React, { createContext, useCallback, useEffect, useState } from "react";
import { useNavigate, useParams } from "react-router";
import { adminGet, adminDelete } from "./adminApi";
import TracksTab from "./TracksTab";
import ArtTab from "./ArtTab";
import NotesTab from "./NotesTab";
import ShowPanel from "./ShowPanel";
import VenueControl from "./VenueControl";
import PublishPanel from "./PublishPanel";
import StagingEditor from "./StagingEditor";
import IngestProgress from "./IngestProgress";
import Modal from "./Modal";
import { deleteDraftMessage } from "./messages";

export const EditorContext = createContext(null);

const TABS = ["Setlist", "Show", "Art"];

const AdminShowEditor = () => {
  const { date } = useParams();
  const navigate = useNavigate();
  const [confirmingDelete, setConfirmingDelete] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [show, setShow] = useState(null);
  const [tab, setTab] = useState("Setlist");
  const [error, setError] = useState(null);
  const [gapsStale, setGapsStale] = useState(false);

  const reload = useCallback(async () => {
    try {
      setShow(await adminGet(`/shows/${date}`));
    } catch (e) {
      setError(e.message);
    }
  }, [date]);

  useEffect(() => {
    reload();
  }, [reload]);

  // PATCH /tracks/:id answers with a single track rather than the editor payload,
  // so it is merged in place instead of replacing show state.
  const setTrack = useCallback((track) => {
    setShow((prev) =>
      prev === null
        ? prev
        : {
            ...prev,
            tracks: prev.tracks.map((t) => (t.id === track.id ? track : t)),
          }
    );
  }, []);

  if (!show) {
    return (
      <div className="admin-show-editor">
        {error ? <p className="admin-error">{error}</p> : <p>Loading...</p>}
      </div>
    );
  }

  // A show is importing while its audio is staged: the commit is what turns
  // the staged tracks into real ones and clears the staging, so until then
  // there is nothing to preview or delete.
  const importing = Boolean(show.staging) || Boolean(show.ingest_job_id);

  return (
    <EditorContext.Provider
      value={{
        show,
        setShow,
        setTrack,
        reload,
        setError,
        gapsStale,
        setGapsStale,
      }}
    >
      <div className="admin-show-editor">
        <header>
          <h1>{formatDate(show.date)}</h1>
          <VenueControl />
          {!importing && (
            <>
              <a
                className="admin-preview-link"
                href={`/${show.date}`}
                target="_blank"
                rel="noreferrer"
                title="Open this show on the public site"
                aria-label="Preview on the site"
              >
                <FontAwesomeIcon icon={faExternalLinkAlt} />
              </a>
              <button
                type="button"
                className="admin-trash-button"
                title="Delete this draft and all its tracks"
                aria-label="Delete draft"
                onClick={() => setConfirmingDelete(true)}
              >
                <FontAwesomeIcon icon={faTrashAlt} />
              </button>
            </>
          )}
          {importing && <span className="admin-badge">IMPORT</span>}
          {!importing && <PublishPanel />}
          {importing && !show.ingest_job_id && (
            <button
              type="button"
              className="admin-trash-button admin-header-delete"
              title="Delete this draft and its staged audio"
              aria-label="Delete draft"
              onClick={() => setConfirmingDelete(true)}
            >
              <FontAwesomeIcon icon={faTrashAlt} />
            </button>
          )}
        </header>
        {error && (
          <Modal title="Error">
            <p className="admin-error admin-modal-message">{error}</p>
            <div className="admin-modal-actions">
              <button type="button" onClick={() => setError(null)}>
                <FontAwesomeIcon icon={faCheck} /> OK
              </button>
            </div>
          </Modal>
        )}
        {confirmingDelete && (
          <Modal title={<>Delete the {formatDate(show.date)} draft?</>}>
            <p className="admin-empty">
              {deleteDraftMessage(show.tracks.length)}
            </p>
            <div className="admin-modal-actions">
              <button
                type="button"
                className="admin-danger"
                disabled={deleting}
                onClick={async () => {
                  setDeleting(true);
                  try {
                    await adminDelete(`/shows/${show.date}`);
                    navigate("/admin");
                  } catch (err) {
                    setError(err.message);
                    setDeleting(false);
                    setConfirmingDelete(false);
                  }
                }}
              >
                <FontAwesomeIcon icon={faCheck} /> Delete Draft
              </button>
              <button type="button" onClick={() => setConfirmingDelete(false)}>
                <FontAwesomeIcon icon={faXmark} /> Cancel
              </button>
            </div>
          </Modal>
        )}
        {show.ingest_job_id ? (
          <IngestProgress
            jobId={show.ingest_job_id}
            title={formatDate(show.date)}
            onDone={reload}
            onCancelled={() => navigate("/admin")}
            onError={setError}
          />
        ) : importing ? (
          <StagingEditor />
        ) : (
          <>
            <ShowPanel />
            <nav className="admin-tabs">
              {TABS.map((t) => (
                <button
                  key={t}
                  type="button"
                  className={t === tab ? "active" : ""}
                  onClick={() => setTab(t)}
                >
                  {t}
                </button>
              ))}
              <div className="admin-tab-actions" id="admin-tab-actions" />
            </nav>
            {tab === "Setlist" && <TracksTab />}
            {tab === "Art" && <ArtTab />}
            {tab === "Show" && <NotesTab />}
              </>
        )}
      </div>
    </EditorContext.Provider>
  );
};

export default AdminShowEditor;
