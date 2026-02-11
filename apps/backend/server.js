const express = require('express');
const mysql = require('mysql2/promise');
const redis = require('redis');
const cors = require('cors');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 8080;

// Middleware
app.use(cors());
app.use(express.json());

// Database connection pool
let dbPool;
let redisClient;

// Initialize connections
async function initializeConnections() {
  try {
    // Parse database secret if available
    let dbConfig;
    if (process.env.DB_SECRET) {
      try {
        const secret = JSON.parse(process.env.DB_SECRET);
        dbConfig = {
          host: secret.host,
          port: secret.port || 3306,
          user: secret.username,
          password: secret.password,
          database: secret.database,
          waitForConnections: true,
          connectionLimit: 10,
          queueLimit: 0
        };
      } catch (e) {
        console.warn('Failed to parse DB_SECRET, using individual env vars');
      }
    }

    // Fallback to individual env vars
    if (!dbConfig) {
      dbConfig = {
        host: process.env.DB_HOST || 'localhost',
        port: process.env.DB_PORT || 3306,
        user: process.env.DB_USER || 'root',
        password: process.env.DB_PASSWORD || 'password',
        database: process.env.DB_NAME || 'app_db',
        waitForConnections: true,
        connectionLimit: 10,
        queueLimit: 0
      };
    }

    // Create MySQL connection pool
    dbPool = mysql.createPool(dbConfig);
    console.log('✅ MySQL connection pool created');

    // Test database connection
    const connection = await dbPool.getConnection();
    console.log('✅ MySQL connected successfully');
    connection.release();

    // Initialize database schema
    await initializeSchema();

    // Create Redis client
    const redisHost = process.env.REDIS_HOST || 'localhost';
    const redisPort = process.env.REDIS_PORT || 6379;
    
    redisClient = redis.createClient({
      socket: {
        host: redisHost,
        port: redisPort
      }
    });

    redisClient.on('error', (err) => console.error('Redis Client Error', err));
    redisClient.on('connect', () => console.log('✅ Redis connected successfully'));

    await redisClient.connect();

  } catch (error) {
    console.error('❌ Connection initialization failed:', error);
    // Don't exit - allow app to run even if DB/Redis unavailable
  }
}

// Initialize database schema
async function initializeSchema() {
  try {
    await dbPool.query(`
      CREATE TABLE IF NOT EXISTS visitors (
        id INT AUTO_INCREMENT PRIMARY KEY,
        ip_address VARCHAR(45),
        user_agent VARCHAR(255),
        visited_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_visited_at (visited_at)
      )
    `);
    console.log('✅ Database schema initialized');
  } catch (error) {
    console.error('❌ Schema initialization failed:', error);
  }
}

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ 
    status: 'healthy',
    timestamp: new Date().toISOString(),
    environment: process.env.ENVIRONMENT || 'development'
  });
});

// Root endpoint
app.get('/', (req, res) => {
  res.json({
    message: '🚀 GCP Lab Backend API',
    version: '1.0.0',
    endpoints: {
      health: '/health',
      stats: '/api/stats',
      visit: 'POST /api/visit',
      visitors: '/api/visitors'
    }
  });
});

// Get statistics (with Redis caching)
app.get('/api/stats', async (req, res) => {
  try {
    // Try to get from cache first
    let stats;
    if (redisClient && redisClient.isOpen) {
      const cached = await redisClient.get('stats');
      if (cached) {
        console.log('📦 Cache hit for stats');
        return res.json(JSON.parse(cached));
      }
    }

    // Get from database
    const [rows] = await dbPool.query(`
      SELECT 
        COUNT(*) as total_visits,
        COUNT(DISTINCT ip_address) as unique_visitors,
        MAX(visited_at) as last_visit
      FROM visitors
    `);

    stats = {
      total_visits: parseInt(rows[0].total_visits),
      unique_visitors: parseInt(rows[0].unique_visitors),
      last_visit: rows[0].last_visit,
      cached: false
    };

    // Cache for 30 seconds
    if (redisClient && redisClient.isOpen) {
      await redisClient.setEx('stats', 30, JSON.stringify(stats));
      console.log('💾 Stats cached');
    }

    res.json(stats);
  } catch (error) {
    console.error('Error getting stats:', error);
    res.status(500).json({ error: 'Failed to get statistics' });
  }
});

// Record a visit
app.post('/api/visit', async (req, res) => {
  try {
    const ip = req.headers['x-forwarded-for'] || req.socket.remoteAddress;
    const userAgent = req.headers['user-agent'] || 'Unknown';

    await dbPool.query(
      'INSERT INTO visitors (ip_address, user_agent) VALUES (?, ?)',
      [ip, userAgent]
    );

    // Invalidate cache
    if (redisClient && redisClient.isOpen) {
      await redisClient.del('stats');
    }

    res.json({ 
      success: true,
      message: 'Visit recorded',
      ip: ip
    });
  } catch (error) {
    console.error('Error recording visit:', error);
    res.status(500).json({ error: 'Failed to record visit' });
  }
});

// Get recent visitors
app.get('/api/visitors', async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 10;
    
    const [rows] = await dbPool.query(
      'SELECT ip_address, user_agent, visited_at FROM visitors ORDER BY visited_at DESC LIMIT ?',
      [limit]
    );

    res.json({
      count: rows.length,
      visitors: rows
    });
  } catch (error) {
    console.error('Error getting visitors:', error);
    res.status(500).json({ error: 'Failed to get visitors' });
  }
});

// Test database connection
app.get('/api/test/db', async (req, res) => {
  try {
    const [rows] = await dbPool.query('SELECT 1 + 1 AS result');
    res.json({ 
      database: 'connected',
      test_query: rows[0].result 
    });
  } catch (error) {
    res.status(500).json({ 
      database: 'disconnected',
      error: error.message 
    });
  }
});

// Test Redis connection
app.get('/api/test/redis', async (req, res) => {
  try {
    if (!redisClient || !redisClient.isOpen) {
      throw new Error('Redis client not connected');
    }
    
    await redisClient.set('test_key', 'test_value', { EX: 10 });
    const value = await redisClient.get('test_key');
    
    res.json({ 
      redis: 'connected',
      test_value: value 
    });
  } catch (error) {
    res.status(500).json({ 
      redis: 'disconnected',
      error: error.message 
    });
  }
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('Unhandled error:', err);
  res.status(500).json({ 
    error: 'Internal server error',
    message: err.message 
  });
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('SIGTERM received, closing connections...');
  
  if (dbPool) {
    await dbPool.end();
  }
  
  if (redisClient && redisClient.isOpen) {
    await redisClient.quit();
  }
  
  process.exit(0);
});

// Start server
async function start() {
  await initializeConnections();
  
  app.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 Backend API running on port ${PORT}`);
    console.log(`📊 Environment: ${process.env.ENVIRONMENT || 'development'}`);
  });
}

start();
