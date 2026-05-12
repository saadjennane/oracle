/// Narrative Engine V2
///
/// Point d'entrée pour la génération narrative V2.
/// Route vers les banques custom, starter DDG, buckets, ou signature prewritten.

import '../../models/models.dart';
import '../narrative_trace.dart';
import 'casebook_fr.dart';
import 'choices_buckets_bank_en.dart';
import 'choices_buckets_bank_fr.dart';
import 'narrative_assembler.dart';
import 'signature_prewritten.dart';
import '../banks/choices_starter_fr_minimal_exact_ddg.dart';

/// Résultat de génération V2 avec trace complète
class NarrativeResultV2 {
  final String generatedText;
  final int wordCount;
  final AssemblyTrace assemblyTrace;
  final NarrativeTrace? legacyTrace;
  final String? bankKey;

  const NarrativeResultV2({
    required this.generatedText,
    required this.wordCount,
    required this.assemblyTrace,
    this.legacyTrace,
    this.bankKey,
  });
}

/// Fonction de génération principale V2
NarrativeResultV2 generateNarrativeV2({
  required GameSession session,
  int? seed,
}) {
  // Priorité 1: Banque custom preprogrammed du preset
  final customResult = _tryCustomPreprogrammedBank(session);
  if (customResult != null) return customResult;

  // Priorité 2: Starter pack DDG (FR, séquences exactes)
  final starterDDGResult = _tryChoicesStarterDDG(session);
  if (starterDDGResult != null) return starterDDGResult;

  // Priorité 3: Banque buckets CHOICES (custom puis défaut)
  final choicesResult = _tryChoicesBucketsBank(session);
  if (choicesResult != null) return choicesResult;

  // Priorité 4: Signature prewritten (DDG FR)
  final signatureResult = _trySignaturePrewritten(session);
  if (signatureResult != null) return signatureResult;

  // Aucune banque trouvée
  return NarrativeResultV2(
    generatedText: '[Aucun texte configuré pour ce résultat]',
    wordCount: 0,
    assemblyTrace: AssemblyTrace(
      hookId: 'no_bank_found',
      patternLineId: 'no_bank_found',
      closerId: 'no_bank_found',
      style: NarrativeStyleV2.direct,
      tone: NarrativeToneV2.neutral,
      tense: NarrativeTenseV2.future,
      isGameMode: session.predictionMode == PredictionMode.game,
    ),
    legacyTrace: null,
  );
}

/// Vérifie si une banque custom preprogrammed existe et retourne le texte
/// Conditions: GAME + preprogrammed + bank existe pour performerKey
/// RESTRICTION: Séquences custom seulement pour 2 options + 1-5 rounds + mode sequences
NarrativeResultV2? _tryCustomPreprogrammedBank(GameSession session) {
  if (session.predictionMode != PredictionMode.game) return null;
  if (session.inputMode != InputMode.preprogrammed) return null;
  if (session.customPreprogrammedBanks == null) return null;
  if (session.options.length != 2 || session.totalRounds > 5) return null;
  if (session.choicesNarrativeMode != ChoicesNarrativeMode.sequences) return null;

  final performerSeq = session.preprogrammedSequence;
  if (performerSeq == null || performerSeq.length != session.totalRounds) return null;

  final performerKey = getSequenceKey(performerSeq, options: session.options);

  if (session.rounds.length != session.totalRounds) return null;

  final spectatorChoices = session.rounds.map((r) => r.spectatorChoice).toList();
  final spectatorKey = getSequenceKey(spectatorChoices, options: session.options);

  final text = session.getCustomBankText(performerKey, spectatorKey);
  if (text == null || text.trim().isEmpty) return null;

  final wordCount = text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

  return NarrativeResultV2(
    generatedText: text,
    wordCount: wordCount,
    assemblyTrace: AssemblyTrace(
      hookId: 'custom_bank.$performerKey.$spectatorKey',
      patternLineId: 'custom_bank.$performerKey.$spectatorKey',
      closerId: 'custom_bank.$performerKey.$spectatorKey',
      style: NarrativeStyleV2.direct,
      tone: NarrativeToneV2.playfulMocking,
      tense: NarrativeTenseV2.future,
      isGameMode: true,
    ),
    legacyTrace: null,
  );
}

