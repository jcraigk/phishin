import React, { useState, useEffect, useRef } from "react";
import { Link, useNavigate } from "react-router-dom";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import logo from "../images/logo-350.png";
import { faQuestionCircle, faBook, faTags, faAddressBook, faUserShield, faFileContract, faCalendarAlt, faMusic, faMapMarkerAlt, faStar, faCalendarDay, faMap, faSearch, faAngleDown, faRecordVinyl, faGuitar, faUser, faCircleXmark, faRightToBracket } from "@fortawesome/free-solid-svg-icons";

const Navbar = ({ user, onLogout }) => {
  const [isMenuOpen, setIsMenuOpen] = useState(false);
  const [searchTerm, setSearchTerm] = useState("");
  const navigate = useNavigate();

  const closeMenus = () => {
    setIsMenuOpen(false);
    // Fix for bulma dropdowns not closing from navbar
    const dropdowns = document.querySelectorAll('.dropdown-menu');
    dropdowns.forEach((dropdown) => {
      dropdown.style.display = 'none';
      setTimeout(() => {
        dropdown.style.display = '';
      }, 200);
    });
  };

  const handleLogout = () => {
    onLogout();
  };

  const handleSearchSubmit = (e) => {
    e.preventDefault();
    if (searchTerm) {
      navigate(`/search?term=${searchTerm}`);
      closeMenus();
    }
  };

  const staticLinks = [
    { path: "/faq", label: "FAQ", icon: faQuestionCircle },
    { path: "/api-docs", label: "API Docs", icon: faBook },
    { path: "/tagin-project", label: "Tagin' Project", icon: faTags },
    { path: "/contact-info", label: "Contact Info", icon: faAddressBook },
    { path: "/privacy", label: "Privacy Policy", icon: faUserShield },
    { path: "/terms", label: "Terms of Service", icon: faFileContract }
  ];

  const browseLinks = [
    { path: "/", label: "Years", icon: faCalendarAlt },
    { path: "/songs", label: "Songs", icon: faMusic },
    { path: "/venues", label: "Venues", icon: faMapMarkerAlt },
    { path: "/tags", label: "Tags", icon: faTags },
    { path: "/today", label: "Today", icon: faCalendarDay },
    { path: "/map", label: "Map", icon: faMap }
  ];

  const topLinks = [
    { path: "/top-shows", label: "Top 46 Shows", icon: faStar },
    { path: "/top-tracks", label: "Top 46 Tracks", icon: faStar }
  ];

  const userLinks = [
    { path: "/my-shows", label: "My Shows", icon: faGuitar },
    { path: "/my-tracks", label: "My Tracks", icon: faRecordVinyl }
  ];

  const combinedLinks = [
    ...browseLinks.map(link => ({ ...link, type: 'link' })),
    { type: 'divider' },
    ...topLinks.map(link => ({ ...link, type: 'link' })),
    { type: 'divider' },
    ...userLinks.map(link => ({ ...link, type: 'link' }))
  ];

  return (
    <nav className="navbar" role="navigation">
      <div className="navbar-brand">
        <Link to="/" className="navbar-item">
          <img src={logo} alt="Site logo" />
        </Link>

        <a
          role="button"
          className={`navbar-burger ${isMenuOpen ? "is-active" : ""}`}
          data-target="navbar"
          onClick={() => setIsMenuOpen(!isMenuOpen)}
        >
          <span></span>
          <span></span>
          <span></span>
          <span></span>
        </a>
      </div>

      <div id="navbar" className={`navbar-menu ${isMenuOpen ? "is-active" : ""}`}>
        <div className="navbar-start">

          <div className="dropdown is-hoverable navbar-item">
            <div className="dropdown-trigger">
              <button className="button">
                <span>INFO</span>
                <span className="icon">
                  <FontAwesomeIcon icon={faAngleDown} />
                </span>
              </button>
            </div>
            <div className="dropdown-menu" role="menu">
              <div className="dropdown-content">
                {staticLinks.map((item, index) => (
                  <Link
                    key={item.path}
                    to={item.path}
                    className="dropdown-item"
                    onClick={closeMenus}
                  >
                    <span className="icon">
                      <FontAwesomeIcon icon={item.icon} />
                    </span>
                    {item.label}
                  </Link>
                ))}
              </div>
            </div>
          </div>

          <div className="dropdown is-hoverable navbar-item">
            <div className="dropdown-trigger">
              <button className="button">
                <span>CONTENT</span>
                <span className="icon">
                  <FontAwesomeIcon icon={faAngleDown} />
                </span>
              </button>
            </div>
            <div className="dropdown-menu" role="menu">
              <div className="dropdown-content">
                {combinedLinks.map((item, index) => (
                  item.type === 'link' ? (
                    <Link
                      key={item.path}
                      to={item.path}
                      className="dropdown-item"
                      onClick={closeMenus}
                    >
                      <span className="icon">
                        <FontAwesomeIcon icon={item.icon} />
                      </span>
                      {item.label}
                    </Link>
                  ) : (
                    <hr key={`divider-${index}`} className="dropdown-divider" />
                  )
                ))}
              </div>
            </div>
          </div>

          <div className="navbar-item">
            <form onSubmit={handleSearchSubmit} className="control has-icons-left">
              <input
                className="input search-term"
                type="text"
                placeholder="SEARCH"
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
              />
              <span className="icon is-left">
                <FontAwesomeIcon icon={faSearch} />
              </span>
            </form>
          </div>

          {!user && (
            <div className="navbar-item">
              <Link
                to="/login"
                className="button login-btn"
                onClick={() => {
                  if (typeof window !== "undefined") {
                    localStorage.setItem("redirectAfterLogin", window.location.pathname);
                  }
                  closeMenus();
                }}
              >
                <div className="icon">
                  <FontAwesomeIcon icon={faRightToBracket} />
                </div>
                LOGIN
              </Link>
            </div>
          )}
        </div>

        {user && (
          <div className="navbar-end">
            <div className="navbar-item">
              <div className="dropdown is-hoverable navbar-item">
                <div className="dropdown-trigger user-dropdown">
                  <button className="button">
                    <span className="icon">
                      <FontAwesomeIcon icon={faUser} />
                    </span>
                    <span>{user.username}</span>
                  </button>
                </div>
                <div className="dropdown-menu" role="menu">
                  <div className="dropdown-content">
                    <a href="#logout" className="navbar-item" onClick={(e) => {
                      e.preventDefault();
                      handleLogout();
                    }}>
                      <span className="icon">
                        <FontAwesomeIcon icon={faCircleXmark} />
                      </span>
                      Logout
                    </a>
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}
      </div>
    </nav>
  );
};

export default Navbar;
