// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors
//
// HTML sourced from Stitch designs (termeni_de_utilizare_updated / politica_de_confidentialitate).
// Green/teal color values replaced with brand blue #5BA4CF.

/// Raw HTML strings for the two legal documents.
/// Rendered via WebView in [LegalDocumentModal].
class LegalContent {
  LegalContent._();

  // ── Terms of Use ────────────────────────────────────────────────────────────

  static const String termsHtml = r'''<!DOCTYPE html>

<html lang="ro"><head>
<meta charset="utf-8"/>
<meta content="width=device-width, initial-scale=1.0" name="viewport"/>
<link href="https://fonts.googleapis.com/css2?family=Lexend:wght@400;700;800&amp;display=swap" rel="stylesheet"/>
<link href="https://fonts.googleapis.com/css2?family=Material+Symbols+Outlined:wght,FILL@100..700,0..1&amp;display=swap" rel="stylesheet"/>
<link href="https://fonts.googleapis.com/css2?family=Material+Symbols+Outlined:wght,FILL@100..700,0..1&amp;display=swap" rel="stylesheet"/>
<script src="https://cdn.tailwindcss.com?plugins=forms,container-queries"></script>
<script id="tailwind-config">
      tailwind.config = {
        darkMode: "class",
        theme: {
          extend: {
            "colors": {
                    "on-tertiary-fixed": "#410003",
                    "inverse-on-surface": "#f1f1f1",
                    "surface-container-high": "#e8e8e8",
                    "outline": "#707a6c",
                    "tertiary-fixed-dim": "#ffb4ac",
                    "on-surface": "#1a1c1c",
                    "on-primary-fixed": "#002d5f",
                    "inverse-surface": "#2f3131",
                    "tertiary-fixed": "#ffdad6",
                    "on-tertiary": "#ffffff",
                    "on-tertiary-container": "#ffeeeb",
                    "tertiary-container": "#cf2f2d",
                    "secondary": "#5e5e5e",
                    "on-secondary": "#ffffff",
                    "tertiary": "#ab1118",
                    "surface-container-highest": "#e2e2e2",
                    "outline-variant": "#bfcaba",
                    "surface-variant": "#e2e2e2",
                    "surface-tint": "#5BA4CF",
                    "surface-dim": "#dadada",
                    "inverse-primary": "#5BA4CF",
                    "error": "#ba1a1a",
                    "surface": "#f9f9f9",
                    "on-surface-variant": "#40493d",
                    "on-primary": "#ffffff",
                    "on-primary-container": "#d6eeff",
                    "primary-container": "#3a7ea8",
                    "secondary-fixed": "#e2e2e2",
                    "secondary-container": "#e2e2e2",
                    "on-secondary-fixed": "#1b1b1b",
                    "on-tertiary-fixed-variant": "#93000e",
                    "on-secondary-fixed-variant": "#474747",
                    "error-container": "#ffdad6",
                    "on-secondary-container": "#646464",
                    "on-primary-fixed-variant": "#2d6fa0",
                    "surface-container": "#eeeeee",
                    "primary-fixed-dim": "#5BA4CF",
                    "surface-container-low": "#f3f3f3",
                    "surface-bright": "#f9f9f9",
                    "on-error": "#ffffff",
                    "on-error-container": "#93000a",
                    "secondary-fixed-dim": "#c6c6c6",
                    "background": "#f9f9f9",
                    "primary-fixed": "#5BA4CF",
                    "primary": "#5BA4CF",
                    "on-background": "#1a1c1c",
                    "surface-container-lowest": "#ffffff"
            },
            "borderRadius": {
                    "DEFAULT": "0.25rem",
                    "lg": "0.5rem",
                    "xl": "0.75rem",
                    "full": "9999px"
            },
            "fontFamily": {
                    "headline": ["Lexend"],
                    "body": ["Lexend"],
                    "label": ["Lexend"]
            }
          },
        },
      }
    </script>
<style>
        body { font-family: 'Lexend', sans-serif; }
        .material-symbols-outlined {
            font-variation-settings: 'FILL' 0, 'wght' 400, 'GRAD' 0, 'opsz' 24;
            display: inline-block;
            vertical-align: middle;
        }
    </style>
<style>
    body {
      min-height: max(884px, 100dvh);
    }
  </style>
</head>
<body class="bg-[#f9f9f9] text-[#1a1c1c] selection:bg-primary-fixed selection:text-on-primary-fixed">
<!-- TopAppBar -->
<header class="fixed top-0 left-0 w-full z-50 bg-[#f9f9f9] dark:bg-[#1a1c1c] flex items-center w-full px-6 py-4 justify-center">
<div class="flex items-center justify-center w-full">
<h1 class="font-['Lexend'] text-[22sp] font-bold text-[#1a1c1c] dark:text-[#f9f9f9]">Termeni de Utilizare</h1>
</div>
</header>
<!-- Main Content Canvas -->
<main class="pt-24 pb-32 px-6 max-w-3xl mx-auto min-h-screen">
<!-- Hero Section Style Content -->
<div class="mb-12">
<div class="bg-surface-container-low rounded-xl p-8 mb-10">
<h2 class="text-3xl font-extrabold mb-4 tracking-tight">Respectul față de datele dumneavoastră</h2>
<p class="text-[18sp] leading-relaxed text-on-surface-variant opacity-90">
                    Acest document definește regulile de utilizare ale serviciului nostru, conceput special pentru a oferi o experiență sigură și demnă.
                </p>
</div>
<!-- Content Body -->
<section class="space-y-10">
<article>
<h3 class="text-xl font-bold mb-4 text-primary">1. Acceptarea Termenilor</h3>
<p class="text-[18sp] leading-relaxed text-on-surface">
                        Prin accesarea și utilizarea acestei aplicații, confirmați că ați citit, înțeles și sunteți de acord cu acești termeni. Serviciul nostru este dedicat exclusiv utilizării personale, oferind suport pentru sănătate și monitorizare zilnică, respectând cele mai înalte standarde de etică digitală.
                    </p>
</article>
<article>
<h3 class="text-xl font-bold mb-4 text-primary">2. Confidențialitatea Datelor</h3>
<p class="text-[18sp] leading-relaxed text-on-surface">
                        Protecția informațiilor dumneavoastră este prioritatea noastră absolută. Nu vindem și nu partajăm datele dumneavoastră medicale sau personale cu terțe părți în scopuri publicitare. Toate datele sunt stocate criptat și sunt folosite exclusiv pentru a vă oferi asistența necesară.
                    </p>
</article>
<!-- Visual Break - Tonal Layering (No Borders) -->
<div class="h-48 w-full bg-surface-container-high rounded-xl overflow-hidden flex items-center justify-center">
<img class="w-full h-full object-cover mix-blend-overlay opacity-60" data-alt="abstract close-up of a secure shield symbol carved in smooth light grey stone with soft blue ambient lighting" src="https://lh3.googleusercontent.com/aida-public/AB6AXuB-9y6YCM22JN-YwUwDMLNATu6id4QAGvqL7FhiG4R1zh3kmckBU0cu9fNCebxgCiZBgxqClPsixtWlDRG-lVOf6M4_OuZr_4I-vjeREHjplXIA2EEjBjAewAcuGcbOkIeJECEBgJkmkLgQl-mEUvchxbjaQBjSuYCXQA6Gy6283xHUJ7Gjgzfaxt8Go-_Yyqg_A6P8OLrN9BOg3TDpB9_E3NlUxoekR00SpPh4I-FDjT42w-nBg2aMHxAfJI2gAoWdnvCcrLQ26UA"/>
</div>
<article>
<h3 class="text-xl font-bold mb-4 text-primary">3. Responsabilitatea Utilizatorului</h3>
<p class="text-[18sp] leading-relaxed text-on-surface">
                        Sunteți responsabil pentru menținerea confidențialității contului dumneavoastră. Vă rugăm să ne notificați imediat în cazul oricărei utilizări neautorizate. Aplicația nu înlocuiește sfatul medical profesionist, ci servește ca un instrument auxiliar de monitorizare a stării de bine.
                    </p>
</article>
<article>
<h3 class="text-xl font-bold mb-4 text-primary">4. Modificări ale Serviciului</h3>
<p class="text-[18sp] leading-relaxed text-on-surface">
                        Ne rezervăm dreptul de a actualiza acești termeni pentru a reflecta schimbările în legislație sau îmbunătățirile aduse tehnologiei noastre. Orice modificare majoră va fi comunicată clar printr-o notificare în cadrul aplicației, oferindu-vă timpul necesar pentru a revizui noile condiții.
                    </p>
</article>
<article>
<h3 class="text-xl font-bold mb-4 text-primary">5. Limitarea Răspunderii</h3>
<p class="text-[18sp] leading-relaxed text-on-surface">
                        În limita permisă de lege, echipa noastră nu va fi responsabilă pentru daune indirecte sau accidentale care rezultă din utilizarea serviciului. Ne angajăm să oferim un serviciu stabil, însă nu putem garanta disponibilitatea neîntreruptă în perioadele de mentenanță critică.
                    </p>
</article>
</section>
</div>
</main>
<!-- Bottom Action Shell (Persistent UI) -->
<nav class="fixed bottom-0 left-0 w-full z-50 flex justify-center items-center px-6 pb-6 bg-white/85 dark:bg-[#1a1c1c]/85 backdrop-blur-md shadow-[0_-4px_32px_rgba(26,28,28,0.06)]">
<button class="flex flex-row items-center justify-center bg-[#5BA4CF] text-white rounded-lg h-16 w-full mx-6 mb-6 font-['Lexend'] text-[20sp] font-bold border-2 border-black active:scale-[0.98] transition-all duration-200">
<span class="material-symbols-outlined mr-3 text-[32px]">chevron_left</span>
            Înapoi
        </button>
</nav>
</body></html>''';

