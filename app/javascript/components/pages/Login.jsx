import React, { useState } from "react";
import { useNavigate, Link } from "react-router-dom";
import PageWrapper from "./PageWrapper";
import { useFeedback } from "../FeedbackContext";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faArrowAltCircleRight, faRightToBracket, faUserCheck } from "@fortawesome/free-solid-svg-icons";

const Login = ({ onLogin, oauthProviders }) => {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const { setAlert, setNotice } = useFeedback();
  const navigate = useNavigate();

  const handleSubmit = async (e) => {
    e.preventDefault();

    fetch("/api/v2/auth/login", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email, password })
    })
    .then(response => response.json().then(data => {
      if (response.ok) {
        onLogin(data);
        setNotice("Login successful");
        navigate("/");
      } else {
        setAlert(data.message || "An error occurred");
      }
    }));
  };

  return (
    <PageWrapper>
      {oauthProviders.map(provider => (
        <a
          key={provider}
          href={`/oauth/${provider}`}
          className={`button external-login-btn ${provider}-btn non-remote`}
        >
          <div className="login-logo">
            <img
              src={require(`../../images/external-logo-${provider}.png`)}
              alt={`${provider.toString().toUpperCase()} Logo`}
              width="18"
              height="18"
            />
          </div>
          {`Login with ${provider.charAt(0).toUpperCase() + provider.slice(1)}`}
        </a>
      ))}

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
              <div className="icon mr-1">
                <FontAwesomeIcon icon={faRightToBracket} />
              </div>
              Login
            </button>
          </div>
        </div>
      </form>

      <hr />

      <h1 className="title">Sign Up with Email</h1>
      <Link to="/signup" className="button">
        <div className="icon mr-1">
          <FontAwesomeIcon icon={faArrowAltCircleRight} />
        </div>
        Sign Up
      </Link>
    </PageWrapper>
  );
};

export default Login;
