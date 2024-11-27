import 'package:flutter/material.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Row(
        children: [
          Icon(Icons.calendar_today,
              color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Training Manager',
                style: TextStyle(color: Theme.of(context).colorScheme.primary)),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pushReplacementNamed(context, '/'),
          child: const Text('Login'),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: () => Navigator.pushNamed(context, '/register'),
          child: const Text('Registrieren'),
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildHeroSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.secondary,
          ],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Revolutionieren Sie Ihr\nSchulungsmanagement',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Effizient. Übersichtlich. Modern.',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white.withOpacity(0.9),
                      ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => Navigator.pushReplacementNamed(context, '/'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 20),
                    textStyle: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  child: const Text('Kostenlos testen'),
                ),
              ],
            ),
          ),
          if (MediaQuery.of(context).size.width > 800)
            Expanded(
              child: Image.asset(
                'assets/images/app_screenshot.png',
                height: 400,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 400,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.image_outlined,
                        size: 64,
                        color: Colors.grey,
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFeatureSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
      color: Colors.white,
      child: Column(
        children: [
          Text(
            'Alles was Sie brauchen',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 48),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: MediaQuery.of(context).size.width > 1200 ? 3 : 2,
            childAspectRatio: 1.5,
            mainAxisSpacing: 30,
            crossAxisSpacing: 30,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            children: [
              _buildFeatureCard(
                context,
                Icons.calendar_month,
                'Intelligente Kalenderansicht',
                'Behalten Sie den Überblick über alle Schulungen mit unserer übersichtlichen Kalenderansicht.',
              ),
              _buildFeatureCard(
                context,
                Icons.people,
                'Teilnehmerverwaltung',
                'Verwalten Sie Teilnehmer und Anmeldungen mit wenigen Klicks.',
              ),
              _buildFeatureCard(
                context,
                Icons.analytics,
                'Detaillierte Statistiken',
                'Analysieren Sie die Auslastung und Erfolge Ihrer Schulungen.',
              ),
              _buildFeatureCard(
                context,
                Icons.schedule,
                'Flexible Terminplanung',
                'Planen Sie Einzel- und Mehrtagsschulungen nach Ihren Bedürfnissen.',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(
      BuildContext context, IconData icon, String title, String description) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTestimonialSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
      color: Colors.grey[100],
      child: SingleChildScrollView(
        child: Column(
          children: [
            Text(
              'Was unsere Kunden sagen',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 48),
            Wrap(
              spacing: 24,
              runSpacing: 24,
              children: [
                _buildTestimonialCard(
                  context,
                  'Max Mustermann',
                  'Geschäftsführer, TechCorp',
                  'Der Training Manager hat unsere Schulungsverwaltung komplett revolutioniert. Einfach fantastisch!',
                ),
                _buildTestimonialCard(
                  context,
                  'Anna Schmidt',
                  'HR Managerin, InnovateCo',
                  'Endlich haben wir alle Schulungen übersichtlich an einem Ort. Die Teilnehmerverwaltung ist ein Traum.',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestimonialCard(
      BuildContext context, String name, String position, String text) {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
          ),
          const SizedBox(height: 16),
          Text(
            name,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          Text(
            position,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      color: Colors.grey[900],
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Training Manager',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Die moderne Lösung für\nIhr Schulungsmanagement',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kontakt',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'support@trainingmanager.de\n+49 123 456789',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 48),
          Text(
            '2024 Training Manager. Alle Rechte vorbehalten.',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeroSection(context),
            _buildFeatureSection(context),
            _buildTestimonialSection(context),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }
}
