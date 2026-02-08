import React from "react";
import { HelmetProvider } from "react-helmet-async";
import { RouterProvider, createBrowserRouter } from "react-router-dom";
import routes from "./routes/routes";
import { FeedbackProvider } from "./contexts/FeedbackContext";
import useDarkMode from "./hooks/useDarkMode";

const App = (props) => {
  useDarkMode();
  const helmetContext = {};
  const router = createBrowserRouter(routes(props), {
    future: {
      v7_relativeSplatPath: true,
    },
  });

  return (
    <HelmetProvider context={helmetContext}>
      <FeedbackProvider>
        <div className="root-layout">
          <RouterProvider router={router} future={{ v7_startTransition: true }} />
        </div>
      </FeedbackProvider>
    </HelmetProvider>
  );
};

export default App;
