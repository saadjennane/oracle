import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../utils/settings_provider.dart';
import '../theme/app_theme.dart';

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _sectionKeys = {};

  @override
  void initState() {
    super.initState();
    for (final id in _sectionIds) {
      _sectionKeys[id] = GlobalKey();
    }
  }

  static const _sectionIds = [
    'overview', 'presets', 'input', 'create', 'flow',
    'routines', 'output', 'variables', 'api', 'import',
    'settings', 'faq', 'credits',
  ];

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollTo(String id) {
    final key = _sectionKeys[id];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(key!.currentContext!, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    }
  }

  void _showTOC(BuildContext ctx, List<_S> sections) {
    showModalBottomSheet(
      context: ctx, backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (c) => SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: sections.map((s) => ListTile(
            leading: Icon(s.icon, size: 16, color: AppTheme.primary),
            title: Text(s.title, style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
            dense: true,
            visualDensity: VisualDensity.compact,
            onTap: () { Navigator.pop(c); _scrollTo(s.id); },
          )).toList(),
        ),
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<SettingsProvider>().appLanguage;
    final sections = _buildSections(lang);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(_t(lang, 'Tutorial', 'Tutoriel', 'Tutorial')),
        backgroundColor: AppTheme.surface,
        actions: [Builder(builder: (c) => IconButton(icon: const Icon(Icons.menu), onPressed: () => _showTOC(c, sections)))],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header + TOC
            const Text('ORACLE', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.textPrimary, letterSpacing: 2)),
            Text(_t(lang, 'User Guide', 'Guide Utilisateur', 'Guía de Usuario'), style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
            const SizedBox(height: 16),
            ...sections.map((s) => GestureDetector(
              onTap: () => _scrollTo(s.id),
              child: Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [
                Icon(s.icon, size: 14, color: AppTheme.primary), const SizedBox(width: 8),
                Expanded(child: Text(s.title, style: TextStyle(fontSize: 13, color: AppTheme.primary, fontWeight: FontWeight.w500))),
              ])),
            )),
            const SizedBox(height: 12), Divider(color: AppTheme.divider), const SizedBox(height: 12),

            // Sections
            ...sections.map((s) => Container(
              key: _sectionKeys[s.id],
              margin: const EdgeInsets.only(bottom: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [Icon(s.icon, size: 18, color: AppTheme.primary), const SizedBox(width: 8), Expanded(child: Text(s.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)))]),
                  const SizedBox(height: 10),
                  ...s.items.map(_buildItem),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(dynamic item) {
    if (item is _H) return Padding(padding: const EdgeInsets.only(top: 14, bottom: 4), child: Text(item.t, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)));
    if (item is _P) return Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(item.t, style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.55)));
    if (item is _Tip) return _buildTip(item);
    if (item is _Table) return _buildTable(item);
    return const SizedBox.shrink();
  }

  Widget _buildTip(_Tip tip) {
    final color = tip.type == 'warning' ? Colors.orange : tip.type == 'example' ? AppTheme.confabulationColor : AppTheme.primary;
    final icon = tip.type == 'warning' ? Icons.warning_amber : tip.type == 'example' ? Icons.lightbulb_outline : Icons.info_outline;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 10),
        Expanded(child: Text(tip.t, style: TextStyle(fontSize: 12, color: AppTheme.textPrimary, height: 1.5))),
      ]),
    );
  }

  Widget _buildTable(_Table table) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(8)),
      child: Column(children: table.rows.asMap().entries.map((e) {
        final isFirst = e.key == 0;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.divider, width: 0.5))),
          child: Row(children: e.value.asMap().entries.map((c) => Expanded(
            child: Text(c.value, style: TextStyle(fontSize: 11, fontWeight: isFirst ? FontWeight.w600 : FontWeight.normal, color: isFirst ? AppTheme.textPrimary : AppTheme.textSecondary)),
          )).toList()),
        );
      }).toList()),
    );
  }

  static String _t(Language l, String en, String fr, String es) => l == Language.french ? fr : l == Language.spanish ? es : en;

  List<_S> _buildSections(Language l) {
    String t(String en, String fr, String es) => _t(l, en, fr, es);

    return [
      // 1. OVERVIEW
      _S(id: 'overview', icon: Icons.info_outline, title: t('1. What is Oracle?', '1. Qu\'est-ce qu\'Oracle ?', '1. ¿Qué es Oracle?'), items: [
        _P(t('Oracle turns your phone into a mentalism tool. You create prediction presets before the show, then secretly input the spectator\'s choices during performance. The app generates text (or saves an image) that matches their choices perfectly.',
            'Oracle transforme votre téléphone en outil de mentalisme. Vous créez des presets de prédiction avant le show, puis entrez secrètement les choix du spectateur pendant la performance. L\'app génère un texte (ou sauvegarde une image) qui correspond parfaitement.',
            'Oracle convierte tu teléfono en una herramienta de mentalismo. Creas presets de predicción antes del show, luego introduces secretamente las elecciones del espectador. La app genera texto (o guarda una imagen) que coincide perfectamente.')),
        _H(t('The 4 Steps', 'Les 4 Étapes', 'Los 4 Pasos')),
        _P(t('1. CREATE — Build a preset with narrative templates for every possible outcome\n2. PERFORM — Do your routine, the spectator makes choices freely\n3. INPUT — Secretly enter their choices using stealth input (black screen)\n4. REVEAL — Show the "prediction" that perfectly matches what happened',
            '1. CRÉER — Construisez un preset avec des templates pour chaque résultat possible\n2. PERFORMER — Faites votre routine, le spectateur choisit librement\n3. INPUT — Entrez secrètement ses choix via l\'input stealth (écran noir)\n4. RÉVÉLER — Montrez la "prédiction" qui correspond parfaitement',
            '1. CREAR — Construye un preset con plantillas para cada resultado posible\n2. ACTUAR — Haz tu rutina, el espectador elige libremente\n3. ENTRADA — Introduce secretamente sus elecciones vía input stealth (pantalla negra)\n4. REVELAR — Muestra la "predicción" que coincide perfectamente')),
        _Tip('example', t('Example: spectator picks Right, Left, Right across 3 rounds. You open Notes and they read: "You will go Right, then Left, then Right again. I knew it."',
            'Exemple : le spectateur choisit Droite, Gauche, Droite sur 3 rounds. Vous ouvrez Notes et on lit : "Tu vas faire Droite, puis Gauche, puis Droite. Je le savais."',
            'Ejemplo: el espectador elige Derecha, Izquierda, Derecha en 3 rondas. Abres Notas y se lee: "Vas a ir Derecha, luego Izquierda, luego Derecha. Lo sabía."')),
      ]),

      // 2. PRESET TYPES
      _S(id: 'presets', icon: Icons.dashboard, title: t('2. Preset Types', '2. Types de Presets', '2. Tipos de Presets'), items: [
        _H('Choices'),
        _P(t('Predict the spectator\'s choices across 1-5 rounds with 2-6 options. Write a narrative template for each Hit/Miss pattern.',
            'Prédisez les choix du spectateur sur 1-5 rounds avec 2-6 options. Écrivez un template narratif pour chaque pattern Hit/Miss.',
            'Predice las elecciones del espectador en 1-5 rondas con 2-6 opciones.')),
        _Tip('example', t('"Which Hand?" — Right or Left, 3 rounds.\nTemplate for HMH: "You\'ll go {choiceS1}, then {choiceS2}, then {choiceS3}. I\'ll guess the first and last, but let you win round 2 ;)"',
            '"Quelle Main ?" — Droite ou Gauche, 3 rounds.\nTemplate pour HMH : "Tu vas faire {choiceS1}, puis {choiceS2}, puis {choiceS3}. Je vais deviner le début et la fin, mais te laisser gagner le 2ème ;)"',
            '"¿Qué Mano?" — Derecha o Izquierda, 3 rondas.\nPlantilla para HMH: "Vas a elegir {choiceS1}, luego {choiceS2}, luego {choiceS3}. Adivinaré la primera y última ;)"')),

        _H('Duel'),
        _P(t('Rock/Paper/Scissors prediction. Fixed Rounds (1-5) or First To (2-5 points). S vs P or S vs S.',
            'Prédiction Pierre/Feuille/Ciseaux. Rounds Fixes (1-5) ou Premier À (2-5 points). S vs P ou S vs S.',
            'Predicción Piedra/Papel/Tijeras. Rondas Fijas (1-5) o Primero En (2-5 puntos).')),
        _Tip('example', t('3 rounds, score 2-1 for you:\n"We\'ll finish 2-1 for me. I\'ll win when you play {loseChoiceS1} and {loseChoiceS2}. I\'ll let you win one to keep it exciting ;)"',
            '3 rounds, score 2-1 pour vous :\n"On va finir 2-1 pour moi. Je vais gagner quand tu joueras {loseChoiceS1} et {loseChoiceS2}. Je te laisse en gagner un pour le suspense ;)"',
            '3 rondas, marcador 2-1:\n"Terminaremos 2-1 para mí. Ganaré cuando juegues {loseChoiceS1} y {loseChoiceS2}."')),

        _H('Free Will'),
        _P(t('3 objects on the table. The spectator takes one, gives one to you, leaves one. 6 possible outcomes. Each outcome has its own pre-written text — no variables needed, the text is complete as-is.',
            '3 objets sur la table. Le spectateur en prend un, vous en donne un, en laisse un. 6 résultats possibles. Chaque résultat a son propre texte pré-écrit — pas de variables, le texte est complet tel quel.',
            '3 objetos en la mesa. 6 resultados posibles. Cada resultado tiene su propio texto pre-escrito.')),
        _Tip('example', t('Objects: Key, Box, Coin.\nIf spectator takes Key, gives Box, leaves Coin:\n"You\'ll keep the Key — the one that opens everything. You\'ll give me the Box — because you trust me. The Coin stays — some choices speak for themselves."',
            'Objets : Clé, Boîte, Pièce.\nSi le spectateur prend la Clé, donne la Boîte, laisse la Pièce :\n"Tu vas garder la Clé — celle qui ouvre tout. Tu vas me donner la Boîte — parce que tu me fais confiance. La Pièce reste — certains choix parlent d\'eux-mêmes."',
            'Objetos: Llave, Caja, Moneda.\n"Vas a quedarte con la Llave — la que abre todo. Me darás la Caja. La Moneda se queda."')),
        _Tip('info', t(
            'Runtime labels: long-press the black input screen BEFORE starting to swap the 3 object names just for this performance (e.g. you forgot the coin and used a pen). The fake note appears with the 3 names stacked — edit them, then tap the top-right corner (just under the battery) to confirm. Original labels return automatically once the result is revealed.',
            'Labels temporaires : long-press sur l\'écran noir AVANT de commencer pour remplacer les 3 noms d\'objets pour cette prestation seulement (ex. tu as oublié la pièce et utilisé un stylo). La fake note apparaît avec les 3 noms empilés — modifie-les, puis tap en haut à droite (sous l\'icône batterie) pour valider. Les labels d\'origine reviennent dès que le résultat s\'affiche.',
            'Etiquetas en tiempo real: mantén pulsada la pantalla negra ANTES de empezar para sustituir los 3 nombres solo en esta actuación (ej. olvidaste la moneda y usaste un bolígrafo). Aparece la fake note con los 3 nombres apilados — edítalos y toca arriba a la derecha (bajo el icono de batería) para confirmar. Los originales vuelven al revelar el resultado.',
        )),
        _Tip('info', t(
            'Bank modes — Free Will offers two ways to write narration:\n• 6 texts: one custom text per permutation. Use ((Label1)), ((Label2)), ((Label3)) to reference the canonical objects. Best when you want detailed, nuanced narration that reacts specifically to each outcome (e.g. a different reasoning for "Phone taken" vs "Coin taken").\n• 1 text: a single template covering all 6 permutations. Use {TAKE}, {GIVE}, {TABLE} which substitute at runtime with whichever object got that action. Faster to set up; less narrative depth.',
            'Modes de banque — Free Will propose deux façons d\'écrire la narration :\n• 6 textes : un texte custom par permutation. Utilise ((Label1)), ((Label2)), ((Label3)) pour référencer les objets canoniques. Idéal quand tu veux une narration détaillée et nuancée qui réagit spécifiquement à chaque sortie (ex. raisonnement différent pour "Téléphone pris" vs "Pièce prise").\n• 1 texte : un seul template qui couvre les 6 permutations. Utilise {TAKE}, {GIVE}, {TABLE} qui se substituent au runtime par l\'objet correspondant à l\'action. Plus rapide à configurer ; moins de profondeur narrative.',
            'Modos de banco — Free Will ofrece dos formas de escribir la narración:\n• 6 textos: un texto personalizado por permutación. Usa ((Label1)), ((Label2)), ((Label3)) para referenciar los objetos canónicos. Ideal cuando quieres una narración detallada y matizada que reacciona específicamente a cada resultado.\n• 1 texto: una plantilla única que cubre las 6 permutaciones. Usa {TAKE}, {GIVE}, {TABLE} que se sustituyen en tiempo de ejecución. Más rápido de configurar; menos profundidad narrativa.',
        )),

        _H('Multiple Out'),
        _P(t('Write 2+ prediction texts. Secretly select the one matching the spectator\'s choice.',
            'Écrivez 2+ textes de prédiction. Sélectionnez secrètement celui qui correspond au choix du spectateur.',
            'Escribe 2+ textos de predicción. Selecciona secretamente el que corresponda.')),
        _Tip('example', t('Astrological sign prediction — one text per sign:\n• Aries: "You\'re a fire sign. Bold, impulsive, always first."\n• Taurus: "Earth grounds you. Patient, loyal, unstoppable."\n• Gemini: "Two minds, one soul. You adapt to everything."\n...12 texts total, one for each sign.',
            'Prédiction signe astrologique — un texte par signe :\n• Bélier : "Tu es un signe de feu. Audacieux, impulsif, toujours premier."\n• Taureau : "La terre t\'ancre. Patient, loyal, inarrêtable."\n• Gémeaux : "Deux esprits, une âme. Tu t\'adaptes à tout."\n...12 textes au total.',
            'Predicción de signo zodiacal — un texto por signo:\n• Aries: "Eres signo de fuego. Audaz, impulsivo, siempre primero."\n...12 textos en total.')),

        _H('Confabulation'),
        _P(t('Multi-slot text template. Each slot has options (Color: red/blue, Animal: cat/dog). Supports API variables.',
            'Template texte multi-slots. Chaque slot a des options (Couleur: rouge/bleu, Animal: chat/chien). Supporte les variables API.',
            'Plantilla multi-slot con opciones. Soporta variables API.')),
        _Tip('example', t('Template: "You\'re thinking of a {{Color}} {{Animal}}"\nSlots: Color (red, blue, green) + Animal (cat, dog, bird)\nResult: "You\'re thinking of a blue cat"',
            'Template : "Tu penses à un {{Animal}} {{Couleur}}"\nSlots : Couleur (rouge, bleu, vert) + Animal (chat, chien, oiseau)\nRésultat : "Tu penses à un chat bleu"',
            'Plantilla: "Piensas en un {{Animal}} {{Color}}"\nResultado: "Piensas en un gato azul"')),

        _H('Numbers'),
        _P(t('• Rainman — formula (e.g., 12345 - XXXX or XX * XX + X)\n• Birthday — birth date → day of the week + days since\n• Today — date complement',
            '• Rainman — formule (ex: 12345 - XXXX ou XX * XX + X)\n• Anniversaire — date → jour de la semaine + jours depuis\n• Aujourd\'hui — complément de date',
            '• Rainman — fórmula (ej: 12345 - XXXX)\n• Cumpleaños — fecha → día de la semana + días desde\n• Hoy — complemento de fecha')),
        _P(t('Number presets have two output screens (chosen in the preset): Notes (same reveal as above) or Calculator (displays the result as if typed on the iOS Calculator). See Output Modes for setup of the Calculator screenshot.',
            'Les presets Number ont deux écrans de sortie (choix dans le preset) : Notes (même révélation qu\'au-dessus) ou Calculatrice (affiche le résultat comme si tapé sur la Calculatrice iOS). Voir Modes de Sortie pour la configuration du screenshot Calculatrice.',
            'Los presets Number tienen dos pantallas de salida: Notas (misma revelación) o Calculadora (muestra el resultado como si fuera tecleado en la Calculadora iOS). Ver Modos de Salida para configurar la captura.')),
      ]),

      // 3. INPUT METHODS
      _S(id: 'input', icon: Icons.touch_app, title: t('3. Input Methods', '3. Méthodes d\'Input', '3. Métodos de Entrada'), items: [
        _P(t('All methods work on a black screen — the spectator sees nothing.', 'Toutes les méthodes fonctionnent sur écran noir — le spectateur ne voit rien.', 'Todos los métodos funcionan en pantalla negra — el espectador no ve nada.')),

        _H(t('Volume Buttons', 'Boutons Volume', 'Botones de Volumen')),
        _Table([
          [t('Gesture', 'Geste', 'Gesto'), t('Option', 'Option', 'Opción')],
          ['UP ×1', '1'], ['DOWN ×1', '2'], ['UP ×2', '3'], ['DOWN ×2', '4'], ['UP ×3', '5'], ['DOWN ×3', '6'],
        ]),
        _P(t('Undo: 3 rapid presses same direction. Reset: double undo. Max 6 options.', 'Annuler : 3 pressions rapides même direction. Reset : double annulation. Max 6 options.', 'Deshacer: 3 pulsaciones rápidas misma dirección. Reset: doble deshacer. Máx 6.')),

        _H(t('Tap Zones', 'Zones Tap', 'Zonas Tap')),
        _P(t('Black screen divided into invisible zones. Max 6 options.', 'Écran noir divisé en zones invisibles. Max 6 options.', 'Pantalla negra dividida en zonas invisibles. Máx 6.')),
        _Table([
          [t('Options', 'Options', 'Opciones'), t('Layout', 'Disposition', 'Diseño')],
          ['2', t('Top / Bottom (or Left / Right)', 'Haut / Bas (ou Gauche / Droite)', 'Arriba / Abajo (o Izq / Der)')],
          ['3', t('3 horizontal bands', '3 bandes horizontales', '3 bandas horizontales')],
          ['4', t('4 corners (or 4 stripes)', '4 coins (ou 4 bandes)', '4 esquinas (o 4 franjas)')],
          ['5', t('2×3 grid (1 disabled)', 'Grille 2×3 (1 désactivée)', 'Cuadrícula 2×3 (1 desactivada)')],
          ['6', t('2×3 grid', 'Grille 2×3', 'Cuadrícula 2×3')],
        ]),

        _H('Swipe'),
        _P(t('Configurable swipe patterns. Each option = a gesture sequence (e.g., ↑→). Fully customizable in the builder. 1 gesture for ≤4 options, 2 for ≤16, 4 for more.', 'Patterns de swipe configurables. Chaque option = une séquence de gestes (ex: ↑→). Entièrement personnalisable. 1 geste pour ≤4 options, 2 pour ≤16, 4 pour plus.', 'Patrones de swipe configurables. Cada opción = una secuencia de gestos. Totalmente personalizable.')),

        _H('Audio IA'),
        _P(t('Speech recognition listens to the conversation. Analyzes context with GPT-4o for maximum accuracy. Optional start/stop trigger sentences. Requires OpenAI API key.', 'Reconnaissance vocale écoute la conversation. Analyse le contexte avec GPT-4o pour une précision maximale. Phrases déclencheur optionnelles. Nécessite clé API OpenAI.', 'Reconocimiento de voz escucha la conversación. Analiza el contexto con GPT-4o para máxima precisión. Requiere clave API OpenAI.')),

        _H('Remote Input (global)'),
        _P(t('A global toggle on the home screen — orange bar when ON. The webapp at oass.app/{your-id} mirrors any preset you launch (buttons / black screen tap / black screen swipe, depending on Settings → Assistant stealth UI), and falls back to a free-text field whenever no preset is active. Always OFF on app restart.',
            'Un bouton global sur l\'écran d\'accueil — barre orange quand ON. La webapp oass.app/{votre-id} mirroir n\'importe quel preset lancé (boutons / écran noir tap / écran noir swipe, selon Paramètres → Assistant stealth UI), et propose un champ texte libre quand aucun preset n\'est actif. OFF par défaut au lancement de l\'app.',
            'Un toggle global en la pantalla principal — barra naranja en ON. La webapp oass.app/{tu-id} refleja cualquier preset lanzado y muestra un campo de texto libre cuando no hay preset activo. OFF al reiniciar.')),
        _H(t('URL shortcut: oass.app/{id}/{command}', 'Raccourci URL : oass.app/{id}/{commande}', 'Atajo URL: oass.app/{id}/{comando}')),
        _P(t('Open this URL on any device — no need to interact with buttons. The webapp auto-sends the command. Examples:\n• Multiple Out 6 texts → oass.app/abc/4 selects the 4th text\n• Choices 3 rounds (preprogrammed) → oass.app/abc/121 sends spectator picks 1,2,1\n• Confab with ((ACROSTIC_URL)) → oass.app/abc/Paris sends "Paris" as the secret word\n• Free Will → oass.app/abc/13 sends 2 inputs',
            'Ouvre cette URL sur n\'importe quel appareil — pas besoin d\'interagir avec les boutons. La webapp envoie la commande automatiquement. Exemples :\n• Multiple Out 6 textes → oass.app/abc/4 sélectionne le 4e texte\n• Choices 3 rounds (preprogrammed) → oass.app/abc/121 envoie les choix spectateur 1,2,1\n• Confab avec ((ACROSTIC_URL)) → oass.app/abc/Paris envoie "Paris" comme mot secret\n• Free Will → oass.app/abc/13 envoie 2 inputs',
            'Abre esta URL en cualquier dispositivo. La webapp envía el comando automáticamente. Ejemplos:\n• Multiple Out 6 textos → oass.app/abc/4 selecciona el 4º\n• Choices 3 rondas → oass.app/abc/121 envía 1,2,1\n• Confab con ((ACROSTIC_URL)) → oass.app/abc/Paris\n• Free Will → oass.app/abc/13')),
        _Tip('warning', t('Limitation: only works for presets in PREPROGRAMMED mode (1 input per round = the spectator\'s pick). Two-Inputs presets (where you also enter the performer\'s choice each round) need the standard webapp UI — the URL shortcut is ambiguous because it can\'t encode both performer + spectator picks per round.',
            'Limite : ne fonctionne que pour les presets en mode PREPROGRAMMED (1 input par round = le choix du spectateur). Les presets en Two-Inputs (où tu entres aussi le choix performer à chaque round) nécessitent l\'UI webapp standard — le raccourci URL est ambigu car il ne peut pas encoder à la fois performer + spectateur par round.',
            'Limitación: solo funciona para presets en modo PREPROGRAMMED (1 entrada por ronda). Los presets Two-Inputs requieren la UI estándar.')),
        _Tip('info', t('Per-preset redirect URL: in any preset editor you can set a custom redirect URL — after the assistant submits input, their browser is sent there. Empty = use the global one in Settings → Assistant. Useful for adding a thank-you page, a fake "loading" screen, or chaining to another tool.',
            'Redirection par preset : dans n\'importe quel éditeur de preset tu peux définir une URL de redirection custom — après l\'envoi de l\'input par l\'assistant, son navigateur va là. Vide = utilise la globale dans Paramètres → Assistant. Utile pour ajouter une page de remerciement, un faux écran de chargement, ou chaîner vers un autre outil.',
            'Redirección por preset: en cualquier editor puedes definir una URL custom — después del input, el navegador del asistente va ahí. Vacío = usa la global.')),
        _Tip('info', t('All stealth screens: long press to exit.', 'Tous les écrans stealth : appui long pour quitter.', 'Todas las pantallas stealth: pulsación larga para salir.')),
      ]),

      // 4. CREATE A PRESET
      _S(id: 'create', icon: Icons.build, title: t('4. Creating a Preset', '4. Créer un Preset', '4. Crear un Preset'), items: [
        _P(t('Step-by-step:', 'Étape par étape :', 'Paso a paso:')),
        _P(t('1. Tap "Add Preset" on the home screen\n2. Choose the type (Choices, Duel, Free Will, etc.)\n3. Name your preset\n4. Configure options and labels\n5. Write narrative templates for each outcome\n6. Choose stealth input method\n7. Choose output mode (Notes / Image / Both)\n8. Save',
            '1. Tapez "Add Preset" sur l\'écran d\'accueil\n2. Choisissez le type\n3. Nommez votre preset\n4. Configurez les options et labels\n5. Écrivez les templates narratifs pour chaque résultat\n6. Choisissez la méthode d\'input stealth\n7. Choisissez le mode de sortie (Notes / Image / Both)\n8. Sauvegardez',
            '1. Toca "Add Preset" en la pantalla principal\n2. Elige el tipo\n3. Nombra tu preset\n4. Configura opciones y etiquetas\n5. Escribe plantillas narrativas\n6. Elige método de entrada stealth\n7. Elige modo de salida\n8. Guarda')),
        _Tip('info', t('Use Test Mode (Settings > General) to practice input without performing. All mappings are shown on screen.', 'Utilisez le Mode Test (Paramètres > Général) pour pratiquer l\'input sans performer. Tous les mappings sont affichés.', 'Usa el Modo Test (Configuración > General) para practicar. Todos los mappings se muestran.')),

        _H(t('Generate Texts via AI Prompt (IA Import)', 'Générer les Textes via IA (IA Import)', 'Generar Textos vía IA (IA Import)')),
        _P(t('Available in the bank editor of Choices, Duel and Free Will. Saves you from writing every outcome by hand — the AI writes them all in a single round-trip.',
            'Disponible dans l\'éditeur de banque de Choices, Duel et Free Will. Évite de devoir écrire chaque résultat à la main — l\'IA les rédige tous en un aller-retour.',
            'Disponible en el editor de banco de Choices, Duel y Free Will. Evita escribir cada resultado a mano — la IA los redacta todos en un solo viaje.')),

        _H(t('Step 1 — PREPARE', 'Étape 1 — PRÉPARER', 'Paso 1 — PREPARAR')),
        _P(t('Tap "IA Import" at the top of the bank editor. The first screen recaps the preset context (number of rounds, option labels, performer sequence if applicable) so you can verify everything before generating.\n\nFour fields you can tune:\n• Language — the AI writes in this language regardless of the app UI language\n• Tense — future / present / past\n• Style — direct, taquin, blunt, minimalist, mocking, psychological, or any free-text style you type\n• Lines per entry — set both min and max (e.g., 2 to 4)',
            'Tapez "IA Import" en haut de l\'éditeur. Le premier écran récapitule le contexte du preset (nombre de rounds, labels d\'options, séquence performer si applicable) — vérifie tout avant de générer.\n\n4 champs ajustables :\n• Langue — l\'IA rédigera dans cette langue quel que soit l\'UI de l\'app\n• Temps — futur / présent / passé\n• Style — direct, taquin, blunt, minimalist, mocking, psychological, ou n\'importe quel style libre saisi\n• Lignes par entrée — min et max (ex: 2 à 4)',
            'Toca "IA Import" arriba del editor. La primera pantalla recapitula el contexto del preset.\n\nCampos ajustables:\n• Idioma — la IA escribirá en este idioma\n• Tiempo — futuro / presente / pasado\n• Estilo — directo, burlón, contundente, minimalista, etc.\n• Líneas por entrada — mín y máx')),
        _P(t('Optional: add 1-2 example entries to show the AI your tone (works like few-shot prompting). The examples are passed verbatim into the prompt.',
            'Optionnel : ajoute 1-2 entrées exemples pour montrer à l\'IA ton ton (fonctionne comme du few-shot prompting). Les exemples sont injectés tels quels dans le prompt.',
            'Opcional: añade 1-2 ejemplos para mostrar tu tono.')),

        _H(t('Step 2 — PROMPT', 'Étape 2 — PROMPT', 'Paso 2 — PROMPT')),
        _P(t('The app generates a complete prompt:\n\n• A header instructing "you are writing prediction scripts for a live mentalism show, output ONLY raw JSON, no markdown."\n• The style/tense block (your settings from Step 1).\n• The game context block (preset type, number of rounds, key encoding rules — e.g., for Choices: H = hit, M = miss, key length = number of rounds).\n• The list of EVERY outcome key the AI must produce (e.g., HHH, HHM, HMH, ... HMHM... — 2^N for Choices).\n• Available placeholder variables: {choiceS1}, {choiceS2}, {choiceP1}, {hitsCount}, etc.\n• Your example entries (if you added any).\n• The expected JSON output schema.\n\nTap "Copy" — the entire prompt goes to your clipboard. Open ChatGPT, Claude or any LLM, paste, send. Ask for raw JSON only.',
            'L\'app génère un prompt complet :\n\n• Un en-tête demandant "tu écris des scripts de prédiction pour un show de mentalisme live, sortie UNIQUEMENT en JSON brut, pas de markdown".\n• Le bloc style/temps (tes réglages de l\'étape 1).\n• Le bloc contexte du jeu (type de preset, nombre de rounds, règles d\'encodage des clés — ex: pour Choices : H = hit, M = miss, longueur = nombre de rounds).\n• La liste de TOUTES les clés de résultat que l\'IA doit produire (ex: HHH, HHM, HMH, ... — 2^N pour Choices).\n• Les variables placeholder disponibles : {choiceS1}, {choiceS2}, {choiceP1}, {hitsCount}, etc.\n• Tes exemples (si tu en as ajoutés).\n• Le schéma JSON attendu en sortie.\n\nTapez "Copier" — le prompt complet va dans le presse-papiers. Ouvre ChatGPT/Claude ou n\'importe quel LLM, colle, envoie. Demande du JSON brut uniquement.',
            'La app genera un prompt completo. Toca "Copiar" → pégalo en ChatGPT/Claude. Pide JSON crudo.')),
        _Tip('info', t('Use a model with strong JSON discipline: Claude 4.6+, GPT-4o or higher. Smaller models often add markdown fences or change the keys, breaking the import.',
            'Utilise un modèle solide en JSON : Claude 4.6+, GPT-4o ou supérieur. Les petits modèles ajoutent souvent des balises markdown ou changent les clés, ce qui casse l\'import.',
            'Usa un modelo sólido: Claude 4.6+, GPT-4o o superior.')),

        _H(t('Step 3 — IMPORT', 'Étape 3 — IMPORTER', 'Paso 3 — IMPORTAR')),
        _P(t('Paste the JSON the AI gave you back into the modal. The app validates:\n• Are all required keys present? (HHH, HHM, etc.)\n• Are there extra keys that don\'t belong?\n• Do any entries reference unresolved variables (e.g., {choiceS4} when there are only 3 rounds)?\n\nIssues are listed in red, valid entries in green. Tap "Import" — the bank is filled in one shot. You can still edit any entry manually afterwards in the bank editor.',
            'Colle le JSON que l\'IA t\'a renvoyé dans le modal. L\'app valide :\n• Toutes les clés requises sont-elles présentes ? (HHH, HHM, etc.)\n• Y a-t-il des clés en trop qui n\'ont pas leur place ?\n• Des entrées font-elles référence à des variables non résolues (ex: {choiceS4} alors qu\'il n\'y a que 3 rounds) ?\n\nLes problèmes apparaissent en rouge, les entrées valides en vert. Tapez "Importer" — la banque est remplie d\'un coup. Tu peux encore éditer chaque entrée manuellement dans l\'éditeur après.',
            'Pega el JSON. La app valida claves y variables. Errores en rojo, válidos en verde. Toca "Importar" para rellenar.')),
        _Tip('warning', t('If the AI returns markdown-wrapped JSON (```json ... ```), the modal\'s parser strips fences automatically. If it returns prose explanation, it fails — go back to the chat and ask "raw JSON only, no commentary".',
            'Si l\'IA retourne du JSON entouré de markdown (```json ... ```), le parser du modal retire les balises automatiquement. Si elle retourne du texte explicatif, l\'import échoue — retourne dans le chat et demande "JSON brut uniquement, pas de commentaire".',
            'Si la IA devuelve markdown, el parser quita las marcas. Si devuelve prosa, vuelve al chat y pide solo JSON.')),
        _Tip('example', t('Choices, 3 rounds, labels "Right/Left":\n→ Prompt asks for 8 texts (HHH, HHM, HMH, HMM, MHH, MHM, MMH, MMM), each using {choiceS1}..{choiceS3} and {hitsCount}.\n→ AI returns: { "HHH": "...", "HHM": "...", ... }\n→ Paste, tap Import, all 8 outcomes are now configured.',
            'Choices, 3 rounds, labels "Droite/Gauche" :\n→ Le prompt demande 8 textes (HHH, HHM, HMH, HMM, MHH, MHM, MMH, MMM), utilisant {choiceS1}..{choiceS3} et {hitsCount}.\n→ L\'IA renvoie : { "HHH": "...", "HHM": "...", ... }\n→ Colle, tape Importer, les 8 résultats sont configurés.',
            'Choices, 3 rondas: el prompt pide 8 textos. La IA devuelve { "HHH": "...", ... }. Pegar → Importar → 8 resultados listos.')),
        _Tip('info', t('Available in: Choices (by H/M pattern, 2^N entries) · Duel Fixed Rounds (by score: "3|2-1") · Duel First To (by FT key: "FT3_S_3-1") · Free Will (6 permutations of object × action).',
            'Disponible dans : Choices (par pattern H/M, 2^N entrées) · Duel Fixed Rounds (par score : "3|2-1") · Duel First To (par clé FT : "FT3_S_3-1") · Free Will (6 permutations objet × action).',
            'Disponible en: Choices · Duel Fixed Rounds · Duel First To · Free Will.')),
      ]),

      // 5. PERFORMANCE FLOW
      _S(id: 'flow', icon: Icons.play_circle_outline, title: t('5. Performance Flow', '5. Flow de Performance', '5. Flujo de Actuación'), items: [
        _H(t('Before the Show', 'Avant le Show', 'Antes del Show')),
        _P(t('✓ Preset created and tested\n✓ Test Mode OFF\n✓ Auto-Copy ON + Shortcut configured\n✓ Battery charged\n✓ Do Not Disturb enabled', '✓ Preset créé et testé\n✓ Mode Test OFF\n✓ Auto-Copy ON + Shortcut configuré\n✓ Batterie chargée\n✓ Ne Pas Déranger activé', '✓ Preset creado y probado\n✓ Modo Test OFF\n✓ Auto-Copy ON + Atajo configurado\n✓ Batería cargada\n✓ No Molestar activado')),

        _H(t('During the Show', 'Pendant le Show', 'Durante el Show')),
        _P(t('1. Play the preset from home screen\n2. Optional: fake pre-screen (Notes or Homescreen)\n3. Volume Down or double-tap → black stealth screen\n4. Input the choices secretly\n5. Text auto-generated, copied, shortcut launches\n6. Show the "prediction"', '1. Lancez le preset depuis l\'accueil\n2. Optionnel : faux écran (Notes ou Homescreen)\n3. Volume Bas ou double-tap → écran noir\n4. Entrez les choix secrètement\n5. Texte auto-généré, copié, shortcut se lance\n6. Montrez la "prédiction"', '1. Lanza el preset desde inicio\n2. Opcional: pantalla falsa\n3. Volumen Abajo o doble-tap → pantalla negra\n4. Introduce las elecciones secretamente\n5. Texto auto-generado, copiado, atajo se ejecuta\n6. Muestra la "predicción"')),

        _H(t('Emergency Gestures', 'Gestes d\'Urgence', 'Gestos de Emergencia')),
        _Table([
          [t('Gesture', 'Geste', 'Gesto'), t('Action', 'Action', 'Acción')],
          [t('3 rapid same direction', '3 rapides même direction', '3 rápidos misma dirección'), 'Undo'],
          [t('Double undo', 'Double annulation', 'Doble deshacer'), 'Reset'],
          [t('Long press', 'Appui long', 'Pulsación larga'), t('Exit', 'Quitter', 'Salir')],
        ]),
      ]),

      // 6. ROUTINES
      _S(id: 'routines', icon: Icons.playlist_play, title: t('6. Routines', '6. Routines', '6. Rutinas'), items: [
        _P(t('A routine chains multiple presets into one flow. After each input, the app automatically moves to the next preset.', 'Une routine enchaîne plusieurs presets. Après chaque input, l\'app passe automatiquement au preset suivant.', 'Una rutina encadena múltiples presets. Después de cada entrada, la app pasa al siguiente.')),

        _H(t('Input Order ≠ Output Order', 'Ordre d\'Input ≠ Ordre d\'Output', 'Orden de Entrada ≠ Orden de Salida')),
        _Tip('example', t('Input order: Color → Number → Card (easy to collect)\nOutput order: Card → Color → Number (dramatic build)\n\nYou collect info in show order, but the prediction text is assembled in revelation order.', 'Ordre d\'input : Couleur → Nombre → Carte (facile à collecter)\nOrdre d\'output : Carte → Couleur → Nombre (montée dramatique)\n\nVous collectez dans l\'ordre du show, mais le texte est assemblé dans l\'ordre de révélation.', 'Orden de entrada: Color → Número → Carta (fácil de recoger)\nOrden de salida: Carta → Color → Número (construcción dramática)')),

        _P(t('Subtle pixel indicators show chain progress on stealth screens. The webapp shows a progress bar for Remote Input.', 'Des indicateurs pixels subtils montrent la progression sur les écrans stealth. La webapp montre une barre de progression en Remote Input.', 'Indicadores de píxeles sutiles muestran el progreso. La webapp muestra una barra de progreso.')),
      ]),

      // 7. OUTPUT MODES
      _S(id: 'output', icon: Icons.output, title: t('7. Output Modes', '7. Modes de Sortie', '7. Modos de Salida'), items: [
        _H('Notes'),
        _P(t('Text displayed in a fake Notes screen with configurable background screenshot. Auto-copied to clipboard. Optional iOS Shortcut launches after (e.g., pastes into real Notes app).', 'Texte affiché dans un faux écran Notes avec screenshot configurable. Copié automatiquement. Raccourci iOS optionnel (ex: coller dans l\'app Notes).', 'Texto mostrado en pantalla Notes falsa con fondo configurable. Copiado automáticamente. Atajo iOS opcional.')),
        _H(t('Setting up the Notes screenshot', 'Configurer le screenshot Notes', 'Configurar la captura de Notes')),
        _P(t('The Notes reveal overlays your generated text on top of a screenshot of your real Notes app. You control the look.',
            'La révélation Notes superpose votre texte généré sur un screenshot de votre vraie app Notes. Vous contrôlez le rendu.',
            'La revelación Notes superpone tu texto sobre una captura de tu app Notes real. Tú controlas el aspecto.')),
        _P(t('1. Open your real Notes app and take an empty-note screenshot (with title bar, date, keyboard hidden).\n2. Go to Settings → Reveal Background → NOTE SCREEN.\n3. Tap Light Mode and upload the screenshot. Repeat for Dark Mode if needed.\n4. Tap Calibrate Light/Dark — drag the text overlay to where the note body is in your screenshot. Adjust font size/color.\n5. Optional: LIST SCREEN background = a screenshot of the Notes folder list (shown briefly before the note opens for added realism).',
            '1. Ouvrez votre vraie app Notes et prenez un screenshot d\'une note vide (barre de titre, date, clavier masqué).\n2. Allez dans Paramètres → Reveal Background → NOTE SCREEN.\n3. Tapez Light Mode et uploadez le screenshot. Répétez pour Dark Mode si besoin.\n4. Tapez Calibrate Light/Dark — glissez l\'overlay texte vers l\'emplacement du corps de la note dans votre screenshot. Ajustez taille/couleur.\n5. Optionnel : LIST SCREEN = screenshot de la liste des notes (affiché brièvement avant l\'ouverture pour plus de réalisme).',
            '1. Abre tu app Notes real y toma una captura de nota vacía.\n2. Ve a Configuración → Reveal Background → NOTE SCREEN.\n3. Toca Light Mode y sube la captura. Repite para Dark Mode.\n4. Toca Calibrate — arrastra el overlay de texto a donde está el cuerpo de la nota. Ajusta tamaño/color.\n5. Opcional: LIST SCREEN = captura de la lista de notas (mostrada brevemente antes de abrir la nota).')),
        _Tip('info', t('Use your own device for the screenshot — the status bar, battery, and time will match. Light + Dark mode choice follows Settings → Reveal Theme.',
            'Utilisez votre propre appareil pour le screenshot — la barre de statut, la batterie et l\'heure correspondront. Le choix Light/Dark suit Paramètres → Reveal Theme.',
            'Usa tu propio dispositivo — barra de estado, batería y hora coincidirán. La elección Light/Dark sigue Configuración → Reveal Theme.')),

        _H('Image'),
        _P(t('A pre-uploaded image (one per possible outcome) is saved to your photo gallery. Two options after save:\n• Black Screen — stealth, small green pixel confirms save\n• Open Photos — the Photos app opens to show the image', 'Une image pré-uploadée (une par résultat possible) est sauvée dans la galerie. Deux options :\n• Écran Noir — stealth, petit pixel vert confirme\n• Ouvrir Photos — l\'app Photos s\'ouvre', 'Una imagen pre-subida se guarda en tu galería. Dos opciones:\n• Pantalla Negra — stealth, píxel verde confirma\n• Abrir Fotos — la app Fotos se abre')),
        _P(t('You can backdate the image timestamp (e.g., 60 min = "taken 1 hour ago").', 'Vous pouvez antidater l\'horodatage (ex: 60 min = "prise il y a 1h").', 'Puedes antedatar la marca de tiempo (ej: 60 min = "tomada hace 1h").')),

        _H('Both'),
        _P(t('Image saved to gallery first → text copied to clipboard → shortcut launches. The performer has both: Notes (text) and Gallery (image) ready.', 'Image sauvée d\'abord → texte copié → shortcut se lance. Le performer a les deux : Notes (texte) et Galerie (image) prêts.', 'Imagen guardada primero → texto copiado → atajo se ejecuta. El artista tiene ambos listos.')),

        _H(t('Calculator Output (Number presets)', 'Sortie Calculatrice (presets Number)', 'Salida Calculadora (presets Number)')),
        _P(t('Number presets can reveal the result on a fake Calculator screen. It looks like you typed the number on the real iOS Calculator.',
            'Les presets Number peuvent révéler le résultat sur une fausse Calculatrice. On dirait que vous avez tapé le nombre sur la vraie Calculatrice iOS.',
            'Los presets Number pueden revelar el resultado en una Calculadora falsa. Parece que tecleaste el número en la Calculadora iOS real.')),
        _P(t('Setup (one-time):\n1. Open the real iOS Calculator and screenshot an empty state (shows "0").\n2. Settings → Reveal Background → CALCULATOR SCREEN → upload the screenshot.\n3. Tap Edit Screenshot → erase the "0" with the provided eraser tool so the display is blank — the generated number will be rendered on top.\n4. In your Number preset, choose "Calculator" as output (instead of Notes).',
            'Configuration (une fois) :\n1. Ouvrez la vraie Calculatrice iOS et prenez un screenshot à l\'état vide (affiche "0").\n2. Paramètres → Reveal Background → CALCULATOR SCREEN → uploadez le screenshot.\n3. Tapez Edit Screenshot → effacez le "0" avec l\'outil gomme intégré pour que l\'affichage soit vide — le nombre généré sera rendu par-dessus.\n4. Dans votre preset Number, choisissez "Calculatrice" comme sortie (au lieu de Notes).',
            'Configuración (una vez):\n1. Abre la Calculadora iOS real y toma una captura en estado vacío (muestra "0").\n2. Configuración → Reveal Background → CALCULATOR SCREEN → sube la captura.\n3. Toca Edit Screenshot → borra el "0" con la herramienta borrador incluida — el número generado se renderizará encima.\n4. En tu preset Number, elige "Calculadora" como salida.')),
        _Tip('info', t('The eraser editor also lets you calibrate position and font of the number overlay. The result aligns exactly with the real calculator digit zone.',
            'L\'éditeur gomme permet aussi de calibrer la position et la police du nombre affiché. Le résultat s\'aligne exactement avec la zone chiffres de la vraie calculatrice.',
            'El editor borrador también permite calibrar posición y fuente del número. El resultado se alinea con la zona de dígitos real.')),
      ]),

      // 8. NARRATIVE VARIABLES
      _S(id: 'variables', icon: Icons.code, title: t('8. Narrative Variables', '8. Variables Narratives', '8. Variables Narrativas'), items: [
        _P(t('Use placeholders in your templates. They\'re replaced with actual values during the show.', 'Utilisez des placeholders dans vos templates. Ils sont remplacés par les vraies valeurs pendant le show.', 'Usa placeholders en tus plantillas. Se reemplazan con valores reales durante el show.')),

        _H('Choices'),
        _Table([
          [t('Variable', 'Variable', 'Variable'), t('Description', 'Description', 'Descripción')],
          ['{choiceS1}, {choiceS2}...', t('Spectator choice per round', 'Choix spectateur par round', 'Elección espectador por ronda')],
          ['{choiceP1}, {choiceP2}...', t('Performer choice per round', 'Choix performer par round', 'Elección artista por ronda')],
          ['{hitsCount}, {missCount}', t('Hit/miss totals', 'Totaux hit/miss', 'Totales acierto/fallo')],
          ['{spectatorSequence}', t('Full sequence', 'Séquence complète', 'Secuencia completa')],
        ]),

        _H('Duel (First To)'),
        _Table([
          [t('Variable', 'Variable', 'Variable'), t('Description', 'Description', 'Descripción')],
          ['{numRounds}', t('Total rounds played', 'Rounds joués', 'Rondas jugadas')],
          ['{numTies}', t('Number of ties', 'Nombre d\'égalités', 'Número de empates')],
          ['{spectatorSequence}', t('Full sequence', 'Séquence complète', 'Secuencia completa')],
        ]),

        _Tip('info', t('Free Will and Multiple Out don\'t use variables — each outcome has its own complete text.',
            'Free Will et Multiple Out n\'utilisent pas de variables — chaque résultat a son propre texte complet.',
            'Free Will y Multiple Out no usan variables — cada resultado tiene su propio texto completo.')),
      ]),

      // 9. API & AI
      _S(id: 'api', icon: Icons.cloud, title: t('9. APIs & AI', '9. APIs & IA', '9. APIs & IA'), items: [
        _P(t('Confabulation presets can fetch live data from external APIs.', 'Les presets Confabulation peuvent récupérer des données en direct depuis des APIs externes.', 'Los presets Confabulation pueden obtener datos en vivo de APIs externas.')),
        _H('Inject'), _P(t('Fetches a value from 11z.co — e.g., a word chosen on another platform. Marker: ((INJECT))', 'Récupère une valeur de 11z.co — ex: un mot choisi sur une autre plateforme. Marqueur : ((INJECT))', 'Obtiene un valor de 11z.co. Marcador: ((INJECT))')),
        _H('Elips'), _P(t('Fetches music data (artist, song, word) from pag.gg. Markers: ((ELIPS_ARTIST)), ((ELIPS_SONG)), ((ELIPS_WORD))', 'Récupère des données musicales de pag.gg. Marqueurs : ((ELIPS_ARTIST)), ((ELIPS_SONG)), ((ELIPS_WORD))', 'Obtiene datos musicales de pag.gg.')),
        _H('HighScore'), _P(t('Fetches game score from SkyHop. Markers: ((HIGHSCORE_SCORE)), ((HIGHSCORE_RANKING))', 'Récupère le score de SkyHop. Marqueurs : ((HIGHSCORE_SCORE)), ((HIGHSCORE_RANKING))', 'Obtiene puntuación de SkyHop.')),
        _H('AI Transform'), _P(t('Transform any value with a custom GPT-4o-mini prompt. Example: transform a city into a poetic description.', 'Transformez n\'importe quelle valeur avec un prompt GPT-4o-mini. Exemple : transformer une ville en description poétique.', 'Transforma cualquier valor con un prompt GPT-4o-mini personalizado.')),
        _H(t('Acrostic', 'Acrostiche', 'Acróstico')),
        _P(t('Generate a word column where the Nth letter of each word spells a secret word. Configure word banks per language in Settings.', 'Générez une colonne de mots dont la Nème lettre épelle un mot secret. Configurez les banques de mots par langue dans les Paramètres.', 'Genera una columna de palabras donde la N-ésima letra deletrea una palabra secreta.')),
        _Tip('example', t('Secret word: PARIS (position 3)\n\nrePas\nbrAve\nfuRie\nmaIs\nbuS\n\nThe 3rd letter of each word spells P-A-R-I-S.',
            'Mot secret : PARIS (position 3)\n\nrePas\nbrAve\nfuRie\nmaIs\nbuS\n\nLa 3ème lettre de chaque mot épelle P-A-R-I-S.',
            'Palabra secreta: PARIS (posición 3)\n\nrePas\nbrAve\nfuRie\nmaIs\nbuS\n\nLa 3ª letra de cada palabra deletrea P-A-R-I-S.')),
      ]),

      // 10. IMPORT / EXPORT
      _S(id: 'import', icon: Icons.import_export, title: t('10. Import / Export', '10. Import / Export', '10. Importar / Exportar'), items: [
        _H(t('Export', 'Exporter', 'Exportar')),
        _P(t('"E" button = export all presets. Export icon on a card = single preset. JSON copied to clipboard.', 'Bouton "E" = exporter tous les presets. Icône export sur une carte = un seul preset. JSON copié.', 'Botón "E" = exportar todos. Icono export en tarjeta = uno solo. JSON copiado.')),
        _H(t('Import', 'Importer', 'Importar')),
        _P(t('"I" button → paste JSON. Accepts: single object, array, or two objects pasted together. New IDs auto-generated.', 'Bouton "I" → collez le JSON. Accepte : objet unique, tableau, ou deux objets collés. Nouveaux IDs auto-générés.', 'Botón "I" → pega JSON. Acepta: objeto único, array, o dos objetos pegados. IDs auto-generados.')),
      ]),

      // 11. SETTINGS
      _S(id: 'settings', icon: Icons.settings, title: t('11. Settings', '11. Paramètres', '11. Configuración'), items: [
        _H('General'), _P(t('Language, stealth options (test mode, visual feedback), haptic feedback, pre-screen, Bluetooth remote.', 'Langue, options stealth (mode test, feedback visuel), retour haptique, pré-écran, télécommande Bluetooth.', 'Idioma, opciones stealth, retroalimentación háptica, pre-pantalla, control Bluetooth.')),
        _H('Integrations'), _P(t('Assistant ID + webapp URL, OpenAI API key, external APIs (Inject, Elips, HighScore), Free Text settings, Acrostic word bank.', 'ID Assistant + URL webapp, clé OpenAI, APIs externes, paramètres Texte Libre, banque de mots Acrostiche.', 'ID Asistente + URL webapp, clave OpenAI, APIs externas, config Texto Libre, banco de palabras.')),
        _H('Display'), _P(t('Auto-copy + shortcut, iCloud sync, data management.', 'Auto-copy + raccourci, sync iCloud, gestion des données.', 'Auto-copiar + atajo, sync iCloud, gestión de datos.')),
        _H('Reveal Background'), _P(t('Upload screenshots used by Notes and Calculator output modes.\n• NOTE SCREEN — Light/Dark backgrounds + Calibrate to position the text overlay\n• LIST SCREEN (optional) — folder list shown briefly before the note opens\n• CALCULATOR SCREEN — screenshot + Edit Screenshot (erase the "0", calibrate number position)',
            'Uploadez les screenshots utilisés par les sorties Notes et Calculatrice.\n• NOTE SCREEN — fonds Light/Dark + Calibrate pour placer le texte\n• LIST SCREEN (optionnel) — liste de dossiers affichée brièvement avant l\'ouverture\n• CALCULATOR SCREEN — screenshot + Edit Screenshot (effacer le "0", calibrer la position du nombre)',
            'Sube las capturas usadas por las salidas Notas y Calculadora.\n• NOTE SCREEN — fondos Light/Dark + Calibrate para colocar el texto\n• LIST SCREEN (opcional)\n• CALCULATOR SCREEN — captura + Edit Screenshot (borrar el "0", calibrar posición del número)')),
      ]),

      // 12. FAQ
      _S(id: 'faq', icon: Icons.help_outline, title: t('12. FAQ', '12. FAQ', '12. FAQ'), items: [
        _H(t('"Audio doesn\'t detect anything"', '"L\'audio ne détecte rien"', '"El audio no detecta nada"')),
        _P(t('→ Check microphone permissions, audio language setting, and that the OpenAI API key is set for AI mode.', '→ Vérifiez les permissions micro, la langue audio, et que la clé API OpenAI est configurée pour le mode IA.', '→ Verifica permisos de micrófono, idioma de audio, y que la clave API OpenAI esté configurada.')),
        _H(t('"Shortcut doesn\'t launch"', '"Le raccourci ne se lance pas"', '"El atajo no se ejecuta"')),
        _P(t('→ Check the exact shortcut name in Settings > Display. It must match your iOS Shortcuts app exactly (case-sensitive).', '→ Vérifiez le nom exact dans Paramètres > Display. Il doit correspondre exactement à l\'app Raccourcis iOS.', '→ Verifica el nombre exacto en Configuración > Display. Debe coincidir exactamente con la app Atajos.')),
        _H(t('"Assistant doesn\'t receive"', '"L\'assistant ne reçoit pas"', '"El asistente no recibe"')),
        _P(t('→ Check the assistant ID matches in Settings and the webapp URL. Both devices need internet. Try refreshing the webapp.', '→ Vérifiez que l\'ID assistant correspond dans les Paramètres et l\'URL webapp. Les deux appareils ont besoin d\'internet.', '→ Verifica que el ID coincida. Ambos dispositivos necesitan internet. Intenta refrescar la webapp.')),
        _H(t('"How to practice safely?"', '"Comment pratiquer sans risque ?"', '"¿Cómo practicar sin riesgo?"')),
        _P(t('→ Enable Test Mode in Settings > General. All stealth screens show mappings and feedback. Switch it OFF before performing.', '→ Activez le Mode Test dans Paramètres > Général. Tous les écrans stealth affichent les mappings. Désactivez-le avant de performer.', '→ Activa el Modo Test en Configuración > General. Desactívalo antes de actuar.')),
      ]),
      _S(id: 'credits', icon: Icons.favorite_outline, title: t('13. Credits', '13. Crédits', '13. Créditos'), items: [
        _H('Hicham Benkiran'),
        _P(t('Swap method for the Free Will preset.', 'Méthode de Swap du preset Free Will.', 'Método de Swap del preset Free Will.')),
      ]),
    ];
  }
}

// Content items
class _H { final String t; const _H(this.t); }
class _P { final String t; const _P(this.t); }
class _Tip { final String type; final String t; const _Tip(this.type, this.t); } // 'info', 'example', 'warning'
class _Table { final List<List<String>> rows; const _Table(this.rows); }
class _S { final String id; final IconData icon; final String title; final List<dynamic> items; const _S({required this.id, required this.icon, required this.title, required this.items}); }
