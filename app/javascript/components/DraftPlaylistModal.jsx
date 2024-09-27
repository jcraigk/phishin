import React, { useState, useEffect } from "react";
import Modal from "react-modal";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faCircleXmark } from "@fortawesome/free-solid-svg-icons";

const DraftPlaylistModal = ({ isOpen, onRequestClose, draftPlaylistMeta, setDraftPlaylistMeta, handleInputFocus, handleInputBlur }) => {
  const [name, setName] = useState(draftPlaylistMeta.name);
  const [slug, setSlug] = useState(draftPlaylistMeta.slug);
  const [description, setDescription] = useState(draftPlaylistMeta.description);
  const [published, setPublished] = useState(draftPlaylistMeta.published);

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

  // Function to auto-generate slug from the name
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

  const handleSave = () => {
    setDraftPlaylistMeta((prev) => ({
      ...prev,
      name,
      slug,
      description,
      published
    }));
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
            placeholder="lowercase-letters-numbers-only"
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
            {" "}Make Public (browse & search)
          </label>
        </div>
      </div>
      <button
        className="button is-primary"
        onClick={handleSave}
      >
        Save
      </button>
    </Modal>
  );
};

export default DraftPlaylistModal;
