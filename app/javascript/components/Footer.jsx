import React from "react"
import PropTypes from "prop-types"

const Footer = (props) => {
  const { show, current_track_id } = React.useContext(PlayerContext);

  return (
    <div className='footer-container'>
      <div className='context-info'>
        <span>Date: {show.date}</span>
        <span>Location: {show.location}</span>
      </div>
      {/* <AudioPlayer /> */}
    </div>
  );
}

Footer.propTypes = {
  show: PropTypes.shape({
    date: PropTypes.string.isRequired,
    location: PropTypes.string.isRequired,
  }).isRequired,
};

export default Footer;
