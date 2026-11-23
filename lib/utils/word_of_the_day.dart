/// A small built-in word list for the home-screen widget's word of the day
/// (plan #25). Common, picturable words so the widget works offline and
/// before the first lesson. The same word all day, a different one the
/// next day, cycling through the list.
class DailyWord {
  const DailyWord(this.tibetan, this.phonetic, this.english);

  final String tibetan;
  final String phonetic;
  final String english;
}

class WordOfTheDay {
  WordOfTheDay._();

  static const List<DailyWord> words = [
    DailyWord('བཀྲ་ཤིས་བདེ་ལེགས།', 'tashi delek', 'hello'),
    DailyWord('ཐུགས་རྗེ་ཆེ།', 'thuk je che', 'thank you'),
    DailyWord('ཆུ།', 'chu', 'water'),
    DailyWord('ཇ།', 'ja', 'tea'),
    DailyWord('ཁ་ལག', 'khalak', 'food'),
    DailyWord('ཉི་མ།', 'nyima', 'sun'),
    DailyWord('ཟླ་བ།', 'dawa', 'moon'),
    DailyWord('སྐར་མ།', 'karma', 'star'),
    DailyWord('ནམ་མཁའ།', 'namkha', 'sky'),
    DailyWord('རི།', 'ri', 'mountain'),
    DailyWord('ཁ་བ།', 'khawa', 'snow'),
    DailyWord('ཆར་པ།', 'charpa', 'rain'),
    DailyWord('མཚོ།', 'tso', 'lake'),
    DailyWord('ཤིང་།', 'shing', 'tree'),
    DailyWord('མེ་ཏོག', 'metok', 'flower'),
    DailyWord('གཡག', 'yak', 'yak'),
    DailyWord('རྟ།', 'ta', 'horse'),
    DailyWord('ཁྱི།', 'khyi', 'dog'),
    DailyWord('ཞི་མི།', 'shimi', 'cat'),
    DailyWord('ཨ་མ།', 'ama', 'mother'),
    DailyWord('གྲོགས་པོ།', 'drokpo', 'friend'),
    DailyWord('ཁང་པ།', 'khangpa', 'house'),
    DailyWord('དཔེ་ཆ།', 'pecha', 'book'),
    DailyWord('ཡི་གེ', 'yige', 'letter'),
    DailyWord('སློབ་གྲྭ།', 'lobdra', 'school'),
    DailyWord('ཞོ།', 'sho', 'yogurt'),
    DailyWord('བོད།', 'bö', 'Tibet'),
    DailyWord('བོད་སྐད།', 'bökä', 'Tibetan language'),
    DailyWord('དཀར་པོ།', 'karpo', 'white'),
    DailyWord('སྔོན་པོ།', 'ngönpo', 'blue'),
    DailyWord('ལེགས་སོ།', 'lekso', 'well done'),
  ];

  static int _dayNumber(DateTime day) =>
      DateTime.utc(day.year, day.month, day.day).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;

  /// The word for [day]'s local calendar date.
  static DailyWord forDay(DateTime day) =>
      words[_dayNumber(day) % words.length];
}
