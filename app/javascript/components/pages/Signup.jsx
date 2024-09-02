import React, { useState } from "react";
import { useNavigate } from "react-router-dom";
import PageWrapper from "./PageWrapper";
import { useNotification } from "../NotificationContext";

const Signup = ({ onSignup }) => {
  const [username, setUsername] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [passwordConfirmation, setPasswordConfirmation] = useState("");
  const { setError, setMessage, clearNotification } = useNotification();
  const navigate = useNavigate();

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
        onSignup(data); // Calls the handleLogin function from App
        setMessage("User created successfully - you are now logged in");
        navigate("/");
      } else {
        setError(data.message || "An error occurred");
      }
    }));
  };

  return (
    <PageWrapper>
      <div className="container">
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
          <div className="field">
            <div className="control">
              <button className="button is-primary" type="submit">
                Sign Up
              </button>
            </div>
          </div>
        </form>
      </div>
    </PageWrapper>
  );
};

export default Signup;
