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
      actions: const [], // Remove the buttons from actions
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
                  onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
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

  void _showLegalDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Rechtliche Hinweise',
              style: Theme.of(context).textTheme.titleLarge),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('§1 Impressum',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'Angaben gemäß § 5 TMG:\n\n'
                  'Training Manager GmbH\n'
                  'Musterstraße 123\n'
                  '12345 Musterstadt\n'
                  'Deutschland\n\n'
                  'Handelsregister: HRB 12345\n'
                  'Registergericht: Amtsgericht Musterstadt\n'
                  'Umsatzsteuer-ID: DE123456789\n\n'
                  'Vertreten durch:\n'
                  'Max Mustermann (Geschäftsführer)',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Text('§2 Kontakt',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'E-Mail: support@trainingmanager.de\n'
                  'Telefon: +49 123 456789\n'
                  'Fax: +49 123 456788\n\n'
                  'Verantwortlich für den Inhalt nach § 55 Abs. 2 RStV:\n'
                  'Max Mustermann\n'
                  'Training Manager GmbH\n'
                  'Musterstraße 123\n'
                  '12345 Musterstadt',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Text('§3 Datenschutzerklärung',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  '1. Grundlegendes\n\n'
                  'Diese Datenschutzerklärung gilt für die Nutzung der Training Manager Software. Wir nehmen den Schutz Ihrer persönlichen Daten sehr ernst und behandeln Ihre personenbezogenen Daten vertraulich entsprechend der gesetzlichen Datenschutzvorschriften sowie dieser Datenschutzerklärung.\n\n'
                  '2. Datenerfassung\n\n'
                  'Die Nutzung unserer Software ist in der Regel ohne Angabe personenbezogener Daten möglich. Soweit personenbezogene Daten (beispielsweise Name, Anschrift oder E-Mail-Adressen) erhoben werden, erfolgt dies, soweit möglich, stets auf freiwilliger Basis.\n\n'
                  '3. Zweckgebundene Datenverwendung\n\n'
                  'Wir beachten den Grundsatz der zweckgebundenen Datenverwendung und erheben, verarbeiten und speichern Ihre personenbezogenen Daten nur für die Zwecke, für die Sie sie uns mitgeteilt haben.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Text('§4 Haftungsausschluss',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  '1. Haftung für Inhalte\n\n'
                  'Die Inhalte unserer Software wurden mit größter Sorgfalt erstellt. Für die Richtigkeit, Vollständigkeit und Aktualität der Inhalte können wir jedoch keine Gewähr übernehmen.\n\n'
                  '2. Haftung für Links\n\n'
                  'Unser Angebot enthält Links zu externen Webseiten Dritter, auf deren Inhalte wir keinen Einfluss haben. Deshalb können wir für diese fremden Inhalte auch keine Gewähr übernehmen.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Text('§5 Urheberrecht',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'Die durch die Training Manager GmbH erstellten Inhalte und Werke in dieser Software unterliegen dem deutschen Urheberrecht. Die Vervielfältigung, Bearbeitung, Verbreitung und jede Art der Verwertung außerhalb der Grenzen des Urheberrechtes bedürfen der schriftlichen Zustimmung des jeweiligen Autors bzw. Erstellers.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Schließen'),
            ),
          ],
        );
      },
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
                  const SizedBox(height: 24),
                  InkWell(
                    onTap: () => _showLegalDialog(context),
                    child: Text(
                      'Rechtliches',
                      style: TextStyle(
                        color: Colors.grey[400],
                        decoration: TextDecoration.underline,
                      ),
                    ),
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
