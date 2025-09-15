import jwt from 'jsonwebtoken';

export const authenticateToken = async (req, res, next) => {
  try {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1]; // Bearer TOKEN

    if (!token) {
      return res.status(401).json({
        error: 'Access token required',
        details: 'Please provide a valid authentication token',
      });
    }

    // Verify token
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    
    // Get user from database
    const user = await req.prisma.user.findUnique({
      where: { id: decoded.userId },
      include: {
        userProgress: true,
      },
    });

    if (!user || !user.isActive) {
      return res.status(401).json({
        error: 'Invalid token',
        details: 'User not found or account inactive',
      });
    }

    // Add user to request object
    req.user = user;
    req.userId = user.id;
    
    next();
  } catch (error) {
    if (error.name === 'JsonWebTokenError') {
      return res.status(401).json({
        error: 'Invalid token',
        details: 'The provided token is malformed',
      });
    }
    
    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({
        error: 'Token expired',
        details: 'Please log in again',
      });
    }
    
    console.error('Auth middleware error:', error);
    res.status(500).json({
      error: 'Authentication failed',
      details: error.message,
    });
  }
};

export const optionalAuth = async (req, res, next) => {
  try {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];

    if (token) {
      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      const user = await req.prisma.user.findUnique({
        where: { id: decoded.userId },
        include: {
          userProgress: true,
        },
      });

      if (user && user.isActive) {
        req.user = user;
        req.userId = user.id;
      }
    }
    
    next();
  } catch (error) {
    // For optional auth, we don't return errors, just proceed without user
    next();
  }
};
