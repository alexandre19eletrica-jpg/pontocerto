enum PunchType { entrada, saida }
enum WorkedDayPeriod { fullDay, halfDay }

class Punch {
  const Punch({
    required this.id,
    required this.employeeId,
    required this.timestamp,
    required this.tipo,
    required this.obraOuCliente,
  });

  final String id;
  final String employeeId;
  final DateTime timestamp;
  final PunchType tipo;
  final String obraOuCliente;
}

class WorkedDay {
  const WorkedDay({
    required this.id,
    required this.employeeId,
    required this.date,
    required this.period,
    required this.hasEntry,
    required this.hasExit,
    required this.autoClosed,
  });

  final String id;
  final String employeeId;
  final DateTime date;
  final WorkedDayPeriod period;
  final bool hasEntry;
  final bool hasExit;
  final bool autoClosed;
}
