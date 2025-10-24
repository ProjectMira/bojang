import express from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { body, validationResult } from 'express-validator';

const router = express.Router();

// =====================================================
// REGISTER
// =====================================================

/**
 * @swagger
 * /auth/register:
 *   post:
 *     tags:
 *       - Authentication
 *     summary: Register a new user
 *     description: Create a new user account with email and password
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - email
 *               - username
 *               - password
 *               - displayName
 *             properties:
 *               email:
 *                 type: string
 *                 format: email
 *                 description: User's email address
 *                 example: user@example.com
 *               username:
 *                 type: string
 *                 minLength: 3
 *                 maxLength: 20
 *                 description: Unique username
 *                 example: john_doe
 *               password:
 *                 type: string
 *                 minLength: 6
 *                 description: User's password
 *                 example: mySecurePassword123
 *               displayName:
 *                 type: string
 *                 minLength: 1
 *                 maxLength: 100
 *                 description: User's display name
 *                 example: John Doe
 *               deviceId:
 *                 type: string
 *                 description: Optional device identifier
 *                 example: device_12345
 *     responses:
 *       201:
 *         description: User registered successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                   example: User registered successfully
 *                 token:
 *                   type: string
 *                   description: JWT authentication token
 *                   example: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
 *                 user:
 *                   $ref: '#/components/schemas/User'
 *       400:
 *         description: Validation failed
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *       409:
 *         description: User already exists
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *       500:
 *         description: Registration failed
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
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

/**
 * @swagger
 * /auth/login:
 *   post:
 *     tags:
 *       - Authentication
 *     summary: User login
 *     description: Authenticate user with email and password
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - email
 *               - password
 *             properties:
 *               email:
 *                 type: string
 *                 format: email
 *                 description: User's email address
 *                 example: user@example.com
 *               password:
 *                 type: string
 *                 description: User's password
 *                 example: mySecurePassword123
 *               deviceId:
 *                 type: string
 *                 description: Optional device identifier
 *                 example: device_12345
 *     responses:
 *       200:
 *         description: Login successful
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                   example: Login successful
 *                 token:
 *                   type: string
 *                   description: JWT authentication token
 *                   example: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
 *                 user:
 *                   $ref: '#/components/schemas/User'
 *       400:
 *         description: Validation failed
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *       401:
 *         description: Authentication failed
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *       500:
 *         description: Login failed
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
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

/**
 * @swagger
 * /auth/logout:
 *   post:
 *     tags:
 *       - Authentication
 *     summary: User logout
 *     description: Logout user (client-side token invalidation for JWT)
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Logout successful
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                   example: Logout successful
 */
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

/**
 * @swagger
 * /auth/refresh:
 *   post:
 *     tags:
 *       - Authentication
 *     summary: Refresh JWT token
 *     description: Get a new JWT token using existing valid token
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - token
 *             properties:
 *               token:
 *                 type: string
 *                 description: Current JWT token
 *                 example: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
 *     responses:
 *       200:
 *         description: Token refreshed successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 token:
 *                   type: string
 *                   description: New JWT authentication token
 *                   example: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
 *       401:
 *         description: Invalid or expired token
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *       500:
 *         description: Token refresh failed
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
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

// =====================================================
// GOOGLE AUTH
// =====================================================

/**
 * @swagger
 * /auth/google:
 *   post:
 *     tags:
 *       - Authentication
 *     summary: Google OAuth authentication
 *     description: Authenticate user with Google OAuth credentials
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - google_id
 *               - email
 *               - display_name
 *             properties:
 *               google_id:
 *                 type: string
 *                 description: Google user ID
 *               email:
 *                 type: string
 *                 format: email
 *                 description: Google account email
 *               display_name:
 *                 type: string
 *                 description: Google account display name
 *               profile_image_url:
 *                 type: string
 *                 format: uri
 *                 description: Google profile image URL
 *               id_token:
 *                 type: string
 *                 description: Google ID token
 *               access_token:
 *                 type: string
 *                 description: Google access token
 *     responses:
 *       200:
 *         description: Google authentication successful
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                   example: Google authentication successful
 *                 token:
 *                   type: string
 *                   description: JWT authentication token
 *                 user:
 *                   $ref: '#/components/schemas/User'
 *       400:
 *         description: Invalid Google credentials
 *       500:
 *         description: Google authentication failed
 */
router.post('/google', async (req, res) => {
  try {
    const { google_id, email, display_name, profile_image_url, id_token, access_token } = req.body;

    if (!google_id || !email || !display_name) {
      return res.status(400).json({
        error: 'Missing required Google credentials',
      });
    }

    // Check if user already exists
    let user = await req.prisma.user.findFirst({
      where: {
        OR: [
          { email },
          { googleId: google_id },
        ],
      },
      include: {
        userProgress: true,
      },
    });

    if (user) {
      // Update existing user
      user = await req.prisma.user.update({
        where: { id: user.id },
        data: {
          lastLogin: new Date(),
          profileImageUrl: profile_image_url || user.profileImageUrl,
        },
        include: {
          userProgress: true,
        },
      });
    } else {
      // Create new user
      user = await req.prisma.user.create({
        data: {
          email,
          username: email.split('@')[0].replace(/[^a-zA-Z0-9]/g, '') + Math.random().toString(36).substr(2, 5),
          passwordHash: '', // No password for Google users
          displayName: display_name,
          profileImageUrl: profile_image_url,
          googleId: google_id,
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
    }

    // Generate JWT token
    const token = jwt.sign(
      { userId: user.id, email: user.email },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
    );

    // Remove password hash from response
    const { passwordHash: _, ...userWithoutPassword } = user;

    res.json({
      message: 'Google authentication successful',
      token,
      user: userWithoutPassword,
    });
  } catch (error) {
    console.error('Google auth error:', error);
    res.status(500).json({
      error: 'Google authentication failed',
      details: error.message,
    });
  }
});

export default router;
