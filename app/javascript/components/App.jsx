import React from "react";
import { RouterProvider } from "react-router-dom";
import router from "./router";

const App = (props) => {
  return <RouterProvider router={router(props)} />;
};

export default App;
