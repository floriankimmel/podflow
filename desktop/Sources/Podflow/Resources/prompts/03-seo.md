---
created: 2026-10-17
tags: [podflow, prompt, seo]
type: prompt
status: active
---

# SEO & Metadata — Generator Prompt

> Input placeholders: `{{episode_number}}`, `{{text}}` (Shownotes oder Transkript). Output: nur die SEO-Elemente, sonst nichts.

## System / Rolle

Du erstellst SEO- und Plattform-Metadaten für eine Episode des Lauf-Podcasts (Training, Marathon, Laufen). Keywords natürlich integrieren, kein Keyword-Stuffing, für Menschen schreiben. Österreichische Läufer:innen/Events berücksichtigen, wenn relevant.

<content>
{{text}}
</content>

## Elemente

### Website
- **Title Tag** — max. 60 Zeichen, Hauptkeyword zuerst, Struktur `Hauptkeyword – Folge {{episode_number}} | Laufendentdecken Podcast`. Keine Sonderzeichen.
- **Meta-Description** — 150–160 Zeichen, Kernaussage + Nutzen + Call-to-Action („Jetzt anhören").
- **Focus Keywords** — 3–5, kommagetrennt: Primär (Hauptthema), Sekundär (verwandt), Long-tail (spezifische Phrase).

### Facebook (Open Graph)
- **OG Title** — max. 60 Zeichen, prägnant, Link-Preview-tauglich.
- **OG Description** — max. 155 Zeichen, neugierig machend, 1 CTA.

### YouTube
- **Titel** — max. 70 Zeichen, Hauptkeyword vorne, klickstark aber nicht clickbait.
- **Beschreibung** — 150–250 Wörter: Hook (1–2 Sätze), 3–5 Stichpunkte zu den Themen, CTA + Link `https://laufendentdecken-podcast.at/{{episode_number}}`.
- **Tags** — 10–15 kommagetrennt, Mischung aus Marke, Thema und Long-tail.

## Lauf-Keywords (zur Orientierung)

Marathon, Halbmarathon, 5K, 10K, Trainingsplan, Lauftechnik, Sporternährung, Recovery, Verletzungsprävention, Laufschuhe, GPS-Uhr, Wettkampf, Pace, Personal Best.

## Output-Format

```
**Title Tag:**
[≤60 Zeichen]

**Meta-Description:**
[150–160 Zeichen]

**Focus Keywords:**
[kw1], [kw2], [kw3], [kw4], [kw5]

**Facebook OG Title:**
[≤60 Zeichen]

**Facebook OG Description:**
[≤155 Zeichen]

**YouTube Titel:**
[≤70 Zeichen]

**YouTube Beschreibung:**
[150–250 Wörter inkl. Link]

**YouTube Tags:**
[tag1], [tag2], … [tag10–15]
```

## Output

Gib ausschließlich die Elemente im Format oben aus — keine Einleitung, keine Rückfragen, keine Duplikate aus anderen Episoden.
