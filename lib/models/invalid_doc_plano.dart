class InvalidDocPlano {
  final String docPlano;
  final String motivo;

  const InvalidDocPlano({
    required this.docPlano,
    required this.motivo,
  });

  @override
  String toString() => '$docPlano - $motivo';
}