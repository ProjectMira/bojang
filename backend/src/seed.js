import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  console.log('🌱 Starting database seed...');

  // =====================================================
  // SEED CATEGORIES
  // =====================================================
  console.log('📚 Creating categories...');
  
  // Clear existing data first
  await prisma.categoryProgress.deleteMany({});
  await prisma.userAchievement.deleteMany({});
  await prisma.achievement.deleteMany({});
  await prisma.questionOption.deleteMany({});
  await prisma.question.deleteMany({});
  await prisma.game.deleteMany({});
  await prisma.level.deleteMany({});
  await prisma.category.deleteMany({});

  const categories = await Promise.all([
    prisma.category.create({
      data: {
        name: 'Greetings',
        tibetanName: 'འཕྲད་པའི་སྐད་ཆ',
        description: 'Basic greetings and polite expressions',
        sortOrder: 1,
      },
    }),
    prisma.category.create({
      data: {
        name: 'Numbers',
        tibetanName: 'གྲངས་ཀ',
        description: 'Numbers from 1 to 100 and counting',
        sortOrder: 2,
      },
    }),
    prisma.category.create({
      data: {
        name: 'Colors',
        tibetanName: 'ཚོས་གཞི',
        description: 'Basic colors and their names',
        sortOrder: 3,
      },
    }),
    prisma.category.create({
      data: {
        name: 'Family',
        tibetanName: 'ཁྱིམ་མི',
        description: 'Family members and relationships',
        sortOrder: 4,
      },
    }),
    prisma.category.create({
      data: {
        name: 'Food',
        tibetanName: 'ཟས་མོ',
        description: 'Common foods and meals',
        sortOrder: 5,
      },
    }),
    prisma.category.create({
      data: {
        name: 'Animals',
        tibetanName: 'སེམས་ཅན',
        description: 'Domestic and wild animals',
        sortOrder: 6,
      },
    }),
  ]);

  console.log(`✅ Created ${categories.length} categories`);

  // =====================================================
  // SEED LEVELS
  // =====================================================
  console.log('📈 Creating levels...');
  
  const levels = [];
  for (const category of categories) {
    for (let levelNum = 1; levelNum <= 3; levelNum++) {
      const difficulty = levelNum === 1 ? 'BEGINNER' : levelNum === 2 ? 'INTERMEDIATE' : 'ADVANCED';
      const level = await prisma.level.create({
        data: {
          categoryId: category.id,
          levelNumber: levelNum,
          name: `${category.name} Level ${levelNum}`,
          description: `${difficulty.toLowerCase()} ${category.name.toLowerCase()} vocabulary and phrases`,
          difficulty: difficulty,
          unlockRequirement: (levelNum - 1) * 50,
        },
      });
      levels.push(level);
    }
  }

  console.log(`✅ Created ${levels.length} levels`);

  // =====================================================
  // SEED ACHIEVEMENTS
  // =====================================================
  console.log('🏆 Creating achievements...');
  
  const achievements = [
    {
      id: 'first_quiz',
      name: 'First Steps',
      description: 'Complete your first quiz',
      category: 'milestone',
      requirementValue: 1,
      xpReward: 10,
      rarity: 'COMMON',
    },
    {
      id: 'first_perfect',
      name: 'Perfect Score',
      description: 'Get 100% on any quiz',
      category: 'accuracy',
      requirementValue: 100,
      xpReward: 25,
      rarity: 'RARE',
    },
    {
      id: 'streak_3',
      name: 'Getting Started',
      description: 'Maintain a 3-day learning streak',
      category: 'streak',
      requirementValue: 3,
      xpReward: 15,
      rarity: 'COMMON',
    },
    {
      id: 'streak_7',
      name: 'Week Warrior',
      description: 'Maintain a 7-day learning streak',
      category: 'streak',
      requirementValue: 7,
      xpReward: 30,
      rarity: 'RARE',
    },
    {
      id: 'streak_30',
      name: 'Monthly Master',
      description: 'Maintain a 30-day learning streak',
      category: 'streak',
      requirementValue: 30,
      xpReward: 100,
      rarity: 'LEGENDARY',
    },
    {
      id: 'accuracy_80',
      name: 'Precision Pro',
      description: 'Achieve 80% overall accuracy with 10+ quizzes',
      category: 'accuracy',
      requirementValue: 80,
      xpReward: 40,
      rarity: 'RARE',
    },
    {
      id: 'quiz_50',
      name: 'Quiz Champion',
      description: 'Complete 50 quizzes',
      category: 'quiz_count',
      requirementValue: 50,
      xpReward: 50,
      rarity: 'RARE',
    },
    {
      id: 'xp_1000',
      name: 'Rising Star',
      description: 'Earn 1,000 total XP',
      category: 'xp',
      requirementValue: 1000,
      xpReward: 50,
      rarity: 'RARE',
    },
  ];

  for (const achievement of achievements) {
    await prisma.achievement.create({
      data: achievement,
    });
  }

  console.log(`✅ Created ${achievements.length} achievements`);

  // =====================================================
  // SEED SAMPLE QUESTIONS (INCLUDING NEW MEDIA TYPES)
  // =====================================================
  console.log('❓ Creating sample questions...');
  
  // Find different categories for various question types
  const greetingsCategory = categories.find(c => c.name === 'Greetings');
  const animalsCategory = categories.find(c => c.name === 'Animals');
  const foodCategory = categories.find(c => c.name === 'Food');
  
  const greetingsLevel1 = levels.find(l => l.categoryId === greetingsCategory.id && l.levelNumber === 1);
  const animalsLevel1 = levels.find(l => l.categoryId === animalsCategory.id && l.levelNumber === 1);
  const foodLevel2 = levels.find(l => l.categoryId === foodCategory.id && l.levelNumber === 2);
  
  let totalQuestions = 0;

  // Traditional text-based questions
  if (greetingsLevel1) {
    const textQuestions = [
      {
        questionType: 'MULTIPLE_CHOICE',
        questionText: 'How do you say "Hello" in Tibetan?',
        questionTextTibetan: 'བོད་སྐད་ནང་"Hello"གི་ཡི་གེ་ག་རེ་རེད།',
        correctAnswer: 'བཀྲ་ཤིས་བདེ་ལེགས།',
        explanation: 'This is the most common greeting in Tibetan',
        options: [
          { text: 'བཀྲ་ཤིས་བདེ་ལེགས།', isCorrect: true, order: 1 },
          { text: 'ཐུགས་རྗེ་ཆེ།', isCorrect: false, order: 2 },
          { text: 'ཕེབས་མཁན།', isCorrect: false, order: 3 },
          { text: 'སྐུ་ཁམས་བཟང་།', isCorrect: false, order: 4 },
        ],
      },
      {
        questionType: 'MULTIPLE_CHOICE',
        questionText: 'What does "ཐུགས་རྗེ་ཆེ།" mean?',
        questionTextTibetan: '"ཐུགས་རྗེ་ཆེ།"གི་དོན་དག་གང་རེད།',
        correctAnswer: 'Thank you',
        explanation: 'A polite way to express gratitude',
        options: [
          { text: 'Thank you', isCorrect: true, order: 1 },
          { text: 'Hello', isCorrect: false, order: 2 },
          { text: 'Goodbye', isCorrect: false, order: 3 },
          { text: 'How are you?', isCorrect: false, order: 4 },
        ],
      },
    ];

    for (const questionData of textQuestions) {
      const question = await prisma.question.create({
        data: {
          levelId: greetingsLevel1.id,
          questionType: questionData.questionType,
          questionText: questionData.questionText,
          questionTextTibetan: questionData.questionTextTibetan,
          correctAnswer: questionData.correctAnswer,
          explanation: questionData.explanation,
          difficultyScore: 1,
        },
      });

      for (const optionData of questionData.options) {
        await prisma.questionOption.create({
          data: {
            questionId: question.id,
            optionText: optionData.text,
            isCorrect: optionData.isCorrect,
            sortOrder: optionData.order,
          },
        });
      }
    }
    totalQuestions += textQuestions.length;
  }

  // Audio-based questions
  if (animalsLevel1) {
    const audioQuestions = [
      {
        questionType: 'AUDIO_TO_TEXT',
        questionText: 'Listen to the Tibetan word. What animal is this?',
        questionAudioUrl: 'audio/animals/khyi_dog.wav',
        correctAnswer: 'Dog',
        explanation: 'This is the Tibetan word for dog: ཁྱི',
        options: [
          { text: 'Dog', tibetan: 'ཁྱི', isCorrect: true, order: 1 },
          { text: 'Cat', tibetan: 'ཞི་མི', isCorrect: false, order: 2 },
          { text: 'Horse', tibetan: 'རྟ', isCorrect: false, order: 3 },
          { text: 'Bird', tibetan: 'བྱ', isCorrect: false, order: 4 },
        ],
      },
      {
        questionType: 'TEXT_TO_AUDIO',
        questionText: 'How do you pronounce "Tiger" in Tibetan?',
        questionTextTibetan: 'སྟག',
        correctAnswer: 'audio/animals/stag_tiger.wav',
        explanation: 'This is the correct pronunciation of སྟག (tiger)',
        options: [
          { audioUrl: 'audio/animals/stag_tiger.wav', isCorrect: true, order: 1 },
          { audioUrl: 'audio/animals/sengge_lion.wav', isCorrect: false, order: 2 },
          { audioUrl: 'audio/animals/dom_bear.wav', isCorrect: false, order: 3 },
          { audioUrl: 'audio/animals/spyang_wolf.wav', isCorrect: false, order: 4 },
        ],
      },
    ];

    for (const questionData of audioQuestions) {
      const question = await prisma.question.create({
        data: {
          levelId: animalsLevel1.id,
          questionType: questionData.questionType,
          questionText: questionData.questionText,
          questionTextTibetan: questionData.questionTextTibetan,
          questionAudioUrl: questionData.questionAudioUrl,
          correctAnswer: questionData.correctAnswer,
          explanation: questionData.explanation,
          difficultyScore: 2,
        },
      });

      for (const optionData of questionData.options) {
        await prisma.questionOption.create({
          data: {
            questionId: question.id,
            optionText: optionData.text,
            optionTextTibetan: optionData.tibetan,
            optionAudioUrl: optionData.audioUrl,
            isCorrect: optionData.isCorrect,
            sortOrder: optionData.order,
          },
        });
      }
    }
    totalQuestions += audioQuestions.length;
  }

  // Image-based questions
  if (foodLevel2) {
    const imageQuestions = [
      {
        questionType: 'IMAGE_TO_TEXT',
        questionText: 'What traditional Tibetan food is shown in the image?',
        questionImageUrl: 'images/food/momo.jpg',
        correctAnswer: 'Momo',
        explanation: 'Momo are traditional Tibetan dumplings, very popular across Tibet',
        options: [
          { text: 'Momo (Dumpling)', tibetan: 'མོག་མོག', isCorrect: true, order: 1 },
          { text: 'Thukpa (Noodle soup)', tibetan: 'ཐུག་པ', isCorrect: false, order: 2 },
          { text: 'Tsampa (Barley flour)', tibetan: 'རྩམ་པ', isCorrect: false, order: 3 },
          { text: 'Shapale (Meat pie)', tibetan: 'ཤ་པ་ལེ', isCorrect: false, order: 4 },
        ],
      },
      {
        questionType: 'TEXT_TO_IMAGE',
        questionText: 'Select the image that shows "Butter tea"',
        questionTextTibetan: 'བོད་ཇ',
        correctAnswer: 'images/food/butter-tea.jpg',
        explanation: 'Butter tea (བོད་ཇ) is a traditional Tibetan drink made with tea, yak butter, and salt',
        options: [
          { imageUrl: 'images/food/butter-tea.jpg', isCorrect: true, order: 1 },
          { imageUrl: 'images/food/sweet-tea.jpg', isCorrect: false, order: 2 },
          { imageUrl: 'images/food/milk-tea.jpg', isCorrect: false, order: 3 },
          { imageUrl: 'images/food/green-tea.jpg', isCorrect: false, order: 4 },
        ],
      },
    ];

    for (const questionData of imageQuestions) {
      const question = await prisma.question.create({
        data: {
          levelId: foodLevel2.id,
          questionType: questionData.questionType,
          questionText: questionData.questionText,
          questionTextTibetan: questionData.questionTextTibetan,
          questionImageUrl: questionData.questionImageUrl,
          correctAnswer: questionData.correctAnswer,
          explanation: questionData.explanation,
          difficultyScore: 2,
        },
      });

      for (const optionData of questionData.options) {
        await prisma.questionOption.create({
          data: {
            questionId: question.id,
            optionText: optionData.text,
            optionTextTibetan: optionData.tibetan,
            optionImageUrl: optionData.imageUrl,
            isCorrect: optionData.isCorrect,
            sortOrder: optionData.order,
          },
        });
      }
    }
    totalQuestions += imageQuestions.length;
  }

  console.log(`✅ Created ${totalQuestions} sample questions (text, audio, and image types)`);

  // =====================================================
  // SEED SAMPLE GAMES
  // =====================================================
  console.log('🎮 Creating sample games...');
  
  // Find greetings level again for games
  const greetingsLevelForGames = levels.find(l => l.categoryId === greetingsCategory.id && l.levelNumber === 1);
  
  if (greetingsLevelForGames) {
    const memoryMatchGame = await prisma.game.create({
      data: {
        gameType: 'MEMORY_MATCH',
        levelId: greetingsLevelForGames.id,
        name: 'Greeting Memory Match',
        description: 'Match Tibetan greetings with their English translations',
        gameData: {
          pairs: [
            { tibetan: 'བཀྲ་ཤིས་བདེ་ལེགས།', english: 'Hello' },
            { tibetan: 'ཐུགས་རྗེ་ཆེ།', english: 'Thank you' },
            { tibetan: 'ཕེབས་མཁན།', english: 'Goodbye' },
            { tibetan: 'སྐུ་ཁམས་བཟང་།', english: 'How are you?' },
          ],
        },
        difficulty: 'EASY',
        estimatedTimeMinutes: 3,
        xpReward: 15,
      },
    });

    console.log('✅ Created sample memory match game');
  }

  // =====================================================
  // SEED CONTENT VERSIONS
  // =====================================================
  console.log('📦 Creating content versions...');
  
  const contentTypes = ['QUESTIONS', 'GAMES', 'ACHIEVEMENTS', 'CATEGORIES'];
  for (const contentType of contentTypes) {
    await prisma.contentVersion.create({
      data: {
        contentType: contentType,
        versionNumber: 1,
        description: `Initial ${contentType.toLowerCase()} content`,
      },
    });
  }

  console.log('✅ Created content versions');

  console.log('🎉 Database seeded successfully!');
  console.log('');
  console.log('📊 Summary:');
  console.log(`   Categories: ${categories.length}`);
  console.log(`   Levels: ${levels.length}`);
  console.log(`   Achievements: ${achievements.length}`);
  console.log(`   Sample Questions: ${totalQuestions} (text, audio, and image types)`);
  console.log(`   Sample Games: 1`);
  console.log('');
  console.log('🚀 Ready to start your Tibetan learning app with multimedia support!');
  console.log('');
  console.log('📱 New Question Types Added:');
  console.log('   • AUDIO_TO_TEXT: Listen and identify');
  console.log('   • TEXT_TO_AUDIO: Choose correct pronunciation');
  console.log('   • IMAGE_TO_TEXT: Visual recognition');
  console.log('   • TEXT_TO_IMAGE: Select matching image');
  console.log('');
  console.log('☁️  S3 Bucket Placeholders:');
  console.log('   • Audio: bojang-audio-bucket.s3.amazonaws.com');
  console.log('   • Images: bojang-images-bucket.s3.amazonaws.com');
}

main()
  .catch((e) => {
    console.error('❌ Seed failed:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
