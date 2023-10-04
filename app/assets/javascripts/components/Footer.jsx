window.Footer = function() {
  const { show, current_track_id } = React.useContext(PlayerContext);

  return (
    <div className='footer-container'>
      <div className='context-info'>
        <span>Date: {show.date}</span>
        <span>City: {show.city}</span>
      </div>
      {/* <AudioPlayer /> */}
    </div>
  );
}
