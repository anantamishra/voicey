"use client";

import { useEffect } from "react";
import { initSoundPreference, setSoundEnabled, sfx, soundEnabled, unlockAudio } from "../lib/sound";

// How far through the scroll story each step starts (0 = press, 1 = talk, 2 = polish, 3 = pasted).
const STORY_STEPS = [0.18, 0.42, 0.7];

const TIPS = [
  { text: "tip: double-tap your shortcut to talk hands-free. press once more to stop.", icon: "💡" },
  { text: "tip: any key can be your shortcut, even a single one like fn or right ⌥.", icon: "⌨️" },
  { text: "tip: add the names you say often to the dictionary and voicey spells them right.", icon: "📖" },
  { text: "tip: say “my address” and a snippet pastes the full text, word for word.", icon: "✂️" },
  { text: "tip: pick a tone for each app, formal in mail and casual in messages.", icon: "🎨" },
  { text: "tip: lost the last thing you said? copy it again from the menu bar.", icon: "📋" },
  { text: "tip: stop talking for a few seconds and voicey transcribes by itself.", icon: "⏱️" },
  { text: "tip: turn on double clap in settings, then clap twice to start without a keyboard.", icon: "👏" },
];

const $ = <T extends HTMLElement = HTMLElement>(sel: string, root: ParentNode = document) => root.querySelector<T>(sel);
const $$ = <T extends HTMLElement = HTMLElement>(sel: string, root: ParentNode = document) =>
  Array.from(root.querySelectorAll<T>(sel));

