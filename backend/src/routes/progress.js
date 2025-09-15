import express from 'express';
import { body, validationResult } from 'express-validator';
import { authenticateToken } from '../middleware/auth.js';

const router = express.Router();

// =====================================================
// SUBMIT QUIZ SESSION
// =====================================================

router.post('/quiz-session', authenticateToken, [
  body('levelId').isString().notEmpty(),
  body('totalQuestions').isInt({ min: 1 }),
  body('correctAnswers').isInt({ min: 0 }),
  body('score').isInt({ min: 0 }),
  body('timeTokenSeconds').optional().isInt({ min: 0 }),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        error: 'Validation failed',
        details: errors.array(),
      });
    }

    const {
      levelId,
      totalQuestions,
      correctAnswers,
      score,
      timeTokenSeconds,
      quizResults = [],
      offlineSessionId,
      deviceTimestamp,
    } = req.body;

    const accuracy = totalQuestions > 0 ? (correctAnswers / totalQuestions) * 100 : 0;
    const xpEarned = Math.floor(score * 1.5); // 1.5 XP per score point

    // Create quiz session
    const quizSession = await req.prisma.quizSession.create({
      data: {
        userId: req.userId,
        levelId,
        totalQuestions,
        correctAnswers,
        score,
        xpEarned,
        timeTokenSeconds,
        accuracy,
        offlineSessionId,
        deviceTimestamp: deviceTimestamp ? new Date(deviceTimestamp) : undefined,
        quizResults: {
          create: quizResults.map(result => ({
            questionId: result.questionId,
            userAnswer: result.userAnswer,
            correctAnswer: result.correctAnswer,
            isCorrect: result.isCorrect,
            timeTokenSeconds: result.timeTokenSeconds,
          })),
        },
      },
      include: {
        quizResults: true,
        level: {
          include: {
            category: true,
          },
        },
      },
    });

    // Update user progress
    await updateUserProgress(req.prisma, req.userId, {
      xpEarned,
      quizCompleted: true,
      correctAnswers,
      totalQuestions,
    });

    // Update category progress
    await updateCategoryProgress(req.prisma, req.userId, levelId, score, totalQuestions);

    // Check for achievements
    const newAchievements = await checkAchievements(req.prisma, req.userId);

    res.status(201).json({
      message: 'Quiz session submitted successfully',
      session: quizSession,
      xpEarned,
      newAchievements,
    });
  } catch (error) {
    console.error('Submit quiz session error:', error);
    res.status(500).json({
      error: 'Failed to submit quiz session',
      details: error.message,
    });
  }
});

// =====================================================
// SUBMIT GAME SCORE
// =====================================================

router.post('/game-score', authenticateToken, [
  body('gameId').isString().notEmpty(),
  body('score').isInt({ min: 0 }),
  body('timeTokenSeconds').optional().isInt({ min: 0 }),
  body('movesCount').optional().isInt({ min: 0 }),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        error: 'Validation failed',
        details: errors.array(),
      });
    }

    const {
      gameId,
      score,
      timeTokenSeconds,
      movesCount,
      offlineScoreId,
    } = req.body;

    // Get game info to calculate XP
    const game = await req.prisma.game.findUnique({
      where: { id: gameId },
    });

    if (!game) {
      return res.status(404).json({
        error: 'Game not found',
      });
    }

    const xpEarned = Math.min(game.xpReward, Math.floor(score * 0.1)); // Cap XP at game reward

    // Create game score
    const gameScore = await req.prisma.gameScore.create({
      data: {
        userId: req.userId,
        gameId,
        score,
        timeTokenSeconds,
        movesCount,
        xpEarned,
        offlineScoreId,
      },
      include: {
        game: {
          include: {
            level: {
              include: {
                category: true,
              },
            },
          },
        },
      },
    });

    // Update user progress
    await updateUserProgress(req.prisma, req.userId, {
      xpEarned,
      gameCompleted: true,
    });

    res.status(201).json({
      message: 'Game score submitted successfully',
      gameScore,
      xpEarned,
    });
  } catch (error) {
    console.error('Submit game score error:', error);
    res.status(500).json({
      error: 'Failed to submit game score',
      details: error.message,
    });
  }
});

// =====================================================
// UPDATE STREAK
// =====================================================

