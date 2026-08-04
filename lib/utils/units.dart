enum UnitSystem { metric, imperial }

extension UnitSystemLabel on UnitSystem {
  String get label => this == UnitSystem.metric ? 'Metric (kg / cm)' : 'Imperial (lb / in)';
  String get weightUnit => this == UnitSystem.metric ? 'kg' : 'lb';
  String get lengthUnit => this == UnitSystem.metric ? 'cm' : 'in';

  /// Standard Olympic barbell weight in this unit system.
  double get defaultBarWeight => this == UnitSystem.metric ? 20.0 : 45.0;
}

double kgToLb(double kg) => kg * 2.2046226218;
double lbToKg(double lb) => lb / 2.2046226218;
double cmToIn(double cm) => cm / 2.54;
double inToCm(double inches) => inches * 2.54;
