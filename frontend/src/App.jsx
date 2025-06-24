import React, { useState, useEffect, useContext } from 'react';
import axiosClient, { setAuthContext } from './axiosClient'; // Import your custom axios instance
import 'bootstrap/dist/css/bootstrap.min.css';
import { useAuth } from 'react-oidc-context';
import WipPage from './WipPage.jsx';

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
  // "create", "view", "results", "client"
  const [view, setView] = useState('create');
  const [queries, setQueries] = useState([]);
  const [message, setMessage] = useState('');

  const [results, setResults] = useState([]);
  const [queryId, setQueryId] = useState('');
  const [clients, setClients] = useState([]);

  // For Query Posting and Viewing
  const [queryForm, setQueryForm] = useState({
    query_text: '',
    client_id: '',
    frequency: '',
    pages_to_scrape: 1,
  });

  // For Client Creation
  const [clientForm, setClientForm] = useState({
    client_name: '',
    client_email: '',
  });

  const auth = useAuth();

  // Set up auth context for axios
  useEffect(() => {
    setAuthContext(() => auth);
  }, [auth]);

  // Determine user role
  const userGroups = auth.user?.profile['cognito:groups'] || [];
  const isAdmin = userGroups.includes('admins');
  const isUser = userGroups.includes('users');

  // Custom logout function with client_id
  const handleLogout = () => {
    const clientIdToken = "__VITE_COGNITO_CLIENT_ID__";
    const domainToken = "__VITE_COGNITO_DOMAIN__";
    
    // Fallback if tokens weren't replaced
    const clientId = clientIdToken.includes("__VITE_") ? "3mpvm5sole4132a8thrlkp43dn" : clientIdToken;
    const cognitoDomain = domainToken.includes("__VITE_") ? "https://mercado-close-monkey.auth.us-east-1.amazoncognito.com" : domainToken;
    
    const logoutUri = window.location.origin;
    
    // Clear local tokens first
    auth.removeUser();
    
    // Redirect to Cognito logout with proper parameters
    window.location.href = `${cognitoDomain}/logout?client_id=${clientId}&logout_uri=${encodeURIComponent(logoutUri)}`;
  };

  if (auth.isLoading) {
    return <div style={{padding:'2rem'}}>Loading authentication...</div>;
  }

  // Show error if there's a non-authentication error
  if (auth.error) {
    return <div style={{padding:'2rem', color: 'red'}}>Error: {auth.error.message}</div>;
  }

  // not authenticated – show login button instead of redirecting
  if (!auth.isAuthenticated) {
    return (
      <div style={{
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        minHeight: '100vh',
        background: 'linear-gradient(135deg, #fff159 0%, #ffeb3b 50%, #fdd835 100%)'
      }}>
        <div style={{
          background: 'white',
          padding: '2rem',
          borderRadius: '10px',
          boxShadow: '0 4px 20px rgba(0,0,0,0.1)',
          textAlign: 'center',
          maxWidth: '400px'
        }}>
          <h2 style={{ color: '#3483fa', marginBottom: '1rem' }}>🛒 Mercado Scrape</h2>
          <p style={{ marginBottom: '2rem', color: '#666' }}>
            Please login to access the application
          </p>
          <button
            onClick={() => auth.signinRedirect()}
            style={{
              display: 'inline-block',
              background: '#3483fa',
              color: 'white',
              padding: '12px 24px',
              borderRadius: '25px',
              border: 'none',
              cursor: 'pointer',
              fontWeight: 'bold',
              transition: 'all 0.3s ease'
            }}
            onMouseOver={(e) => e.target.style.background = '#2968c8'}
            onMouseOut={(e) => e.target.style.background = '#3483fa'}
          >
            Login with Cognito
          </button>
        </div>
      </div>
    );
  }

  // Show appropriate interface based on user role
  if (isUser && !isAdmin) {
    return <UserDashboard auth={auth} userGroups={userGroups} onLogout={handleLogout} />;
  }

  // If user has no recognized groups, show WIP page
  if (!isAdmin && !isUser) {
    return <WipPage onLogout={handleLogout} />;
  }

  // Admin interface continues below...

  // Change handler for query form
  const handleQueryChange = (e) => {
    setQueryForm({ ...queryForm, [e.target.name]: e.target.value });
  };

  // Change handler for client form
  const handleClientChange = (e) => {
    setClientForm({ ...clientForm, [e.target.name]: e.target.value });
  };

  // Fetch all clients
  const fetchClients = async () => {
    try {
      console.log('Fetching clients...');
      const response = await axiosClient.get('/client');
      console.log('Clients response:', response.data);
      setClients(response.data);
      if (response.data.length === 0) {
        setMessage('⚠️ No clients found. Please create a client first.');
      }
    } catch (error) {
      console.error('Error fetching clients:', error);
      setMessage('❌ Error fetching clients: ' + (error.response?.data?.detail || error.message));
    }
  };

  // Load clients when component mounts
  useEffect(() => {
    fetchClients();
  }, []);

  // Trigger scraping by posting to the endpoint
  const handleTriggerScrape = async () => {
    try {
      const response = await axiosClient.post('/trigger-scrape');
      setMessage(response.data.message || 'Scrape triggered successfully!');
    } catch (error) {
      setMessage('❌ Error triggering scrape: ' + (error.response?.data?.detail || error.message));
    }
  };

  // Submit new query using axiosClient
  const handleQuerySubmit = async (e) => {
    e.preventDefault();
    try {
      const response = await axiosClient.post('/query', {
        ...queryForm,
        client_id: parseInt(queryForm.client_id),
        pages_to_scrape: parseInt(queryForm.pages_to_scrape),
      });
      const data = response.data;
      if (data.query) {
        setMessage('✅ Query created successfully!');
      } else {
        setMessage('❌ ' + data.error);
      }
    } catch (error) {
      setMessage('❌ Error: ' + (error.response?.data?.detail || error.message));
    }
  };

  // Load queries for a given client_id using axiosClient
  const fetchQueries = async () => {
    if (!queryForm.client_id) {
      setMessage("⚠️ Please enter a Client ID to load queries.");
      return;
    }
    try {
      const response = await axiosClient.get(`/query?client_id=${queryForm.client_id}`);
      setQueries(response.data);
      setMessage('');
    } catch (error) {
      setMessage('❌ Error fetching queries: ' + (error.response?.data?.detail || error.message));
    }
  };

  // Submit new client using axiosClient
  const handleClientSubmit = async (e) => {
    e.preventDefault();
    try {
      const response = await axiosClient.post('/client', clientForm);
      const data = response.data;
      if (data.message) {
        setMessage('✅ ' + data.message);
        // Clear the form
        setClientForm({ client_name: '', client_email: '' });
        // Refresh the clients list
        fetchClients();
      } else {
        setMessage('❌ ' + (data.detail || data.error));
      }
    } catch (error) {
      setMessage('❌ Error: ' + (error.response?.data?.detail || error.message));
    }
  };

  // Fetch product results for a given query ID using axiosClient
  const fetchResults = async () => {
    if (!queryId) {
      setMessage("⚠️ Please enter a Query ID to load results.");
      return;
    }
    try {
      const response = await axiosClient.get(`/query/results?query_id=${queryId}`);
      setResults(response.data);
      setMessage('');
    } catch (error) {
      setMessage('❌ Error fetching results: ' + (error.response?.data?.detail || error.message));
    }
  };

  // Simple callback handler component
  function CallbackHandler() {
    return <div style={{padding:'2rem'}}>Processing login...</div>;
  }

  // Component for regular users (non-admin)
  function UserDashboard({ auth, userGroups, onLogout }) {
    return (
      <div style={{ 
        backgroundColor: '#fff159', 
        minHeight: '100vh',
        background: 'linear-gradient(135deg, #fff159 0%, #ffeb3b 50%, #fdd835 100%)',
        width: '100vw',
        overflowX: 'hidden'
      }}>
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
                  Panel de Usuario
                </p>
              </div>
              <div className="d-flex align-items-center gap-3">
                <div style={{ color: 'white', fontSize: '1rem' }}>
                  👋 {auth.user?.profile?.email || auth.user?.profile?.username || 'Usuario'}
                </div>
                <button
                  onClick={onLogout}
                  className="btn btn-outline-light btn-lg rounded-pill px-4"
                  style={{
                    fontWeight: '600',
                    border: '2px solid white',
                    transition: 'all 0.3s ease'
                  }}
                  onMouseOver={(e) => {
                    e.target.style.backgroundColor = 'white';
                    e.target.style.color = '#3483fa';
                  }}
                  onMouseOut={(e) => {
                    e.target.style.backgroundColor = 'transparent';
                    e.target.style.color = 'white';
                  }}
                >
                  🚪 Cerrar Sesión
                </button>
              </div>
            </div>
          </div>
        </div>

        {/* User Content */}
        <div className="container-fluid">
          <div className="row justify-content-center">
            <div className="col-12" style={{ maxWidth: '800px' }}>
              <div className="card shadow-lg border-0 rounded-4" style={{ backgroundColor: 'white' }}>
                <div className="card-header text-center" style={{ 
                  backgroundColor: '#3483fa', 
                  color: 'white',
                  fontWeight: '600',
                  fontSize: '1.5rem',
                  borderRadius: '1.5rem 1.5rem 0 0'
                }}>
                  👤 Bienvenido Usuario
                </div>
                <div className="card-body p-5 text-center">
                  <h3 style={{ color: '#3483fa', marginBottom: '2rem' }}>
                    ¡Hola {auth.user?.profile?.email || auth.user?.profile?.username}!
                  </h3>
                  <p style={{ fontSize: '1.2rem', color: '#666', marginBottom: '3rem' }}>
                    Tu cuenta de usuario está activa y funcionando correctamente.
                  </p>
                  
                  <div className="row g-4">
                    <div className="col-md-6">
                      <div style={{ 
                        background: '#f8f9fa', 
                        padding: '2rem', 
                        borderRadius: '15px',
                        height: '100%'
                      }}>
                        <h5 style={{ color: '#3483fa', marginBottom: '1rem' }}>📊 Tus Consultas</h5>
                        <p style={{ color: '#666' }}>
                          Próximamente podrás ver y gestionar tus consultas de productos.
                        </p>
                      </div>
                    </div>
                    
                    <div className="col-md-6">
                      <div style={{ 
                        background: '#f8f9fa', 
                        padding: '2rem', 
                        borderRadius: '15px',
                        height: '100%'
                      }}>
                        <h5 style={{ color: '#3483fa', marginBottom: '1rem' }}>🔔 Notificaciones</h5>
                        <p style={{ color: '#666' }}>
                          Configura alertas de precios para tus productos favoritos.
                        </p>
                      </div>
                    </div>
                  </div>
                  
                  <div style={{ 
                    background: '#e3f2fd', 
                    padding: '2rem', 
                    borderRadius: '15px',
                    marginTop: '2rem'
                  }}>
                    <h5 style={{ color: '#1976d2', marginBottom: '1rem' }}>ℹ️ Información de Cuenta</h5>
                    <p style={{ color: '#666', marginBottom: '0.5rem' }}>
                      <strong>Email:</strong> {auth.user?.profile?.email || 'No disponible'}
                    </p>
                    <p style={{ color: '#666', marginBottom: '0.5rem' }}>
                      <strong>Usuario:</strong> {auth.user?.profile?.username || 'No disponible'}
                    </p>
                    <p style={{ color: '#666', marginBottom: '0' }}>
                      <strong>Grupos:</strong> {userGroups.join(', ') || 'Ninguno'}
                    </p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    );
  }

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
              <div style={{ color: 'white', fontSize: '1rem' }}>
                👋 {auth.user?.profile?.email || auth.user?.profile?.username || 'Usuario'}
              </div>
              <button
                onClick={handleLogout}
                className="btn btn-outline-light btn-lg rounded-pill px-4"
                style={{
                  fontWeight: '600',
                  border: '2px solid white',
                  transition: 'all 0.3s ease'
                }}
                onMouseOver={(e) => {
                  e.target.style.backgroundColor = 'white';
                  e.target.style.color = '#3483fa';
                }}
                onMouseOut={(e) => {
                  e.target.style.backgroundColor = 'transparent';
                  e.target.style.color = 'white';
                }}
              >
                🚪 Cerrar Sesión
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
                  setView('view');
                  fetchQueries();
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
  );
}

export default App;
