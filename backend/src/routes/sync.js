import express from 'express';
import { authenticateToken } from '../middleware/auth.js';

const router = express.Router();

// Sync offline data
router.post('/offline-data', authenticateToken, async (req, res) => {
  try {
    const { sync_data } = req.body;
    
    if (!sync_data || !Array.isArray(sync_data)) {
      return res.status(400).json({ error: 'Invalid sync data' });
    }
    
    const results = [];
    
    for (const item of sync_data) {
      try {
        if (item.sync_type === 'quiz_session') {
          // Handle quiz session sync
          const session = await req.prisma.quizSession.create({
            data: {
              userId: req.userId,
              levelId: item.levelId,
              totalQuestions: item.totalQuestions,
              correctAnswers: item.correctAnswers,
              score: item.score,
              xpEarned: item.xpEarned,
              accuracy: item.accuracy,
              completedAt: new Date(item.deviceTimestamp),
              offlineSessionId: item.offline_id,
              deviceTimestamp: new Date(item.deviceTimestamp),
            },
          });
          results.push({ type: 'quiz_session', id: session.id, status: 'synced' });
        }
        // Add other sync types as needed
      } catch (error) {
        results.push({ type: item.sync_type, error: error.message, status: 'failed' });
      }
    }
    
    res.json({ message: 'Sync completed', results });
  } catch (error) {
    res.status(500).json({ error: 'Sync failed', details: error.message });
  }
});

export default router;
