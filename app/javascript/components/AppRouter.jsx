import React, { useState, useEffect } from "react";
import { RouterProvider } from "react-router-dom";
import clientRouter from "./clientRouter";
import serverRouter from "./serverRouter";
import { useNotification } from "./NotificationContext";

const AppRouter = (props) => {
  const [user, setUser] = useState(null);
  const { setAlert, setNotice } = useNotification();

  useEffect(() => {
    if (typeof window !== "undefined") {
      const jwt = localStorage.getItem("jwt");
      const username = localStorage.getItem("username");
      const email = localStorage.getItem("email");

      if (jwt && username && email) {
        setUser({ jwt, username, email });
      }
    }
  }, []);

  useEffect(() => {
    if (props.jwt && props.username && props.email) {
      handleLogin({ jwt: props.jwt, username: props.username, email: props.email });
    }
  }, [props.jwt, props.username, props.email]);

  useEffect(() => {
    if (props.notice) {
      setNotice(props.notice);
    }
    if (props.alert) {
      setAlert(props.alert);
    }
  }, [props.notice, props.alert]);

  const handleLogin = (userData) => {
    if (typeof window !== "undefined") {
      localStorage.setItem("jwt", userData.jwt);
      localStorage.setItem("username", userData.username);
      localStorage.setItem("email", userData.email);

      const redirectPath = localStorage.getItem("redirectAfterLogin") || "/";
      localStorage.removeItem("redirectAfterLogin");
      window.location.href = redirectPath;
    }
    setUser(userData);
  };

  const handleLogout = () => {
    if (typeof window !== "undefined") {
      localStorage.removeItem("jwt");
      localStorage.removeItem("username");
      localStorage.removeItem("email");
    }
    setUser(null);
    setNotice("Logged out successfully");
  };

  const RouterComponent = typeof window === "undefined" ? serverRouter : clientRouter;

  return (
    <RouterProvider
      router={RouterComponent({ ...props, user, handleLogin, handleLogout })}
    />
  );
};

export default AppRouter;
