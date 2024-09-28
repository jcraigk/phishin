import React, { useState } from "react";
import PageWrapper from "./PageWrapper";
import { useFeedback } from "../controls/FeedbackContext"; // Updated path

const RequestPasswordReset = () => {
  const { setAlert, setNotice } = useFeedback();
  const [email, setEmail] = useState("");

  const handleSubmit = async (e) => {
    e.preventDefault();

    fetch('/api/v2/auth/request_password_reset', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email })
    })
    .then(response => {
      return response.json();
    })
    .then(data => {
      setNotice(data.message);
    })
    .catch(error => {
      setAlert('Sorry, something went wrong');
    });
  };

  return (
    <PageWrapper>
      <div className="container">
        <h1 className="title">Request Password Reset</h1>
        <form onSubmit={handleSubmit}>
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
            <div className="control">
              <button className="button is-primary" type="submit">
                Request Password Reset
              </button>
            </div>
          </div>
        </form>
      </div>
    </PageWrapper>
  );
};

export default RequestPasswordReset;
