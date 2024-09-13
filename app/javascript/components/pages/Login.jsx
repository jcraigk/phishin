import React, { useState } from "react";
import { useNavigate, Link } from "react-router-dom";
import PageWrapper from "./PageWrapper";
import { useNotification } from "../NotificationContext";

const Login = ({ onLogin, oauthProviders }) => {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const { setAlert, setNotice } = useNotification();
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
      <div className="container">
        {oauthProviders.map(provider => (
          <a
            key={provider}
            href={`/oauth/${provider}`}
            className={`button external-login-btn ${provider}-btn non-remote`}
          >
            <div className="login-logo">
              <img
                src={require(`../../images/external-logos/${provider}.png`)}
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
              <button className="button is-primary has-text-weight-bold" type="submit">
                Login
              </button>
            </div>
          </div>
        </form>

        <hr />

        <h1 className="title">Sign Up with Email</h1>
        <Link to="/signup" className="button has-text-weight-bold">
          Sign Up
        </Link>
      </div>
    </PageWrapper>
  );
};

export default Login;
