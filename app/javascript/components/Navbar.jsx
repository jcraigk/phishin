import React, { useState, useEffect, useRef } from "react";
import PropTypes from "prop-types";
import { Link } from "react-router-dom";
import { useNotification } from "./NotificationContext";

const Navbar = ({ appName, user, onLogout }) => {
  const [isMenuOpen, setIsMenuOpen] = useState(false);
  const [isAboutDropdownOpen, setIsAboutDropdownOpen] = useState(false);
  const [isContentDropdownOpen, setIsContentDropdownOpen] = useState(false);
  const { setNotice } = useNotification();
  const menuRef = useRef(null);

  const handleLinkClick = () => {
    setIsMenuOpen(false);
    setIsAboutDropdownOpen(false);
    setIsContentDropdownOpen(false);

    // Forcefully remove the 'is-active' class from dropdowns
    const dropdowns = document.querySelectorAll('.has-dropdown.is-active');
    dropdowns.forEach((dropdown) => dropdown.classList.remove('is-active'));
  };

  const toggleDropdown = (setDropdown) => {
    setDropdown((prevState) => !prevState);
  };

  const handleLogout = () => {
    onLogout();
    handleLinkClick(); // Ensure dropdowns close after logout
  };

  useEffect(() => {
    const handleClickOutside = (event) => {
      if (menuRef.current && !menuRef.current.contains(event.target)) {
        setIsMenuOpen(false);
        setIsAboutDropdownOpen(false);
        setIsContentDropdownOpen(false);

        // Forcefully remove the 'is-active' class from dropdowns
        const dropdowns = document.querySelectorAll('.has-dropdown.is-active');
        dropdowns.forEach((dropdown) => dropdown.classList.remove('is-active'));
      }
    };

    document.addEventListener("mousedown", handleClickOutside);
    return () => {
      document.removeEventListener("mousedown", handleClickOutside);
    };
  }, [menuRef]);

  useEffect(() => {
    if (!isMenuOpen) {
      setIsAboutDropdownOpen(false);
      setIsContentDropdownOpen(false);
    }
  }, [isMenuOpen]);

  const siteLinks = [
    { path: "/faq", label: "FAQ" },
    { path: "/api-docs", label: "API" },
    { path: "/tagin-project", label: "Tagin' Project" },
    { path: "/privacy", label: "Privacy Policy" },
    { path: "/terms", label: "Terms of Service" },
    { path: "/contact-info", label: "Contact" },
    { path: "/request-password-reset", label: "Reset Password" },
  ];

  const contentLinks = [
    { path: "/", label: "Years" },
    { path: "/search", label: "Search" },
    { path: "/songs", label: "Songs" },
    { path: "/venues", label: "Venues" },
    { path: "/top-shows", label: "Top Shows" },
    { path: "/top-tracks", label: "Top Tracks" },
    { path: "/tags", label: "Tags" },
    { path: "/today", label: "Today" },
    { path: "/map", label: "Map" },
  ];

  return (
    <nav className="navbar" role="navigation" aria-label="main navigation" ref={menuRef}>
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
          <span aria-hidden="true"></span>
        </a>
      </div>

      <div
        id="navbarBasicExample"
        className={`navbar-menu ${isMenuOpen ? "is-active" : ""}`}
      >
        <div className="navbar-start">
          {/* About Dropdown */}
          <div
            className={`navbar-item has-dropdown ${
              isAboutDropdownOpen ? "is-active" : ""
            }`}
            onClick={() => toggleDropdown(setIsAboutDropdownOpen)}
          >
            <a className="navbar-link">Site</a>
            <div className="navbar-dropdown">
              {siteLinks.map((link) => (
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

          {/* Content Dropdown */}
          <div
            className={`navbar-item has-dropdown ${
              isContentDropdownOpen ? "is-active" : ""
            }`}
            onClick={() => toggleDropdown(setIsContentDropdownOpen)}
          >
            <a className="navbar-link">Content</a>
            <div className="navbar-dropdown">
              {contentLinks.map((link) => (
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
              ) : (
                <>
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
  user: PropTypes.object,
  onLogout: PropTypes.func.isRequired,
};

export default Navbar;
