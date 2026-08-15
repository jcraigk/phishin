import React, { createContext, useCallback, useEffect, useState } from "react";
import { useParams } from "react-router";
import { adminGet } from "./adminApi";
import TracksTab from "./TracksTab";
import AudioTab from "./AudioTab";
import ArtTab from "./ArtTab";
import TagsTab from "./TagsTab";
import ShowPanel from "./ShowPanel";

export const EditorContext = createContext(null);

const TABS = ["Tracks", "Audio", "Art", "Tags"];

const AdminShowEditor = () => {
  const { date } = useParams();
  const [show, setShow] = useState(null);
  const [tab, setTab] = useState("Tracks");
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
            {show.date} {show.venue_name}
            {!show.published && <span className="admin-badge">DRAFT</span>}
          </h1>
        </header>
        {error && <p className="admin-error">{error}</p>}
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
        </nav>
        {tab === "Tracks" && <TracksTab />}
        {tab === "Audio" && <AudioTab />}
        {tab === "Art" && <ArtTab />}
        {tab === "Tags" && <TagsTab />}
      </div>
    </EditorContext.Provider>
  );
};

export default AdminShowEditor;
