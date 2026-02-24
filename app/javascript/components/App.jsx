import React from "react";
import { HelmetProvider } from "react-helmet-async";
import { RouterProvider, createBrowserRouter } from "react-router";
import routes from "./routes/routes";
import { FeedbackProvider } from "./contexts/FeedbackContext";
import useDarkMode from "./hooks/useDarkMode";

const App = (props) => {
  useDarkMode();
  const helmetContext = {};
  const router = createBrowserRouter(routes(props));

  return (
    <HelmetProvider context={helmetContext}>
      <FeedbackProvider>
        <div className="root-layout">
          <RouterProvider router={router} />
        </div>
      </FeedbackProvider>
    </HelmetProvider>
  );
};

export default App;
