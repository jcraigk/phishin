import React, { useState, useEffect } from "react";
import { RouterProvider } from "react-router-dom";
import router from "./router";
import { useNotification } from "./NotificationContext";

const AppRouter = (props) => {
  const [user, setUser] = useState(() => {
    const jwt = localStorage.getItem("jwt");
    const username = localStorage.getItem("username");
    const email = localStorage.getItem("email");
    return jwt ? { jwt, username, email } : null;
  });

  const { setError, setMessage } = useNotification();

  useEffect(() => {
    if (props.jwt && props.username && props.email) {
      handleLogin({ jwt: props.jwt, username: props.username, email: props.email });
    }
  }, [props.jwt, props.username, props.email]);

  useEffect(() => {
    if (props.notice) {
      setMessage(props.notice);
    }
    if (props.alert) {
      setError(props.alert);
    }
  }, [props.notice, props.alert]);

  const handleLogin = (userData) => {
    localStorage.setItem("jwt", userData.jwt);
    localStorage.setItem("username", userData.username);
    localStorage.setItem("email", userData.email);
    setUser(userData);
    setMessage("You are now logged in as " + userData.email);
  };

  const handleLogout = () => {
    localStorage.removeItem("jwt");
    localStorage.removeItem("username");
    localStorage.removeItem("email");
    setUser(null);
    setMessage("Logged out successfully");
  };

  return (
    <RouterProvider router={router({ ...props, user, handleLogin, handleLogout })} />
  );
};

export default AppRouter;