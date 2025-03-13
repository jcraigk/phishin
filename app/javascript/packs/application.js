// Images and CSS
const images = require.context('../images', true)
const imagePath = (name) => images(name, true)
import "../stylesheets/application.scss";

// React on Rails app
import ReactOnRails from "react-on-rails";
import App from "../components/App";
ReactOnRails.register({ App });
