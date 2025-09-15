import express from 'express';
import { authenticateToken } from '../middleware/auth.js';

const router = express.Router();

// Get leaderboard
router.get('/', authenticateToken, async (req, res) => {
  const { type = 'weekly_xp', limit = 50 } = req.query;
  
  const leaderboard = await req.prisma.leaderboard.findMany({
    where: { leaderboardType: type.toUpperCase() },
    include: { user: { select: { displayName: true, username: true } } },
    orderBy: { rank: 'asc' },
    take: parseInt(limit),
  });
  
  res.json({ leaderboard });
});

export default router;
