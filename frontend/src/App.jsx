import React, { useState, useEffect } from 'react'
import { login } from './login'
import axiosClient from './axiosClient'
import 'bootstrap/dist/css/bootstrap.min.css'

// Add CSS for lighter placeholder text
const placeholderStyles = `
  .form-control::placeholder,
  .form-select::placeholder {
    color: #bbb !important;
    opacity: 1;
  }
  
  .form-control::-webkit-input-placeholder,
  .form-select::-webkit-input-placeholder {
    color: #bbb !important;
  }
  
  .form-control::-moz-placeholder,
  .form-select::-moz-placeholder {
    color: #bbb !important;
    opacity: 1;
  }
  
  .form-control:-ms-input-placeholder,
  .form-select:-ms-input-placeholder {
    color: #bbb !important;
  }

  /* Eliminate horizontal gutters */
  .row,
  [class*='col-'] {
    margin-left: 0 !important;
    margin-right: 0 !important;
    padding-left: 0 !important;
    padding-right: 0 !important;
  }
`;

function App() {
  const [isLoggedIn, setIsLoggedIn] = useState(false)
  const [userEmail, setUserEmail] = useState('')

  // Mercado Scraper state
  const [view, setView] = useState('create')
  const [queries, setQueries] = useState([])
  const [message, setMessage] = useState('')
  const [results, setResults] = useState([])
  const [queryId, setQueryId] = useState('')
  const [clients, setClients] = useState([])

  // For Query Posting and Viewing
  const [queryForm, setQueryForm] = useState({
    query_text: '',
    client_id: '',
    frequency: '',
    pages_to_scrape: 1,
  })

  // For Client Creation
  const [clientForm, setClientForm] = useState({
    client_name: '',
    client_email: '',
  })

  useEffect(() => {
    // Check for tokens in URL fragment (after Cognito callback)
    const hash = window.location.hash;
    if (hash) {
      const params = new URLSearchParams(hash.substring(1)); // Remove the '#'
      const idToken = params.get('id_token');
      const accessToken = params.get('access_token');
      
      if (idToken && accessToken) {
        // Save tokens to localStorage
        localStorage.setItem('id_token', idToken);
        localStorage.setItem('access_token', accessToken);
        
        // Clean up the URL
        window.history.replaceState(null, null, window.location.pathname);
        
        setIsLoggedIn(true);
        
        // Decode the JWT to get user info
        try {
          const tokenPayload = JSON.parse(atob(idToken.split('.')[1]));
          setUserEmail(tokenPayload.email || 'Unknown user');
        } catch (error) {
          console.error('Error decoding token:', error);
          setUserEmail('Unknown user');
        }
        
        return; // Exit early since we found tokens in URL
      }
    }
    
    // Check if user is already logged in by looking for tokens in localStorage
    const storedIdToken = localStorage.getItem('id_token');
    const storedAccessToken = localStorage.getItem('access_token');
    
    if (storedIdToken && storedAccessToken) {
      setIsLoggedIn(true);
      
      // Decode the JWT to get user info
      try {
        const tokenPayload = JSON.parse(atob(storedIdToken.split('.')[1]));
        setUserEmail(tokenPayload.email || 'Unknown user');
      } catch (error) {
        console.error('Error decoding token:', error);
        setUserEmail('Unknown user');
      }
    }
  }, [])

  // Change handler for query form
  const handleQueryChange = (e) => {
    setQueryForm({ ...queryForm, [e.target.name]: e.target.value })
  }

  // Change handler for client form
  const handleClientChange = (e) => {
    setClientForm({ ...clientForm, [e.target.name]: e.target.value })
  }

  // Fetch all clients
  const fetchClients = async () => {
    try {
      console.log('Fetching clients...')
      const response = await axiosClient.get('/client')
      console.log('Clients response:', response.data)
      setClients(response.data)
      if (response.data.length === 0) {
        setMessage('⚠️ No clients found. Please create a client first.')
      }
    } catch (error) {
      console.error('Error fetching clients:', error)
      setMessage('❌ Error fetching clients: ' + (error.response?.data?.detail || error.message))
    }
  }

  // Load clients when component mounts and user is logged in
  useEffect(() => {
    if (isLoggedIn) {
      fetchClients()
    }
  }, [isLoggedIn])

  // Trigger scraping by posting to the endpoint
  const handleTriggerScrape = async () => {
    try {
      const response = await axiosClient.post('/trigger-scrape')
      setMessage(response.data.message || 'Scrape triggered successfully!')
    } catch (error) {
      setMessage('❌ Error triggering scrape: ' + (error.response?.data?.detail || error.message))
    }
  }

  // Submit new query using axiosClient
  const handleQuerySubmit = async (e) => {
    e.preventDefault()
    try {
      const response = await axiosClient.post('/query', {
        ...queryForm,
        client_id: parseInt(queryForm.client_id),
        pages_to_scrape: parseInt(queryForm.pages_to_scrape),
      })
      const data = response.data
      if (data.query) {
        setMessage('✅ Query created successfully!')
      } else {
        setMessage('❌ ' + data.error)
      }
    } catch (error) {
      setMessage('❌ Error: ' + (error.response?.data?.detail || error.message))
    }
  }

  // Load queries for a given client_id using axiosClient
  const fetchQueries = async () => {
    if (!queryForm.client_id) {
      setMessage("⚠️ Please enter a Client ID to load queries.")
      return
    }
    try {
      const response = await axiosClient.get(`/query?client_id=${queryForm.client_id}`)
      setQueries(response.data)
      setMessage('')
    } catch (error) {
      setMessage('❌ Error fetching queries: ' + (error.response?.data?.detail || error.message))
    }
  }

  // Submit new client using axiosClient
  const handleClientSubmit = async (e) => {
    e.preventDefault()
    try {
      const response = await axiosClient.post('/client', clientForm)
      const data = response.data
      if (data.message) {
        setMessage('✅ ' + data.message)
        // Clear the form
        setClientForm({ client_name: '', client_email: '' })
        // Refresh the clients list
        fetchClients()
      } else {
        setMessage('❌ ' + (data.detail || data.error))
      }
    } catch (error) {
      setMessage('❌ Error: ' + (error.response?.data?.detail || error.message))
    }
  }

  // Fetch product results for a given query ID using axiosClient
  const fetchResults = async () => {
    if (!queryId) {
      setMessage("⚠️ Please enter a Query ID to load results.")
      return
    }
    try {
      const response = await axiosClient.get(`/query/results?query_id=${queryId}`)
      setResults(response.data)
      setMessage('')
    } catch (error) {
      setMessage('❌ Error fetching results: ' + (error.response?.data?.detail || error.message))
    }
  }

  const logout = () => {
    // Clear tokens from localStorage
    localStorage.removeItem('id_token')
    localStorage.removeItem('access_token')
    setIsLoggedIn(false)
    setUserEmail('')
    
    // Optionally redirect to Cognito logout URL
    const domain = import.meta.env.VITE_COGNITO_DOMAIN
    const region = import.meta.env.VITE_COGNITO_REGION
    const clientId = import.meta.env.VITE_COGNITO_CLIENT_ID
    const logoutUri = import.meta.env.VITE_COGNITO_LOGOUT_URI || window.location.origin
    
    if (domain && region && clientId) {
      window.location.href = `https://${domain}.auth.${region}.amazoncognito.com/logout?client_id=${clientId}&logout_uri=${encodeURIComponent(logoutUri)}`
    }
  }

  if (isLoggedIn) {
    return (
      <div style={{ 
        backgroundColor: '#fff159', 
        minHeight: '100vh',
        background: 'linear-gradient(135deg, #fff159 0%, #ffeb3b 50%, #fdd835 100%)',
        width: '100vw',
        overflowX: 'hidden'
      }}>
        {/* Inject placeholder styles */}
        <style>{placeholderStyles}</style>
        
        {/* Header Section */}
        <div style={{ 
          backgroundColor: '#3483fa', 
          boxShadow: '0 2px 10px rgba(0,0,0,0.1)',
          marginBottom: '30px'
        }}>
          <div className="container-fluid py-4 px-4">
            <div className="d-flex justify-content-between align-items-center">
              <div>
                <h1 style={{ 
                  color: 'white', 
                  fontWeight: 'bold', 
                  fontSize: '2.5rem',
                  margin: 0,
                  textShadow: '2px 2px 4px rgba(0,0,0,0.3)'
                }}>
                  🛒 Mercado Scrape
                </h1>
                <p style={{ 
                  color: '#e3f2fd', 
                  margin: 0, 
                  fontSize: '1.1rem' 
                }}>
                  Tu herramienta de análisis de precios
                </p>
              </div>
              <div className="d-flex align-items-center gap-3">
                <span className="text-white">Welcome, {userEmail}</span>
                <button
                  onClick={logout}
                  className="btn btn-outline-light px-4 py-2"
                  style={{ fontWeight: '600' }}
                >
                  Logout
                </button>
              </div>
            </div>
          </div>
        </div>

        <div className="container-fluid pb-5 px-0">
          {/* Navigation Cards */}
          <div className="row mb-4">
            <div className="col-12">
              <div className="d-flex justify-content-center flex-wrap gap-3">
                <button 
                  className={`btn btn-lg px-4 py-3 rounded-pill shadow-sm ${
                    view === 'create' 
                      ? 'btn-primary text-white' 
                      : 'btn-light border-2'
                  }`}
                  style={{ 
                    fontWeight: '600',
                    transition: 'all 0.3s ease',
                    border: view === 'create' ? '2px solid #3483fa' : '2px solid #ddd'
                  }} 
                  onClick={() => setView('create')}
                >
                  ➕ Crear Consulta
                </button>
                <button 
                  className={`btn btn-lg px-4 py-3 rounded-pill shadow-sm ${
                    view === 'view' 
                      ? 'btn-primary text-white' 
                      : 'btn-light border-2'
                  }`}
                  style={{ 
                    fontWeight: '600',
                    transition: 'all 0.3s ease',
                    border: view === 'view' ? '2px solid #3483fa' : '2px solid #ddd'
                  }} 
                  onClick={() => { 
                    setView('view')
                    fetchQueries()
                  }}
                >
                  📋 Ver Consultas
                </button>
                <button 
                  className={`btn btn-lg px-4 py-3 rounded-pill shadow-sm ${
                    view === 'results' 
                      ? 'btn-primary text-white' 
                      : 'btn-light border-2'
                  }`}
                  style={{ 
                    fontWeight: '600',
                    transition: 'all 0.3s ease',
                    border: view === 'results' ? '2px solid #3483fa' : '2px solid #ddd'
                  }} 
                  onClick={() => setView('results')}
                >
                  📦 Ver Resultados
                </button>
                <button 
                  className={`btn btn-lg px-4 py-3 rounded-pill shadow-sm ${
                    view === 'client' 
                      ? 'btn-primary text-white' 
                      : 'btn-light border-2'
                  }`}
                  style={{ 
                    fontWeight: '600',
                    transition: 'all 0.3s ease',
                    border: view === 'client' ? '2px solid #3483fa' : '2px solid #ddd'
                  }} 
                  onClick={() => setView('client')}
                >
                  👤 Crear Cliente
                </button>
              </div>
            </div>
          </div>

          {/* Message Alert */}
          {message && (
            <div className="row mb-4">
              <div className="col-12">
                <div className="alert alert-info shadow-sm border-0 rounded-3" style={{
                  backgroundColor: message.includes('✅') ? '#d4edda' : message.includes('❌') ? '#f8d7da' : '#d1ecf1',
                  color: message.includes('✅') ? '#155724' : message.includes('❌') ? '#721c24' : '#0c5460',
                  fontSize: '1.1rem',
                  fontWeight: '500'
                }}>
                  {message}
                </div>
              </div>
            </div>
          )}

          {/* Create Query Form */}
          {view === 'create' && (
            <div className="row justify-content-center">
              <div className="col-12" style={{ maxWidth: '800px' }}>
                <div className="card shadow-lg border-0 rounded-4" style={{ backgroundColor: 'white' }}>
                  <div className="card-header" style={{ 
                    backgroundColor: '#3483fa', 
                    color: 'white',
                    fontWeight: '600',
                    fontSize: '1.2rem',
                    borderRadius: '1.5rem 1.5rem 0 0'
                  }}>
                    ➕ Crear Nueva Consulta de Productos
                  </div>
                  <div className="card-body p-4">
                    <form onSubmit={handleQuerySubmit}>
                      <div className="row g-3">
                        <div className="col-md-12">
                          <label className="form-label fw-bold" style={{ color: '#666' }}>
                            Texto de búsqueda
                          </label>
                          <input 
                            type="text" 
                            className="form-control form-control-lg rounded-3" 
                            name="query_text" 
                            placeholder="ej: iPhone 15 Pro Max" 
                            onChange={handleQueryChange} 
                            required
                            style={{ border: '2px solid #e0e0e0', fontSize: '1.1rem' }}
                          />
                        </div>
                        <div className="col-md-4">
                          <label className="form-label fw-bold" style={{ color: '#666' }}>
                            Seleccionar Cliente
                          </label>
                          <select 
                            className="form-select form-select-lg rounded-3" 
                            name="client_id" 
                            value={queryForm.client_id}
                            onChange={handleQueryChange} 
                            required
                            style={{ border: '2px solid #e0e0e0', fontSize: '1.1rem' }}
                          >
                            <option value="">Selecciona un cliente...</option>
                            {clients.map((client) => (
                              <option key={client.id} value={client.id}>
                                ID: {client.id} - {client.name} ({client.email})
                              </option>
                            ))}
                          </select>
                        </div>
                        <div className="col-md-4">
                          <label className="form-label fw-bold" style={{ color: '#666' }}>
                            Frecuencia
                          </label>
                          <input 
                            type="text" 
                            className="form-control form-control-lg rounded-3" 
                            name="frequency" 
                            placeholder="daily" 
                            onChange={handleQueryChange} 
                            required
                            style={{ border: '2px solid #e0e0e0', fontSize: '1.1rem' }}
                          />
                        </div>
                        <div className="col-md-4">
                          <label className="form-label fw-bold" style={{ color: '#666' }}>
                            Páginas a Escanear
                          </label>
                          <input 
                            type="number" 
                            className="form-control form-control-lg rounded-3" 
                            name="pages_to_scrape" 
                            placeholder="1" 
                            onChange={handleQueryChange} 
                            required
                            style={{ border: '2px solid #e0e0e0', fontSize: '1.1rem' }}
                          />
                        </div>
                      </div>
                      <button 
                        className="btn btn-success btn-lg mt-4 px-5 py-3 rounded-pill shadow" 
                        type="submit"
                        style={{ 
                          fontWeight: '600',
                          fontSize: '1.1rem',
                          background: 'linear-gradient(45deg, #00a650, #00b956)',
                          border: 'none'
                        }}
                      >
                        🚀 Crear Consulta
                      </button>
                    </form>
                  </div>
                </div>
              </div>
            </div>
          )}

          {/* View Queries */}
          {view === 'view' && (
            <div className="row justify-content-center">
              <div className="col-12" style={{ maxWidth: '1000px' }}>
                <div className="card shadow-lg border-0 rounded-4" style={{ backgroundColor: 'white' }}>
                  <div className="card-header" style={{ 
                    backgroundColor: '#3483fa', 
                    color: 'white',
                    fontWeight: '600',
                    fontSize: '1.2rem',
                    borderRadius: '1.5rem 1.5rem 0 0'
                  }}>
                    📋 Consultas Existentes
                  </div>
                  <div className="card-body p-4">
                    <div className="row mb-4">
                      <div className="col-md-4">
                        <label className="form-label fw-bold" style={{ color: '#666' }}>
                          Seleccionar Cliente
                        </label>
                        <select 
                          className="form-select form-select-lg rounded-3" 
                          name="client_id" 
                          value={queryForm.client_id} 
                          onChange={handleQueryChange}
                          style={{ border: '2px solid #e0e0e0', fontSize: '1.1rem' }}
                        >
                          <option value="">Selecciona un cliente...</option>
                          {clients.map((client) => (
                            <option key={client.id} value={client.id}>
                              ID: {client.id} - {client.name} ({client.email})
                            </option>
                          ))}
                        </select>
                      </div>
                      <div className="col-md-4 d-flex align-items-end">
                        <button 
                          className="btn btn-primary btn-lg px-4 py-3 rounded-pill shadow" 
                          onClick={fetchQueries}
                          style={{ fontWeight: '600' }}
                        >
                          🔍 Cargar Consultas
                        </button>
                      </div>
                    </div>
                    
                    <div className="row">
                      {queries.length === 0 ? (
                        <div className="col-12 text-center py-5">
                          <div style={{ fontSize: '3rem', marginBottom: '1rem' }}>📋</div>
                          <h4 style={{ color: '#666' }}>No se encontraron consultas</h4>
                          <p style={{ color: '#999' }}>Ingresa un ID de cliente válido para ver las consultas</p>
                        </div>
                      ) : (
                        queries.map((q, index) => (
                          <div key={index} className="col-md-6 mb-3">
                            <div className="card border-0 shadow-sm rounded-3" style={{ 
                              border: '1px solid #e0e0e0',
                              transition: 'transform 0.2s ease'
                            }}>
                              <div className="card-body p-3">
                                <div className="d-flex justify-content-between align-items-start mb-2">
                                  <h6 className="card-title text-primary fw-bold mb-0">
                                    🔍 {q.query_text}
                                  </h6>
                                  <span className="badge bg-info text-dark fs-6 px-2 py-1 rounded-pill">
                                    ID: {q.query_id}
                                  </span>
                                </div>
                                <div className="small text-muted">
                                  <div><strong>Cliente:</strong> {q.client_id}</div>
                                  <div><strong>Frecuencia:</strong> {q.frequency}</div>
                                  <div><strong>Páginas:</strong> {q.pages_to_scrape}</div>
                                </div>
                              </div>
                            </div>
                          </div>
                        ))
                      )}
                    </div>
                  </div>
                </div>
              </div>
            </div>
          )}

          {/* View Results */}
          {view === 'results' && (
            <div className="row justify-content-center">
              <div className="col-12" style={{ maxWidth: '1200px' }}>
                <div className="card shadow-lg border-0 rounded-4" style={{ backgroundColor: 'white' }}>
                  <div className="card-header" style={{ 
                    backgroundColor: '#3483fa', 
                    color: 'white',
                    fontWeight: '600',
                    fontSize: '1.2rem',
                    borderRadius: '1.5rem 1.5rem 0 0'
                  }}>
                    📦 Resultados de Productos
                  </div>
                  <div className="card-body p-4">
                    <div className="row mb-4">
                      <div className="col-md-8">
                        <label className="form-label fw-bold" style={{ color: '#666' }}>
                          ID de la Consulta
                        </label>
                        <input 
                          type="number" 
                          className="form-control form-control-lg rounded-3" 
                          placeholder="Ej: 123 (ver en 'Ver Consultas')" 
                          value={queryId} 
                          onChange={(e) => setQueryId(e.target.value)}
                          style={{ border: '2px solid #e0e0e0', fontSize: '1.1rem' }}
                        />
                        <small className="text-muted mt-1">
                          💡 Puedes encontrar el ID en la sección "Ver Consultas"
                        </small>
                      </div>
                      <div className="col-md-4 d-flex align-items-end">
                        <button 
                          className="btn btn-primary btn-lg px-4 py-3 rounded-pill shadow w-100" 
                          onClick={fetchResults}
                          style={{ fontWeight: '600' }}
                        >
                          📥 Cargar Resultados
                        </button>
                      </div>
                    </div>

                    <div className="row">
                      {results.length === 0 ? (
                        <div className="col-12 text-center py-5">
                          <div style={{ fontSize: '3rem', marginBottom: '1rem' }}>📦</div>
                          <h4 style={{ color: '#666' }}>No se encontraron resultados</h4>
                          <p style={{ color: '#999' }}>Ingresa un ID de consulta válido para ver los productos</p>
                        </div>
                      ) : (
                        results.map((r, index) => (
                          <div key={index} className="col-md-6 mb-3">
                            <div className="card border-0 shadow-sm rounded-3" style={{ 
                              border: '1px solid #e0e0e0',
                              transition: 'transform 0.2s ease'
                            }}>
                              <div className="card-body p-3">
                                <div className="row">
                                  <div className="col-4">
                                    <img 
                                      src={r.listings[0]?.img_url || 'https://via.placeholder.com/120x120?text=Sin+Imagen'} 
                                      alt={r.title || r.id} 
                                      style={{ 
                                        width: '100%',
                                        height: '120px',
                                        objectFit: 'cover',
                                        borderRadius: '8px'
                                      }}
                                    />
                                  </div>
                                  <div className="col-8">
                                    <div className="d-flex justify-content-between align-items-start mb-2">
                                      <h6 className="card-title text-primary fw-bold mb-0" style={{
                                        fontSize: '0.9rem',
                                        lineHeight: '1.2',
                                        overflow: 'hidden',
                                        display: '-webkit-box',
                                        WebkitLineClamp: 2,
                                        WebkitBoxOrient: 'vertical'
                                      }}>
                                        🛍️ {r.title || `Producto ${r.id}`}
                                      </h6>
                                    </div>
                                    <div className="small text-muted mb-2">
                                      {r.listings && r.listings.length > 0 ? (
                                        r.listings.map((listing, idx) => {
                                          const latestPrice = listing.prices && listing.prices.length > 0 
                                            ? listing.prices[listing.prices.length - 1] 
                                            : null;
                                          return (
                                            <div key={idx} className="mb-2 pb-2" style={{ borderBottom: idx < r.listings.length - 1 ? '1px solid #eee' : 'none' }}>
                                              <div className="d-flex justify-content-between align-items-center">
                                                <div>
                                                  <div><strong>Precio:</strong> ${latestPrice && latestPrice.price ? latestPrice.price.toLocaleString() : 'N/A'}</div>
                                                  <div><strong>Tienda:</strong> MercadoLibre</div>
                                                </div>
                                                <div>
                                                  <a 
                                                    href={listing.url || '#'} 
                                                    target="_blank" 
                                                    rel="noopener noreferrer" 
                                                    className="btn btn-warning btn-sm rounded-pill px-2 py-1"
                                                    style={{ 
                                                      fontWeight: '600',
                                                      fontSize: '0.7rem',
                                                      backgroundColor: '#fff159',
                                                      border: '1px solid #f57c00',
                                                      color: '#333'
                                                    }}
                                                  >
                                                    Ver
                                                  </a>
                                                </div>
                                              </div>
                                            </div>
                                          );
                                        })
                                      ) : (
                                        <div>Sin información de precio</div>
                                      )}
                                    </div>
                                  </div>
                                </div>
                              </div>
                            </div>
                          </div>
                        ))
                      )}
                    </div>
                  </div>
                </div>
              </div>
            </div>
          )}

          {/* Create Client Form */}
          {view === 'client' && (
            <div className="row justify-content-center">
              <div className="col-12" style={{ maxWidth: '600px' }}>
                <div className="card shadow-lg border-0 rounded-4" style={{ backgroundColor: 'white' }}>
                  <div className="card-header" style={{ 
                    backgroundColor: '#3483fa', 
                    color: 'white',
                    fontWeight: '600',
                    fontSize: '1.2rem',
                    borderRadius: '1.5rem 1.5rem 0 0'
                  }}>
                    👤 Crear Nuevo Cliente
                  </div>
                  <div className="card-body p-4">
                    <form onSubmit={handleClientSubmit}>
                      <div className="row g-3">
                        <div className="col-12">
                          <label className="form-label fw-bold" style={{ color: '#666' }}>
                            Nombre del Cliente
                          </label>
                          <input 
                            type="text" 
                            className="form-control form-control-lg rounded-3" 
                            name="client_name" 
                            placeholder="ej: Juan Pérez" 
                            value={clientForm.client_name}
                            onChange={handleClientChange} 
                            required
                            style={{ border: '2px solid #e0e0e0', fontSize: '1.1rem' }}
                          />
                        </div>
                        <div className="col-12">
                          <label className="form-label fw-bold" style={{ color: '#666' }}>
                            Email del Cliente
                          </label>
                          <input 
                            type="email" 
                            className="form-control form-control-lg rounded-3" 
                            name="client_email" 
                            placeholder="ej: juan@email.com" 
                            value={clientForm.client_email}
                            onChange={handleClientChange} 
                            required
                            style={{ border: '2px solid #e0e0e0', fontSize: '1.1rem' }}
                          />
                        </div>
                      </div>
                      <button 
                        className="btn btn-success btn-lg mt-4 px-5 py-3 rounded-pill shadow w-100" 
                        type="submit"
                        style={{ 
                          fontWeight: '600',
                          fontSize: '1.1rem',
                          background: 'linear-gradient(45deg, #00a650, #00b956)',
                          border: 'none'
                        }}
                      >
                        ✨ Crear Cliente
                      </button>
                    </form>
                  </div>
                </div>
              </div>
            </div>
          )}
        </div>
      </div>
    )
  }

  return (
    <div style={{ 
      backgroundColor: '#fff159', 
      minHeight: '100vh',
      background: 'linear-gradient(135deg, #fff159 0%, #ffeb3b 50%, #fdd835 100%)',
      width: '100vw',
      overflowX: 'hidden',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center'
    }}>
      <div className="container-fluid">
        <div className="row justify-content-center">
          <div className="col-12" style={{ maxWidth: '500px' }}>
            <div className="text-center mb-5">
              <h1 style={{ 
                color: '#3483fa', 
                fontWeight: 'bold', 
                fontSize: '3.5rem',
                margin: 0,
                textShadow: '2px 2px 4px rgba(0,0,0,0.1)',
                marginBottom: '10px'
              }}>
                🛒 Mercado Scrape
              </h1>
              <p style={{ 
                color: '#666', 
                margin: 0, 
                fontSize: '1.3rem',
                fontWeight: '500'
              }}>
                Tu herramienta de análisis de precios
              </p>
            </div>
            
            <div className="card shadow-lg border-0 rounded-4" style={{ backgroundColor: 'white' }}>
              <div className="card-header text-center" style={{ 
                backgroundColor: '#3483fa', 
                color: 'white',
                fontWeight: '600',
                fontSize: '1.3rem',
                borderRadius: '1.5rem 1.5rem 0 0',
                padding: '20px'
              }}>
                🔐 Iniciar Sesión
              </div>
              <div className="card-body p-5 text-center">
                <div className="mb-4">
                  <div style={{ fontSize: '4rem', marginBottom: '1rem' }}>👋</div>
                  <h4 style={{ color: '#666', marginBottom: '1rem' }}>¡Bienvenido!</h4>
                  <p style={{ color: '#999', fontSize: '1.1rem', marginBottom: '2rem' }}>
                    Inicia sesión para acceder a tu panel de control y comenzar a monitorear precios en MercadoLibre
                  </p>
                </div>
                
                <button
                  onClick={login}
                  className="btn btn-lg px-5 py-3 rounded-pill shadow"
                  style={{ 
                    fontWeight: '600',
                    fontSize: '1.2rem',
                    background: 'linear-gradient(45deg, #3483fa, #1976d2)',
                    border: 'none',
                    color: 'white',
                    transition: 'all 0.3s ease',
                    width: '100%'
                  }}
                  onMouseOver={(e) => {
                    e.target.style.transform = 'translateY(-2px)';
                    e.target.style.boxShadow = '0 8px 25px rgba(52, 131, 250, 0.3)';
                  }}
                  onMouseOut={(e) => {
                    e.target.style.transform = 'translateY(0)';
                    e.target.style.boxShadow = '0 4px 15px rgba(0,0,0,0.1)';
                  }}
                >
                  🚀 Iniciar Sesión con Cognito
                </button>
                
                <div className="mt-4">
                  <small style={{ color: '#999' }}>
                    Autenticación segura con AWS Cognito
                  </small>
                </div>
              </div>
            </div>
            
            <div className="text-center mt-4">
              <small style={{ color: '#666', fontSize: '0.9rem' }}>
                💡 Monitorea precios • 📊 Analiza tendencias • 🎯 Toma mejores decisiones
              </small>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}

export default App
