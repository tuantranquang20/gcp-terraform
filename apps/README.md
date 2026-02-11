# Sample Applications

This directory contains sample Dockerized applications that demonstrate the 3-tier architecture.

## Quick Start (Local Development)

### Using Docker Compose

The easiest way to test locally:

```bash
# Start all services (frontend, backend, MySQL, Redis)
docker-compose up

# Visit http://localhost:3000 in your browser
```

That's it! Docker Compose will:
- Start MySQL database
- Start Redis cache
- Build and run backend API
- Build and run frontend
- Wire everything together

### Manual Setup

If you prefer to run services individually:

#### 1. Start Dependencies

```bash
# MySQL
docker run -d \
  -p 3306:3306 \
  -e MYSQL_ROOT_PASSWORD=password \
  -e MYSQL_DATABASE=app_db \
  mysql:8.0

# Redis
docker run -d \
  -p 6379:6379 \
  redis:7-alpine
```

#### 2. Backend

```bash
cd apps/backend

# Install dependencies
npm install

# Copy environment file
cp .env.example .env

# Start server
npm start

# Visit http://localhost:8080
```

#### 3. Frontend

```bash
cd apps/frontend

# Install dependencies
npm install

# Copy environment file
cp .env.example .env

# Start dev server
npm start

# Visit http://localhost:3000
```

## Deploying to GCP

### Prerequisites

1. Complete Terraform infrastructure deployment
2. Docker installed locally
3. gcloud CLI configured
4. `PROJECT_ID` environment variable set

### Build and Push Images

Use the provided script:

```bash
# Set your GCP project ID
export PROJECT_ID=your-gcp-project-id

# Build and push images
./build-and-push.sh
```

This script will:
1. Build backend Docker image
2. Build frontend Docker image
3. Push both to Google Container Registry (GCR)
4. Update `terraform.tfvars` with image URLs

### Update Infrastructure

```bash
# Apply Terraform changes
terraform apply

# Cloud Run will pull and deploy the new images
```

### Verify Deployment

```bash
# Get frontend URL
terraform output frontend_url

# Visit the URL in your browser
```

## Application Architecture

### Backend (`apps/backend`)

**Tech Stack:**
- Node.js + Express
- MySQL (via mysql2)
- Redis (for caching)

**Features:**
- Health check endpoint (`/health`)
- Visitor tracking (stores in MySQL)
- Statistics API with Redis caching
- Environment variable configuration
- Docker multi-stage build

**Endpoints:**
- `GET /` - API info
- `GET /health` - Health check
- `GET /api/stats` - Get statistics (cached)
- `POST /api/visit` - Record a visit
- `GET /api/visitors` - Get recent visitors
- `GET /api/test/db` - Test database connection
- `GET /api/test/redis` - Test Redis connection

### Frontend (`apps/frontend`)

**Tech Stack:**
- React 18
- Nginx (for production serving)

**Features:**
- Interactive architecture visualization
- Real-time statistics display
- Visitor tracking
- Backend health monitoring
- Auto-refresh every 10 seconds
- Responsive design

**Production Build:**
- Multi-stage Docker build
- Nginx web server (port 8080)
- Gzip compression
- Security headers
- Health check endpoint

## File Structure

```
apps/
├── backend/
│   ├── server.js              # Express app
│   ├── package.json           # Dependencies
│   ├── Dockerfile             # Production container
│   └── .env.example           # Environment template
│
└── frontend/
    ├── src/
    │   ├── App.js             # Main React component
    │   ├── App.css            # Styles
    │   ├── index.js           # Entry point
    │   └── index.css          # Global styles
    ├── public/
    │   └── index.html         # HTML template
    ├── package.json           # Dependencies
    ├── Dockerfile             # Production container
    ├── nginx.conf             # Nginx configuration
    └── .env.example           # Environment template
```

## Environment Variables

### Backend

```bash
PORT=8080                    # Server port
ENVIRONMENT=development      # Environment name
DB_HOST=localhost           # MySQL host
DB_PORT=3306                # MySQL port
DB_USER=root                # MySQL user
DB_PASSWORD=password        # MySQL password
DB_NAME=app_db              # Database name
DB_SECRET=...               # Cloud Run: JSON secret from Secret Manager
REDIS_HOST=localhost        # Redis host
REDIS_PORT=6379             # Redis port
```

### Frontend

```bash
REACT_APP_BACKEND_URL=http://localhost:8080  # Backend API URL
REACT_APP_ENVIRONMENT=development            # Environment name
```

## Development Tips

### Backend Development

```bash
cd apps/backend

# Install nodemon for auto-reload
npm install --save-dev nodemon

# Run in dev mode
npm run dev
```

### Frontend Development

```bash
cd apps/frontend

# Start dev server with hot reload
npm start

# Build for production
npm run build
```

### Database Access

```bash
# Connect to local MySQL
docker exec -it gcp-lab-mysql mysql -u root -p app_db

# View visitors table
SELECT * FROM visitors ORDER BY visited_at DESC LIMIT 10;
```

### Redis Access

```bash
# Connect to local Redis
docker exec -it gcp-lab-redis redis-cli

# View cached stats
GET stats
```

## Customization

### Adding New Backend Endpoints

Edit `apps/backend/server.js`:

```javascript
app.get('/api/custom', async (req, res) => {
  // Your code here
  res.json({ message: 'Custom endpoint' });
});
```

### Modifying Frontend UI

Edit `apps/frontend/src/App.js` and `App.css` to customize the interface.

### Adding Database Tables

Add schema initialization in `apps/backend/server.js`:

```javascript
async function initializeSchema() {
  await dbPool.query(`
    CREATE TABLE IF NOT EXISTS your_table (
      id INT AUTO_INCREMENT PRIMARY KEY,
      -- your columns
    )
  `);
}
```

## Troubleshooting

### Backend won't connect to database

1. Check MySQL is running: `docker ps`
2. Check environment variables in `.env`
3. Check logs: `docker logs gcp-lab-backend`

### Frontend shows connection error

1. Check backend is running: `curl http://localhost:8080/health`
2. Check `REACT_APP_BACKEND_URL` in frontend `.env`
3. Check browser console for CORS errors

### Docker build fails

1. Ensure you're in the correct directory
2. Check Dockerfile syntax
3. Try: `docker-compose down && docker-compose up --build`

### GCP deployment fails

1. Verify images are in GCR: `gcloud container images list`
2. Check Cloud Run service account permissions
3. Verify VPC connector is ready
4. Check Cloud Run logs in GCP Console

## Next Steps

1. **Customize the apps** - Add your own features
2. **Add monitoring** - Integrate Cloud Logging/Monitoring
3. **Implement CI/CD** - Automate builds with Cloud Build
4. **Add tests** - Unit and integration tests
5. **Scale up** - Increase Cloud Run instances for load testing

---

**Happy coding! 🚀**
