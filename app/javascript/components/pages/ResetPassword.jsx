import React, { useState } from "react";
import { useParams } from "react-router-dom";
import PageWrapper from "./PageWrapper";
import { useNotification } from "../NotificationContext";


const ResetPassword = () => {
  const { setError, setMessage } = useNotification();
  const { token } = useParams();
  const [password, setPassword] = useState("");
  const [passwordConfirmation, setPasswordConfirmation] = useState("");

  const handleSubmit = (e) => {
    e.preventDefault();

    // Client-side validation
    if (password.length < 5) {
      setError("Password must be at least 5 characters long.");
      return;
    }

    if (password !== passwordConfirmation) {
      setError("Passwords do not match.");
      return;
    }

    setError(""); // Clear any existing errors

    fetch('/api/v2/auth/reset_password', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ token, password, password_confirmation: passwordConfirmation })
    })
    .then(response => {
      if (!response.ok) {
        if (response.status === 401) {
          throw new Error('Invalid or expired token');
        } else if (response.status === 422) {
          throw new Error('Passwords do not match or are invalid');
        } else {
          throw new Error('Something went wrong');
        }
      }
      return response.json();
    })
    .then(data => {
      setMessage(data.message);
    })
    .catch(error => {
      setError(error.message);
    });
  };

  return (
    <PageWrapper>
      <div className="container">
        <h1 className="title">Reset Password</h1>
        <form onSubmit={handleSubmit}>
          <input type="hidden" name="token" value={token} />

          <div className="field">
            <label className="label" htmlFor="password">New Password</label>
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
            <label className="label" htmlFor="passwordConfirmation">Confirm New Password</label>
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
              <button className="button is-primary" type="submit">Reset Password</button>
            </div>
          </div>
        </form>
      </div>
    </PageWrapper>
  );
};

export default ResetPassword;