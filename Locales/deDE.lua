local _, ns = ...
if ns.skip then return end
if ns.locale ~= "deDE" then return end

-- German (#22). Game terms follow the German client (Seelenstein,
-- Verdammniswache); spell, item and demon names come from the client itself.
local L = ns.L

-- Bar
L["Demon"] = "Dämon"
L["Demons"] = "Dämonen"
L["Armor"] = "Rüstung"
L["Soulstone"] = "Seelenstein"
L["Healthstone"] = "Gesundheitsstein"
L["Summoning"] = "Beschwörung"
L["Use %s"] = "Benutzen: %s"
L["item %d"] = "Gegenstand %d"
L["spell %d"] = "Zauber %d"
L["Needs %s"] = "Benötigt: %s"
L["a reagent"] = "eine Reagenz"
L["Not on you"] = "Nicht aktiv"
L["Click: %s"] = "Klick: %s"
L["(already out: asks first)"] = "(schon da: fragt zuerst)"
L["Right-click: %s"] = "Rechtsklick: %s"
L["%d waiting for a summon"] = "%d warten auf eine Beschwörung"
L["Nothing learned for this yet"] = "Dafür noch nichts erlernt"
L["The demon wheel can't open in combat"] = "Das Dämonenrad öffnet sich nicht im Kampf"
L["Click: the demon wheel"] = "Klick: das Dämonenrad"
L["Shift-drag: move the bar"] = "Umschalt-Ziehen: Leiste verschieben"
L["the bar can't be shown or hidden in combat."] = "die Leiste kann im Kampf nicht ein- oder ausgeblendet werden."

-- Demon wheel
L["Select a demon to summon"] = "Wähle einen Dämon zum Beschwören"
L["DEMON SUMMONING"] = "DÄMONENBESCHWÖRUNG"
L["PREVIEW"] = "VORSCHAU"
L["Doomguard"] = "Verdammniswache"
L["Demonic Sacrifice"] = "Dämonische Opferung"
L["Sacrifice"] = "Opferung"
L["Active"] = "Aktiv"
L["No demon"] = "Kein Dämon"
L["Not learned"] = "Nicht erlernt"
L["No %s"] = "Fehlt: %s"
L["reagent"] = "Reagenz"
L["Preview: click a demon to put it in the centre"] = "Vorschau: Klicke einen Dämon, um ihn in die Mitte zu setzen"
L["Preview: put the %s in the centre"] = "Vorschau: %s in die Mitte setzen"
L["%s: not learned yet"] = "%s: noch nicht erlernt"
L["%s again (already out)"] = "%s erneut (schon da)"
L["%s: needs %s"] = "%s: benötigt %s"
L["Shift: %s first"] = "Umschalt: zuerst %s"
L["Preview: nothing is cast"] = "Vorschau: es wird nichts gewirkt"
L["preview can't change in combat."] = "die Vorschau kann sich im Kampf nicht ändern."
L["preview on: every demon is shown, nothing is cast. Click a demon to put it in the centre; /123 preview again to stop."] =
    "Vorschau an: alle Dämonen werden gezeigt, nichts wird gewirkt. Klicke einen Dämon, um ihn in die Mitte zu setzen; erneut /123 preview zum Beenden."
L["preview off."] = "Vorschau aus."
L["the demon wheel can't open in combat."] = "das Dämonenrad öffnet sich nicht im Kampf."
L["the demon wheel closes when combat ends."] = "das Dämonenrad schließt sich, wenn der Kampf endet."

-- Re-summon prompt
L["Summon"] = "Beschwören"
L["Cancel"] = "Abbrechen"
L["Don't ask again"] = "Nicht mehr fragen"
L["that demon"] = "diesen Dämon"
L["You already have your %s summoned. Summon it again?"] = "%s ist bereits beschworen. Erneut beschwören?"
L["won't ask again before re-summoning (/123 confirm to ask again)."] =
    "fragt nicht mehr vor dem erneuten Beschwören (/123 confirm, um wieder zu fragen)."

-- Summon queue
L["%ds"] = "%ds"
L["%dm"] = "%dmin"
L["Summons (%d)"] = "Beschwörungen (%d)"
L["and %d more"] = "und %d weitere"

