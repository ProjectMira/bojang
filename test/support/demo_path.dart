/// A seven-unit path, one unit per biome: the first passed, the second in
/// progress, the rest locked.
Map<String, dynamic> demoPathJson() {
  const units = [
    (
      'Reading Tibetan',
      'Letters, syllables, numbers and first phrases',
      ['Letters 1: ཀ to ང', 'Letters 2: ཅ to ཉ', 'Vowels', 'Review: Reading'],
    ),
    (
      'First words',
      'Greetings, people and everyday things',
      [
        'Saying hello',
        'Family',
        'Numbers 1 to 10',
        'Practice',
        'Review: First words',
      ],
    ),
    (
      'Food and drink',
      'Butter tea, tsampa and the market',
      ['At the table', 'Butter tea', 'Market', 'Review: Food'],
    ),
    (
      'Home and village',
      'Rooms, animals and the fields',
      ['The house', 'Animals', 'Saying where', 'Review: Home'],
    ),
    (
      'Monastery visit',
      'Places, offerings and polite speech',
      ['Honorifics', 'At the temple', 'Review: Monastery'],
    ),
    (
      'Travel',
      'Directions, time and the weather',
      ['Directions', 'Telling time', 'Weather', 'Review: Travel'],
    ),
    (
      'Over the pass',
      'Stories and longer sentences',
      ['A short story', 'Questions', 'Review: Over the pass'],
    ),
  ];
  var unitIndex = 0;
  return {
    'active_node_id': 'u2-n2',
    'daily': {'sessions': 1, 'goal': 2},
    'units': [
      for (final (title, desc, nodes) in units)
        {
          'id': 'unit-${++unitIndex}',
          'index': unitIndex,
          'title': title,
          'description': desc,
          'nodes': [
            for (var i = 0; i < nodes.length; i++)
              {
                'id': 'u$unitIndex-n$i',
                'type':
                    nodes[i].startsWith('Review')
                        ? 'unit_review'
                        : nodes[i] == 'Practice'
                        ? 'practice'
                        : 'lesson',
                'subtype': unitIndex == 1 ? 'script' : 'vocabulary',
                'title': nodes[i],
                'state':
                    unitIndex == 1
                        ? 'passed'
                        : unitIndex == 2
                        ? (i < 2
                            ? 'passed'
                            : i == 2
                            ? 'active'
                            : 'locked')
                        : 'locked',
                'finished_sessions': unitIndex == 2 && i == 2 ? 1 : 0,
                'total_sessions': 3,
              },
          ],
        },
    ],
  };
}
