import React, { useRef, useState, useEffect } from "react";
import { useOutletContext, Link } from "react-router-dom";
import { useFeedback } from "./FeedbackContext";
import { useAudioFilter } from "../contexts/AudioFilterContext";
import DraftPlaylistTrackModal from "../modals/DraftPlaylistTrackModal";
import LikeButton from "./LikeButton";
import TagBadges from "./TagBadges";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faEllipsis, faShareFromSquare, faCirclePlus, faDownload, faMusic, faCircleChevronLeft, faCircleChevronRight, faTrashAlt, faClock } from "@fortawesome/free-solid-svg-icons";

const TrackContextMenu = ({ track, indexInPlaylist = null, highlight }) => {
  const dropdownRef = useRef(null);
  const { setNotice, setAlert } = useFeedback();
  const { showMissingAudio } = useAudioFilter();
  const [dropdownVisible, setDropdownVisible] = useState(false);
  const [isEditModalOpen, setIsEditModalOpen] = useState(false);
  const { user, draftPlaylist, setDraftPlaylist, setIsDraftPlaylistSaved } = useOutletContext();

  const hideDropdown = () => {
    setDropdownVisible(false);
  };

  const copyToClipboard = (e) => {
    e.stopPropagation();
    let url = `https://phish.in/${track.show_date}/${track.slug}`;
    navigator.clipboard.writeText(url);
    setNotice("URL copied to clipboard");
    hideDropdown();
  };

  const toggleDropdownVisibility = (e) => {
    e.stopPropagation();
    setDropdownVisible(!dropdownVisible);
  };

  const handleAddToPlaylist = (e) => {
    e.stopPropagation();
    if (user === "anonymous") {
      setAlert("You must login to edit playlists");
      return;
    }
    setDraftPlaylist([...draftPlaylist, track]);
    setNotice("Track added to draft playlist");
    hideDropdown();
    setIsDraftPlaylistSaved(false);
  };

  const handleRemoveFromPlaylist = (e) => {
    e.stopPropagation();
    const updatedPlaylist = [...draftPlaylist];
    updatedPlaylist.splice(indexInPlaylist, 1);
    setDraftPlaylist(updatedPlaylist);
    setNotice("Track removed from draft playlist");
    hideDropdown();
    setIsDraftPlaylistSaved(false);
  };

  const handleDownload = (e, trackId) => {
    e.stopPropagation();
    const link = document.createElement("a");
    link.href = `/download-track/${trackId}`;
    link.setAttribute("download", true);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  const handlePlaylistEntry = (e) => {
    e.stopPropagation();
    setIsEditModalOpen(true);
    hideDropdown();
  };

  // Close dropdown when clicking outside
  useEffect(() => {
    const handleClickOutside = (event) => {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target)) {
        hideDropdown();
      }
    };

    document.addEventListener("mousedown", handleClickOutside);
    return () => {
      document.removeEventListener("mousedown", handleClickOutside);
    };
  }, [dropdownRef]);

  return (
    <>
      <div className="dropdown is-right context-dropdown" ref={dropdownRef}>
        <div className="dropdown-trigger">
          <button className="button" onClick={toggleDropdownVisibility}>
            <FontAwesomeIcon icon={faEllipsis} className="icon" />
          </button>
        </div>
        <div
          className="dropdown-menu"
          id="dropdown-menu"
          role="menu"
          style={{ display: dropdownVisible ? "block" : "none" }}
        >
          <div className="dropdown-content context-dropdown-content">
            <div className="dropdown-item display-mobile-only">
              <LikeButton likable={track} type="Track" />
            </div>

            {track.tags?.length > 0 && (
              <div className="dropdown-item display-mobile-only">
                <TagBadges tags={track.tags} parentId={track.id} highlight={highlight} />
              </div>
            )}

            <a className="dropdown-item" onClick={(e) => copyToClipboard(e)}>
              <FontAwesomeIcon icon={faShareFromSquare} className="icon" />
              Share
            </a>

            {track.audio_status !== 'missing' && (
              <a
                className="dropdown-item"
                onClick={(e) => {
                  e.stopPropagation();
                  handleDownload(e, track.id);
                }}
              >
                <FontAwesomeIcon icon={faDownload} className="icon" />
                Download MP3
              </a>
            )}

            {track.songs?.sort((a, b) => a.title.localeCompare(b.title)).map((song) => (
              <div key={`${track.id}-${song.slug}`}>
                <hr className="dropdown-divider" />

                <Link
                  className="dropdown-item"
                  to={`/songs/${song.slug}`}
                  key={`${track.id}-${song.id}-link`}
                  onClick={(e) => e.stopPropagation()}
                >
                  <FontAwesomeIcon icon={faMusic} className="icon" />
                  Song: {song.title}
                </Link>

                {(showMissingAudio ? song.previous_performance_slug : song.previous_performance_with_audio_slug) && (
                  <Link
                    className="dropdown-item"
                    to={`/${showMissingAudio ? song.previous_performance_slug : song.previous_performance_with_audio_slug}`}
                    key={`${track.id}-${song.id}-previous-performance`}
                    onClick={(e) => e.stopPropagation()}
                  >
                    <FontAwesomeIcon icon={faCircleChevronLeft} className="icon" />
                    Previous Performance{(() => {
                      const gap = showMissingAudio ? song.previous_performance_gap : song.previous_performance_with_audio_gap;
                      return gap != null && gap > 0 ? ` (gap: ${gap})` : '';
                    })()}
                  </Link>
                )}

                {(showMissingAudio ? song.next_performance_slug : song.next_performance_with_audio_slug) && (
                  <Link
                    className="dropdown-item"
                    to={`/${showMissingAudio ? song.next_performance_slug : song.next_performance_with_audio_slug}`}
                    key={`${track.id}-${song.id}-next-performance`}
                    onClick={(e) => e.stopPropagation()}
                  >
                    <FontAwesomeIcon icon={faCircleChevronRight} className="icon" />
                    Next Performance{(() => {
                      const gap = showMissingAudio ? song.next_performance_gap : song.next_performance_with_audio_gap;
                      return gap != null && gap > 0 ? ` (gap: ${gap})` : '';
                    })()}
                  </Link>
                )}
              </div>
            ))}

            {track.audio_status !== 'missing' && (
              <>
                <hr className="dropdown-divider" />

                <a className="dropdown-item" onClick={handleAddToPlaylist}>
                  <FontAwesomeIcon icon={faCirclePlus} className="icon" />
                  Add to Draft Playlist
                </a>

                {draftPlaylist.includes(track) && (
                  <a className="dropdown-item" onClick={handleRemoveFromPlaylist}>
                    <FontAwesomeIcon icon={faTrashAlt} className="icon" />
                    Remove from Draft Playlist
                  </a>
                )}

                {draftPlaylist.includes(track) && (
                  <a className="dropdown-item" onClick={handlePlaylistEntry}>
                    <FontAwesomeIcon icon={faClock} className="icon" />
                    Edit Draft Playlist Entry
                  </a>
                )}
              </>
            )}
          </div>
        </div>
      </div>

      {draftPlaylist.includes(track) && (
        <DraftPlaylistTrackModal
          isOpen={isEditModalOpen}
          onRequestClose={() => setIsEditModalOpen(false)}
          track={track}
          indexInPlaylist={indexInPlaylist}
          draftPlaylist={draftPlaylist}
          setDraftPlaylist={setDraftPlaylist}
        />
      )}
    </>
  );
};

export default TrackContextMenu;
