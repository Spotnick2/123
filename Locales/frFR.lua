local _, ns = ...
if ns.skip then return end
if ns.locale ~= "frFR" then return end

-- French (#22). Game terms follow the French client (Pierre d'âme, Garde
-- funeste); spell, item and demon names come from the client itself.
local L = ns.L

-- Bar
L["Demon"] = "Démon"
L["Demons"] = "Démons"
L["Armor"] = "Armure"
L["Soulstone"] = "Pierre d'âme"
L["Healthstone"] = "Pierre de soins"
L["Summoning"] = "Invocation"
L["Use %s"] = "Utiliser : %s"
L["item %d"] = "objet %d"
L["spell %d"] = "sort %d"
L["Needs %s"] = "Nécessite : %s"
L["a reagent"] = "un composant"
L["Not on you"] = "Absente"
L["Click: %s"] = "Clic : %s"
L["(already out: asks first)"] = "(déjà là : demande d'abord)"
L["Right-click: %s"] = "Clic droit : %s"
L["%d waiting for a summon"] = "%d en attente d'invocation"
L["Nothing learned for this yet"] = "Rien d'appris pour cela"
L["The demon wheel can't open in combat"] = "La roue des démons ne s'ouvre pas en combat"
L["Click: the demon wheel"] = "Clic : la roue des démons"
L["Shift-drag: move the bar"] = "Maj-glisser : déplacer la barre"
L["the bar can't be shown or hidden in combat."] = "la barre ne peut pas être affichée ou masquée en combat."

-- Demon wheel
L["Select a demon to summon"] = "Choisissez un démon à invoquer"
L["DEMON SUMMONING"] = "INVOCATION DE DÉMONS"
L["PREVIEW"] = "APERÇU"
L["Doomguard"] = "Garde funeste"
L["Demonic Sacrifice"] = "Sacrifice démoniaque"
L["Sacrifice"] = "Sacrifice"
L["Active"] = "Actif"
L["No demon"] = "Aucun démon"
L["Not learned"] = "Non appris"
L["No %s"] = "Manque : %s"
L["reagent"] = "composant"
L["Preview: click a demon to put it in the centre"] = "Aperçu : cliquez sur un démon pour le mettre au centre"
L["Preview: put the %s in the centre"] = "Aperçu : mettre %s au centre"
L["%s: not learned yet"] = "%s : pas encore appris"
L["%s again (already out)"] = "%s à nouveau (déjà là)"
L["%s: needs %s"] = "%s : nécessite %s"
L["Shift: %s first"] = "Maj : %s d'abord"
L["Preview: nothing is cast"] = "Aperçu : aucun sort lancé"
L["preview can't change in combat."] = "l'aperçu ne peut pas changer en combat."
L["preview on: every demon is shown, nothing is cast. Click a demon to put it in the centre; /123 preview again to stop."] =
    "aperçu activé : tous les démons sont affichés, aucun sort n'est lancé. Cliquez sur un démon pour le mettre au centre ; /123 preview à nouveau pour arrêter."
L["preview off."] = "aperçu désactivé."
L["the demon wheel can't open in combat."] = "la roue des démons ne s'ouvre pas en combat."
L["the demon wheel closes when combat ends."] = "la roue des démons se fermera à la fin du combat."

-- Re-summon prompt
L["Summon"] = "Invoquer"
L["Cancel"] = "Annuler"
L["Don't ask again"] = "Ne plus demander"
L["that demon"] = "ce démon"
L["You already have your %s summoned. Summon it again?"] = "%s est déjà là. L'invoquer à nouveau ?"
L["won't ask again before re-summoning (/123 confirm to ask again)."] =
    "ne demandera plus avant de réinvoquer (/123 confirm pour redemander)."

-- Summon queue
L["%ds"] = "%ds"
L["%dm"] = "%dmin"
L["Summons (%d)"] = "Invocations (%d)"
L["and %d more"] = "et %d de plus"

