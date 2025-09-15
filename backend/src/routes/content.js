import express from 'express';
import { authenticateToken } from '../middleware/auth.js';

const router = express.Router();

// =====================================================
// CATEGORIES
// =====================================================

/**
 * @swagger
 * /content/categories:
 *   get:
 *     tags:
 *       - Content
 *     summary: Get all categories
 *     description: Retrieve all active categories with their levels
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Categories retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 categories:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/Category'
 *                 count:
 *                   type: integer
 *                   description: Number of categories
 *       401:
 *         description: Unauthorized
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *       500:
 *         description: Failed to fetch categories
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
router.get('/categories', authenticateToken, async (req, res) => {
  try {
    const categories = await req.prisma.category.findMany({
      where: { isActive: true },
      orderBy: { sortOrder: 'asc' },
      include: {
        levels: {
          where: { isActive: true },
          orderBy: { levelNumber: 'asc' },
        },
      },
    });

    res.json({
      categories,
      count: categories.length,
    });
  } catch (error) {
    console.error('Get categories error:', error);
    res.status(500).json({
      error: 'Failed to fetch categories',
      details: error.message,
    });
  }
});

// =====================================================
// LEVELS
// =====================================================

/**
 * @swagger
 * /content/categories/{categoryId}/levels:
 *   get:
 *     tags:
 *       - Content
 *     summary: Get levels for a category
 *     description: Retrieve all levels for a specific category
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: categoryId
 *         required: true
 *         schema:
 *           type: string
 *         description: Category ID
 *     responses:
 *       200:
 *         description: Levels retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 levels:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/Level'
 *                 count:
 *                   type: integer
 *                   description: Number of levels
 *       401:
 *         description: Unauthorized
 *       404:
 *         description: Category not found
 *       500:
 *         description: Failed to fetch levels
 */
router.get('/categories/:categoryId/levels', authenticateToken, async (req, res) => {
  try {
    const { categoryId } = req.params;

    const levels = await req.prisma.level.findMany({
      where: {
        categoryId,
        isActive: true,
      },
      orderBy: { levelNumber: 'asc' },
      include: {
        category: true,
        _count: {
          select: {
            questions: true,
            games: true,
          },
        },
      },
    });

    res.json({
      levels,
      count: levels.length,
    });
  } catch (error) {
    console.error('Get levels error:', error);
    res.status(500).json({
      error: 'Failed to fetch levels',
      details: error.message,
    });
  }
});

// Get all levels structure (similar to levels.json)
router.get('/levels', authenticateToken, async (req, res) => {
  try {
    const categories = await req.prisma.category.findMany({
      where: { isActive: true },
      orderBy: { sortOrder: 'asc' },
      include: {
        levels: {
          where: { isActive: true },
          orderBy: { levelNumber: 'asc' },
        },
      },
    });

    const levelsStructure = {
      levels: categories.map(category => ({
        level: category.sortOrder,
        title: category.name,
        sublevels: category.levels.map(level => ({
          level: `${category.sortOrder}.${level.levelNumber}`,
          name: level.name,
          description: level.description,
          difficulty: level.difficulty,
          questionCount: 0, // Will be populated by separate API calls
        }))
      }))
    };

    res.json(levelsStructure);
  } catch (error) {
    console.error('Get levels structure error:', error);
    res.status(500).json({
      error: 'Failed to fetch levels structure',
      details: error.message,
    });
  }
});

// =====================================================
// QUESTIONS
// =====================================================

