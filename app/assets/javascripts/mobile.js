//= require soundmanager2
//= require react
//= require react_ujs
//= require_tree ./components

import React from 'react';
import ReactDOM from 'react-dom';
import App from '../components/App';

document.addEventListener('DOMContentLoaded', () => {
  ReactDOM.render(<App />, document.querySelector('#root'));
});
