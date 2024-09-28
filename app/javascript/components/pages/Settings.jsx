import React, { useState, useEffect } from "react";
import { useNavigate, useOutletContext } from "react-router-dom";
import { authFetch } from "../util/utils";
import { useFeedback } from "../controls/FeedbackContext";
import PageWrapper from "./PageWrapper";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faLock, faCheckCircle, faUserEdit, faCircleExclamation } from "@fortawesome/free-solid-svg-icons";

const Settings = ({ setUser, usernameCooldown }) => {
  const navigate = useNavigate();
  const [currentUsername, setCurrentUsername] = useState("");
  const [newUsername, setNewUsername] = useState("");
  const [usernameUpdatedAt, setUsernameUpdatedAt] = useState(null);
  const { setAlert, setNotice } = useFeedback();
  const [isCooldown, setIsCooldown] = useState(false);
  const [cooldownMessage, setCooldownMessage] = useState("");
  const { user } = useOutletContext();

  // Redirect if not logged in
  useEffect(() => {
    if (!user) {
      navigate("/");
    }
  }, [navigate]);

  useEffect(() => {
    const storedUsername = localStorage.getItem("username");
    const storedUsernameUpdatedAt = localStorage.getItem("usernameUpdatedAt");

    if (storedUsername) setCurrentUsername(storedUsername);
    if (storedUsernameUpdatedAt) setUsernameUpdatedAt(new Date(storedUsernameUpdatedAt));
  }, []);

  useEffect(() => {
    if (usernameUpdatedAt) {
      const cooldownEnd = new Date(usernameUpdatedAt.getTime() + usernameCooldown * 1000);
      const now = new Date();
      setIsCooldown(now < cooldownEnd);
      setCooldownMessage(`You can change your username again on ${cooldownEnd.toLocaleDateString()}`);
    }
  }, [usernameUpdatedAt, usernameCooldown]);

  const handleChangeUsername = async (e) => {
    e.preventDefault();

    if (!window.confirm("You won't be able to change your username again for a year. Are you sure?")) {
      return;
    }

    authFetch(`/api/v2/auth/change_username/${newUsername}`, { method: "PATCH" })
      .then((response) => response.json().then((data) => {
        if (response.ok) {
          setCurrentUsername(data.username);
          setUsernameUpdatedAt(new Date());
          setNotice("Username changed successfully");
          localStorage.setItem("username", data.username);
          localStorage.setItem("usernameUpdatedAt", new Date().toISOString());
          setUser((prev) => ({ ...prev, username: data.username }));
        } else {
          setAlert(data.message || "An error occurred");
        }
      }));
  };

  return (
    <PageWrapper>
      <h1 className="title">Settings</h1>

      <div className="box">
        <h2>
          <FontAwesomeIcon icon={faUserEdit} className="mr-2" />
          Change Username
        </h2>
        {isCooldown ? (
          <div className="cooldown-message">
            <FontAwesomeIcon icon={faLock} className="mr-1" /> {cooldownMessage}
          </div>
        ) : (
          <>
            <p>
              <FontAwesomeIcon icon={faCircleExclamation} className="mr-2" />
              You may change your username only once per year so choose as Icculus would!
            </p>
            <form onSubmit={handleChangeUsername}>
              <div className="field">
                <label className="label" htmlFor="new-username">Current Username: {currentUsername}</label>
                <div className="control">
                  <input
                    className="input"
                    type="text"
                    id="new-username"
                    value={newUsername}
                    onChange={(e) => setNewUsername(e.target.value)}
                    placeholder="Enter new username"
                    required
                  />
                </div>
              </div>
              <div className="field">
                <div className="control">
                  <button className="button has-text-weight-bold" type="submit">
                    <FontAwesomeIcon icon={faCheckCircle} className="mr-2" />
                    Update Username
                  </button>
                </div>
              </div>
            </form>
          </>
        )}
      </div>
    </PageWrapper>
  );
};

export default Settings;