router.get('/levels/:levelId/questions', authenticateToken, async (req, res) => {
  try {
    const { levelId } = req.params;
    const { limit = 10, shuffle = 'false' } = req.query;

    let questions = await req.prisma.question.findMany({
      where: {
        levelId,
        isActive: true,
      },
      include: {
        options: {
          orderBy: { sortOrder: 'asc' },
        },
      },
      take: parseInt(limit),
    });

    // Shuffle questions if requested
    if (shuffle === 'true') {
      questions = questions.sort(() => Math.random() - 0.5);
    }

    // Transform URLs to full API URLs
    const baseUrl = `${req.protocol}://${req.get('host')}/media`;
    
    const transformedQuestions = questions.map(question => ({
      ...question,
      questionImageUrl: question.questionImageUrl ? `${baseUrl}/${question.questionImageUrl.replace('assets/', '')}` : null,
      questionAudioUrl: question.questionAudioUrl ? `${baseUrl}/${question.questionAudioUrl.replace('assets/', '')}` : null,
      options: question.options.map(option => ({
        ...option,
        optionImageUrl: option.optionImageUrl ? `${baseUrl}/${option.optionImageUrl.replace('assets/', '')}` : null,
        optionAudioUrl: option.optionAudioUrl ? `${baseUrl}/${option.optionAudioUrl.replace('assets/', '')}` : null,
      }))
    }));

    res.json({
      questions: transformedQuestions,
      count: transformedQuestions.length,
    });
  } catch (error) {
    console.error('Get questions error:', error);
    res.status(500).json({
      error: 'Failed to fetch questions',
      details: error.message,
    });
  }
});

// =====================================================
// GAMES
// =====================================================

router.get('/levels/:levelId/games', authenticateToken, async (req, res) => {
  try {
    const { levelId } = req.params;

    const games = await req.prisma.game.findMany({
      where: {
        levelId,
        isActive: true,
      },
      include: {
        level: {
          include: {
            category: true,
          },
        },
      },
    });

    res.json({
      games,
      count: games.length,
    });
  } catch (error) {
    console.error('Get games error:', error);
    res.status(500).json({
      error: 'Failed to fetch games',
      details: error.message,
    });
  }
});

// =====================================================
// CONTENT VERSION
// =====================================================

router.get('/version', authenticateToken, async (req, res) => {
  try {
    const versions = await req.prisma.contentVersion.findMany({
      where: { isActive: true },
      orderBy: { versionNumber: 'desc' },
    });

    const latestVersions = {};
    versions.forEach(version => {
      if (!latestVersions[version.contentType] || 
          version.versionNumber > latestVersions[version.contentType].versionNumber) {
        latestVersions[version.contentType] = version;
      }
    });

    res.json({
      versions: latestVersions,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    console.error('Get content version error:', error);
    res.status(500).json({
      error: 'Failed to fetch content version',
      details: error.message,
    });
  }
});

// =====================================================
// SEARCH CONTENT
// =====================================================

router.get('/search', authenticateToken, async (req, res) => {
  try {
    const { q, type = 'all' } = req.query;

    if (!q || q.trim().length < 2) {
      return res.status(400).json({
        error: 'Search query must be at least 2 characters',
      });
    }

    const searchTerm = q.trim();
    const results = {};

    if (type === 'all' || type === 'questions') {
      results.questions = await req.prisma.question.findMany({
        where: {
          isActive: true,
          OR: [
            { questionText: { contains: searchTerm, mode: 'insensitive' } },
            { questionTextTibetan: { contains: searchTerm } },
            { explanation: { contains: searchTerm, mode: 'insensitive' } },
          ],
        },
        include: {
          level: {
            include: {
              category: true,
            },
          },
        },
        take: 20,
      });
    }

    if (type === 'all' || type === 'categories') {
      results.categories = await req.prisma.category.findMany({
        where: {
          isActive: true,
          OR: [
            { name: { contains: searchTerm, mode: 'insensitive' } },
            { tibetanName: { contains: searchTerm } },
            { description: { contains: searchTerm, mode: 'insensitive' } },
          ],
        },
        take: 10,
      });
    }

    res.json({
      query: searchTerm,
      results,
      totalResults: Object.values(results).reduce((sum, arr) => sum + arr.length, 0),
    });
  } catch (error) {
    console.error('Search error:', error);
    res.status(500).json({
      error: 'Search failed',
      details: error.message,
    });
  }
});

export default router;
