import React, { useState, useEffect } from "react";
import { useNavigate, useOutletContext } from "react-router-dom";
import { authFetch } from "../helpers/utils";
import { useFeedback } from "../controls/FeedbackContext";
import PageWrapper from "./PageWrapper";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faLock, faCheckCircle, faCircleExclamation } from "@fortawesome/free-solid-svg-icons";

const Settings = () => {
  const navigate = useNavigate();
  const { user, setUser, usernameCooldown } = useOutletContext();
  const { setAlert, setNotice } = useFeedback();
  const [newUsername, setNewUsername] = useState("");
  const [isCooldown, setIsCooldown] = useState(false);
  const [cooldownMessage, setCooldownMessage] = useState("");

  // Redirect if not logged in
  useEffect(() => {
    if (!user) {
      navigate("/");
    }
  }, [navigate, user]);

  // Cooldown check for username change
  useEffect(() => {
    if (user?.usernameUpdatedAt) {
      const cooldownEnd = new Date(new Date(user.usernameUpdatedAt).getTime() + usernameCooldown * 1000);
      const now = new Date();
      console.log(now < cooldownEnd);
      console.log(usernameCooldown);
      setIsCooldown(now < cooldownEnd);
      setCooldownMessage(`You can change your username again on ${cooldownEnd.toLocaleDateString()}`);
    }
  }, [user, usernameCooldown]);

  const handleChangeUsername = async (e) => {
    e.preventDefault();

    if (!window.confirm("You won't be able to change your username again for a year. Are you sure?")) {
      return;
    }

    authFetch(`/api/v2/auth/change_username/${newUsername}`, { method: "PATCH" })
      .then((response) => response.json().then((data) => {
        if (response.ok) {
          setNotice("Username changed successfully");
          setUser((prev) => ({ ...prev, username: data.username, usernameUpdatedAt: new Date().toISOString() }));
        } else {
          setAlert(data.message || "An error occurred");
        }
      }));
  };

  if (!user) {
    return null;
  } else {
    console.log(user);
  }

  return (
    <PageWrapper>
      <h2 className="title">Settings</h2>

      <div className="box">
        <h2 className="subtitle">Change Username</h2>
        {isCooldown ? (
          <>
            <FontAwesomeIcon icon={faLock} className="mr-1" />
            {cooldownMessage}
          </>
        ) : (
          <>
            <p>
              <FontAwesomeIcon icon={faCircleExclamation} className="mr-2" />
              You may change your username only once per year so choose wisely!
            </p>
            <form onSubmit={handleChangeUsername}>
              <div className="field">
                <label className="label" htmlFor="new-username">Current Username: {user.username}</label>
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
