import React from "react";
import { HelmetProvider } from "react-helmet-async";
import { createBrowserRouter } from "react-router";
import { RouterProvider } from "react-router/dom";
import routes from "./routes/routes";
import { FeedbackProvider } from "./contexts/FeedbackContext";

const App = (props) => {
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
