window.YearList = function() {
  const [erasData, setErasData] = React.useState({});

  React.useEffect(() => {
    const apiKey = window.API_KEY;

    fetch(`/api/v1/eras`, {
      headers: {
        'Authorization': `Bearer ${apiKey}`
      }
    })
    .then(response => response.json())
    .then(data => {
      if (data.success) {
        const sortedErasData = {};
        const sortedEras = Object.keys(data.data).sort().reverse();
        sortedEras.forEach(era => {
          sortedErasData[era] = data.data[era].sort((a, b) => b - a);
        });
        setErasData(sortedErasData);
      }
    })
    .catch(error => console.error('Error fetching eras:', error));
  }, []);

  return (
    <div className='yearlist-container'>
      {Object.entries(erasData).map(([era, years]) => (
        <div key={era} className='era-container'>
          <h2 className='era-header'>{era}</h2>
          {years.map(year => (
            <div key={year} className='year-item'>
              {year}
            </div>
          ))}
        </div>
      ))}
    </div>
  );
}
