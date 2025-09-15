import express from 'express';
import { authenticateToken } from '../middleware/auth.js';

const router = express.Router();

// Get all achievements
router.get('/', authenticateToken, async (req, res) => {
  const achievements = await req.prisma.achievement.findMany({
    where: { isActive: true },
  });
  res.json({ achievements });
});

// Get user achievements
router.get('/user', authenticateToken, async (req, res) => {
  const userAchievements = await req.prisma.userAchievement.findMany({
    where: { userId: req.userId },
    include: { achievement: true },
  });
  res.json({ userAchievements });
});

export default router;
