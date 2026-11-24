# Voicey website

Live at **https://anantamishra.github.io/voicey/**. Marketing site for [Voicey](https://github.com/anantamishra/voicey), a Mac app that turns your voice into polished text in any app.
Built with Next.js (App Router) and plain CSS. It has a scroll-driven demo, tabbed scenes, feature cards, a comparison table,
a feature marquee, a maker's note, a free-and-open-source card, an FAQ and a download section.

## Run it

```bash
npm install
npm run dev          # http://localhost:3000
npm run build && npm start
npm run lint
```

## Deploy

It is hosted on GitHub Pages. `.github/workflows/pages.yml` (in the repository root) builds this folder as a static export
and publishes it whenever something under `website/` changes on `main`. To publish by hand, open the repository's **Actions**
tab, choose **Deploy website** and press **Run workflow**.

The site is served from `/voicey`, so the workflow sets `NEXT_PUBLIC_BASE_PATH=/voicey`. Locally the base path is empty. To try
the hosted build on your machine:

```bash
NEXT_PUBLIC_BASE_PATH=/voicey NEXT_PUBLIC_SITE_URL=https://anantamishra.github.io npm run build
```

Anything in `public/` must be referenced with `asset("/path")` from `app/lib/links.ts`, so it still works under `/voicey`.

## Layout

```
app/
  layout.tsx, page.tsx          page shell, metadata and section order
  opengraph-image.png           the social-share image
  icon.png, apple-icon.png      favicon and touch icon
  components/
    sections/                   one component per page section
    layout/                     nav, footer and the rotating tip toast
    mock/                       the small window and pop-up mock-ups used by the demos
    icons/<Section>/            every SVG as its own component (icons/shared = reused ones)
    Interactions.tsx            client-side behaviour (scroll story, orbit, tabs, tips, copy button, sound)
  lib/sound.ts                  synthesized UI sounds (Web Audio)
  styles/
    fonts.css                   @font-face
    site.css                    the page chrome inherited from the Vaultly site (pruned to what is used)
    voicey.css                  the Voicey demo, pop-up, keycaps and feature cards
    utilities.css               small utility classes
public/
  brand/                        Voicey app icon
  tiles/                        the app tiles that orbit the demo
  brands/apps/                  Claude and ChatGPT marks used in the price list
```

## Sections, in order

| Section | What it shows |
|---|---|
| Hero | the pitch and the download button |
| Dictation story | scroll to watch press, talk, polish, paste (`data-step` 0 to 3) |
| Every app | tabs: any app, email, chat, writing, code, ai chats |
| How it works | what it is, why it's different, three steps, the feature list |
| Voice statement | your voice stays on your Mac |
| Gestures | hold to talk, hands-free, per-app tone, dictionary and snippets |
| Typing | why typing and plain dictation fall short |
| Why Voicey | comparison with built-in and cloud dictation |
| Little things | scrolling cards of small features |
| Maker's note | who made it and why |
| Free | the "pricing" card: $0, open source (MIT) |
| FAQ | privacy, AI tools, permissions, requirements, the macOS warning |
| Download | download button and the Terminal install line |

## Before you publish

- **Maker's note** (`MakerNote.tsx`) is a draft in the maker's voice. Edit it so it says what you want to say.
- **No testimonials.** The Vaultly site had placeholder quotes; here that wall shows feature cards instead. Add real quotes
  (with permission) if you get them.
- **Links.** Download and footer links point at the GitHub repository and its latest release. There is no privacy or terms
  page yet.
- **Domain.** `metadataBase` in `layout.tsx` is the GitHub repo URL. Change it to your real domain when you deploy.
- **Comparison table** (`WhyVoicey.tsx`) compares categories ("built-in dictation", "cloud dictation apps") rather than
  named products, and says "varies" where it differs. Re-check it before you launch.
- **Install line** is the same command as in the Voicey README.

## Safety

The site never injects raw HTML. ESLint fails the build on `dangerouslySetInnerHTML`, `innerHTML`/`outerHTML` assignments and
`insertAdjacentHTML`. Text that scripts write into the page uses `textContent`.

## License

No license has been chosen yet, so all rights are reserved for now. The fonts and logos in `public/` have their own terms:
see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
