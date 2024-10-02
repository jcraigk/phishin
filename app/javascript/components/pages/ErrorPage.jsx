import React from "react";
import { useRouteError, Link } from "react-router-dom";
import logo from "../../images/logo-350.png";

const ErrorPage = () => {
  const error = useRouteError();

  return (
    <div className="error-page">
      <img src={logo} className="site-logo" alt="Site logo" />
      {error?.status === 404 ? (
        <>
          <p className="error-title">404</p>
          <p className="error-subtitle">Got a blank space...</p>
        </>
      ) : (
        <>
          <p className="error-title">500</p>
          <p className="error-subtitle">We are so very sorry...</p>
        </>
      )}
      <p className="error-detail">
        {error?.data || "An unexpected error has occurred"}
      </p>

      <Link to="/" className="button">Return Home</Link>
    </div>
  );
};

export default ErrorPage;
