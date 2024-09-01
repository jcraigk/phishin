import React, { useState } from "react";
import { useNavigate } from "react-router-dom";
import PageWrapper from "./PageWrapper";
import { useNotification } from "../NotificationContext";

const Login = () => {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const { setError, setMessage, clearNotification } = useNotification();
  const navigate = useNavigate();

  const handleSubmit = async (e) => {
    e.preventDefault();

    fetch('/api/v2/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password })
    })
    .then(response => {
      if (response.ok) {
        return response.json();
      } else {
        throw new Error('Invalid email or password');
      }
    })
    .then(data => {
      // Store the JWT and user information in localStorage
      localStorage.setItem('jwt', data.jwt);
      localStorage.setItem('username', data.username);
      localStorage.setItem('email', data.email);

      // Clear any existing feedback messages
      clearNotification();

      // Navigate to the root path after successful login
      navigate('/');
    })
    .catch(error => {
      setError(error.message);
    });
  };

  return (
    <PageWrapper>
      <div className="container">
        <h1 className="title">Login</h1>
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
