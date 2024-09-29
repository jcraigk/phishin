import React, { useState } from "react";
import { Link, useOutletContext } from "react-router-dom";
import PageWrapper from "./PageWrapper";
import { useFeedback } from "../controls/FeedbackContext";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faArrowAltCircleRight, faRightToBracket } from "@fortawesome/free-solid-svg-icons";

const Login = () => {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const { setAlert } = useFeedback();
  const { handleLogin } = useOutletContext();

  const handleSubmit = async (e) => {
    e.preventDefault();

    fetch("/api/v2/auth/login", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email, password })
    })
    .then(response => response.json().then(data => {
      if (response.ok) {
        handleLogin(data, "Login successful");
      } else {
        setAlert(data.message || "An error occurred");
      }
    }));
  };

  return (
    <PageWrapper>
      <a
        href="/oauth/google"
        className="button external-login-btn google-btn non-remote"
      >
        <div className="login-logo">
          <img
            src={require(`../../images/external-logo-google.png`)}
            alt="Google logo"
            width="18"
            height="18"
          />
        </div>
        Login with Google
      </a>

      <hr />

      <h1 className="title">Login with Email / Password</h1>
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
          <div className="control">
            <button className="button" type="submit">
              <FontAwesomeIcon icon={faRightToBracket} className="mr-1" />
              Login
            </button>
          </div>
        </div>
      </form>

      <div className="mt-4">
        <Link to="/request-password-reset">Forgot your password?</Link>
      </div>
      <hr />

      <h1 className="title">Sign Up with Email</h1>
      <Link to="/signup" className="button">
        <FontAwesomeIcon icon={faArrowAltCircleRight} className="mr-1" />
        Sign Up
      </Link>
    </PageWrapper>
  );
};

export default Login;
