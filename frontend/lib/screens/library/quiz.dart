// lib/screens/library/quiz.dart
//
// Takes `chunk.quiz` (a List of JSON maps) and renders an interactive quiz:
// one question at a time, instant right/wrong feedback, explanation, final score.
//
// Accepted keys per question (first match wins):
//   question : "question" | "q" | "prompt"
//   options  : "options" | "choices" | "answers"   (List<String>, or Map like {"A": "...", "B": "..."})
//   answer   : "answer" | "correct_answer" | "correct" | "correct_index"
//              -> option text, a letter ("B"), or a 0-based index
//   explain  : "explanation" | "rationale"

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

// ------------------------------------------------------------------ model
class QuizQuestion {
  const QuizQuestion({
    required this.question,
    required this.options,
    required this.answerIndex,
    this.explanation,
  });

  final String question;
  final List<String> options;
  final int answerIndex;
  final String? explanation;

  factory QuizQuestion.fromJson(Map<String, dynamic> j) {
    final question =
        (j['question'] ?? j['q'] ?? j['prompt'] ?? '').toString().trim();

    final rawOpts = j['options'] ?? j['choices'] ?? j['answers'] ?? const [];
    List<String> options;
    if (rawOpts is Map) {
      final keys = rawOpts.keys.map((k) => k.toString()).toList()..sort();
      options = [for (final k in keys) rawOpts[k].toString()];
    } else if (rawOpts is List) {
      options = rawOpts.map((e) => e.toString()).toList();
    } else {
      options = const [];
    }

    final rawAnswer = j['answer'] ??
        j['correct_answer'] ??
        j['correct'] ??
        j['correct_index'];

    var answerIndex = -1;
    if (rawAnswer is num) {
      answerIndex = rawAnswer.toInt();
    } else if (rawAnswer != null) {
      final a = rawAnswer.toString().trim();
      // 1) matches option text
      answerIndex =
          options.indexWhere((o) => o.trim().toLowerCase() == a.toLowerCase());
      // 2) a letter such as "B" or "b)"
      if (answerIndex < 0 && a.isNotEmpty) {
        final letter = a.toLowerCase().codeUnitAt(0) - 'a'.codeUnitAt(0);
        if (a.length <= 2 && letter >= 0 && letter < options.length) {
          answerIndex = letter;
        }
      }
      // 3) numeric string
      answerIndex = answerIndex >= 0 ? answerIndex : (int.tryParse(a) ?? -1);
    }

    if (answerIndex < 0 || answerIndex >= options.length) {
      debugPrint('QuizQuestion: could not resolve answer for "$question"');
      answerIndex = 0;
    }

    return QuizQuestion(
      question: question,
      options: options,
      answerIndex: answerIndex,
      explanation: (j['explanation'] ?? j['rationale'])?.toString(),
    );
  }
}

/// Handy while building UI: `QuizScreen(title: 'Demo', questions: kDummyQuiz)`
const List<Map<String, dynamic>> kDummyQuiz = [
  {
    'question': 'What is the main idea of this part?',
    'options': [
      'Reading is slower than listening',
      'Spaced repetition improves recall',
      'Notes should never be summarised',
      'Quizzes replace reading',
    ],
    'answer': 'Spaced repetition improves recall',
    'explanation': 'Revisiting material at growing intervals strengthens memory.',
  },
  {
    'question': 'Which option is a good study habit?',
    'options': ['Cramming', 'Active recall', 'Multitasking', 'Rereading only'],
    'answer': 'B',
    'explanation': 'Testing yourself beats passive review.',
  },
  {
    'question': 'Quizzes are most useful when taken…',
    'options': ['Never', 'Right after reading', 'Only before exams'],
    'answer': 1,
  },
];

