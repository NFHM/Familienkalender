# Familienkalender – eigene App mit GitHub Pages und Supabase

Die App ist eine einzelne Webseite. Sie läuft im Browser und lässt sich auf dem Handy wie eine App auf den Startbildschirm legen. Termine liegen in deiner eigenen Supabase-Datenbank. Niemand braucht ein Claude-Konto.

## Was in diesem Ordner liegt

| Datei | Wofür |
|---|---|
| `index.html` | Die App. Supabase-Adresse und Schlüssel sind schon eingetragen. |
| `manifest.webmanifest`, `sw.js`, `icon*.png`, `icon.svg` | Damit man die App auf dem Handy installieren kann. |
| `supabase/schema.sql` | Datenbankstruktur mit Zugriffsregeln (ist schon eingespielt, nur zur Sicherheit dabei). |
| `src/`, `build.py` | Quelltext, falls die App später geändert wird. Für den Betrieb nicht nötig. |

## 1. Auf GitHub veröffentlichen (ca. 5 Minuten)

1. Auf github.com anmelden → oben rechts **+** → **New repository**.
2. Name z. B. `familienkalender`, Sichtbarkeit **Public** (GitHub Pages ist im kostenlosen Plan nur für öffentliche Repos verfügbar). Der Code enthält keine Geheimnisse: Der Publishable Key ist dafür gemacht, im Browser zu stehen, und die Termine sind durch die Zugriffsregeln geschützt.
3. **Create repository** → auf der leeren Seite **uploading an existing file** anklicken.
4. Die ZIP-Datei entpacken, den Ordner `familienkalender-app` öffnen und **dessen Inhalt** (nicht den Ordner selbst) ins Browserfenster ziehen. `index.html` muss danach direkt auf der obersten Ebene des Repos liegen. → **Commit changes**.
5. Im Repo **Settings** → **Pages** → bei *Branch* `main` und `/ (root)` wählen → **Save**.
6. Nach 1–2 Minuten steht oben die Adresse, z. B. `https://DEINNAME.github.io/familienkalender/`.

## 2. Supabase auf die Adresse einstellen

Im Supabase-Dashboard das Projekt **Familienkalender** (Organisation „Privat“) öffnen:

1. **Authentication → URL Configuration** (https://supabase.com/dashboard/project/iemcjjpmkwtrdztgzcsn/auth/url-configuration): Bei **Site URL** die GitHub-Pages-Adresse eintragen und speichern. Dieselbe Adresse unter **Redirect URLs** hinzufügen.
2. **Authentication → Sign In / Providers → Email** (https://supabase.com/dashboard/project/iemcjjpmkwtrdztgzcsn/auth/providers): Den Schalter **Confirm email** ausschalten und speichern.

Warum Schritt 2? Supabase verschickt ohne eigenen E-Mail-Dienst nur Mails an Mitglieder deines Supabase-Teams. Familienmitglieder könnten ihre Bestätigungsmail also nicht bekommen. Mit ausgeschalteter Bestätigung legen sie einfach E-Mail und Passwort fest und sind sofort drin. In den Kalender kommt trotzdem nur, wer euren Einladungslink hat.

## 3. Loslegen

1. Die Adresse öffnen → **Konto anlegen** → einen Namen für den Kalender vergeben.
2. Bei „Wer bist du?“ deinen Namen eintragen.
3. Unten bei **Familie → Verwalten** → **Link teilen** oder **Link kopieren** → per WhatsApp an die Familie schicken.
4. Wer den Link öffnet, legt ein Konto an und ist sofort im Kalender. Kinder ohne eigenes Handy legst du unter „Person hinzufügen“ an.

**Aufs Handy legen:** iPhone: Seite in Safari öffnen → Teilen → *Zum Home-Bildschirm*. Android: Chrome → Menü ⋮ → *App installieren*.

## Gut zu wissen

- **Passwort vergessen** funktioniert erst, wenn ein E-Mail-Dienst eingerichtet ist (siehe unten). Bis dahin kannst du im Supabase-Dashboard unter *Authentication → Users* ein Konto löschen, dann legt die Person es neu an.
- **Admin:** Wer den Kalender angelegt hat, ist Admin. Nur der Admin lädt ein, fügt Personen hinzu, entfernt sie und benennt den Kalender um. Alle können Termine eintragen und ändern.
- **Einladungslink zurückziehen:** Unter „Familie → Verwalten“ auf *Neuen Code erzeugen*. Der alte Link funktioniert danach nicht mehr.
- **Kosten:** Der kostenlose Supabase-Plan reicht für eine Familie. Projekte im Free-Plan werden nach 7 Tagen ohne jede Nutzung pausiert. Bei regelmäßiger Nutzung passiert das nicht, und ein pausiertes Projekt lässt sich im Dashboard mit einem Klick wieder starten.

## Optional: E-Mails verschicken (Passwort zurücksetzen, Bestätigung)

1. Kostenloses Konto bei einem Maildienst anlegen, z. B. Brevo (300 Mails/Tag gratis) oder Resend.
2. Dort die SMTP-Zugangsdaten abrufen.
3. In Supabase **Authentication → Emails → SMTP Settings** eintragen.
4. Danach kann **Confirm email** wieder eingeschaltet werden.

## Datenmodell (für später)

- `families`: Kalender mit Name und Einladungscode
- `family_members`: wer zu welchem Kalender gehört (Rolle `owner` oder `member`)
- `people`: Personen im Kalender mit Farbe, optional mit Konto verknüpft
- `events`: Termine mit Datum, Uhrzeit, Personen, Wiederholung, Ort, Notiz

Alle Tabellen sind per Row Level Security geschützt: Man sieht und ändert nur Daten der Kalender, in denen man Mitglied ist. Beitreten geht nur über den Einladungscode.