-- Summon execution and announcements (#10, #11)
L["Click: %s on %s"] = "Klick: %s auf %s"
L["next"] = "nächste"
L["summoning"] = "Beschwörung"
L["pending"] = "angefragt"
L["accepted"] = "angenommen"
L["declined"] = "abgelehnt"
L["here"] = "hier"
L["Summoning {name}, please click the portal"] = "Beschwöre {name}, bitte das Portal anklicken"
L["Need 2 clickers for the summon"] = "Brauche 2 Klicker für die Beschwörung"
L["Summon announcements"] = "Beschwörungsansagen"
L["Announce the summon in group chat"] = "Beschwörung im Gruppenchat ansagen"
L["Ask for clickers when fewer than 2 are near"] = "Nach Klickern fragen, wenn weniger als 2 in der Nähe sind"
L["{name} is who you summon. Sent to instance, raid or party chat when the ritual starts, at most every 10 seconds."] =
    "{name} ist, wen du beschwörst. Geht an den Instanz-, Schlachtzugs- oder Gruppenchat, wenn das Ritual beginnt, höchstens alle 10 Sekunden."

-- Soulstone target (#5)
L["Soulstone target"] = "Seelenstein-Ziel"
L["Clear"] = "Entfernen"
L["Right-click: choose who gets it"] = "Rechtsklick: wählen, wer ihn bekommt"
L["%s: in combat, on your target"] = "%s: im Kampf auf dein Ziel"
L["%s left the group: no soulstone target."] = "%s hat die Gruppe verlassen: kein Seelenstein-Ziel mehr."

-- Healthstone requests (#8)
L["%s asks for a healthstone."] = "%s bittet um einen Gesundheitsstein."
L["Open trade"] = "Handel öffnen"
L["Place the healthstone"] = "Gesundheitsstein hineinlegen"
L["Skip"] = "Überspringen"
L["Put your best healthstone in the trade."] = "Lege deinen besten Gesundheitsstein in den Handel."
L["Accept the trade to give it."] = "Nimm den Handel an, um ihn zu geben."
L["No healthstone: create one first (the Healthstone button)."] = "Kein Gesundheitsstein: erst einen herstellen (Gesundheitsstein-Knopf)."
L["Not in your group: target them first."] = "Nicht in deiner Gruppe: zuerst ins Ziel nehmen."
L["A test request: nothing to trade."] = "Eine Testanfrage: nichts zu handeln."
L["No healthstone, or no free trade slot."] = "Kein Gesundheitsstein oder kein freier Handelsplatz."
L["%d healthstone requests. /123 hs test | clear"] = "%d Gesundheitsstein-Anfragen. /123 hs test | clear"
L["Healthstone requests"] = "Gesundheitsstein-Anfragen"
L["Prompt when someone asks for a healthstone"] = "Handel anbieten, wenn jemand um einen Gesundheitsstein bittet"
L["Also whispers from outside the group"] = "Auch Flüstern von außerhalb der Gruppe"
L["Whole message, in group chat or a whisper. You open the trade and place the stone; you accept. /123 hs test shows the prompt."] =
    "Die ganze Nachricht, im Gruppenchat oder geflüstert. Du öffnest den Handel und legst den Stein hinein; du nimmst an. /123 hs test zeigt das Fenster."

-- Minimap
L["Shift-click: show or hide the bar"] = "Umschalt-Klick: Leiste ein- oder ausblenden"
L["Right-click: options"] = "Rechtsklick: Optionen"

-- Sounds
L["Whisper"] = "Flüstern"
L["Group invite"] = "Gruppeneinladung"
L["Ready check"] = "Bereitschaftscheck"
L["Raid warning"] = "Schlachtzugswarnung"
L["None"] = "Keiner"
L["Summon request"] = "Beschwörungsanfrage"
L["Healthstone request"] = "Gesundheitsstein-Anfrage"

-- Options
L["123 — Warlock Summons, Demons & Stones"] = "123 — Hexenmeister: Beschwörungen, Dämonen & Steine"
L["/123 shows or hides the bar, /123 wheel opens the demon wheel, /123 options opens this page."] =
    "/123 blendet die Leiste ein oder aus, /123 wheel öffnet das Dämonenrad, /123 options öffnet diese Seite."
L["Key bindings: Options > Keybindings > AddOns > 123."] = "Tastenbelegung: Optionen > Tastaturbelegung > AddOns > 123."
L["Bar"] = "Leiste"
L["Show the bar"] = "Leiste anzeigen"
L["Names under the icons"] = "Namen unter den Symbolen"
L["Bar scale"] = "Leistengröße"
L["Reset position"] = "Position zurücksetzen"
L["Shift-drag the 123 handle to move the bar."] = "Umschalt-Ziehen am 123-Griff verschiebt die Leiste."
L["Demon wheel"] = "Dämonenrad"
L["Ask before re-summoning the demon that is out"] = "Vor dem erneuten Beschwören des aktiven Dämons fragen"
L["Cinematic camera"] = "Kinokamera"
L["Slow camera orbit"] = "Langsame Kamerafahrt"
L["Hide the game UI while the wheel is open"] = "Spieloberfläche ausblenden, solange das Rad offen ist"
L["Preview the wheel"] = "Rad-Vorschau"
L["Sound"] = "Ton"
L["Demon voices on the wheel"] = "Dämonenstimmen am Rad"
L["Alert sounds"] = "Warntöne"
L["the game didn't play that sound; pick another."] = "das Spiel hat diesen Ton nicht abgespielt; wähle einen anderen."
L["Picking a sound plays it. Requests arrive with the summon queue and healthstone requests."] =
    "Die Auswahl spielt den Ton ab. Anfragen kommen mit der Beschwörungsliste und den Gesundheitsstein-Anfragen."
L["Summon queue"] = "Beschwörungsliste"
L["Queue group members who type a keyword"] = "Gruppenmitglieder einreihen, die ein Stichwort schreiben"
L["Keywords"] = "Stichwörter"
L["Minutes before a request drops"] = "Minuten, bis eine Anfrage verfällt"
L["The whole message must be a keyword: \"123\" asks, \"1234\" or \"123 dps\" don't. /123 queue test tries it alone."] =
    "Die ganze Nachricht muss ein Stichwort sein: „123“ fragt an, „1234“ oder „123 dps“ nicht. /123 queue test probiert es allein aus."
L["Minimap"] = "Minikarte"
L["Minimap button"] = "Minikartenknopf"
L["Addon compartment entry (after /reload)"] = "Eintrag im AddOn-Fach (nach /reload)"
L["the bar can't change in combat."] = "die Leiste kann sich im Kampf nicht ändern."
L["options can't open in combat."] = "die Optionen öffnen sich nicht im Kampf."

-- Slash commands and key bindings (the command words stay as typed)
L["%d test requests joined the summon queue (\"1234\" didn't match)."] =
    "%d Testanfragen sind der Beschwörungsliste beigetreten („1234“ passte nicht)."
L["%d waiting. /123 queue test | clear"] = "%d warten. /123 queue test | clear"
L["demon voices on."] = "Dämonenstimmen an."
L["demon voices off."] = "Dämonenstimmen aus."
L["the demon wheel opens with the cinematic camera and hides the game UI."] =
    "das Dämonenrad öffnet sich mit der Kinokamera und blendet die Spieloberfläche aus."
L["the demon wheel opens over the game, no camera."] = "das Dämonenrad öffnet sich über dem Spiel, ohne Kamera."
L["will ask before re-summoning the demon that is out."] = "fragt vor dem erneuten Beschwören des aktiven Dämons."
L["won't ask before re-summoning the demon that is out."] = "fragt nicht vor dem erneuten Beschwören des aktiven Dämons."
L["/123 | options | queue (test, clear) | hs (test, clear) | wheel | preview (every demon, nothing cast) | camera (cinematic opening) | sounds (demon voices) | labels (names under the icons) | confirm (ask before re-summoning) | debug"] =
    "/123 | options | queue (test, clear) | hs (test, clear) | wheel | preview (alle Dämonen, nichts gewirkt) | camera (Kino-Öffnung) | sounds (Dämonenstimmen) | labels (Namen unter den Symbolen) | confirm (vor erneutem Beschwören fragen) | debug"
L["Show or hide the 123 bar"] = "123-Leiste ein- oder ausblenden"
L["Open or close the demon wheel"] = "Dämonenrad öffnen oder schließen"
L["Summon the last demon"] = "Den letzten Dämon beschwören"
L["Demonic Sacrifice, or summon the last demon"] = "Dämonische Opferung oder den letzten Dämon beschwören"
L["Ritual of Summoning"] = "Ritual der Beschwörung"
