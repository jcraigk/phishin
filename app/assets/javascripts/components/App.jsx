const PlayerContext = React.createContext();
const PlayerProvider = PlayerContext.Provider;
const PlayerConsumer = PlayerContext.Consumer;

window.App = function() {
  const apiKey = window.API_KEY;
  const emptyShow = {
    date: '',
    city: '',
    venue: '',
    tracks: []
  };
  const [trackSelected, setTrackSelected] = React.useState(false); // TODO put this in context

  return (
    <React.Fragment>
      <PlayerProvider value={{ show: emptyShow, current_track_id: null }}>
        <Header />
        <YearList />
        {trackSelected && <Footer />}
      </PlayerProvider>
    </React.Fragment>
  )
}
