import '../models/quiz_question.dart';

class QuizData {
  static List<QuizQuestion> getQuestionsForLevel(int level) {
    switch (level) {
      case 1:
        return [
          QuizQuestion(
            tibetanText: 'ང་བོད་པ་ཡིན།',
            options: ['I am Tibetan.', 'You are Tibetan.', 'He is Tibetan.'],
            correctAnswerIndex: 0,
          ),
          QuizQuestion(
            tibetanText: 'ཁྱེད་རང་ག་པར་ཕེབས་ཀྱི་ཡོད།',
            options: ['Where are you going?', 'What are you doing?', 'How are you?'],
            correctAnswerIndex: 0,
          ),
          QuizQuestion(
            tibetanText: 'དེ་རིང་གནམ་གཤིས་ཡག་པོ་འདུག',
            options: ['The weather is nice today.', 'Today is Monday.', 'I like this weather.'],
            correctAnswerIndex: 0,
          ),
          QuizQuestion(
            tibetanText: 'ང་དཔེ་ཆ་ལྟ་གི་ཡོད།',
            options: ['I am studying.', 'I am walking.', 'I am eating.'],
            correctAnswerIndex: 0,
          ),
          QuizQuestion(
            tibetanText: 'ཁྱེད་རང་བདེ་པོ་ཡིན་པས།',
            options: ['How are you?', 'Where are you?', 'What is your name?'],
            correctAnswerIndex: 0,
          ),
        ];
      case 2:
        return [
          QuizQuestion(
            tibetanText: 'ང་ཚོ་ལྷ་སར་འགྲོ་གི་ཡིན།',
            options: ['We are going to Lhasa.', 'I am going to Lhasa.', 'They are going to Lhasa.'],
            correctAnswerIndex: 0,
          ),
          QuizQuestion(
            tibetanText: 'ཁྱེད་རང་བོད་སྐད་ཤེས་ཀྱི་ཡོད་པས།',
            options: ['Do you know Tibetan?', 'Can you speak English?', 'Are you Tibetan?'],
            correctAnswerIndex: 0,
          ),
          QuizQuestion(
            tibetanText: 'སང་ཉིན་ང་ཚོ་མཉམ་དུ་ཞལ་ལག་མཆོད།',
            options: ['Let\'s eat together tomorrow.', 'I ate yesterday.', 'I am hungry now.'],
            correctAnswerIndex: 0,
          ),
          QuizQuestion(
            tibetanText: 'ང་དེ་རིང་ཁོམ་ལ་འགྲོ་དགོས།',
            options: ['I need to go to market today.', 'I went to market yesterday.', 'The market is closed today.'],
            correctAnswerIndex: 0,
          ),
          QuizQuestion(
            tibetanText: 'ཁྱེད་རང་གི་པར་འདི་ཡག་པོ་འདུག',
            options: ['Your photo is nice.', 'This is a good camera.', 'I like photography.'],
            correctAnswerIndex: 0,
          ),
        ];
      case 3:
        return [
          QuizQuestion(
            tibetanText: 'ང་ཚོས་བོད་ཀྱི་སྐད་ཡིག་སྲུང་སྐྱོབ་བྱེད་དགོས།',
            options: ['We must preserve Tibetan language.', 'Tibetan is an ancient language.', 'I like Tibetan language.'],
            correctAnswerIndex: 0,
          ),
          QuizQuestion(
            tibetanText: 'བོད་ཀྱི་རིག་གཞུང་ཧ་ཅང་ཕྱུག་པོ་རེད།',
            options: ['Tibetan culture is very rich.', 'Tibet has many traditions.', 'I study Tibetan culture.'],
            correctAnswerIndex: 0,
          ),
          QuizQuestion(
            tibetanText: 'ང་ཚོ་ཚང་མས་མཉམ་རུབ་བྱས་ནས་ལས་ཀ་བྱེད་དགོས།',
            options: ['We all need to work together.', 'Everyone is working hard.', 'The work is finished.'],
            correctAnswerIndex: 0,
          ),
          QuizQuestion(
            tibetanText: 'བོད་ཀྱི་གནམ་གཤིས་གྲང་མོ་ཡོད།',
            options: ['The weather in Tibet is cold.', 'Tibet has four seasons.', 'I like cold weather.'],
            correctAnswerIndex: 0,
          ),
          QuizQuestion(
            tibetanText: 'ང་རྒྱ་གར་ལ་སློབ་སྦྱོང་བྱེད་དུ་ཕྱིན་པ་ཡིན།',
            options: ['I went to India to study.', 'I am studying in India.', 'India has good schools.'],
            correctAnswerIndex: 0,
          ),
        ];
      default:
        return [];
    }
  }
} 