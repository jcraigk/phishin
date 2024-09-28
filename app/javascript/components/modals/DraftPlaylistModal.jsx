import React, { useState, useEffect } from "react";
import Modal from "react-modal";
import { authFetch } from "../utils";
import { useFeedback } from "../FeedbackContext";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faCircleXmark, faCircleCheck, faCloudArrowUp, faTrash } from "@fortawesome/free-solid-svg-icons";

const DraftPlaylistModal = ({ isOpen, onRequestClose, draftPlaylist, setDraftPlaylist, draftPlaylistMeta, setDraftPlaylistMeta, resetDraftPlaylist, handleInputFocus, handleInputBlur }) => {
  const [name, setName] = useState("");
  const [slug, setSlug] = useState("");
  const [description, setDescription] = useState("");
  const [published, setPublished] = useState(false);
  const [charCount, setCharCount] = useState(0);
  const [isDescriptionModified, setIsDescriptionModified] = useState(false);
  const { setAlert, setNotice } = useFeedback();

  useEffect(() => {
    setName(draftPlaylistMeta.name);
    setSlug(draftPlaylistMeta.slug);
    setDescription(draftPlaylistMeta.description);
    setPublished(draftPlaylistMeta.published);
  }, [draftPlaylistMeta]);

  const handleNameChange = (e) => {
    const updatedName = e.target.value;
    setName(updatedName); // Update local state
    setDraftPlaylistMeta((prev) => ({
      ...prev,
      name: updatedName,
    }));
    autoGenerateSlug(updatedName);
  };

  const handleSlugChange = (e) => {
    const updatedSlug = e.target.value.toLowerCase().replace(/[^a-z0-9-]/g, "");
    setSlug(updatedSlug); // Update local state
    setDraftPlaylistMeta((prev) => ({
      ...prev,
      slug: updatedSlug,
    }));
  };

  const handleDescriptionChange = (e) => {
    const updatedDescription = e.target.value.slice(0, 500); // Limit to 500 characters
    setDescription(updatedDescription); // Update local state
    setDraftPlaylistMeta((prev) => ({
      ...prev,
      description: updatedDescription,
    }));
    setCharCount(updatedDescription.length);
    setIsDescriptionModified(true);
  };

  const handlePublishedChange = (e) => {
    const updatedPublished = e.target.checked;
    setPublished(updatedPublished); // Update local state
    setDraftPlaylistMeta((prev) => ({
      ...prev,
      published: updatedPublished,
    }));
  };

  const autoGenerateSlug = (value) => {
    const generatedSlug = value
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, "-")
      .replace(/^-+|-+$/g, "");
    setSlug(generatedSlug); // Update local state
    setDraftPlaylistMeta((prev) => ({
      ...prev,
      slug: generatedSlug,
    }));
  };

  const handleSavePlaylist = async () => {
    if (draftPlaylist.length < 2) {
      setAlert("Add at least 2 tracks to save the playlist");
      return;
    }

    const url = draftPlaylistMeta.id
      ? `/api/v2/playlists/${draftPlaylistMeta.id}`
      : "/api/v2/playlists";
    const method = draftPlaylistMeta.id ? "PUT" : "POST";

    try {
      const body = JSON.stringify({
        ...draftPlaylistMeta,
        track_ids: draftPlaylist.map((track) => track.id),
        starts_at_seconds: draftPlaylist.map((track) => track.starts_at_second ?? 0),
        ends_at_seconds: draftPlaylist.map((track) => track.ends_at_second ?? 0),
      });
      const response = await authFetch(url, {
        method,
        body,
      });
      if (!response.ok) throw response;
      const updatedPlaylist = await response.json();
      setDraftPlaylistMeta((prev) => ({
        ...prev,
        id: updatedPlaylist.id
      }));
      setNotice("Playlist saved successfully");
    } catch (error) {
      if (error.status === 422) {
        const errorData = await error.json();
        setAlert(`Error saving playlist: ${errorData.message}`);
      } else {
        setAlert("Error saving playlist");
      }
    }

    onRequestClose();
  };

  const handleClearPlaylist = () => {
    if (window.confirm("Are you sure you want to reset the draft playlist? Any changes you have made will be lost.")) {
      resetDraftPlaylist();
    }
    onRequestClose();
  };

  const handleDeletePlaylist = async () => {
    if (window.confirm("Are you sure you want to delete this playlist? This action cannot be undone.")) {
      try {
        const response = await authFetch(`/api/v2/playlists/${draftPlaylistMeta.id}`, {
          method: "DELETE",
        });
        if (!response.ok) throw response;
        setNotice("Playlist deleted successfully");
        resetDraftPlaylist();
        onRequestClose();
      } catch (error) {
        setAlert("Error deleting playlist");
      }
    }
  };

  return (
    <Modal
      isOpen={isOpen}
      onRequestClose={onRequestClose}
      className="modal-content"
      overlayClassName="modal-overlay"
      onClick={(e) => e.stopPropagation()}
    >
      <FontAwesomeIcon
        icon={faCircleXmark}
        onClick={onRequestClose}
        className="is-pulled-right close-btn is-size-3"
        style={{ cursor: "pointer" }}
      />
      <h2 className="title">Edit Playlist Details</h2>

      <div className="field">
        <label className="label">Name</label>
        <div className="control">
          <input
            className="input"
            type="text"
            value={name}
            onChange={handleNameChange}
            onFocus={handleInputFocus}
            onBlur={handleInputBlur}
            placeholder="(Untitled Playlist)"
          />
        </div>
      </div>

      <div className="field">
        <label className="label">Slug</label>
        <div className="control">
          <input
            className="input"
            type="text"
            value={slug}
            onChange={handleSlugChange}
            placeholder="lowercase-letters-numbers"
            onFocus={handleInputFocus}
            onBlur={handleInputBlur}
            autoCapitalize="off"
          />
        </div>
      </div>

      <div className="field">
        <label className="label">Description</label>
        <div className="control">
          <textarea
            className="textarea"
            value={description || ""}
            onChange={handleDescriptionChange}
            onFocus={handleInputFocus}
            onBlur={handleInputBlur}
            placeholder="Add a description"
          ></textarea>
          {isDescriptionModified && (
            <p className="help is-size-7 has-text-right">
              {500 - charCount} characters remaining
            </p>
          )}
        </div>
      </div>

      <div className="field">
        <div className="control">
          <label className="checkbox">
            <input
              type="checkbox"
              checked={published}
              onChange={handlePublishedChange}
            />
            {" "}Publish for browse & search
          </label>
        </div>
      </div>

      <button
        className="button"
        onClick={onRequestClose}
      >
        <span className="icon mr-1">
          <FontAwesomeIcon icon={faCircleCheck} />
        </span>
        Done Editing
      </button>

      <button
        className="button ml-2"
        onClick={handleSavePlaylist}
      >
        <span className="icon mr-1">
          <FontAwesomeIcon icon={faCloudArrowUp} />
        </span>
        Save
      </button>

      <button
        className="button ml-2"
        onClick={handleClearPlaylist}
      >
        <span className="icon mr-1">
          <FontAwesomeIcon icon={faTrash} />
        </span>
        Clear
      </button>

      {draftPlaylistMeta.id && (
        <button
          className="button ml-2"
          onClick={handleDeletePlaylist}
        >
          <span className="icon mr-1">
            <FontAwesomeIcon icon={faTrash} />
          </span>
          Delete
        </button>
      )}
    </Modal>
  );
};

export default DraftPlaylistModal;