  // ── Privacy Policy ──────────────────────────────────────────────────────────

  static const String privacyHtml = r'''<!DOCTYPE html>

<html class="light" lang="ro"><head>
<meta charset="utf-8"/>
<meta content="width=device-width, initial-scale=1.0" name="viewport"/>
<link href="https://fonts.googleapis.com/css2?family=Lexend:wght@300;400;600;700;800&amp;display=swap" rel="stylesheet"/>
<link href="https://fonts.googleapis.com/css2?family=Material+Symbols+Outlined:wght,FILL@100..700,0..1&amp;display=swap" rel="stylesheet"/>
<link href="https://fonts.googleapis.com/css2?family=Material+Symbols+Outlined:wght,FILL@100..700,0..1&amp;display=swap" rel="stylesheet"/>
<script src="https://cdn.tailwindcss.com?plugins=forms,container-queries"></script>
<script id="tailwind-config">
        tailwind.config = {
            darkMode: "class",
            theme: {
                extend: {
                    "colors": {
                        "on-primary-fixed": "#002d5f",
                        "surface-container-lowest": "#ffffff",
                        "tertiary-fixed-dim": "#ffb4ac",
                        "on-background": "#1a1c1c",
                        "on-primary": "#ffffff",
                        "outline-variant": "#bfcaba",
                        "on-error-container": "#93000a",
                        "inverse-surface": "#2f3131",
                        "on-secondary-container": "#646464",
                        "surface-dim": "#dadada",
                        "on-tertiary-container": "#ffeeeb",
                        "surface-bright": "#f9f9f9",
                        "tertiary-fixed": "#ffdad6",
                        "inverse-primary": "#5BA4CF",
                        "on-primary-fixed-variant": "#2d6fa0",
                        "on-primary-container": "#d6eeff",
                        "error-container": "#ffdad6",
                        "surface-variant": "#e2e2e2",
                        "inverse-on-surface": "#f1f1f1",
                        "surface": "#f9f9f9",
                        "primary-fixed-dim": "#5BA4CF",
                        "surface-tint": "#5BA4CF",
                        "surface-container-high": "#e8e8e8",
                        "on-tertiary-fixed": "#410003",
                        "on-surface-variant": "#40493d",
                        "tertiary-container": "#cf2f2d",
                        "error": "#ba1a1a",
                        "on-error": "#ffffff",
                        "primary-container": "#3a7ea8",
                        "background": "#f9f9f9",
                        "on-tertiary": "#ffffff",
                        "on-secondary-fixed": "#1b1b1b",
                        "surface-container-highest": "#e2e2e2",
                        "on-secondary-fixed-variant": "#474747",
                        "on-surface": "#1a1c1c",
                        "surface-container": "#eeeeee",
                        "secondary-container": "#e2e2e2",
                        "primary": "#5BA4CF"
                    },
                    "borderRadius": {
                        "DEFAULT": "0.25rem",
                        "lg": "0.5rem",
                        "xl": "0.75rem",
                        "full": "9999px"
                    },
                    "fontFamily": {
                        "headline": ["Lexend"],
                        "body": ["Lexend"],
                        "label": ["Lexend"]
                    }
                },
            },
        }
    </script>
<style>
        body {
            font-family: 'Lexend', sans-serif;
            background-color: #f9f9f9;
            color: #1a1c1c;
            -webkit-font-smoothing: antialiased;
        }
        .policy-container {
            max-width: 800px;
            margin: 0 auto;
        }
        .material-symbols-outlined {
            font-variation-settings: 'FILL' 0, 'wght' 400, 'GRAD' 0, 'opsz' 24;
        }
    </style>
<style>
    body {
      min-height: max(884px, 100dvh);
    }
  </style>
  </head>
<body class="bg-surface text-on-surface">
<header class="w-full top-0 sticky bg-[#f9f9f9] dark:bg-slate-900 flex items-center justify-center h-20 px-6 w-full z-40">
<h1 class="text-[#5BA4CF] font-lexend font-bold text-[22px] leading-tight text-center">
            Politica de Confidențialitate
        </h1>
</header>
<main class="policy-container px-6 pt-8 pb-40">
<div class="space-y-12">
<section class="space-y-6">
<h2 class="text-[28px] font-bold text-on-surface leading-tight">1. Angajamentul Nostru</h2>
<p class="text-[18px] leading-relaxed text-on-surface">
                    Protecția datelor dumneavoastră medicale este prioritatea noastră absolută. Înțelegem responsabilitatea pe care o avem în gestionarea informațiilor sensibile legate de sănătatea dumneavoastră și ne angajăm să respectăm cele mai înalte standarde de securitate și confidențialitate, conform Regulamentului General privind Protecția Datelor (GDPR).
                </p>
</section>
<section class="bg-surface-container-low p-8 rounded-xl space-y-6">
<h2 class="text-[28px] font-bold text-on-surface leading-tight">2. Ce date colectăm?</h2>
<p class="text-[18px] leading-relaxed text-on-surface">
                    Pentru a vă oferi cea mai bună îngrijire și asistență, colectăm următoarele categorii de date:
                </p>
<ul class="space-y-4 list-none">
<li class="flex gap-4 items-start">
<span class="text-primary font-bold text-[24px]">•</span>
<span class="text-[18px]">Informații de identificare: Nume, prenume și data nașterii.</span>
</li>
<li class="flex gap-4 items-start">
<span class="text-primary font-bold text-[24px]">•</span>
<span class="text-[18px]">Date de contact: Număr de telefon și adresa de domiciliu.</span>
</li>
<li class="flex gap-4 items-start">
<span class="text-primary font-bold text-[24px]">•</span>
<span class="text-[18px]">Informații medicale: Istoric medical, tratamente curente și observații ale medicului.</span>
</li>
</ul>
</section>
<section class="space-y-6">
<h2 class="text-[28px] font-bold text-on-surface leading-tight">3. Scopul Prelucrării</h2>
<p class="text-[18px] leading-relaxed text-on-surface">
                    Datele dumneavoastră sunt utilizate exclusiv pentru:
                </p>
<div class="grid grid-cols-1 md:grid-cols-2 gap-4">
<div class="bg-surface-container-high p-6 rounded-lg">
<h3 class="font-bold mb-2">Monitorizare Sănătate</h3>
<p class="text-[18px]">Urmărirea parametrilor vitali și a evoluției stării de bine.</p>
</div>
<div class="bg-surface-container-high p-6 rounded-lg">
<h3 class="font-bold mb-2">Comunicare Medic</h3>
<p class="text-[18px]">Facilitarea legăturii directe cu personalul medical autorizat.</p>
</div>
</div>
</section>
<section class="space-y-6">
<h2 class="text-[28px] font-bold text-on-surface leading-tight">4. Drepturile Dumneavoastră</h2>
<p class="text-[18px] leading-relaxed text-on-surface">
                    În calitate de utilizator, aveți drepturi depline asupra informațiilor dumneavoastră:
                </p>
<div class="space-y-4">
<div class="border-l-4 border-primary pl-6 py-2">
<h4 class="font-bold">Dreptul de acces</h4>
<p class="text-[18px]">Puteți solicita oricând o copie a datelor pe care le deținem.</p>
</div>
<div class="border-l-4 border-primary pl-6 py-2">
<h4 class="font-bold">Dreptul la rectificare</h4>
<p class="text-[18px]">Puteți corecta orice informație eronată din profilul dumneavoastră.</p>
</div>
<div class="border-l-4 border-primary pl-6 py-2">
<h4 class="font-bold">Dreptul de a fi uitat</h4>
<p class="text-[18px]">Puteți solicita ștergerea definitivă a contului și a datelor asociate.</p>
</div>
</div>
</section>
<section class="space-y-6">
<h2 class="text-[28px] font-bold text-on-surface leading-tight">5. Securitatea Datelor</h2>
<p class="text-[18px] leading-relaxed text-on-surface">
                    Utilizăm tehnologii de criptare de ultimă generație pentru a ne asigura că nimeni în afară de dumneavoastră și medicul dumneavoastră nu are acces la aceste informații. Serverele noastre sunt securizate și monitorizate 24 de ore din 24.
                </p>
</section>
<section class="space-y-6 pb-20">
<h2 class="text-[28px] font-bold text-on-surface leading-tight">6. Contact</h2>
<p class="text-[18px] leading-relaxed text-on-surface">
                    Pentru orice întrebări legate de confidențialitatea datelor dumneavoastră, ne puteți contacta la adresa de email: <span class="font-bold text-primary">protectie.date@digital-concierge.ro</span> sau la numărul de telefon afișat în secțiunea de asistență.
                </p>
</section>
</div>
</main>
<footer class="fixed bottom-0 left-0 w-full flex justify-center p-6 bg-[#ffffff]/85 backdrop-blur-md dark:bg-slate-900/85 shadow-[0_-4px_32px_rgba(26,28,28,0.06)] z-50">
<button class="bg-[#5BA4CF] text-white w-[280px] h-16 rounded-lg border-2 border-black flex items-center justify-center gap-3 hover:brightness-110 active:scale-95 transition-all">
<span class="material-symbols-outlined text-[32px]" data-icon="arrow_back">arrow_back</span>
<span class="font-lexend font-bold text-[18px]">Înapoi</span>
</button>
</footer>
</body></html>''';
}
