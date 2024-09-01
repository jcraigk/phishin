import React from "react";
import { RouterProvider } from "react-router-dom";
import router from "./router";
import { NotificationProvider } from "./NotificationContext";

const App = (props) => {
  return (
    <NotificationProvider>
      <RouterProvider router={router(props)} />
    </NotificationProvider>
  );
};

export default App;