export default function Interactions() {
  useEffect(() => {
    const cleanups: Array<() => void> = [];
    const on = (el: EventTarget | null | undefined, type: string, fn: (e: Event) => void) => {
      if (!el) return;
      el.addEventListener(type, fn);
      cleanups.push(() => el.removeEventListener(type, fn));
    };

    // ---- sound: unlock on first gesture, mute toggle (button or the M key) ----
    initSoundPreference();
    const unlock = () => unlockAudio();
    document.addEventListener("pointerdown", unlock, { capture: true, passive: true });
    document.addEventListener("keydown", unlock, { capture: true, passive: true });
    cleanups.push(() => {
      document.removeEventListener("pointerdown", unlock, { capture: true });
      document.removeEventListener("keydown", unlock, { capture: true });
    });
    const soundBtn = document.createElement("button");
    soundBtn.type = "button";
    soundBtn.setAttribute("aria-label", "toggle sound");
    soundBtn.className = "sound-toggle";
    const paintSound = () => {
      soundBtn.textContent = soundEnabled() ? "sound on" : "sound off";
      soundBtn.setAttribute("aria-pressed", String(soundEnabled()));
    };
    const flipSound = () => {
      unlockAudio();
      setSoundEnabled(!soundEnabled());
      paintSound();
      if (soundEnabled()) sfx.click();
    };
    paintSound();
    document.body.appendChild(soundBtn);
    cleanups.push(() => soundBtn.remove());
    on(soundBtn, "click", flipSound);
    on(document, "keydown", (e) => {
      const k = e as KeyboardEvent;
      const t = k.target as HTMLElement | null;
      if (k.key.toLowerCase() === "m" && !k.metaKey && !k.ctrlKey && !k.altKey && !/input|textarea/i.test(t?.tagName ?? "")) flipSound();
    });
    on(document, "click", (e) => {
      const a = (e.target as HTMLElement | null)?.closest?.(".nav a, a.pill");
      if (a) sfx.click();
    });

    // ---- story: scroll progress drives data-step; nav scroll spy ----
    const story = $(".story");
    const navLinks = $$<HTMLAnchorElement>(".nav a[href^='#']");
    const navTargets = navLinks.map((a) => {
      const id = a.getAttribute("href")!;
      return id === "#top" ? null : document.getElementById(id.slice(1));
    });
    const setStep = (step: number) => {
      if (!story) return;
      const prev = Number(story.dataset.step ?? 0);
      story.dataset.step = String(step);
      if (step < prev) sfx.close();
      else if (step === 1) sfx.select();
      else if (step === 2) sfx.menu();
      else if (step === 3) sfx.open();
    };
    // Cache geometry; only re-measure on resize so scrolling never forces layout.
    let storyTop = 0;
    let storySpan = 0;
    const measure = () => {
      if (!story) return;
      storyTop = story.getBoundingClientRect().top + window.scrollY;
      storySpan = story.offsetHeight - window.innerHeight;
    };
    let ticking = false;
    const update = () => {
      ticking = false;
      if (story) {
        const p = storySpan > 0 ? (window.scrollY - storyTop) / storySpan : 0;
        const step = STORY_STEPS.filter((t) => p >= t).length;
        if (story.dataset.step !== String(step)) setStep(step);
      }
      const line = window.innerHeight * 0.4;
      let current = "#top";
      navTargets.forEach((t, i) => {
        if (t && t.getBoundingClientRect().top <= line) current = navLinks[i].getAttribute("href")!;
      });
      navLinks.forEach((a) => a.classList.toggle("on", a.getAttribute("href") === current));
    };
    const onScroll = () => {
      if (ticking) return;
      ticking = true;
      requestAnimationFrame(update);
    };
    const onResize = () => {
      measure();
      onScroll();
    };
    measure();
    update();
    window.addEventListener("scroll", onScroll, { passive: true });
    window.addEventListener("resize", onResize);
    cleanups.push(() => {
      window.removeEventListener("scroll", onScroll);
      window.removeEventListener("resize", onResize);
    });

    // ---- app tiles orbiting around the ring ----
    const orbit = $(".orbit");
    const ring = $(".orbit-ring");
    const orbs = $$(".orb");
    if (orbit && ring && orbs.length && !window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      const OMEGA = 0.133;
      const TILT = (-6 * Math.PI) / 180;
      const COS = Math.cos(TILT);
      const SIN = Math.sin(TILT);
      const t0 = performance.now();
      let geo = { cx: 0, cy: 0, rx: 0, ry: 0 };
      const readGeo = () => {
        geo = { cx: orbit.offsetWidth / 2, cy: orbit.offsetHeight * 0.56, rx: ring.offsetWidth / 2, ry: ring.offsetHeight / 2 };
      };
      readGeo();
      const ro = new ResizeObserver(readGeo);
      ro.observe(orbit);
      cleanups.push(() => ro.disconnect());
      let raf = 0;
      let visible = true;
      const io = new IntersectionObserver(([e]) => (visible = e.isIntersecting));
      io.observe(orbit);
      cleanups.push(() => io.disconnect());
      const tick = (now: number) => {
        raf = requestAnimationFrame(tick);
        if (!visible) return;
        const t = (now - t0) / 1000;
        for (let i = 0; i < orbs.length; i++) {
          const th = 0.11 + (i * 2 * Math.PI) / orbs.length + OMEGA * t;
          const ex = geo.rx * Math.cos(th);
          const ey = geo.ry * Math.sin(th);
          const sn = Math.sin(th);
          const x = geo.cx + ex * COS - ey * SIN;
          const y = geo.cy + ex * SIN + ey * COS;
          const el = orbs[i];
          el.style.transform = `translate3d(${x.toFixed(2)}px, ${y.toFixed(2)}px, 0) scale(${(0.9 + 0.1 * sn).toFixed(4)})`;
          el.style.zIndex = sn > 0 ? "2" : "-1"; // near half in front of the demo, far half behind it
        }
      };
      raf = requestAnimationFrame(tick);
      cleanups.push(() => cancelAnimationFrame(raf));
    }

    // ---- "built for every app" tabs ----
    const chips = $$<HTMLButtonElement>(".ek-chips [role=tab]");
    const scenes = $$(".ek-stage .ek-scene");
    chips.forEach((chip, i) =>
      on(chip, "click", () => {
        sfx.tab();
        chips.forEach((c, j) => {
          c.classList.toggle("ek-on", i === j);
          c.setAttribute("aria-selected", String(i === j));
        });
        scenes.forEach((s, j) => s.classList.toggle("ek-on", i === j));
      }),
    );

    // ---- tip toast: cycles, can be closed ----
    const proof = $(".proof");
    if (proof) {
      let n = 0;
      const timer = window.setInterval(() => {
        if (!proof.classList.contains("on")) return;
        n = (n + 1) % TIPS.length;
        const tip = TIPS[n];
        const quote = $(".proof-quote", proof);
        const face = $(".say-face", proof);
        const count = $(".say-name span", proof);
        if (quote) quote.textContent = tip.text;
        if (face) face.textContent = tip.icon;
        if (count) count.textContent = `${n + 1} of ${TIPS.length}`;
      }, 8000);
      cleanups.push(() => clearInterval(timer));
      on($(".proof-close", proof), "click", () => {
        proof.classList.remove("on");
        proof.setAttribute("aria-hidden", "true");
        clearInterval(timer);
      });
    }

    // ---- copy the install command ----
    $$<HTMLButtonElement>(".v-copy").forEach((btn) =>
      on(btn, "click", async () => {
        const text = btn.dataset.copy ?? "";
        try {
          await navigator.clipboard.writeText(text);
          btn.textContent = "copied";
          sfx.select();
        } catch {
          btn.textContent = "select it and press ⌘C";
        }
        window.setTimeout(() => (btn.textContent = "copy"), 1800);
      }),
    );

    // ---- smooth in-page anchors ----
    $$<HTMLAnchorElement>("a[href^='#']").forEach((a) =>
      on(a, "click", (e) => {
        const id = a.getAttribute("href")!;
        if (id === "#top") {
          e.preventDefault();
          window.scrollTo({ top: 0, behavior: "smooth" });
          return;
        }
        const target = document.getElementById(id.slice(1));
        if (!target) return;
        e.preventDefault();
        target.scrollIntoView({ behavior: "smooth", block: "start" });
        history.replaceState(null, "", id);
      }),
    );

    return () => cleanups.forEach((fn) => fn());
  }, []);

  return null;
}