/// Vérifie si c'est un cas CHOICES starter DDG et retourne le texte exact
/// Conditions: GAME + binary (2 options) + 1-3 rounds + preprogrammed + DDG + FR + sequences mode
NarrativeResultV2? _tryChoicesStarterDDG(GameSession session) {
  if (session.predictionMode != PredictionMode.game) return null;
  if (session.gameType == GameType.duel) return null;
  if (session.inputMode != InputMode.preprogrammed) return null;
  if (session.language != Language.french) return null;
  if (session.options.length != 2) return null;
  if (session.totalRounds < 1 || session.totalRounds > 3) return null;
  if (session.choicesNarrativeMode != ChoicesNarrativeMode.sequences) return null;

  final performerSeq = session.preprogrammedSequence;
  if (performerSeq == null || performerSeq.length < session.totalRounds) return null;

  if (!canUseChoicesStarterDDG(
    languageCode: session.language.name,
    rounds: session.totalRounds,
    isPreprogrammed: true,
    performerSequence: performerSeq,
    options: session.options,
  )) {
    return null;
  }

  if (session.rounds.length != session.totalRounds) return null;
  final spectatorChoices = session.rounds.map((r) => r.spectatorChoice).toList();

  final text = getChoicesStarterDDGText(spectatorChoices, session.options);
  if (text == null) return null;

  final wordCount = text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  final spectatorKey = spectatorChoices.map((c) => c == session.options[0] ? 'D' : 'G').join();

  return NarrativeResultV2(
    generatedText: text,
    wordCount: wordCount,
    assemblyTrace: AssemblyTrace(
      hookId: 'starter_ddg_fr.$spectatorKey',
      patternLineId: 'starter_ddg_fr.$spectatorKey',
      closerId: 'starter_ddg_fr.$spectatorKey',
      style: NarrativeStyleV2.direct,
      tone: NarrativeToneV2.playfulMocking,
      tense: NarrativeTenseV2.future,
      isGameMode: true,
    ),
    legacyTrace: null,
  );
}

/// Vérifie si c'est un cas signature DDG et retourne le texte prewritten
/// Conditions: GAME + 3 rounds + preprogrammed + DDG + FR
NarrativeResultV2? _trySignaturePrewritten(GameSession session) {
  if (session.predictionMode != PredictionMode.game) return null;
  if (session.totalRounds != 3) return null;
  if (session.inputMode != InputMode.preprogrammed) return null;
  if (session.language != Language.french) return null;

  final performerSeq = session.preprogrammedSequence;
  if (performerSeq == null || performerSeq.length != 3) return null;

  final performerKey = toDDGKey(performerSeq);
  if (performerKey != 'DDG') return null;

  if (session.rounds.length != 3) return null;
  final spectatorChoices = session.rounds.map((r) => r.spectatorChoice).toList();
  final spectatorKey = toDDGKey(spectatorChoices);

  final text = SignaturePrewrittenBank.getText('DDG', spectatorKey);
  if (text == null) return null;

  final wordCount = text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

  return NarrativeResultV2(
    generatedText: text,
    wordCount: wordCount,
    assemblyTrace: AssemblyTrace(
      hookId: 'signature_prewritten_ddg_fr.$spectatorKey',
      patternLineId: 'signature_prewritten_ddg_fr.$spectatorKey',
      closerId: 'signature_prewritten_ddg_fr.$spectatorKey',
      style: NarrativeStyleV2.direct,
      tone: NarrativeToneV2.playfulMocking,
      tense: NarrativeTenseV2.future,
      isGameMode: true,
    ),
    legacyTrace: null,
  );
}

