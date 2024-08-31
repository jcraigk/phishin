import ReactOnRails from 'react-on-rails';
import '../stylesheets/react.css.scss';

import HelloWorld from '../components/HelloWorld';

// This is how react_on_rails can see the HelloWorld in the browser.
ReactOnRails.register({
  HelloWorld,
});
