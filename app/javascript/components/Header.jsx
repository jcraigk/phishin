const Header = ({ title = 'Eras of Phish', backRoute = null}) => {
  return (
    <div className='header-container'>
      { backRoute && <Link to={backRoute} className='back-button'>&lt;</Link> }
      <h1>{title}</h1>
    </div>
  );
}

Header.propTypes = {
  title: PropTypes.string,
  backRoute: PropTypes.string
};

export default Header;
