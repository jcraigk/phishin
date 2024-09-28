import React, { useState, useEffect } from "react";
import Modal from "react-modal";
import { authFetch } from "./utils";
import { useFeedback } from "./FeedbackContext";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faCircleXmark, faCircleCheck, faCloudArrowUp, faTrash } from "@fortawesome/free-solid-svg-icons";

const DraftPlaylistModal = ({ isOpen, onRequestClose, draftPlaylist, setDraftPlaylist, draftPlaylistMeta, setDraftPlaylistMeta, handleInputFocus, handleInputBlur }) => {
  const [name, setName] = useState(draftPlaylistMeta.name);
  const [slug, setSlug] = useState(draftPlaylistMeta.slug);
  const [description, setDescription] = useState(draftPlaylistMeta.description);
  const [published, setPublished] = useState(draftPlaylistMeta.published);
  const { setAlert } = useFeedback();

  useEffect(() => {
    setName(draftPlaylistMeta.name);
    setSlug(draftPlaylistMeta.slug);
    setDescription(draftPlaylistMeta.description);
    setPublished(draftPlaylistMeta.published);
  }, [draftPlaylistMeta]);

  const handleNameChange = (e) => {
    const updatedName = e.target.value;
    setName(updatedName);
    autoGenerateSlug(updatedName);
  };

  const handleSlugChange = (e) => setSlug(e.target.value.toLowerCase().replace(/[^a-z0-9-]/g, ""));

  const handleDescriptionChange = (e) => setDescription(e.target.value);
  const handlePublishedChange = (e) => setPublished(e.target.checked);

  const autoGenerateSlug = (value) => {
    const generatedSlug = value
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, "-") // Replace non-alphanumeric with dashes
      .replace(/^-+|-+$/g, ""); // Remove leading and trailing dashes
    setSlug(generatedSlug);
  };

  const handleNameBlur = () => {
    autoGenerateSlug(name);
    handleInputBlur();
  };

  const handleDoneEditing = () => {
    setDraftPlaylistMeta((prev) => ({
      ...prev,
      name,
      slug,
      description,
      published
    }));
    onRequestClose();
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
        starts_at_seconds: draftPlaylist.map((track) => track.starts_at_second),
        ends_at_seconds: draftPlaylist.map((track) => track.ends_at_second),
      });
      console.log(body);
      const response = await authFetch(url, {
        method,
        body,
      });
      console.log(response);
      if (!response.ok) throw response;
      const updatedPlaylist = await response.json();
      setDraftPlaylistMeta((prev) => ({
        ...prev,
        id: updatedPlaylist.id
      }));
      setNotice("Playlist saved successfully");
    } catch (error) {
      setAlert("Error saving playlist");
    }

    onRequestClose();
  };

  const handleClearPlaylist = () => {
    if (window.confirm("Are you sure you want to clear the draft playlist?")) {
      setDraftPlaylist([]);
      setDraftPlaylistMeta({
        id: null,
        name: "",
        slug: "",
        description: "",
        published: false
      });
    }
    onRequestClose();
  };

  return (
    <Modal
      isOpen={isOpen}
      onRequestClose={onRequestClose}
      className="modal-content"
      overlayClassName="modal-overlay"
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
            onKeyUp={handleNameChange}
            onBlur={handleNameBlur}
            onFocus={handleInputFocus}
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
          />
        </div>
      </div>
      <div className="field">
        <label className="label">Description</label>
        <div className="control">
          <textarea
            className="textarea"
            value={description}
            onChange={handleDescriptionChange}
            onFocus={handleInputFocus}
            onBlur={handleInputBlur}
            placeholder="Add a description"
          ></textarea>
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
        onClick={handleDoneEditing}
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
        Save Playlist
      </button>
      <button
        className="button ml-2"
        onClick={handleClearPlaylist}
      >
        <span className="icon mr-1">
          <FontAwesomeIcon icon={faTrash} />
        </span>
        Clear Playlist
      </button>
    </Modal>
  );
};

export default DraftPlaylistModal;
