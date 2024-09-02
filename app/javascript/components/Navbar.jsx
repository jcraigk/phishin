import React, { useState, useEffect } from "react";
import PropTypes from "prop-types";
import { Link } from "react-router-dom";
import { useNotification } from "./NotificationContext";

const Navbar = ({ appName }) => {
  const [isMenuOpen, setIsMenuOpen] = useState(false);
  const [isDropdownOpen, setIsDropdownOpen] = useState(false);
  const [user, setUser] = useState(null);
  const { setMessage } = useNotification();

  useEffect(() => {
    const jwt = localStorage.getItem("jwt");
    const username = localStorage.getItem("username");
    const email = localStorage.getItem("email");

    if (jwt) {
      setUser({ username, email });
    }
  }, []);

  const handleLinkClick = () => {
    setIsMenuOpen(false);
    setIsDropdownOpen(false);
  };

  const toggleDropdown = () => {
    setIsDropdownOpen(!isDropdownOpen);
  };

  const handleLogout = () => {
    localStorage.removeItem("jwt");
    localStorage.removeItem("username");
    localStorage.removeItem("email");
    setUser(null);
    setMessage("Logged out successfully");
  };

  const staticLinks = [
    { path: "/faq", label: "FAQ" },
    { path: "/api-docs", label: "API" },
    { path: "/tagin-project", label: "Tagin' Project" },
    { path: "/privacy", label: "Privacy Policy" },
    { path: "/terms", label: "Terms of Service" },
    { path: "/contact-info", label: "Contact" },
    { path: "/request-password-reset", label: "Reset Password" },
  ];

  return (
    <nav className="navbar" role="navigation" aria-label="main navigation">
      <div className="navbar-brand">
        <Link to="/" className="navbar-item" onClick={handleLinkClick}>
          <img src="/static/logo-96.png" alt="Site Logo" />
        </Link>

        <a
          role="button"
          className={`navbar-burger ${isMenuOpen ? "is-active" : ""}`}
          aria-label="menu"
          aria-expanded={isMenuOpen}
          data-target="navbarBasicExample"
          onClick={() => setIsMenuOpen(!isMenuOpen)}
        >
          <span aria-hidden="true"></span>
          <span aria-hidden="true"></span>
          <span aria-hidden="true"></span>
        </a>
      </div>

      <div
        id="navbarBasicExample"
        className={`navbar-menu ${isMenuOpen ? "is-active" : ""}`}
      >
        <div className="navbar-start">
          <Link to="/faq" className="navbar-item" onClick={handleLinkClick}>
            FAQ
          </Link>
          <Link to="/api-docs" className="navbar-item" onClick={handleLinkClick}>
            API
          </Link>

          <div
            className={`navbar-item has-dropdown ${
              isDropdownOpen ? "is-active" : ""
            }`}
            onClick={toggleDropdown}
          >
            <a className="navbar-link">More</a>

            <div className="navbar-dropdown">
              {staticLinks.slice(2).map((link) => (
                <Link
                  key={link.path}
                  to={link.path}
                  className="navbar-item"
                  onClick={handleLinkClick}
                >
                  {link.label}
                </Link>
              ))}
            </div>
          </div>
        </div>

        <div className="navbar-end">
          <div className="navbar-item">
            <div className="buttons">
              {user ? (
                <>
                  <div className="navbar-item has-dropdown is-hoverable">
                    <a className="navbar-link">
                      {user.username}
                    </a>
                    <div className="navbar-dropdown is-right">
                      <a
                        href="#logout"
                        className="navbar-item"
                        onClick={handleLogout}
                      >
                        Logout
                      </a>
                    </div>
                  </div>
                </>
              ) : (
                <>
                  <Link to="/signup" className="button is-primary">
                    <strong>Sign up</strong>
                  </Link>
                  <Link to="/login" className="button is-light">
                    Log in
                  </Link>
                </>
              )}
            </div>
          </div>
        </div>
      </div>
    </nav>
  );
};

Navbar.propTypes = {
  appName: PropTypes.string.isRequired,
};

export default Navbar;
