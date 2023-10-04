const images = require.context('../images', true)
const imagePath = (name) => images(name, true)

import 'jquery/src/jquery';

import 'jquery-ui/ui/widgets/slider'
import 'jquery-ui/ui/widgets/sortable'
import 'jquery-ujs'
import 'jquery.cookie'
// import 'bootstrap/dist/js/bootstrap';
import History from 'historyjs/scripts/uncompressed/history'

import App from '../src/coffeescript/app-main.js.coffee';
import 'soundmanager2'
