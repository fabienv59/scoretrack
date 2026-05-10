enum CountMode {
  cumul('Cumul', 'Additionne les points de chaque manche'),
  direct('Direct', 'Saisie directe du score total');

  const CountMode(this.label, this.description);
  final String label;
  final String description;
}
