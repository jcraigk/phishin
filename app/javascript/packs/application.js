const images = require.context('../images', true)
const imagePath = (name) => images(name, true)

import 'jquery/src/jquery';
import 'jquery-ujs'
import 'bootstrap/dist/js/bootstrap';
import 'historyjs/scripts/uncompressed/history'
import 'soundmanager2'

import App from '../src/coffeescript/app-main.js.coffee';