/// Vérifie si c'est un cas CHOICES et utilise la banque H/M patterns ou buckets
/// Priorité: 1. Custom H/M pattern (e.g. "HMH"), 2. Legacy bucket "N|hitsCount", 3. Default bank (FR/EN)
NarrativeResultV2? _tryChoicesBucketsBank(GameSession session) {
  if (session.predictionMode != PredictionMode.game) return null;
  if (session.gameType == GameType.duel) return null;
  if (session.inputMode != InputMode.preprogrammed &&
      session.inputMode != InputMode.twoInputs) return null;
  if (session.rounds.length != session.totalRounds) return null;

  final spectatorChoices = session.rounds.map((r) => r.spectatorChoice).toList();
  final performerChoices = <String>[];
  int hitsCount = 0;
  final patternBuf = StringBuffer();
  for (int i = 0; i < session.rounds.length; i++) {
    final performerChoice = session.getPerformerChoice(i);
    performerChoices.add(performerChoice);
    final isHit = spectatorChoices[i] == performerChoice;
    if (isHit) hitsCount++;
    patternBuf.write(isHit ? 'H' : 'M');
  }

  final missCount = session.totalRounds - hitsCount;
  final hmPatternKey = patternBuf.toString();
  final legacyBucketKey = '${session.totalRounds}|$hitsCount';
  final spectatorSequence = spectatorChoices.join(', ');

  // PRIORITÉ 1: Custom H/M pattern key (new unified model)
  final hmTemplate = session.getCustomChoicesBankText(hmPatternKey);
  if (hmTemplate != null && hmTemplate.trim().isNotEmpty) {
    final text = applyChoicesPlaceholders(
      hmTemplate,
      spectatorSequence: spectatorSequence,
      hitsCount: hitsCount,
      missCount: missCount,
      spectatorChoices: spectatorChoices,
      performerChoices: performerChoices,
      options: session.options,
    );
    final wordCount = text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

    return NarrativeResultV2(
      generatedText: text,
      wordCount: wordCount,
      assemblyTrace: AssemblyTrace(
        hookId: 'choices_hm_custom.$hmPatternKey',
        patternLineId: 'choices_hm_custom.$hmPatternKey',
        closerId: 'choices_hm_custom.$hmPatternKey',
        style: NarrativeStyleV2.direct,
        tone: NarrativeToneV2.playfulMocking,
        tense: NarrativeTenseV2.future,
        isGameMode: true,
      ),
      legacyTrace: null,
      bankKey: hmPatternKey,
    );
  }

  // PRIORITÉ 2: Legacy bucket key (backward compat with old presets)
  final customTemplate = session.getCustomChoicesBankText(legacyBucketKey);
  if (customTemplate != null && customTemplate.trim().isNotEmpty) {
    final text = applyChoicesPlaceholders(
      customTemplate,
      spectatorSequence: spectatorSequence,
      hitsCount: hitsCount,
      missCount: missCount,
      spectatorChoices: spectatorChoices,
      performerChoices: performerChoices,
      options: session.options,
    );
    final wordCount = text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

    return NarrativeResultV2(
      generatedText: text,
      wordCount: wordCount,
      assemblyTrace: AssemblyTrace(
        hookId: 'choices_bucket_custom.$legacyBucketKey',
        patternLineId: 'choices_bucket_custom.$legacyBucketKey',
        closerId: 'choices_bucket_custom.$legacyBucketKey',
        style: NarrativeStyleV2.direct,
        tone: NarrativeToneV2.playfulMocking,
        tense: NarrativeTenseV2.future,
        isGameMode: true,
      ),
      legacyTrace: null,
    );
  }

  // PRIORITÉ 2: Default bank (FR/EN)
  final isFrench = session.language == Language.french;
  final template = isFrench
      ? getChoicesBucketText(session.totalRounds, hitsCount)
      : getChoicesBucketTextEN(session.totalRounds, hitsCount);
  if (template == null) return null;

  final text = isFrench
      ? applyChoicesPlaceholders(
          template,
          spectatorSequence: spectatorSequence,
          hitsCount: hitsCount,
          missCount: missCount,
          spectatorChoices: spectatorChoices,
          performerChoices: performerChoices,
          options: session.options,
        )
      : applyChoicesPlaceholdersEN(
          template,
          spectatorSequence: spectatorSequence,
          hitsCount: hitsCount,
          missCount: missCount,
          spectatorChoices: spectatorChoices,
          performerChoices: performerChoices,
          options: session.options,
        );

  final wordCount = text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  final langKey = isFrench ? 'fr' : 'en';

  return NarrativeResultV2(
    generatedText: text,
    wordCount: wordCount,
    assemblyTrace: AssemblyTrace(
      hookId: 'choices_bucket_$langKey.$legacyBucketKey',
      patternLineId: 'choices_bucket_$langKey.$legacyBucketKey',
      closerId: 'choices_bucket_$langKey.$legacyBucketKey',
      style: NarrativeStyleV2.direct,
      tone: NarrativeToneV2.playfulMocking,
      tense: NarrativeTenseV2.future,
      isGameMode: true,
    ),
    legacyTrace: null,
  );
}
