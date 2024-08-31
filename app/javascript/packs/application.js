// Images
const images = require.context("../images", true)
const imagePath = (name) => images(name, true)

// Global dependencies
import "jquery/src/jquery"
import "jquery-ujs"
import "bootstrap/dist/js/bootstrap"

// CoffeeScript bundle
import "../src/coffeescript/app.js.coffee"

document.addEventListener("DOMContentLoaded", () => {
  document.fonts.ready.then(() => {
    document.body.classList.remove("fonts-loading");
  });
});
