import swaggerJSDoc from 'swagger-jsdoc';
import swaggerUi from 'swagger-ui-express';

const options = {
  definition: {
    openapi: '3.0.0',
    info: {
      title: 'Bojang API',
      version: '1.0.0',
      description: 'Backend API for Bojang Tibetan Learning App',
      contact: {
        name: 'Bojang Team',
        email: 'support@bojang.app'
      },
      license: {
        name: 'MIT',
        url: 'https://opensource.org/licenses/MIT'
      }
    },
    servers: [
      {
        url: process.env.NODE_ENV === 'production' 
          ? 'https://bojang.onrender.com/api/v1' 
          : 'http://localhost:3000/api/v1',
        description: process.env.NODE_ENV === 'production' ? 'Production server' : 'Development server'
      }
    ],
    components: {
      securitySchemes: {
        bearerAuth: {
          type: 'http',
          scheme: 'bearer',
          bearerFormat: 'JWT',
          description: 'Enter JWT token'
        }
      },
      schemas: {
        User: {
          type: 'object',
          required: ['id', 'email', 'username', 'displayName'],
          properties: {
            id: {
              type: 'string',
              description: 'Unique user identifier'
            },
            email: {
              type: 'string',
              format: 'email',
              description: 'User email address'
            },
            username: {
              type: 'string',
              description: 'Unique username'
            },
            displayName: {
              type: 'string',
              description: 'User display name'
            },
            profileImageUrl: {
              type: 'string',
              format: 'uri',
              description: 'Profile image URL'
            },
            createdAt: {
              type: 'string',
              format: 'date-time',
              description: 'Account creation timestamp'
            },
            lastLogin: {
              type: 'string',
              format: 'date-time',
              description: 'Last login timestamp'
            },
            isActive: {
              type: 'boolean',
              description: 'Account status'
            },
            timezone: {
              type: 'string',
              description: 'User timezone'
            },
            preferredLanguage: {
              type: 'string',
              description: 'Preferred language code'
            }
          }
        },
        UserProgress: {
          type: 'object',
          properties: {
            id: { type: 'string' },
            userId: { type: 'string' },
            currentLevel: { type: 'integer' },
            totalXp: { type: 'integer' },
            currentStreak: { type: 'integer' },
            longestStreak: { type: 'integer' },
            lastActivityDate: { type: 'string', format: 'date' },
            totalQuizzesTaken: { type: 'integer' },
            totalCorrectAnswers: { type: 'integer' },
            overallAccuracy: { type: 'number', format: 'float' }
          }
        },
        Category: {
          type: 'object',
          properties: {
            id: { type: 'string' },
            name: { type: 'string' },
            tibetanName: { type: 'string' },
            description: { type: 'string' },
            iconUrl: { type: 'string', format: 'uri' },
            sortOrder: { type: 'integer' },
            isActive: { type: 'boolean' }
          }
        },
        Level: {
          type: 'object',
          properties: {
            id: { type: 'string' },
            categoryId: { type: 'string' },
            levelNumber: { type: 'integer' },
            name: { type: 'string' },
            description: { type: 'string' },
            difficulty: { 
              type: 'string', 
              enum: ['BEGINNER', 'INTERMEDIATE', 'ADVANCED'] 
            },
            unlockRequirement: { type: 'integer' },
            isActive: { type: 'boolean' }
          }
        },
        Question: {
          type: 'object',
          properties: {
            id: { type: 'string' },
            levelId: { type: 'string' },
            questionType: { 
              type: 'string',
              enum: [
                'MULTIPLE_CHOICE', 'FILL_BLANK', 'PRONUNCIATION', 'MATCHING',
                'AUDIO_TO_TEXT', 'TEXT_TO_AUDIO', 'IMAGE_TO_TEXT', 'TEXT_TO_IMAGE',
                'AUDIO_MULTIPLE_CHOICE', 'IMAGE_MULTIPLE_CHOICE'
              ]
            },
            questionText: { type: 'string' },
            questionTextTibetan: { type: 'string' },
            questionAudioUrl: { type: 'string', format: 'uri' },
            questionImageUrl: { type: 'string', format: 'uri' },
            correctAnswer: { type: 'string' },
            explanation: { type: 'string' },
            explanationTibetan: { type: 'string' },
            difficultyScore: { type: 'integer' },
            isActive: { type: 'boolean' }
          }
        },
        QuizSession: {
          type: 'object',
          properties: {
            id: { type: 'string' },
            userId: { type: 'string' },
            levelId: { type: 'string' },
            totalQuestions: { type: 'integer' },
            correctAnswers: { type: 'integer' },
            score: { type: 'integer' },
            xpEarned: { type: 'integer' },
            timeTokenSeconds: { type: 'integer' },
            accuracy: { type: 'number', format: 'float' },
            completedAt: { type: 'string', format: 'date-time' }
          }
        },
        Achievement: {
          type: 'object',
          properties: {
            id: { type: 'string' },
            name: { type: 'string' },
            description: { type: 'string' },
            iconUrl: { type: 'string', format: 'uri' },
            category: { type: 'string' },
            requirementValue: { type: 'integer' },
            xpReward: { type: 'integer' },
            rarity: { 
              type: 'string', 
              enum: ['COMMON', 'RARE', 'EPIC', 'LEGENDARY'] 
            },
            isActive: { type: 'boolean' }
          }
        },
        Error: {
          type: 'object',
          properties: {
            error: {
              type: 'string',
              description: 'Error message'
            },
            details: {
              type: 'string',
              description: 'Additional error details'
            }
          }
        },
        SuccessResponse: {
          type: 'object',
          properties: {
            success: {
              type: 'boolean',
              example: true
            },
            message: {
              type: 'string',
              description: 'Success message'
            },
            data: {
              type: 'object',
              description: 'Response data'
            }
          }
        }
      }
    },
    security: [
      {
        bearerAuth: []
      }
    ]
  },
  apis: ['./src/routes/*.js'], // paths to files containing OpenAPI definitions
};

const specs = swaggerJSDoc(options);

export { specs, swaggerUi };
