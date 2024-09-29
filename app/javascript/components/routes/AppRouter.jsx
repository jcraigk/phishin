import React from "react";
import { RouterProvider } from "react-router-dom";
import clientRouter from "./clientRouter";
import serverRouter from "./serverRouter";

const AppRouter = (props) => {
  const RouterComponent = typeof window === "undefined" ? serverRouter : clientRouter;

  return (
    <RouterProvider
      router={RouterComponent({ ...props })}
    />
  );
};

export default AppRouter;
