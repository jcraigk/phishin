import PropTypes from 'prop-types';
import React, { useState } from 'react';
// import style from './HelloWorld.module.css';

const PlayerContext = React.createContext();
const PlayerProvider = PlayerContext.Provider;
const PlayerConsumer = PlayerContext.Consumer;

const App = (props) => {
  const apiKey = window.API_KEY;
  const emptyShow = {
    date: '',
    city: '',
    venue: '',
    tracks: []
  };
  const [trackSelected, setTrackSelected] = React.useState(false); // TODO put this in context

  return (
    <>
      <PlayerProvider value={{ show: emptyShow, current_track_id: null }}>
        <Header />
        <YearList />
        {trackSelected && <Footer />}
      </PlayerProvider>
    </>
  )
}

export default App;
