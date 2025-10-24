import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import rateLimit from 'express-rate-limit';
import dotenv from 'dotenv';
import { PrismaClient } from '@prisma/client';

// Import Swagger configuration
import { specs, swaggerUi } from './config/swagger.js';

// Import routes
import authRoutes from './routes/auth.js';
import contentRoutes from './routes/content.js';
import progressRoutes from './routes/progress.js';
import userRoutes from './routes/user.js';
import achievementRoutes from './routes/achievements.js';
import leaderboardRoutes from './routes/leaderboard.js';
import syncRoutes from './routes/sync.js';

// Load environment variables
dotenv.config();

// Initialize Prisma
const prisma = new PrismaClient();

// Initialize Express
const app = express();
const PORT = process.env.PORT || 3000;

// =====================================================
// MIDDLEWARE
// =====================================================

// Security middleware
app.use(helmet());

// CORS configuration
app.use(cors({
  origin: process.env.CORS_ORIGIN || 'http://localhost:*',
  credentials: true,
}));

// Rate limiting
const limiter = rateLimit({
  windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS) || 15 * 60 * 1000, // 15 minutes
  max: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS) || 100, // limit each IP to 100 requests per windowMs
  message: {
    error: 'Too many requests from this IP, please try again later.',
  },
});
app.use('/api/', limiter);

// Body parsing middleware
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Logging middleware
if (process.env.NODE_ENV !== 'test') {
  app.use(morgan('combined'));
}

// Serve static files (images and audio)
app.use('/media', express.static('public', {
  setHeaders: (res, path) => {
    if (path.endsWith('.jpg') || path.endsWith('.png')) {
      res.setHeader('Content-Type', 'image/jpeg');
    } else if (path.endsWith('.wav') || path.endsWith('.mp3')) {
      res.setHeader('Content-Type', 'audio/wav');
    }
  }
}));

// Make Prisma available in request context
app.use((req, res, next) => {
  req.prisma = prisma;
  next();
});

// =====================================================
// ROUTES
// =====================================================

// Swagger Documentation
app.use('/api/docs', swaggerUi.serve, swaggerUi.setup(specs, {
  customCss: '.swagger-ui .topbar { display: none }',
  customSiteTitle: 'Bojang API Documentation',
  customfavIcon: '/favicon.ico'
}));

// Health check
app.get('/health', (req, res) => {
  res.json({
    status: 'OK',
    timestamp: new Date().toISOString(),
    service: process.env.APP_NAME || 'Bojang API',
    version: process.env.APP_VERSION || '1.0.0',
  });
});

// API routes
app.use('/api/v1/auth', authRoutes);
app.use('/api/v1/content', contentRoutes);
app.use('/api/v1/progress', progressRoutes);
app.use('/api/v1/user', userRoutes);
app.use('/api/v1/achievements', achievementRoutes);
app.use('/api/v1/leaderboard', leaderboardRoutes);
app.use('/api/v1/sync', syncRoutes);

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({
    error: 'Route not found',
    path: req.originalUrl,
  });
});

// Global error handler
app.use((error, req, res, next) => {
  console.error('Global error handler:', error);
  
  // Prisma errors
  if (error.code === 'P2002') {
    return res.status(409).json({
      error: 'Duplicate entry',
      details: 'A record with this information already exists',
    });
  }
  
  if (error.code === 'P2025') {
    return res.status(404).json({
      error: 'Record not found',
      details: 'The requested record does not exist',
    });
  }
  
  // JWT errors
  if (error.name === 'JsonWebTokenError') {
    return res.status(401).json({
      error: 'Invalid token',
      details: 'The provided token is invalid',
    });
  }
  
  if (error.name === 'TokenExpiredError') {
    return res.status(401).json({
      error: 'Token expired',
      details: 'The provided token has expired',
    });
  }
  
  // Validation errors
  if (error.type === 'validation') {
    return res.status(400).json({
      error: 'Validation error',
      details: error.details || 'Invalid input data',
    });
  }
  
  // Default error
  res.status(error.status || 500).json({
    error: error.message || 'Internal server error',
    ...(process.env.NODE_ENV === 'development' && { stack: error.stack }),
  });
});

// =====================================================
// SERVER STARTUP
// =====================================================

async function startServer() {
  try {
    // Test database connection
    await prisma.$connect();
    console.log('✅ Connected to database');
    
    // Start server
    app.listen(PORT, () => {
      console.log(`🚀 Bojang API server running on port ${PORT}`);
      console.log(`📊 Health check: http://localhost:${PORT}/health`);
      console.log(`🔍 Prisma Studio: npx prisma studio`);
    });
  } catch (error) {
    console.error('❌ Failed to start server:', error);
    process.exit(1);
  }
}

// Graceful shutdown
process.on('SIGINT', async () => {
  console.log('\n⏳ Shutting down gracefully...');
  await prisma.$disconnect();
  process.exit(0);
});

process.on('SIGTERM', async () => {
  console.log('\n⏳ Shutting down gracefully...');
  await prisma.$disconnect();
  process.exit(0);
});

// Start the server
startServer();

export default app;
