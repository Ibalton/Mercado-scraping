import React, { useState } from 'react';
import axiosClient from './axiosClient'; // Import your custom axios instance
import 'bootstrap/dist/css/bootstrap.min.css';

function App() {
  // "create", "view", "results", "client"
  const [view, setView] = useState('create');
  const [queries, setQueries] = useState([]);
  const [message, setMessage] = useState('');

  const [results, setResults] = useState([]);
  const [queryId, setQueryId] = useState('');

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

  // Change handler for query form
  const handleQueryChange = (e) => {
    setQueryForm({ ...queryForm, [e.target.name]: e.target.value });
  };

  // Change handler for client form
  const handleClientChange = (e) => {
    setClientForm({ ...clientForm, [e.target.name]: e.target.value });
  };

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

  return (
    <div className="container py-5">
      {/* Header with title and Trigger Scrape button */}
      <div className="d-flex justify-content-between align-items-center mb-4">
      <h1 className="text-center mb-4">Mercado Scrape</h1>
        <button className="btn btn-danger" onClick={handleTriggerScrape}>
          Trigger Scrape
        </button>
      </div>

      {/* View Selector */}
      <div className="mb-4 d-flex justify-content-center">
        <button 
          className={`btn me-2 ${view === 'create' ? 'btn-primary' : 'btn-outline-primary'}`} 
          onClick={() => setView('create')}
        >
          ➕ Create Query
        </button>
        <button 
          className={`btn me-2 ${view === 'view' ? 'btn-primary' : 'btn-outline-primary'}`} 
          onClick={() => { 
            setView('view');
            fetchQueries();
          }}
        >
          📋 View Queries
        </button>
        <button 
          className={`btn me-2 ${view === 'results' ? 'btn-primary' : 'btn-outline-primary'}`} 
          onClick={() => setView('results')}
        >
          📦 View Results
        </button>
        <button 
          className={`btn ${view === 'client' ? 'btn-primary' : 'btn-outline-primary'}`} 
          onClick={() => setView('client')}
        >
          📝 Create Client
        </button>
      </div>

      {/* Message Alert */}
      {message && <div className="alert alert-info">{message}</div>}

      {/* Create Query Form */}
      {view === 'create' && (
        <form onSubmit={handleQuerySubmit}>
          <div className="row g-3">
            <div className="col-md-6">
              <input 
                type="text" 
                className="form-control" 
                name="query_text" 
                placeholder="Query Text" 
                onChange={handleQueryChange} 
                required 
              />
            </div>
            <div className="col-md-3">
              <input 
                type="number" 
                className="form-control" 
                name="client_id" 
                placeholder="Client ID" 
                onChange={handleQueryChange} 
                required 
              />
            </div>
            <div className="col-md-3">
              <input 
                type="text" 
                className="form-control" 
                name="frequency" 
                placeholder="Frequency" 
                onChange={handleQueryChange} 
                required 
              />
            </div>
            <div className="col-md-3">
              <input 
                type="number" 
                className="form-control" 
                name="pages_to_scrape" 
                placeholder="Pages to Scrape" 
                onChange={handleQueryChange} 
                required 
              />
            </div>
          </div>
          <button className="btn btn-success mt-3" type="submit">Submit Query</button>
        </form>
      )}

      {/* View Queries */}
      {view === 'view' && (
        <>
          <h3 className="mt-4">Existing Queries for Client</h3>
          <div className="row mb-3">
            <div className="col-md-3">
              <input 
                type="number" 
                className="form-control" 
                name="client_id" 
                placeholder="Enter Client ID" 
                value={queryForm.client_id} 
                onChange={handleQueryChange} 
              />
            </div>
            <div className="col-md-3">
              <button className="btn btn-secondary" onClick={fetchQueries}>
                🔍 Load Queries
              </button>
            </div>
          </div>
          <ul className="list-group">
            {queries.length === 0 ? (
              <li className="list-group-item">No queries found.</li>
            ) : (
              queries.map((q, index) => (
                <li key={index} className="list-group-item">
                  <strong>{q.query_text}</strong> | Client ID: {q.client_id}, Frequency: {q.frequency}, Pages: {q.pages_to_scrape}
                </li>
              ))
            )}
          </ul>
        </>
      )}

      {/* View Results */}
      {view === 'results' && (
        <>
          <h3 className="mt-4">Product Results for Query</h3>
          <div className="row mb-3">
            <div className="col-md-3">
              <input 
                type="number" 
                className="form-control" 
                placeholder="Enter Query ID" 
                value={queryId} 
                onChange={(e) => setQueryId(e.target.value)} 
              />
            </div>
            <div className="col-md-3">
              <button className="btn btn-secondary" onClick={fetchResults}>
                📥 Load Results
              </button>
            </div>
          </div>

          <div className="row">
            {results.length === 0 ? (
              <div className="col-12">
                <p>No results found.</p>
              </div>
            ) : (
              results.map((r, index) => (
                <div key={index} className="col-md-4 mb-4">
                  <div className="card h-100 shadow-sm">
                    <img 
                      src={r.image || 'https://via.placeholder.com/300x200?text=No+Image'} 
                      className="card-img-top" 
                      alt={r.title || r.id} 
                      style={{ objectFit: 'cover', height: '200px' }}
                    />
                    <div className="card-body d-flex flex-column">
                      <h5 className="card-title">{r.title || r.id}</h5>
                      {r.listings && r.listings.length > 0 ? (
                        r.listings.map((listing, idx) => {
                          // Get the latest price from this listing's prices array
                          const latestPrice = listing.prices && listing.prices.length > 0 
                            ? listing.prices[listing.prices.length - 1] 
                            : null;
                          return (
                            <div key={idx} className="d-flex justify-content-between align-items-center my-2">
                              <span className="text-primary h5">
                                ${latestPrice && latestPrice.price ? latestPrice.price.toLocaleString() : 'N/A'}
                              </span>
                              <a 
                                href={listing.url || '#'} 
                                target="_blank" 
                                rel="noopener noreferrer" 
                                className="btn btn-warning"
                              >
                                Ver producto
                              </a>
                            </div>
                          );
                        })
                      ) : (
                        <p>No listings available.</p>
                      )}
                      <div className="mt-auto"></div>
                    </div>
                  </div>
                </div>
              ))
            )}
          </div>
        </>
      )}

      {/* Create Client Form */}
      {view === 'client' && (
        <form onSubmit={handleClientSubmit}>
          <div className="row g-3">
            <div className="col-md-6">
              <input 
                type="text" 
                className="form-control" 
                name="client_name" 
                placeholder="Client Name" 
                value={clientForm.client_name}
                onChange={handleClientChange} 
                required 
              />
            </div>
            <div className="col-md-6">
              <input 
                type="email" 
                className="form-control" 
                name="client_email" 
                placeholder="Client Email" 
                value={clientForm.client_email}
                onChange={handleClientChange} 
                required 
              />
            </div>
          </div>
          <button className="btn btn-success mt-3" type="submit">Create Client</button>
        </form>
      )}
    </div>
  );
}

export default App;
