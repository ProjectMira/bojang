import express from 'express';
import { authenticateToken } from '../middleware/auth.js';

const router = express.Router();

// Get user profile
router.get('/profile', authenticateToken, async (req, res) => {
  const { passwordHash, ...userWithoutPassword } = req.user;
  res.json({ user: userWithoutPassword });
});

// Get user progress
router.get('/progress', authenticateToken, async (req, res) => {
  const progress = await req.prisma.userProgress.findUnique({
    where: { userId: req.userId },
  });
  res.json({ progress });
});

export default router;
