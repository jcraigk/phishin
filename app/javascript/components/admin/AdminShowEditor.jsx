import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faExternalLinkAlt, faTrashAlt, faCheck, faXmark } from "@fortawesome/free-solid-svg-icons";
import { formatDate } from "../helpers/utils";
import React, { createContext, useCallback, useEffect, useState } from "react";
import { useNavigate, useParams } from "react-router";
import { adminGet, adminDelete } from "./adminApi";
import TracksTab from "./TracksTab";
import ArtTab from "./ArtTab";
import TagsTab from "./TagsTab";
import NotesTab from "./NotesTab";
import ShowPanel from "./ShowPanel";
import VenueControl from "./VenueControl";
import PublishPanel from "./PublishPanel";
import StagingEditor from "./StagingEditor";

export const EditorContext = createContext(null);

const TABS = ["Setlist", "Tags", "Notes", "Art"];

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

  const tabCounts = show
    ? {
        Setlist: show.tracks.length,
        Tags:
          show.show_tags.length +
          show.tracks.reduce((sum, t) => sum + t.track_tags.length, 0),
      }
    : {};

  if (!show) {
    return (
      <div className="admin-show-editor">
        {error ? <p className="admin-error">{error}</p> : <p>Loading...</p>}
      </div>
    );
  }

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
          <h1>
            {formatDate(show.date)}
            {!show.published && <span className="admin-badge">DRAFT</span>}
          </h1>
          <VenueControl />
          <a
            className="admin-preview-link"
            href={`/${show.date}`}
            target="_blank"
            rel="noreferrer"
            title="Preview on the site"
            aria-label="Preview on the site"
          >
            <FontAwesomeIcon icon={faExternalLinkAlt} />
          </a>
          <button
            type="button"
            className="admin-trash-button"
            title="Delete show"
            aria-label="Delete show"
            onClick={() => setConfirmingDelete(true)}
          >
            <FontAwesomeIcon icon={faTrashAlt} />
          </button>
        </header>
        {error && (
          <div className="admin-modal-overlay">
            <div className="admin-modal" onClick={(e) => e.stopPropagation()}>
              <h3>Error</h3>
              <p className="admin-error admin-modal-message">{error}</p>
              <div className="admin-modal-actions">
                <button type="button" onClick={() => setError(null)}>
                  <FontAwesomeIcon icon={faCheck} /> OK
                </button>
              </div>
            </div>
          </div>
        )}
        {confirmingDelete && (
          <div className="admin-modal-overlay">
            <div className="admin-modal" onClick={(e) => e.stopPropagation()}>
              <h3>Delete {show.date}?</h3>
              <p className="admin-empty">
                The show, its {show.tracks.length} tracks, audio, tags and likes are
                removed permanently.
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
                  <FontAwesomeIcon icon={faCheck} /> Delete Show
                </button>
                <button type="button" onClick={() => setConfirmingDelete(false)}>
                  <FontAwesomeIcon icon={faXmark} /> Cancel
                </button>
              </div>
            </div>
          </div>
        )}
        {show.staging && show.tracks.length === 0 ? (
          <StagingEditor />
        ) : (
          <>
            <ShowPanel />
            <PublishPanel />
            <nav className="admin-tabs">
              {TABS.map((t) => {
                const count = tabCounts[t];
                return (
                  <button
                    key={t}
                    type="button"
                    className={t === tab ? "active" : ""}
                    onClick={() => setTab(t)}
                  >
                    {t}
                    {count > 0 && <span className="admin-count">{count}</span>}
                  </button>
                );
              })}
              <div className="admin-tab-actions" id="admin-tab-actions" />
            </nav>
            {tab === "Setlist" && <TracksTab />}
            {tab === "Art" && <ArtTab />}
            {tab === "Tags" && <TagsTab />}
            {tab === "Notes" && <NotesTab />}
              </>
        )}
      </div>
    </EditorContext.Provider>
  );
};

export default AdminShowEditor;
