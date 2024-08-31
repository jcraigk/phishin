import React, { useState } from "react";
import PropTypes from "prop-types";

import Header from "./Header";
import Footer from "./Footer";

const App = (props) => {
  const [appName, setAppName] = useState(props.app_name);

  return (
    <div className="bg-blue-500 p-4 rounded text-white">
      <h3 className="text-xl">Hello, {appName}!</h3>
      <hr className="my-4" />
      <form>
        <label className="block text-sm font-bold mb-2" htmlFor="name">
          Say <span className="special">hello</span> to:
        </label>
        <input
          id="name"
          type="text"
          value={appName}
          onChange={(e) => setAppName(e.target.value)}
          className="p-2 border border-gray-300 rounded w-full"
        />
      </form>
    </div>
  );
};

App.propTypes = {
  appName: PropTypes.string.isRequired, // this is passed from the Rails view
};

export default App;






// import PropTypes from "prop-types";
// import React, { useState } from "react";

// import Header from "./Header";
// import Footer from "./Footer";

// // const PlayerContext = React.createContext();
// // const PlayerProvider = PlayerContext.Provider;
// // const PlayerConsumer = PlayerContext.Consumer;

// const App = (props) => {
//   const [appName, setAppName] = useState(props.app_name);
//   // const apiKey = window.API_KEY;
//   const emptyShow = {
//     date: "",
//     location: "",
//     venue_name: "",
//     tracks: []
//   };
//   // const [trackSelected, setTrackSelected] = React.useState(false); // TODO put this in context

//   return (
//     <>
//       <PlayerProvider value={{ show: emptyShow, current_track_id: null }}>
//         <Header />
//         {/* <YearList /> */}
//         {trackSelected && <Footer />}
//       </PlayerProvider>
//     </>
//   )
// }

// HelloWorld.propTypes = {
//   app_name: PropTypes.string.isRequired,
// };

// export default App;
