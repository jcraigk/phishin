import PropTypes from 'prop-types';
import React, { useState } from 'react';

const HelloWorld = (props) => {
  const [name, setName] = useState(props.name);

  return (
    <div className="bg-blue-500 p-4 rounded text-white">
      <h3 className="text-xl">Hello, {name}!</h3>
      <hr className="my-4" />
      <form>
        <label className="block text-sm font-bold mb-2" htmlFor="name">
          Say <span className="special">hello</span> to:
        </label>
        <input
          id="name"
          type="text"
          value={name}
          onChange={(e) => setName(e.target.value)}
          className="p-2 border border-gray-300 rounded w-full"
        />
      </form>
    </div>
  );
};

HelloWorld.propTypes = {
  name: PropTypes.string.isRequired, // this is passed from the Rails view
};

export default HelloWorld;