router.post('/streak', authenticateToken, async (req, res) => {
  try {
    const today = new Date();
    const todayDate = new Date(today.getFullYear(), today.getMonth(), today.getDate());

    // Check if user already has activity today
    const existingStreak = await req.prisma.dailyStreak.findUnique({
      where: {
        userId_activityDate: {
          userId: req.userId,
          activityDate: todayDate,
        },
      },
    });

    if (existingStreak) {
      // Update existing streak
      const updatedStreak = await req.prisma.dailyStreak.update({
        where: { id: existingStreak.id },
        data: {
          quizzesCompleted: { increment: 1 },
          xpEarned: { increment: req.body.xpEarned || 0 },
        },
      });

      return res.json({
        message: 'Streak updated',
        streak: updatedStreak,
      });
    }

    // Get user's current progress
    const userProgress = await req.prisma.userProgress.findUnique({
      where: { userId: req.userId },
    });

    // Calculate new streak
    let newStreakDay = 1;
    if (userProgress?.lastActivityDate) {
      const lastActivity = new Date(userProgress.lastActivityDate);
      const daysDiff = Math.floor((todayDate - lastActivity) / (1000 * 60 * 60 * 24));
      
      if (daysDiff === 1) {
        // Consecutive day
        newStreakDay = userProgress.currentStreak + 1;
      } else if (daysDiff > 1) {
        // Streak broken
        newStreakDay = 1;
      }
    }

    // Create new daily streak
    const dailyStreak = await req.prisma.dailyStreak.create({
      data: {
        userId: req.userId,
        activityDate: todayDate,
        quizzesCompleted: 1,
        xpEarned: req.body.xpEarned || 0,
        streakDay: newStreakDay,
      },
    });

    // Update user progress
    const longestStreak = Math.max(userProgress?.longestStreak || 0, newStreakDay);
    await req.prisma.userProgress.update({
      where: { userId: req.userId },
      data: {
        currentStreak: newStreakDay,
        longestStreak,
        lastActivityDate: todayDate,
      },
    });

    res.json({
      message: 'Streak updated successfully',
      streak: dailyStreak,
      currentStreak: newStreakDay,
      longestStreak,
    });
  } catch (error) {
    console.error('Update streak error:', error);
    res.status(500).json({
      error: 'Failed to update streak',
      details: error.message,
    });
  }
});

// =====================================================
// HELPER FUNCTIONS
// =====================================================

async function updateUserProgress(prisma, userId, updates) {
  const currentProgress = await prisma.userProgress.findUnique({
    where: { userId },
  });

  if (!currentProgress) return;

  const updateData = {
    totalXp: { increment: updates.xpEarned || 0 },
  };

  if (updates.quizCompleted) {
    updateData.totalQuizzesTaken = { increment: 1 };
    updateData.totalCorrectAnswers = { increment: updates.correctAnswers || 0 };
    
    // Calculate new accuracy
    const newTotalQuizzes = currentProgress.totalQuizzesTaken + 1;
    const newTotalCorrect = currentProgress.totalCorrectAnswers + (updates.correctAnswers || 0);
    updateData.overallAccuracy = newTotalQuizzes > 0 ? (newTotalCorrect / newTotalQuizzes) * 100 : 0;
  }

  await prisma.userProgress.update({
    where: { userId },
    data: updateData,
  });
}

async function updateCategoryProgress(prisma, userId, levelId, score, totalQuestions) {
  const level = await prisma.level.findUnique({
    where: { id: levelId },
    include: { category: true },
  });

  if (!level) return;

  const progress = await prisma.categoryProgress.upsert({
    where: {
      userId_categoryId: {
        userId,
        categoryId: level.categoryId,
      },
    },
    update: {
      totalScore: { increment: score },
      bestScore: { max: score },
      timesPracticed: { increment: 1 },
      lastPracticed: new Date(),
      progressPercentage: Math.min(100, (score / totalQuestions) * 100),
    },
    create: {
      userId,
      categoryId: level.categoryId,
      totalScore: score,
      bestScore: score,
      timesPracticed: 1,
      lastPracticed: new Date(),
      progressPercentage: (score / totalQuestions) * 100,
    },
  });

  return progress;
}

async function checkAchievements(prisma, userId) {
  const userProgress = await prisma.userProgress.findUnique({
    where: { userId },
  });

  if (!userProgress) return [];

  const newAchievements = [];
  const existingAchievements = await prisma.userAchievement.findMany({
    where: { userId },
    select: { achievementId: true },
  });

  const existingIds = new Set(existingAchievements.map(a => a.achievementId));

  // Check various achievement conditions
  const achievements = [
    { id: 'first_quiz', condition: userProgress.totalQuizzesTaken >= 1 },
    { id: 'quiz_10', condition: userProgress.totalQuizzesTaken >= 10 },
    { id: 'quiz_50', condition: userProgress.totalQuizzesTaken >= 50 },
    { id: 'streak_3', condition: userProgress.currentStreak >= 3 },
    { id: 'streak_7', condition: userProgress.currentStreak >= 7 },
    { id: 'streak_30', condition: userProgress.currentStreak >= 30 },
    { id: 'accuracy_80', condition: userProgress.overallAccuracy >= 80 && userProgress.totalQuizzesTaken >= 10 },
    { id: 'xp_1000', condition: userProgress.totalXp >= 1000 },
  ];

  for (const achievement of achievements) {
    if (achievement.condition && !existingIds.has(achievement.id)) {
      await prisma.userAchievement.create({
        data: {
          userId,
          achievementId: achievement.id,
        },
      });
      newAchievements.push(achievement.id);
    }
  }

  return newAchievements;
}

export default router;
