/// Ajoute [months] mois à [base] sans jamais « déborder » sur le mois suivant.
///
/// `DateTime(2026, 2, 31)` vaut en réalité le 3 mars : une échéance mensuelle
/// fixée au 31 janvier sautait donc février, puis restait bloquée au 3.
/// Ici, le jour est ramené au dernier jour du mois cible (28/29 février,
/// 30 avril...). [anchorDay] permet de conserver le jour d'origine voulu
/// (ex. 31) quand [base] a déjà été ramené à un jour plus petit.
///
/// Seule la date est conservée (heure remise à zéro).
DateTime addMonthsClamped(DateTime base, int months, {int? anchorDay}) {
  final wantedDay = anchorDay ?? base.day;
  final monthIndex = base.month - 1 + months;
  final yearShift = (monthIndex / 12).floor();
  final year = base.year + yearShift;
  final month = monthIndex - yearShift * 12 + 1;
  final lastDay = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, wantedDay > lastDay ? lastDay : wantedDay);
}