// ----------------------------------------------------------------- screen
class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, required this.title, required this.questions});

  final String title;

  /// Raw `chunk.quiz` data. Maps are parsed with [QuizQuestion.fromJson].
  final List<dynamic> questions;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late List<QuizQuestion> _questions;

  int _index = 0;
  int _score = 0;
  int? _selected; // option picked for the current question
  bool _finished = false;
  final List<int?> _picks = [];

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  void _prepare() {
    _questions = widget.questions
        .whereType<Map>()
        .map((m) => QuizQuestion.fromJson(Map<String, dynamic>.from(m)))
        .where((q) => q.question.isNotEmpty && q.options.length >= 2)
        .toList();
    _index = 0;
    _score = 0;
    _selected = null;
    _finished = false;
    _picks
      ..clear()
      ..addAll(List<int?>.filled(_questions.length, null));
  }

  void _pick(int i) {
    if (_selected != null) return; // already answered
    final q = _questions[_index];
    setState(() {
      _selected = i;
      _picks[_index] = i;
      if (i == q.answerIndex) _score++;
    });
  }

  void _next() {
    if (_index >= _questions.length - 1) {
      setState(() => _finished = true);
    } else {
      setState(() {
        _index++;
        _selected = null;
      });
    }
  }

  void _retry() => setState(_prepare);

  // ------------------------------------------------------------------ build
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: _questions.isEmpty
            ? const Center(child: Text('No quiz questions available.'))
            : _finished
                ? _result()
                : _question(),
      ),
    );
  }

  // --------------------------------------------------------------- question
  Widget _question() {
    final q = _questions[_index];
    final answered = _selected != null;
    final isLast = _index == _questions.length - 1;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            children: [
              Row(
                children: [
                  Text(
                    'Question ${_index + 1} of ${_questions.length}',
                    style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Text('Score $_score',
                      style: const TextStyle(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  minHeight: 6,
                  value: (_index + (answered ? 1 : 0)) / _questions.length,
                  backgroundColor: AppColors.surface,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                q.question,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w700, height: 1.35),
              ),
              const SizedBox(height: 20),
              for (var i = 0; i < q.options.length; i++) ...[
                _option(q, i),
                const SizedBox(height: 12),
              ],
              if (answered && (q.explanation?.isNotEmpty ?? false))
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lightbulb_outline,
                          size: 20, color: AppColors.accent),
                      const SizedBox(width: 10),
                      Expanded(child: Text(q.explanation!)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: answered ? _next : null,
              child: Text(isLast ? 'See results' : 'Next'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _option(QuizQuestion q, int i) {
    final answered = _selected != null;
    final isCorrect = i == q.answerIndex;
    final isPicked = _selected == i;

    Color border = Colors.grey.withOpacity(0.3);
    Color fill = AppColors.surface;
    IconData? trailing;
    Color? trailingColor;

    if (answered && isCorrect) {
      border = Colors.green;
      fill = Colors.green.withOpacity(0.15);
      trailing = Icons.check_circle;
      trailingColor = Colors.green;
    } else if (answered && isPicked) {
      border = Colors.redAccent;
      fill = Colors.redAccent.withOpacity(0.15);
      trailing = Icons.cancel;
      trailingColor = Colors.redAccent;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: answered ? null : () => _pick(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border, width: 1.5),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.accentDim,
              child: Text(
                String.fromCharCode(65 + i),
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(q.options[i], style: const TextStyle(fontSize: 15))),
            if (trailing != null) Icon(trailing, color: trailingColor),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------------- result
  Widget _result() {
    final total = _questions.length;
    final pct = (_score / total * 100).round();
    final message = pct >= 80
        ? 'Great job!'
        : pct >= 50
            ? 'Good effort, keep going.'
            : 'Worth another read.';

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 16),
        Center(
          child: SizedBox(
            width: 140,
            height: 140,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: _score / total,
                    strokeWidth: 10,
                    backgroundColor: AppColors.surface,
                    color: AppColors.accent,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$_score / $total',
                        style: const TextStyle(
                            fontSize: 28, fontWeight: FontWeight.w800)),
                    Text('$pct%',
                        style: const TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Text(message,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 28),
        const Text('Review',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 8),
        for (var i = 0; i < total; i++) _reviewTile(i),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Done'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _retry,
                child: const Text('Try again'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _reviewTile(int i) {
    final q = _questions[i];
    final pick = _picks[i];
    final correct = pick == q.answerIndex;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(correct ? Icons.check_circle : Icons.cancel,
              color: correct ? Colors.green : Colors.redAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(q.question,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                if (!correct && pick != null)
                  Text('Your answer: ${q.options[pick]}',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                Text('Correct: ${q.options[q.answerIndex]}',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
