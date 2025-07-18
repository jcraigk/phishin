import React, { useState } from "react";
import { useOutletContext } from "react-router-dom";
import PageWrapper from "./PageWrapper";
import { useFeedback } from "../contexts/FeedbackContext";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faCheckCircle } from "@fortawesome/free-solid-svg-icons";

const Signup = () => {
  const [username, setUsername] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [passwordConfirmation, setPasswordConfirmation] = useState("");
  const { setAlert } = useFeedback();
  const { handleLogin } = useOutletContext();

  const handleSubmit = async (e) => {
    e.preventDefault();

    fetch("/api/v2/auth/create_user", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        username,
        email,
        password,
        password_confirmation: passwordConfirmation
      })
    })
    .then(response => response.json().then(data => {
      if (response.ok) {
        handleLogin(data, "User created successfully - you are now logged in");
      } else {
        setAlert(data.message || "An error occurred");
      }
    }));
  };

  return (
    <PageWrapper>
      <h1 className="title">Sign Up</h1>
      <form onSubmit={handleSubmit}>
        <div className="field">
          <label className="label" htmlFor="username">Username</label>
          <div className="control">
            <input
              className="input"
              type="text"
              id="username"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              required
            />
          </div>
        </div>
        <div className="field">
          <label className="label" htmlFor="email">Email Address</label>
          <div className="control">
            <input
              className="input"
              type="email"
              id="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
            />
          </div>
        </div>
        <div className="field">
          <label className="label" htmlFor="password">Password</label>
          <div className="control">
            <input
              className="input"
              type="password"
              id="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
            />
          </div>
        </div>
        <div className="field">
          <label className="label" htmlFor="passwordConfirmation">Confirm Password</label>
          <div className="control">
            <input
              className="input"
              type="password"
              id="passwordConfirmation"
              value={passwordConfirmation}
              onChange={(e) => setPasswordConfirmation(e.target.value)}
              required
            />
          </div>
        </div>
        <div className="field mt-6">
          <div className="control">
            <button className="button" type="submit">
              <FontAwesomeIcon icon={faCheckCircle} className="mr-1" />
              Sign Up
            </button>
          </div>
        </div>
      </form>
    </PageWrapper>
  );
};

export default Signup;
