window.YearList = function({ years }) {
  console.log('YearList', years)
  return <div>Years: {years.join(', ')}</div>
}

YearList.propTypes = {
  years: PropTypes.array
}
