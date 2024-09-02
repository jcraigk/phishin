import React, { useState } from "react";
import { useNavigate } from "react-router-dom";
import PageWrapper from "./PageWrapper";
import { useNotification } from "../NotificationContext";

const Login = ({ onLogin, oauth_providers }) => {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const { setError, setMessage } = useNotification();
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
        setMessage("Login successful");
        navigate("/");
      } else {
        setError(data.message || "An error occurred");
      }
    }));
  };

  const getProviderLogo = (provider) => {
    return require(`../../images/external-logos/${provider}.png`);
  };

  return (
    <PageWrapper>
      <div className="container">
        <h1 className="title">Login with Google</h1>
        <div className="external-login-container">
          {oauth_providers.map(provider => (
            <a
              key={provider}
              href={`/oauth/${provider}`}
              className={`button external-login-btn ${provider}-btn non-remote`}
            >
              <div className="login-logo">
                <img
                  src={getProviderLogo(provider)}
                  alt={`${provider.toString().toUpperCase()} Logo`}
                  width="18"
                  height="18"
                />
              </div>
              {`Login with ${provider.charAt(0).toUpperCase() + provider.slice(1)}`}
            </a>
          ))}
        </div>

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
              <button className="button is-primary" type="submit">
                Login
              </button>
            </div>
          </div>
        </form>
      </div>
    </PageWrapper>
  );
};

export default Login;
