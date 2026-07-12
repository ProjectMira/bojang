/// Shared visual helpers for vocabulary topics.
library;

const Map<String, String> _topicEmojis = {
  'action': '🏃',
  'adjectives': '✨',
  'animals': '🐾',
  'body': '💪',
  'books': '📚',
  'clothes': '👕',
  'colors': '🎨',
  'digital': '💻',
  'direction': '🧭',
  'drinks': '🍵',
  'electricity': '💡',
  'extreme adverb': '⚡',
  'family': '👨‍👩‍👧‍👦',
  'fruits': '🍎',
  'home': '🏠',
  'hospital': '🏥',
  'kitchen': '🍳',
  'money': '💰',
  'nature': '🌿',
  'noun': '🔤',
  'number': '🔢',
  'numbers': '🔢',
  'photo': '📷',
  'political terms': '🏛️',
  'tent': '⛺',
  'time': '⏰',
  'transport': '🚌',
  'types of mountains': '🗻',
  'vegetables': '🥕',
  'verbs(body mov.)': '🤸',
  'vocabulary': '📖',
  'week': '📅',
  'alphabet': 'ཀ',
  'greetings': '🙏',
};

String topicEmoji(String name) {
  return _topicEmojis[name.toLowerCase().trim()] ?? '📖';
}
