import React, { useState } from "react";
import PageWrapper from "./PageWrapper";
import { useFeedback } from "../contexts/FeedbackContext";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faEnvelope } from "@fortawesome/free-solid-svg-icons";

const RequestPasswordReset = () => {
  const { setNotice } = useFeedback();
  const [email, setEmail] = useState("");

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      const response = await fetch(
        "/api/v2/auth/request_password_reset",
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ email })
        }
      );
      if (!response.ok) throw response;
      const data = await response.json();
      setNotice(data.message);
    } catch (error) {
      if (error instanceof Response) throw error;
      throw new Response("Sorry, something went wrong", { status: 500 });
    }
  };

  return (
    <PageWrapper>
      <h2 className="title">Request Password Reset</h2>
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
            <button className="button mt-2" type="submit">
              <FontAwesomeIcon icon={faEnvelope} className="mr-1" />

              Request password reset
            </button>
          </div>
        </div>
      </form>
    </PageWrapper>
  );
};

export default RequestPasswordReset;
