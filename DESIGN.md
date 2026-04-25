```markdown
# Design System Documentation: The Dignified Guardian

## 1. Overview & Creative North Star
The Creative North Star for this design system is **"Empathetic Brutalism."** 

Often, apps designed for elderly users feel patronizing—infantilized with overly rounded "toy-like" buttons and cluttered layouts. We reject this. This design system treats the user with the respect of a high-end editorial experience. We combine the unwavering clarity of **Swiss Design** with the warmth of **Soft Minimalism**. 

By utilizing massive, high-contrast typography and intentional asymmetry, we create a layout that isn't just "easy to read," but feels curated and authoritative. We replace the traditional "mobile app" feel with a "Digital Concierge" aesthetic—prioritizing breathing room and tonal depth over rigid grids and borders.

---

## 2. Colors
Our palette is rooted in strict WCAG AAA compliance, but we elevate it through sophisticated layering rather than flat fills.

### The Palette
- **Primary (`#5BA4CF`):** The "Reassuring Blue." Used for health-positive states and primary progress.
- **Tertiary (`#ab1118`):** The "Alert Red." Reserved strictly for critical warnings or ending a call.
- **Surface (`#f9f9f9`):** Our soft off-white canvas. It reduces eye strain compared to pure `#ffffff`.
- **On-Surface (`#1a1c1c`):** Our high-contrast black for maximum legibility.

### The "No-Line" Rule
**Explicit Instruction:** Designers are prohibited from using 1px solid borders to section content. Boundaries must be defined solely through background color shifts. 
- Use `surface-container-low` for secondary sections.
- Use `surface-container-high` for interactive elements.
- Visual separation is achieved by the "physicality" of color blocks, not by "drawing lines" around them.

### Signature Textures
To add "soul" to the interface, use a subtle linear gradient on primary CTAs—transitioning from `primary` (#5BA4CF) to `primary_container` (#7BC4EF). This creates a gentle convexity that suggests "pressability" without resorting to dated skeuomorphism.

---

## 3. Typography
We use **Lexend**, a typeface specifically designed to reduce visual stress and improve reading proficiency.

- **Scale & Weight:** Minimum size is **18sp**. All actionable text (buttons, links) must use **Bold** weights.
- **Display & Headline:** Used for high-level navigation and greetings (e.g., "Bună dimineața, Maria"). Use `display-md` or `headline-lg` to create a clear "anchor" on the screen.
- **Bilingual Intent:** Given the Romanian and English support, typography must account for varying word lengths (e.g., "History" vs "Istoric"). Always allow for 20% text expansion in layouts.
- **The Voice-First Weight:** When the app is "listening," the typography should transition to a larger `display-sm` scale to confirm the app has captured the user's intent visually.

---

## 4. Elevation & Depth
In this design system, depth is a functional tool for cognitive mapping, not just an aesthetic choice.

### The Layering Principle
Hierarchy is achieved by "stacking" surface-container tiers. 
- **Base Layer:** `surface` (#f9f9f9).
- **In-Page Sections:** `surface-container-low` (#f3f3f3).
- **Interactive Cards:** `surface-container-lowest` (#ffffff).
This stacking creates a soft, natural lift that guides the eye toward the interactive element without the clutter of shadows.

### Glassmorphism & The Bottom Nav
To ensure the persistent bottom navigation feels premium, apply a **Glassmorphism** effect:
- **Color:** `surface_container_lowest` at 85% opacity.
- **Effect:** `backdrop-blur` (20px).
- This allows the content to scroll "underneath" the navigation, maintaining a sense of depth and ensuring the navigation feels like a solid, permanent fixture.

### Ambient Shadows
If an element must float (like a voice-activation FAB), use a "Ghost Shadow":
- **Color:** A 6% opacity tint of `on-surface`.
- **Blur:** 32px to 48px.
- **Spread:** -4px.
This mimics natural, ambient light rather than a harsh digital drop shadow.

---

## 5. Components

### Buttons (The Core Interaction)
- **Sizing:** Minimum height **64dp**. 
- **Shape:** Use `md` (0.75rem) roundedness for a sophisticated look—avoid "pill" shapes which can look like toys.
- **Primary:** `primary` background with `on-primary` text. Bold 20sp.
- **Tactile State:** On press, the button should shift to `primary_container`.

### Cards & Lists
- **The Divider Ban:** Never use horizontal lines between list items. Use 16dp to 24dp of vertical whitespace (the "Breath" principle) or alternating background shifts (`surface` to `surface-container-low`).
- **Touch Targets:** Every list item must be a minimum of **80dp** in height to ensure error-free tapping.

### Voice-First Input (Visualizer)
Instead of a keyboard, use a full-width `surface-container-highest` pulse at the bottom of the screen. As the user speaks, the `primary` color expands vertically to represent volume, providing immediate, high-contrast visual feedback.

### Persistent Bottom Nav
- **Icons:** Massive (32dp x 32dp) stroke icons with a 2px weight.
- **Labels:** Title-md (18sp) Bold.
- **Labels (RO/EN):** *Acasă / Home*, *Istoric / History*, *Doctorul Meu / My Doctor*.

---

## 6. Do's and Don'ts

### Do:
- **Use Massive Whitespace:** High-end design is defined by what isn't there. If a screen feels crowded, remove a secondary element.
- **Bilingual Alignment:** Ensure that "Acasă" and "Home" are centered perfectly within their 64dp touch targets.
- **Tonal Transitions:** Use the `surface-variant` color for inactive states rather than "greying out" text, which fails WCAG contrast tests.

### Don't:
- **No 1px Lines:** Do not use borders to separate the "Istoric" list items. Use the spacing scale.
- **No Virtual Keyboards:** Unless it is a critical edge case, use voice-to-text or pre-defined selection chips.
- **No Small Icons:** Never use an icon without a text label. The label must be at least 18sp.
- **No "Default" Shadows:** Avoid the standard Material Design shadow. Use the Tonal Layering or Ambient Shadow rules defined above.

---

### Director’s Final Note:
Every pixel must serve the user's dignity. If a component feels "standard" or "generic," go back to the Tonal Layering principle. We are not just building a tool; we are building a bridge for someone's health. Make it feel solid, expensive, and incredibly simple.
