import express from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { body, validationResult } from 'express-validator';

const router = express.Router();

// =====================================================
// REGISTER
// =====================================================

router.post('/register', [
  body('email').isEmail().normalizeEmail(),
  body('username').isLength({ min: 3, max: 20 }).trim(),
  body('password').isLength({ min: 6 }),
  body('displayName').isLength({ min: 1, max: 100 }).trim(),
], async (req, res) => {
  try {
    // Check validation errors
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        error: 'Validation failed',
        details: errors.array(),
      });
    }

    const { email, username, password, displayName, deviceId } = req.body;

    // Check if user already exists
    const existingUser = await req.prisma.user.findFirst({
      where: {
        OR: [
          { email },
          { username },
        ],
      },
    });

    if (existingUser) {
      return res.status(409).json({
        error: 'User already exists',
        details: 'Email or username already taken',
      });
    }

    // Hash password
    const passwordHash = await bcrypt.hash(password, 12);

    // Create user
    const user = await req.prisma.user.create({
      data: {
        email,
        username,
        passwordHash,
        displayName,
        deviceId,
        userProgress: {
          create: {
            currentLevel: 1,
            totalXp: 0,
          },
        },
      },
      include: {
        userProgress: true,
      },
    });

    // Generate JWT token
    const token = jwt.sign(
      { userId: user.id, email: user.email },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
    );

    // Remove password hash from response
    const { passwordHash: _, ...userWithoutPassword } = user;

    res.status(201).json({
      message: 'User registered successfully',
      token,
      user: userWithoutPassword,
    });
  } catch (error) {
    console.error('Registration error:', error);
    res.status(500).json({
      error: 'Registration failed',
      details: error.message,
    });
  }
});

// =====================================================
// LOGIN
// =====================================================

router.post('/login', [
  body('email').isEmail().normalizeEmail(),
  body('password').exists(),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        error: 'Validation failed',
        details: errors.array(),
      });
    }

    const { email, password, deviceId } = req.body;

    // Find user
    const user = await req.prisma.user.findUnique({
      where: { email },
      include: {
        userProgress: true,
      },
    });

    if (!user || !user.isActive) {
      return res.status(401).json({
        error: 'Authentication failed',
        details: 'Invalid credentials',
      });
    }

    // Check password
    const isPasswordValid = await bcrypt.compare(password, user.passwordHash);
    if (!isPasswordValid) {
      return res.status(401).json({
        error: 'Authentication failed',
        details: 'Invalid credentials',
      });
    }

    // Update last login and device ID
    await req.prisma.user.update({
      where: { id: user.id },
      data: {
        lastLogin: new Date(),
        deviceId: deviceId || user.deviceId,
      },
    });

    // Generate JWT token
    const token = jwt.sign(
      { userId: user.id, email: user.email },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
    );

    // Remove password hash from response
    const { passwordHash: _, ...userWithoutPassword } = user;

    res.json({
      message: 'Login successful',
      token,
      user: userWithoutPassword,
    });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({
      error: 'Login failed',
      details: error.message,
    });
  }
});

// =====================================================
// LOGOUT
// =====================================================

router.post('/logout', async (req, res) => {
  // Since we're using stateless JWT, logout is handled client-side
  // But we can track it for analytics
  res.json({
    message: 'Logout successful',
  });
});

// =====================================================
// REFRESH TOKEN
// =====================================================

router.post('/refresh', async (req, res) => {
  try {
    const { token } = req.body;

    if (!token) {
      return res.status(401).json({
        error: 'Token required',
      });
    }

    // Verify existing token
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    
    // Check if user still exists and is active
    const user = await req.prisma.user.findUnique({
      where: { id: decoded.userId },
    });

    if (!user || !user.isActive) {
      return res.status(401).json({
        error: 'User not found or inactive',
      });
    }

    // Generate new token
    const newToken = jwt.sign(
      { userId: user.id, email: user.email },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
    );

    res.json({
      token: newToken,
    });
  } catch (error) {
    if (error.name === 'JsonWebTokenError' || error.name === 'TokenExpiredError') {
      return res.status(401).json({
        error: 'Invalid or expired token',
      });
    }
    
    res.status(500).json({
      error: 'Token refresh failed',
      details: error.message,
    });
  }
});

export default router;
