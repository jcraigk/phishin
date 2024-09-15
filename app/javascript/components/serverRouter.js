import React from "react";
import { createStaticHandler, createStaticRouter, StaticRouterProvider } from "react-router-dom/server";
import routes from "./routes"; // Your routes configuration

const serverRouter = async (props) => {
  const { location, context } = props;

  console.log("SSR: location passed to serverRouter", location);
  console.log("SSR: context passed to serverRouter", context);

  const helmetContext = {};  // Track helmet context for SSR

  const staticHandler = createStaticHandler(routes(props));
  console.log("SSR: staticHandler", staticHandler);

  const staticRouter = createStaticRouter(staticHandler.dataRoutes, { location });
  console.log("SSR: staticRouter created", staticRouter);

  const result = await staticHandler.query({ request: { url: location } });
  console.log("SSR: result from staticHandler.query", result);

  if (result instanceof Response) {
    context.url = result.headers.get("Location");
    context.statusCode = result.status;
    console.log("SSR: Redirect detected, statusCode", result.status, "URL:", context.url);
  } else if (result.status === 404) {
    context.statusCode = 404;
    console.log("SSR: 404 detected");
  }

  // Render the component tree, no need for another HelmetProvider
  const html = (
    <StaticRouterProvider router={staticRouter} context={result} location={location} />
  );

  // Pass helmet context back to Rails for head tags
  context.helmetData = helmetContext.helmet;
  console.log("SSR: helmetContext", helmetContext);

  return html;  // Return rendered HTML
};

export default serverRouter;
