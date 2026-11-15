import 'package:flutter/material.dart';
import 'clerk_auth_screen.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static const Color accent = Color.fromARGB(255, 65, 0, 228); // Deep Purple
  static const Color accentDim = Color.fromARGB(255, 162, 231, 0); // Lime Green

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Scrolz',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ClerkAuthScreen(),
                  ),
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: accentDim,
              ),
              child: const Text(
                'Sign In',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: accentDim.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: accentDim.withOpacity(0.4)),
              ),
              child: const Text(
                'PDF TO VIDEO & AI LEARNING',
                style: TextStyle(
                  color: accentDim,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Main Headline
            RichText(
              text: const TextSpan(
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                  color: Colors.white,
                ),
                children: [
                  TextSpan(text: 'Understand Any PDF in '),
                  TextSpan(
                    text: 'Minutes.',
                    style: TextStyle(color: accentDim),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Subtitle
            Text(
              'Turn dense documents into engaging videos, podcasts, audio streams, and interactive quizzes.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 15,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),

            // Primary Auth Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const ClerkAuthScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Sign In / Sign Up',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, color: accentDim),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Features Section
            const Text(
              'Everything you can do with your PDFs',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),

            _buildFeatureTile(
              icon: Icons.ondemand_video_rounded,
              title: 'Watch PDF as Video',
              subtitle: 'Convert complex pages into easy-to-follow visual videos.',
              highlight: true,
            ),
            const SizedBox(height: 12),
            _buildFeatureTile(
              icon: Icons.podcasts_rounded,
              title: 'Listen to a Podcast',
              subtitle: 'Turn your document into an engaging AI host discussion.',
            ),
            const SizedBox(height: 12),
            _buildFeatureTile(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'Chat with Your PDF',
              subtitle: 'Ask questions and get instant answers from your file.',
            ),
            const SizedBox(height: 12),
            _buildFeatureTile(
              icon: Icons.quiz_outlined,
              title: 'Answer Quizzes',
              subtitle: 'Test your knowledge with auto-generated smart quizzes.',
            ),
            const SizedBox(height: 12),
            _buildFeatureTile(
              icon: Icons.headphones_rounded,
              title: 'Listen as Audio',
              subtitle: 'Stream your document content hands-free anywhere.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureTile({
    required IconData icon,
    required String title,
    required String subtitle,
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlight ? accent.withOpacity(0.2) : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlight ? accentDim.withOpacity(0.5) : Colors.white.withOpacity(0.08),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: highlight ? accentDim : accent.withOpacity(0.35),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: highlight ? Colors.black : accentDim,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.65),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
