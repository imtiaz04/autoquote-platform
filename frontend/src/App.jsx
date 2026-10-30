import { useState } from 'react'
import './App.css'

function App() {
  const [driverAge, setDriverAge] = useState(
    () => localStorage.getItem('driverAge') || ''
  )

  const [vehicleYear, setVehicleYear] = useState(
    () => localStorage.getItem('vehicleYear') || ''
  )

  const [vehicleMake, setVehicleMake] = useState(
    () => localStorage.getItem('vehicleMake') || ''
  )

  const [vehicleModel, setVehicleModel] = useState(
    () => localStorage.getItem('vehicleModel') || ''
  )

  const [coverageType, setCoverageType] = useState(
    () => localStorage.getItem('coverageType') || ''
  )

  const [zipCode, setZipCode] = useState(
    () => localStorage.getItem('zipCode') || ''
  )

  const [quotes, setQuotes] = useState([])

  // Find the lowest monthly premium dynamically
  const lowestPremium =
    quotes.length > 0
      ? Math.min(...quotes.map((quote) => quote.monthly_premium))
      : null

  // Submit insurance details to the FastAPI backend
  async function handleCompareQuotes(event) {
    event.preventDefault()

    try {
      const response = await fetch('/quotes/compare', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          driver_age: Number(driverAge),
          zip_code: zipCode,
          vehicle_year: Number(vehicleYear),
          vehicle_make: vehicleMake,
          vehicle_model: vehicleModel,
          coverage_type: coverageType,
        }),
      })

      if (!response.ok) {
        throw new Error(`API request failed: ${response.status}`)
      }

      const data = await response.json()

      setQuotes(data.quotes)

      console.log('Insurance quotes received:', data)
    } catch (error) {
      setQuotes([])
      console.error('Error fetching insurance quotes:', error)
    }
  }

  return (
    <>
      {/* Purple Navigation Header */}
      <header className="site-header">
        <div className="header-content">
          <div className="site-logo">
            🚘 Auto<span>Quote</span>
          </div>

          <nav className="site-nav" aria-label="Main navigation">
            <span>Compare Quotes</span>
            <span>Save Money</span>
            <span>Trusted Providers</span>
          </nav>
        </div>
      </header>

      {/* Main Application */}
      <main>
        <h1>AutoQuote Insurance Comparison</h1>

        <p>
          Compare auto insurance quotes from multiple providers.
        </p>

        <h2>Get Your Insurance Quote</h2>

        {/* Insurance Quote Form */}
        <form onSubmit={handleCompareQuotes}>

          {/* Driver Age */}
          <div>
            <label htmlFor="driverAge">Driver Age</label>

            <input
              type="number"
              id="driverAge"
              name="driverAge"
              min="18"
              max="100"
              required
              value={driverAge}
              onChange={(event) => {
                const value = event.target.value
                setDriverAge(value)
                localStorage.setItem('driverAge', value)
              }}
              placeholder="Enter your age"
            />
          </div>

          {/* Vehicle Year */}
          <div>
            <label htmlFor="vehicleYear">Vehicle Year</label>

            <input
              type="number"
              id="vehicleYear"
              name="vehicleYear"
              min="1980"
              max={new Date().getFullYear() + 1}
              required
              value={vehicleYear}
              onChange={(event) => {
                const value = event.target.value
                setVehicleYear(value)
                localStorage.setItem('vehicleYear', value)
              }}
              placeholder="Enter vehicle year"
            />
          </div>

          {/* Vehicle Make */}
          <div>
            <label htmlFor="vehicleMake">Vehicle Make</label>

            <input
              type="text"
              id="vehicleMake"
              name="vehicleMake"
              required
              value={vehicleMake}
              onChange={(event) => {
                const value = event.target.value
                setVehicleMake(value)
                localStorage.setItem('vehicleMake', value)
              }}
              placeholder="e.g. Toyota"
            />
          </div>

          {/* Vehicle Model */}
          <div>
            <label htmlFor="vehicleModel">Vehicle Model</label>

            <input
              type="text"
              id="vehicleModel"
              name="vehicleModel"
              required
              value={vehicleModel}
              onChange={(event) => {
                const value = event.target.value
                setVehicleModel(value)
                localStorage.setItem('vehicleModel', value)
              }}
              placeholder="e.g. Camry"
            />
          </div>

          {/* Coverage Type */}
          <div>
            <label htmlFor="coverageType">Coverage Type</label>

            <select
              id="coverageType"
              name="coverageType"
              required
              value={coverageType}
              onChange={(event) => {
                const value = event.target.value
                setCoverageType(value)
                localStorage.setItem('coverageType', value)
              }}
            >
              <option value="">Select Coverage</option>
              <option value="liability">Liability Coverage</option>
              <option value="full">Full Coverage</option>
            </select>
          </div>

          {/* ZIP Code */}
          <div>
            <label htmlFor="zipCode">ZIP Code</label>

            <input
              type="text"
              id="zipCode"
              name="zipCode"
              placeholder="e.g. 08830"
              value={zipCode}
              maxLength={5}
              inputMode="numeric"
              pattern="[0-9]{5}"
              required
              onChange={(event) => {
                const value = event.target.value

                if (/^\d{0,5}$/.test(value)) {
                  setZipCode(value)
                  localStorage.setItem('zipCode', value)
                }
              }}
            />
          </div>

          {/* Compare Quotes Button */}
          <button type="submit">
            Compare Quotes
          </button>
        </form>

        {/* Entered Details Summary */}
        <section className="details-summary">
          <h2>Your Entered Details</h2>

          <div className="details-grid">
            <div>
              <strong>Driver Age:</strong>{' '}
              {driverAge || 'Not entered'}
            </div>

            <div>
              <strong>Vehicle Year:</strong>{' '}
              {vehicleYear || 'Not entered'}
            </div>

            <div>
              <strong>Vehicle Make:</strong>{' '}
              {vehicleMake || 'Not entered'}
            </div>

            <div>
              <strong>Vehicle Model:</strong>{' '}
              {vehicleModel || 'Not entered'}
            </div>
          </div>
        </section>

        {/* Insurance Comparison Results */}
        {quotes.length > 0 && (
          <section className="results-section">
            <h2>Insurance Comparison Results</h2>

            <p>
              Simulated insurance quotes for demonstration only.
            </p>

            <table className="comparison-table">
              <thead>
                <tr>
                  <th>Insurance Provider</th>
                  <th>Monthly Premium</th>
                  <th>Annual Premium</th>
                </tr>
              </thead>

              <tbody>
                {quotes.map((quote) => (
                  <tr
                    key={quote.provider}
                    className={
                      quote.monthly_premium === lowestPremium
                        ? 'best-price'
                        : ''
                    }
                  >
                    <td>
                      {quote.provider}

                      {quote.monthly_premium === lowestPremium && (
                        <span className="best-price-badge">
                          {' '}🏆 Best Price
                        </span>
                      )}
                    </td>

                    <td>
                      ${quote.monthly_premium.toFixed(2)}
                    </td>

                    <td>
                      ${quote.annual_premium.toFixed(2)}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </section>
        )}
      </main>
    </>
  )
}

export default App