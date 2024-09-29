import React, { useState, useEffect } from "react";
import { RouterProvider } from "react-router-dom";
import clientRouter from "./clientRouter";
import serverRouter from "./serverRouter";
import { useFeedback } from "../controls/FeedbackContext";

const AppRouter = (props) => {
  const [user, setUser] = useState(null);
  const { setAlert, setNotice } = useFeedback();

  useEffect(() => {
    if (props.jwt) {
      setUser({
        jwt: props.jwt,
        username: props.username,
        usernameUpdatedAt: props.username_updated_at,
        email: props.email,
      });
    }

    if (typeof window !== "undefined") {
      const jwt = localStorage.getItem("jwt");
      const username = localStorage.getItem("username");
      const usernameUpdatedAt = localStorage.getItem("usernameUpdatedAt");
      const email = localStorage.getItem("email");

      if (jwt && username && email) {
        setUser({ jwt, username, usernameUpdatedAt, email });
      }
    }
  }, []);

  useEffect(() => {
    if (props.notice) {
      setNotice(props.notice);
    }
    if (props.alert) {
      setAlert(props.alert);
    }
  }, [props.notice, props.alert]);

  const RouterComponent = typeof window === "undefined" ? serverRouter : clientRouter;

  return (
    <RouterProvider
      router={RouterComponent({ ...props, user, setUser })}
    />
  );
};

export default AppRouter;
