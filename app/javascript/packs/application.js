const images = require.context('../images', true)
const imagePath = (name) => images(name, true)

import ReactOnRails from "react-on-rails";
import "../stylesheets/application.css.scss";

import App from "../components/App";

ReactOnRails.register({
  App,
});