-- Summon execution and announcements (#10, #11)
L["Click: %s on %s"] = "Clic : %s sur %s"
L["next"] = "suivant"
L["summoning"] = "invocation"
L["pending"] = "proposée"
L["accepted"] = "acceptée"
L["declined"] = "refusée"
L["here"] = "ici"
L["Summoning {name}, please click the portal"] = "J'invoque {name}, cliquez sur le portail svp"
L["Need 2 clickers for the summon"] = "Il faut 2 personnes pour cliquer sur le portail"
L["Summon announcements"] = "Annonces d'invocation"
L["Announce the summon in group chat"] = "Annoncer l'invocation dans la discussion de groupe"
L["Ask for clickers when fewer than 2 are near"] = "Demander de l'aide quand moins de 2 personnes sont proches"
L["{name} is who you summon. Sent to instance, raid or party chat when the ritual starts, at most every 10 seconds."] =
    "{name} est la personne invoquée. Envoyé en discussion d'instance, de raid ou de groupe quand le rituel commence, au plus toutes les 10 secondes."

-- Soulstone target (#5)
L["Soulstone target"] = "Cible de la pierre d'âme"
L["Clear"] = "Effacer"
L["Right-click: choose who gets it"] = "Clic droit : choisir qui la reçoit"
L["%s: in combat, on your target"] = "%s : en combat, sur votre cible"
L["%s left the group: no soulstone target."] = "%s a quitté le groupe : plus de cible pour la pierre d'âme."

-- Healthstone requests (#8)
L["%s asks for a healthstone."] = "%s demande une pierre de soins."
L["Open trade"] = "Ouvrir l'échange"
L["Place the healthstone"] = "Placer la pierre de soins"
L["Skip"] = "Ignorer"
L["Put your best healthstone in the trade."] = "Placez votre meilleure pierre de soins dans l'échange."
L["Accept the trade to give it."] = "Acceptez l'échange pour la donner."
L["No healthstone: create one first (the Healthstone button)."] = "Pas de pierre de soins : créez-en une d'abord (bouton Pierre de soins)."
L["Not in your group: target them first."] = "Pas dans votre groupe : ciblez cette personne d'abord."
L["A test request: nothing to trade."] = "Une demande de test : rien à échanger."
L["No healthstone, or no free trade slot."] = "Pas de pierre de soins, ou plus de place dans l'échange."
L["Your cursor holds something: put it down first."] = "Votre curseur tient un objet : posez-le d'abord."
L["%d healthstone requests. /123 hs test | clear"] = "%d demandes de pierre de soins. /123 hs test | clear"
L["Healthstone requests"] = "Demandes de pierre de soins"
L["Prompt when someone asks for a healthstone"] = "Proposer un échange quand on demande une pierre de soins"
L["Also whispers from outside the group"] = "Aussi les chuchotements hors du groupe"
L["Whole message, in group chat or a whisper. You open the trade and place the stone; you accept. /123 hs test shows the prompt."] =
    "Le message entier, en discussion de groupe ou chuchoté. Vous ouvrez l'échange et placez la pierre ; vous acceptez. /123 hs test montre la fenêtre."

-- Banish and Subjugate Demon (#29)
L["Banish"] = "Bannir"
L["Subjugate"] = "Asservir"
L["Subjugate Demon"] = "Asservir un démon"
L["Dismiss the subjugated demon"] = "Renvoyer le démon asservi"
L["Banished: %s left"] = "Banni : encore %s"
L["From the cast: a break before that can't be seen."] = "Depuis le sort : une rupture avant ne peut pas être vue."
L["Subjugated: %s left at most"] = "Asservi : encore %s au plus"
L["Right-click: dismiss the subjugated demon"] = "Clic droit : renvoyer le démon asservi"
L["%s broke free: it's hostile again!"] = "%s s'est libéré : il est de nouveau hostile !"
L["the subjugated demon"] = "le démon asservi"
L["Subjugated demon breaks free"] = "Démon asservi libéré"

-- Minimap
L["Shift-click: show or hide the bar"] = "Maj-clic : afficher ou masquer la barre"
L["Right-click: options"] = "Clic droit : options"

-- Sounds
L["Whisper"] = "Chuchotement"
L["Group invite"] = "Invitation de groupe"
L["Ready check"] = "Appel"
L["Raid warning"] = "Avertissement de raid"
L["None"] = "Aucun"
L["Summon request"] = "Demande d'invocation"
L["Healthstone request"] = "Demande de pierre de soins"

-- Options
L["123 — Warlock Summons, Demons & Stones"] = "123 — Invocations, démons et pierres du démoniste"
L["/123 shows or hides the bar, /123 wheel opens the demon wheel, /123 options opens this page."] =
    "/123 affiche ou masque la barre, /123 wheel ouvre la roue des démons, /123 options ouvre cette page."
L["Key bindings: Options > Keybindings > AddOns > 123."] = "Raccourcis : Options > Raccourcis > AddOns > 123."
L["Bar"] = "Barre"
L["Show the bar"] = "Afficher la barre"
L["Names under the icons"] = "Noms sous les icônes"
L["Bar scale"] = "Échelle de la barre"
L["Reset position"] = "Réinitialiser la position"
L["Shift-drag the 123 handle to move the bar."] = "Maj-glisser la poignée 123 pour déplacer la barre."
L["Demon wheel"] = "Roue des démons"
L["Ask before re-summoning the demon that is out"] = "Demander avant de réinvoquer le démon présent"
L["Cinematic camera"] = "Caméra cinématique"
L["Slow camera orbit"] = "Rotation lente de la caméra"
L["Hide the game UI while the wheel is open"] = "Masquer l'interface du jeu quand la roue est ouverte"
L["Preview the wheel"] = "Aperçu de la roue"
L["Sound"] = "Son"
L["Demon voices on the wheel"] = "Voix des démons sur la roue"
L["Alert sounds"] = "Sons d'alerte"
L["the game didn't play that sound; pick another."] = "le jeu n'a pas joué ce son ; choisissez-en un autre."
L["Picking a sound plays it. Requests arrive with the summon queue and healthstone requests."] =
    "Choisir un son le joue. Les demandes arrivent avec la file d'invocation et les demandes de pierre de soins."
L["Summon queue"] = "File d'invocation"
L["Queue group members who type a keyword"] = "Ajouter à la file les membres qui tapent un mot-clé"
L["Keywords"] = "Mots-clés"
L["Minutes before a request drops"] = "Minutes avant qu'une demande expire"
L["The whole message must be a keyword: \"123\" asks, \"1234\" or \"123 dps\" don't. /123 queue test tries it alone."] =
    "Le message entier doit être un mot-clé : « 123 » demande, « 1234 » ou « 123 dps » non. /123 queue test l'essaie seul."
L["Minimap"] = "Minicarte"
L["Minimap button"] = "Bouton de la minicarte"
L["Addon compartment entry (after /reload)"] = "Entrée dans le compartiment des AddOns (après /reload)"
L["the bar can't change in combat."] = "la barre ne peut pas changer en combat."
L["options can't open in combat."] = "les options ne s'ouvrent pas en combat."

-- Slash commands and key bindings (the command words stay as typed)
L["%d test requests joined the summon queue (\"1234\" didn't match)."] =
    "%d demandes de test ont rejoint la file d'invocation (« 1234 » ne correspondait pas)."
L["%d waiting. /123 queue test | clear"] = "%d en attente. /123 queue test | clear"
L["demon voices on."] = "voix des démons activées."
L["demon voices off."] = "voix des démons désactivées."
L["the demon wheel opens with the cinematic camera and hides the game UI."] =
    "la roue des démons s'ouvre avec la caméra cinématique et masque l'interface du jeu."
L["the demon wheel opens over the game, no camera."] = "la roue des démons s'ouvre par-dessus le jeu, sans caméra."
L["will ask before re-summoning the demon that is out."] = "demandera avant de réinvoquer le démon présent."
L["won't ask before re-summoning the demon that is out."] = "ne demandera pas avant de réinvoquer le démon présent."
L["/123 | options | queue (test, clear) | hs (test, clear) | wheel | preview (every demon, nothing cast) | camera (cinematic opening) | sounds (demon voices) | labels (names under the icons) | confirm (ask before re-summoning) | debug"] =
    "/123 | options | queue (test, clear) | hs (test, clear) | wheel | preview (tous les démons, aucun sort) | camera (ouverture cinématique) | sounds (voix des démons) | labels (noms sous les icônes) | confirm (demander avant de réinvoquer) | debug"
L["Show or hide the 123 bar"] = "Afficher ou masquer la barre 123"
L["Open or close the demon wheel"] = "Ouvrir ou fermer la roue des démons"
L["Summon the last demon"] = "Invoquer le dernier démon"
L["Demonic Sacrifice, or summon the last demon"] = "Sacrifice démoniaque, ou invoquer le dernier démon"
L["Ritual of Summoning"] = "Rituel d'invocation"
