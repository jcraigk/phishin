import React, { useState } from "react";
import { useNavigate, useOutletContext } from "react-router";
import { authFetch, formatDurationShow } from "./helpers/utils";
import { useFeedback } from "./contexts/FeedbackContext";
import CoverArt from "./CoverArt";
import CoverArtPicker from "./CoverArtPicker";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import {
  faCloudArrowUp,
  faShareFromSquare,
  faFileImport,
  faTrash,
  faCircleCheck,
  faExclamationCircle,
  faGlobe,
  faLock,
  faPencil,
  faClock,
  faCompactDisc
} from "@fortawesome/free-solid-svg-icons";

export const draftDuration = (tracks) =>
  tracks.reduce((total, track) => {
    const startSecond = parseInt(track.starts_at_second) || 0;
    const endSecond = parseInt(track.ends_at_second) || 0;
    if (startSecond > 0 && endSecond > 0) return total + (endSecond - startSecond) * 1000;
    if (startSecond > 0) return total + track.duration - startSecond * 1000;
    if (endSecond > 0) return total + endSecond * 1000;
    return total + track.duration;
  }, 0);

const slugify = (value) =>
  value.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");

const DraftPlaylistDetails = () => {
  const {
    activePlaylist,
    setDraftPlaylist,
    draftPlaylist,
    draftPlaylistMeta,
    setDraftPlaylistMeta,
    isDraftPlaylistSaved,
    setIsDraftPlaylistSaved,
    resetDraftPlaylist
  } = useOutletContext();
  const { setNotice, setAlert } = useFeedback();
  const navigate = useNavigate();
  const [slugEditable, setSlugEditable] = useState(false);
  const [pickerOpen, setPickerOpen] = useState(false);

  const { id, name, slug, description, published, cover_art_track_id } = draftPlaylistMeta;

  const coverArtTrack =
    draftPlaylist.find((track) => track.id === cover_art_track_id) ?? draftPlaylist[0];
  const coverArtTrackIdInDraft = coverArtTrack?.id === cover_art_track_id ? cover_art_track_id : undefined;

  const updateMeta = (changes) => {
    setDraftPlaylistMeta((prev) => ({ ...prev, ...changes }));
    setIsDraftPlaylistSaved(false);
  };

  const handleNameChange = (e) => {
    const value = e.target.value;
    updateMeta(id || slugEditable ? { name: value } : { name: value, slug: slugify(value) });
  };

  const handleSlugChange = (e) => {
    updateMeta({ slug: e.target.value.toLowerCase().replace(/[^a-z0-9-]/g, "") });
  };

  const handleDescriptionChange = (e) => {
    updateMeta({ description: e.target.value.slice(0, 500) });
  };

  const handleSave = async () => {
    if (draftPlaylist.length < 2) {
      setAlert("Add at least 2 tracks and try again");
      return;
    }

    const url = id ? `/api/v2/playlists/${id}` : "/api/v2/playlists";
    const method = id ? "PUT" : "POST";

    try {
      const response = await authFetch(url, {
        method,
        body: JSON.stringify({
          ...draftPlaylistMeta,
          cover_art_track_id: coverArtTrackIdInDraft,
          track_ids: draftPlaylist.map((track) => track.id),
          starts_at_second: draftPlaylist.map((track) => track.starts_at_second ?? 0),
          ends_at_second: draftPlaylist.map((track) => track.ends_at_second ?? 0)
        })
      });
      if (!response.ok) throw response;
      const saved = await response.json();
      setDraftPlaylistMeta((prev) => ({ ...prev, id: saved.id, cover_art_track_id: saved.cover_art_track_id }));
      setIsDraftPlaylistSaved(true);
      setNotice("Playlist saved successfully");
    } catch (error) {
      if (error.status === 422) {
        const data = await error.json();
        setAlert(`Error saving playlist: ${data.message}`);
      } else {
        setAlert("Error saving playlist");
      }
    }
  };

  const handleShare = () => {
    navigator.clipboard.writeText(`https://phish.in/play/${slug}`);
    setNotice("Playlist URL copied to clipboard");
  };

  const handleClear = () => {
    if (window.confirm("Reset the draft playlist? Any unsaved changes will be lost.")) {
      resetDraftPlaylist();
    }
  };

  const handleDelete = async () => {
    if (!window.confirm("Delete this playlist? This cannot be undone.")) return;
    try {
      const response = await authFetch(`/api/v2/playlists/${id}`, { method: "DELETE" });
      if (!response.ok) throw response;
      setNotice("Playlist deleted successfully");
      resetDraftPlaylist();
      navigate("/playlists?filter=mine");
    } catch {
      setAlert("Error deleting playlist");
    }
  };

  const handleImportActive = () => {
    setDraftPlaylist(activePlaylist);
    setIsDraftPlaylistSaved(false);
  };

  return (
    <div className="draft-details">
      {coverArtTrack && (
        <div className="draft-cover-art">
          <div onClick={() => setPickerOpen((open) => !open)} title="Choose cover art">
            <CoverArt coverArtUrls={coverArtTrack.show_cover_art_urls} size="medium" />
          </div>
          {pickerOpen && (
            <CoverArtPicker
              tracks={draftPlaylist}
              selectedTrackId={cover_art_track_id}
              onSelect={(track) => {
                updateMeta({ cover_art_track_id: track.id });
                setPickerOpen(false);
              }}
            />
          )}
        </div>
      )}

      <input
        id="playlist-name"
        className="input draft-name-input"
        type="text"
        value={name || ""}
        onChange={handleNameChange}
        placeholder="Playlist name"
      />

      <div className="draft-slug">
        {slugEditable ? (
          <input
            id="playlist-slug"
            className="input is-small"
            type="text"
            value={slug || ""}
            onChange={handleSlugChange}
            onBlur={() => setSlugEditable(false)}
            autoCapitalize="off"
            autoFocus
          />
        ) : (
          <span onClick={() => setSlugEditable(true)} title="Edit slug">
            /play/{slug || "..."}
            <FontAwesomeIcon icon={faPencil} className="ml-1" />
          </span>
        )}
      </div>

      <textarea
        id="playlist-description"
        className="textarea draft-description"
        value={description || ""}
        onChange={handleDescriptionChange}
        placeholder="Description (optional)"
        rows={3}
      />

      <div className="buttons has-addons draft-visibility">
        <button
          className={`button is-small ${published ? "is-selected" : ""}`}
          onClick={() => updateMeta({ published: true })}
        >
          <FontAwesomeIcon icon={faGlobe} className="mr-1" />
          Public
        </button>
        <button
          className={`button is-small ${!published ? "is-selected" : ""}`}
          onClick={() => updateMeta({ published: false })}
        >
          <FontAwesomeIcon icon={faLock} className="mr-1" />
          Private
        </button>
      </div>

      <div className="draft-stats">
        <span>
          <FontAwesomeIcon icon={faCompactDisc} className="mr-1 text-gray" />
          {draftPlaylist.length} tracks
        </span>
        <span>
          <FontAwesomeIcon icon={faClock} className="mr-1 text-gray" />
          {formatDurationShow(draftDuration(draftPlaylist))}
        </span>
        {(draftPlaylist.length > 0 || name) && (
          isDraftPlaylistSaved ? (
            <span className="badge-saved">
              <FontAwesomeIcon icon={faCircleCheck} className="mr-1" />
              Saved
            </span>
          ) : (
            <span className="badge-unsaved">
              <FontAwesomeIcon icon={faExclamationCircle} className="mr-1" />
              Unsaved
            </span>
          )
        )}
      </div>

      <div className="draft-actions">
        <button
          className="button"
          onClick={handleSave}
          disabled={draftPlaylist.length < 2}
          title={draftPlaylist.length < 2 ? "Add at least 2 tracks to save" : ""}
        >
          <FontAwesomeIcon icon={faCloudArrowUp} className="mr-1" />
          Save
        </button>
        {id && (
          <button className="button" onClick={handleShare}>
            <FontAwesomeIcon icon={faShareFromSquare} className="mr-1" />
            Share
          </button>
        )}
        {activePlaylist.length > 0 && (
          <button className="button" onClick={handleImportActive}>
            <FontAwesomeIcon icon={faFileImport} className="mr-1" />
            Import Active Playlist
          </button>
        )}
        <button className="button" onClick={handleClear}>
          <FontAwesomeIcon icon={faTrash} className="mr-1" />
          Clear
        </button>
        {id && (
          <button className="button" onClick={handleDelete}>
            <FontAwesomeIcon icon={faTrash} className="mr-1" />
            Delete
          </button>
        )}
      </div>
      {draftPlaylist.length < 2 && (
        <p className="draft-hint">Playlists need at least 2 tracks before they can be saved.</p>
      )}
    </div>
  );
};

export default DraftPlaylistDetails;
