import React, { useState, useEffect } from "react";
import { useOutletContext } from "react-router";
import { authFetch, formatDate, formatDurationTrack } from "./helpers/utils";
import { useFeedback } from "./contexts/FeedbackContext";
import CoverArt from "./CoverArt";
import TagBadges from "./controls/TagBadges";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import {
  faPlay,
  faPlus,
  faCheck,
  faChevronDown,
  faChevronUp,
  faChevronRight,
  faLayerGroup
} from "@fortawesome/free-solid-svg-icons";

const MAX_TRACKS = 250;
const RECENT_KEY = "playlistBuilderRecentShows";
const COLLAPSED_KEY = "playlistBuilderCollapsed";

const readLocal = (key, fallback) => {
  try {
    const raw = localStorage.getItem(key);
    return raw === null ? fallback : JSON.parse(raw);
  } catch {
    return fallback;
  }
};

const writeLocal = (key, value) => {
  try {
    localStorage.setItem(key, JSON.stringify(value));
  } catch {
    // Ignore
  }
};

const PlaylistBuilder = () => {
  const {
    draftPlaylist,
    setDraftPlaylist,
    draftPlaylistMeta,
    setIsDraftPlaylistSaved,
    playTrack,
    setCustomPlaylist,
    activeTrack
  } = useOutletContext();
  const { setNotice, setAlert } = useFeedback();

  const [collapsed, setCollapsed] = useState(() =>
    readLocal(COLLAPSED_KEY, draftPlaylist.length > 0 && !!draftPlaylistMeta.id)
  );
  const [years, setYears] = useState(null);
  const [period, setPeriod] = useState(null);
  const [shows, setShows] = useState(null);
  const [show, setShow] = useState(null);
  const [loading, setLoading] = useState(false);
  const [dateInput, setDateInput] = useState("");
  const [recentShows, setRecentShows] = useState(() => readLocal(RECENT_KEY, []));

  useEffect(() => {
    writeLocal(COLLAPSED_KEY, collapsed);
  }, [collapsed]);

  useEffect(() => {
    if (collapsed || years) return;
    setLoading(true);
    authFetch("/api/v2/years")
      .then((response) => (response.ok ? response.json() : []))
      .then((data) => setYears(data))
      .catch(() => setAlert("Error loading years"))
      .finally(() => setLoading(false));
  }, [collapsed, years]);

  const loadShows = async (selectedPeriod) => {
    setPeriod(selectedPeriod);
    setShow(null);
    setShows(null);
    setLoading(true);
    const filter = selectedPeriod.includes("-") ? `year_range=${selectedPeriod}` : `year=${selectedPeriod}`;
    try {
      const response = await authFetch(`/api/v2/shows?${filter}&sort=date:asc&per_page=1000`);
      if (!response.ok) throw response;
      const data = await response.json();
      setShows(data.shows);
    } catch {
      setAlert("Error loading shows");
    } finally {
      setLoading(false);
    }
  };

  const loadShow = async (date) => {
    setLoading(true);
    try {
      const response = await authFetch(`/api/v2/shows/${date}`);
      if (!response.ok) throw response;
      const data = await response.json();
      setShow(data);
      setPeriod((current) => current ?? String(new Date(date).getUTCFullYear()));
    } catch {
      setAlert(`No show found for ${date}`);
    } finally {
      setLoading(false);
    }
  };

  const handleDateInput = (e) => {
    const value = e.target.value;
    setDateInput(value);
    if (/^\d{4}-\d{2}-\d{2}$/.test(value)) loadShow(value);
  };

  const rememberShow = (currentShow) => {
    const entry = {
      date: currentShow.date,
      venue_name: currentShow.venue_name,
      cover_art_urls: currentShow.cover_art_urls
    };
    const next = [entry, ...recentShows.filter((s) => s.date !== entry.date)].slice(0, 5);
    setRecentShows(next);
    writeLocal(RECENT_KEY, next);
  };

  const isInDraft = (track) => draftPlaylist.some((t) => t.id === track.id);

  const addTracks = (tracks) => {
    const additions = tracks.filter((track) => track.audio_status !== "missing" && !isInDraft(track));
    if (additions.length === 0) return;
    if (draftPlaylist.length + additions.length > MAX_TRACKS) {
      setAlert(`Playlists can't have more than ${MAX_TRACKS} tracks`);
      return;
    }
    setDraftPlaylist([...draftPlaylist, ...additions]);
    setIsDraftPlaylistSaved(false);
    rememberShow(show);
    setNotice(additions.length === 1 ? "Track added to draft playlist" : `${additions.length} tracks added to draft playlist`);
  };

  const removeTrack = (track) => {
    const idx = draftPlaylist.findIndex((t) => t.id === track.id);
    if (idx < 0) return;
    const updated = [...draftPlaylist];
    updated.splice(idx, 1);
    setDraftPlaylist(updated);
    setIsDraftPlaylistSaved(false);
    setNotice("Track removed from draft playlist");
  };

  const tracksWithAudio = show?.tracks?.filter((t) => t.audio_status !== "missing") ?? [];
  const allAdded = tracksWithAudio.length > 0 && tracksWithAudio.every(isInDraft);

  const previewTrack = (track) => {
    setCustomPlaylist(null);
    playTrack(tracksWithAudio, track);
  };

  const renderBreadcrumb = () => (
    <nav className="builder-breadcrumb">
      <a onClick={() => { setPeriod(null); setShows(null); setShow(null); }}>All years</a>
      {period && (
        <>
          <FontAwesomeIcon icon={faChevronRight} className="mx-1" />
          <a onClick={() => { setShow(null); if (!shows) loadShows(period); }}>{period}</a>
        </>
      )}
      {show && (
        <>
          <FontAwesomeIcon icon={faChevronRight} className="mx-1" />
          <span>{formatDate(show.date)}</span>
        </>
      )}
    </nav>
  );

  const renderYears = () => (
    <div className="builder-years">
      {(years ?? []).map((year) => (
        <button key={year.period} className="button builder-year" onClick={() => loadShows(year.period)}>
          {year.period}
          <span className="builder-count">{year.shows_with_audio_count ?? year.shows_count}</span>
        </button>
      ))}
    </div>
  );

  const renderShows = () => (
    <ul className="builder-shows">
      {(shows ?? []).map((s) => {
        const missing = s.audio_status === "missing";
        return (
          <li
            key={s.date}
            className={`builder-show-row ${missing ? "no-audio" : ""}`}
            onClick={() => !missing && loadShow(s.date)}
          >
            <CoverArt coverArtUrls={s.cover_art_urls} css="cover-art-small" />
            <span className="builder-show-date">{formatDate(s.date)}</span>
            <span className="builder-show-venue">{s.venue_name}</span>
            <span className="builder-show-location">{s.venue?.location}</span>
          </li>
        );
      })}
    </ul>
  );

  const renderTracks = () => (
    <div className="builder-tracks">
      <div className="builder-show-header">
        <CoverArt coverArtUrls={show.cover_art_urls} css="cover-art-small" />
        <div>
          <div className="builder-show-date">{formatDate(show.date)}</div>
          <div className="builder-show-venue">{show.venue_name}, {show.venue?.location}</div>
        </div>
        <button className="button is-small builder-add-all" onClick={() => addTracks(show.tracks)} disabled={allAdded}>
          <FontAwesomeIcon icon={faLayerGroup} className="mr-1" />
          {allAdded ? "All added" : "Add all"}
        </button>
      </div>
      <ul>
        {show.tracks.map((track) => {
          const missing = track.audio_status === "missing";
          const added = isInDraft(track);
          const isActive = track.id === activeTrack?.id;
          return (
            <li key={track.id} className={`builder-track-row ${missing ? "no-audio" : ""} ${isActive ? "active-item" : ""}`}>
              <span className="builder-track-set">{track.set_name}</span>
              <span className="builder-track-title">{track.title}</span>
              <span className="builder-track-tags"><TagBadges tags={track.tags} parentId={`builder-${track.id}`} /></span>
              <span className="builder-track-duration">{formatDurationTrack(track.duration)}</span>
              <span className="builder-track-actions">
                <button className="button is-small" onClick={() => previewTrack(track)} disabled={missing} title="Preview">
                  <FontAwesomeIcon icon={faPlay} />
                </button>
                {added ? (
                  <button className="button is-small is-added" onClick={() => removeTrack(track)} title="Remove from draft">
                    <FontAwesomeIcon icon={faCheck} className="mr-1" />
                    Added
                  </button>
                ) : (
                  <button className="button is-small" onClick={() => addTracks([track])} disabled={missing}>
                    <FontAwesomeIcon icon={faPlus} className="mr-1" />
                    Add
                  </button>
                )}
              </span>
            </li>
          );
        })}
      </ul>
    </div>
  );

  const renderBody = () => {
    if (show) return renderTracks();
    if (period && shows) return renderShows();
    return renderYears();
  };

  return (
    <div className={`playlist-builder ${collapsed ? "is-collapsed" : ""}`}>
      <div className="builder-header" onClick={() => setCollapsed((c) => !c)}>
        <span className="builder-title">
          <FontAwesomeIcon icon={faPlus} className="mr-2" />
          Add Tracks
        </span>
        <FontAwesomeIcon icon={collapsed ? faChevronDown : faChevronUp} />
      </div>

      {!collapsed && (
        <div className="builder-body">
          <div className="builder-toolbar">
            {renderBreadcrumb()}
            <input
              id="builder-date"
              className="input is-small builder-date-input"
              type="date"
              value={dateInput}
              onChange={handleDateInput}
              min="1983-01-01"
              title="Jump to a show by date"
            />
          </div>

          {recentShows.length > 0 && !show && (
            <div className="builder-recent">
              <span className="builder-recent-label">Recent:</span>
              {recentShows.map((s) => (
                <button key={s.date} className="button is-small" onClick={() => loadShow(s.date)}>
                  {formatDate(s.date)}
                </button>
              ))}
            </div>
          )}

          {loading ? <p className="builder-loading">Loading...</p> : renderBody()}
        </div>
      )}
    </div>
  );
};

export default PlaylistBuilder;
