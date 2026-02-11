import React, { useState, useEffect } from 'react';
import './App.css';

const API_URL = process.env.REACT_APP_BACKEND_URL || 'http://localhost:8080';

function App() {
    const [stats, setStats] = useState(null);
    const [visitors, setVisitors] = useState([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);
    const [backendHealth, setBackendHealth] = useState('checking');

    // Fetch stats from backend
    const fetchStats = async () => {
        try {
            const response = await fetch(`${API_URL}/api/stats`);
            if (!response.ok) throw new Error('Failed to fetch stats');
            const data = await response.json();
            setStats(data);
            setBackendHealth('healthy');
        } catch (err) {
            console.error('Error fetching stats:', err);
            setError('Could not connect to backend');
            setBackendHealth('unhealthy');
        }
    };

    // Fetch recent visitors
    const fetchVisitors = async () => {
        try {
            const response = await fetch(`${API_URL}/api/visitors?limit=5`);
            if (!response.ok) throw new Error('Failed to fetch visitors');
            const data = await response.json();
            setVisitors(data.visitors || []);
        } catch (err) {
            console.error('Error fetching visitors:', err);
        }
    };

    // Record current visit
    const recordVisit = async () => {
        try {
            await fetch(`${API_URL}/api/visit`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' }
            });
            // Refresh stats after recording visit
            setTimeout(() => {
                fetchStats();
                fetchVisitors();
            }, 500);
        } catch (err) {
            console.error('Error recording visit:', err);
        }
    };

    useEffect(() => {
        const loadData = async () => {
            setLoading(true);
            await Promise.all([fetchStats(), fetchVisitors()]);
            await recordVisit();
            setLoading(false);
        };

        loadData();

        // Refresh stats every 10 seconds
        const interval = setInterval(() => {
            fetchStats();
            fetchVisitors();
        }, 10000);

        return () => clearInterval(interval);
    }, []);

    if (loading) {
        return (
            <div className="App">
                <div className="container">
                    <div className="card">
                        <div className="loading">Loading...</div>
                    </div>
                </div>
            </div>
        );
    }

    return (
        <div className="App">
            <div className="container">
                <header className="header">
                    <h1>🚀 GCP 3-Tier Architecture Lab</h1>
                    <p className="subtitle">Frontend → Backend → Database + Cache</p>
                </header>

                {/* Architecture Diagram */}
                <div className="card architecture">
                    <h2>Architecture</h2>
                    <div className="architecture-flow">
                        <div className="tier">
                            <div className="tier-icon">🌐</div>
                            <div className="tier-name">Frontend</div>
                            <div className="tier-tech">Cloud Run (Public)</div>
                            <div className="tier-status">
                                <span className="status-dot active"></span>
                                Active
                            </div>
                        </div>
                        <div className="arrow">→</div>
                        <div className="tier">
                            <div className="tier-icon">⚙️</div>
                            <div className="tier-name">Backend API</div>
                            <div className="tier-tech">Cloud Run (Private)</div>
                            <div className="tier-status">
                                <span className={`status-dot ${backendHealth === 'healthy' ? 'active' : 'inactive'}`}></span>
                                {backendHealth === 'healthy' ? 'Connected' : 'Disconnected'}
                            </div>
                        </div>
                        <div className="arrow">→</div>
                        <div className="tier">
                            <div className="tier-icon">💾</div>
                            <div className="tier-name">Data Layer</div>
                            <div className="tier-tech">Cloud SQL + Redis</div>
                            <div className="tier-status">
                                <span className={`status-dot ${stats ? 'active' : 'inactive'}`}></span>
                                {stats ? 'Connected' : 'Disconnected'}
                            </div>
                        </div>
                    </div>
                </div>

                {/* Statistics */}
                {stats && (
                    <div className="stats-grid">
                        <div className="stat-card">
                            <div className="stat-icon">👥</div>
                            <div className="stat-value">{stats.total_visits}</div>
                            <div className="stat-label">Total Visits</div>
                        </div>
                        <div className="stat-card">
                            <div className="stat-icon">🌟</div>
                            <div className="stat-value">{stats.unique_visitors}</div>
                            <div className="stat-label">Unique Visitors</div>
                        </div>
                        <div className="stat-card">
                            <div className="stat-icon">⚡</div>
                            <div className="stat-value">{stats.cached ? 'YES' : 'NO'}</div>
                            <div className="stat-label">Redis Cached</div>
                        </div>
                    </div>
                )}

                {/* Recent Visitors */}
                {visitors.length > 0 && (
                    <div className="card">
                        <h2>📊 Recent Visitors</h2>
                        <div className="visitors-list">
                            {visitors.map((visitor, index) => (
                                <div key={index} className="visitor-item">
                                    <span className="visitor-time">
                                        {new Date(visitor.visited_at).toLocaleString()}
                                    </span>
                                    <span className="visitor-ip">{visitor.ip_address}</span>
                                </div>
                            ))}
                        </div>
                    </div>
                )}

                {/* Error Message */}
                {error && (
                    <div className="card error">
                        <h2>⚠️ Connection Error</h2>
                        <p>{error}</p>
                        <p className="error-hint">
                            Make sure the backend is running and REACT_APP_BACKEND_URL is set correctly.
                        </p>
                    </div>
                )}

                {/* Info */}
                <div className="card info">
                    <h3>ℹ️ How It Works</h3>
                    <ul>
                        <li><strong>Frontend (You are here):</strong> React app on Cloud Run with public access</li>
                        <li><strong>Backend API:</strong> Node.js Express on Cloud Run with private VPC access</li>
                        <li><strong>Database:</strong> Cloud SQL MySQL stores visitor data (private IP only)</li>
                        <li><strong>Cache:</strong> Memorystore Redis caches statistics for 30 seconds</li>
                    </ul>
                </div>

                <footer className="footer">
                    <p>Built with ❤️ for learning GCP Infrastructure as Code</p>
                    <p className="footer-meta">
                        Environment: {process.env.REACT_APP_ENVIRONMENT || 'development'} |
                        Backend: {API_URL}
                    </p>
                </footer>
            </div>
        </div>
    );
}

export default App;
