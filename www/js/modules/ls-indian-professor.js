(function () {
  "use strict";
  if (window.__lsIndianProfessorV321) return;
  window.__lsIndianProfessorV321 = true;

  var AUDIO_CACHE = "ls-prof-audio-v1", CDN_BASE = "https://law-studyes.vercel.app";
  var manifest = null, htmlAudio = null, playing = false, paused = false, curIdx = 0, sentences = [], token = 0;

  function vc() { return window.LSVoiceController || null; }
  function getEng() { return vc() ? vc().getEngine() : "studio"; }
  function getGen() { return vc() ? vc().getGender() : "female"; }
  function getRate() { return vc() ? vc().getRate() : 1.0; }
  function getPitch() { return vc() ? vc().getPitch() : 1.0; }
  function bcp47(l) { return vc() ? vc().langToBcp47(l) : (l === "te" ? "te-IN" : (l === "hi" ? "hi-IN" : "en-IN")); }
  function clean(s) { return String(s || "").replace(/<[^>]+>/g, " ").replace(/\s+/g, " ").trim(); }

  function topicTitle(tid) {
    try { var m = typeof findTopicMeta === "function" ? findTopicMeta(tid) : null; if (m && m.topic && m.topic.title) return m.topic.title; } catch (e) {}
    return String(tid || "Topic").replace(/-/g, " ");
  }

  function buildLesson(tid, lang) {
    var rec = (typeof state !== "undefined" && state.notes) ? state.notes[tid] : null;
    if (!rec) return null;
    var ld = rec[lang] || rec.en;
    if (!ld) return null;
    var t = topicTitle(tid), m1 = clean(ld.inOneMinute), pr = clean(ld.legalProvision), mn = clean(ld.meaning);
    var pts = Array.isArray(ld.keyPoints) ? ld.keyPoints.slice(0, 5).map(function (x) { return clean(typeof x === "string" ? x : (x && (x.point || x.text || x.summary))); }).filter(Boolean) : [];
    var c0 = Array.isArray(ld.caseLaws) && ld.caseLaws[0];
    var topCase = !c0 ? "" : (typeof c0 === "string" ? clean(c0) : (clean(c0.name || c0.title) + (c0.principle || c0.summary ? " - " + clean(c0.principle || c0.summary) : "")));

    if (lang === "te") {
      return {
        heading: "\u0c07\u0c02\u0c21\u0c3f\u0c2f\u0c28\u0c4d \u0c2a\u0c4d\u0c30\u0c4a\u0c2b\u0c46\u0c38\u0c30\u0c4d \u0c15\u0c4d\u0c32\u0c3e\u0c38\u0c4d\u200c\u0c30\u0c42\u0c2e\u0c4d (AI Teaching Mode)",
        sub: "\u0c38\u0c3f\u0c02\u0c2a\u0c41\u0c32\u0c4d \u0c24\u0c46\u0c32\u0c41\u0c17\u0c41 \u0c15\u0c4d\u0c32\u0c3e\u0c38\u0c4d \u0c35\u0c3f\u0c35\u0c30\u0c23 + \u0c0e\u0c17\u0c4d\u0c1c\u0c3e\u0c2e\u0c4d \u0c1f\u0c3f\u0c2a\u0c4d\u0c38\u0c4d",
        steps: [
          { tag: "\u0c15\u0c4d\u0c32\u0c3e\u0c38\u0c4d", text: "\u0c28\u0c2e\u0c38\u0c4d\u0c15\u0c3e\u0c30\u0c02 \u0c38\u0c4d\u0c1f\u0c42\u0c21\u0c46\u0c02\u0c1f\u0c4d\u0c38\u0c4d! \u0c08\u0c30\u0c4b\u0c1c\u0c41 " + t + " \u0c17\u0c41\u0c30\u0c3f\u0c02\u0c1a\u0c3f \u0c38\u0c3f\u0c02\u0c2a\u0c41\u0c32\u0c4d\u200c\u0c17\u0c3e \u0c28\u0c47\u0c30\u0c4d\u0c1a\u0c41\u0c15\u0c41\u0c02\u0c26\u0c3e\u0c02." },
          m1 ? { tag: "\u0c38\u0c3e\u0c30\u0c3e\u0c02\u0c36\u0c02", text: m1 } : null,
          pr ? { tag: "\u0c38\u0c46\u0c15\u0c4d\u0c37\u0c28\u0c4d", text: pr } : null,
          mn ? { tag: "\u0c35\u0c3f\u0c35\u0c30\u0c23", text: mn } : null,
          pts.length ? { tag: "\u0c2a\u0c3e\u0c2f\u0c3f\u0c02\u0c1f\u0c4d\u0c32\u0c41", text: pts.join(" | ") } : null,
          topCase ? { tag: "\u0c15\u0c47\u0c38\u0c4d \u0c32\u0c3e", text: topCase } : null
        ].filter(Boolean)
      };
    }
    if (lang === "hi") {
      return {
        heading: "\u0907\u0902\u0921\u093f\u092f\u0928 \u092a\u094d\u0930\u094b\u092b\u0947\u0938\u0930 \u0915\u094d\u0932\u093e\u0938\u0930\u0942\u092e (AI Teaching Mode)",
        sub: "\u0906\u0938\u093e\u0928 \u0939\u093f\u0902\u0926\u0940 \u0915\u094d\u0932\u093e\u0938\u0930\u0942\u092e \u0938\u092e\u091d + \u090f\u0917\u094d\u091c\u093e\u092e \u091f\u094d\u0930\u093f\u0915\u094d\u0938",
        steps: [
          { tag: "\u0915\u094d\u0932\u093e\u0938", text: "\u0928\u092e\u0938\u094d\u0924\u0947 \u0938\u094d\u091f\u0942\u0921\u0947\u0902\u091f\u094d\u0938! \u0906\u091c \u0939\u092e " + t + " \u0915\u094b \u0906\u0938\u093e\u0928 \u0915\u094d\u0932\u093e\u0938\u0930\u0942\u092e \u0905\u0902\u0926\u093e\u091c \u092e\u0947\u0902 \u0938\u092e\u091d\u0947\u0902\u0917\u0947\u0964" },
          m1 ? { tag: "\u0915\u0949\u0928\u094d\u0938\u0947\u092a\u094d\u091f", text: m1 } : null,
          pr ? { tag: "\u0938\u0947\u0915\u094d\u0936\u0928", text: pr } : null,
          mn ? { tag: "\u0905\u0930\u094d\u0925", text: mn } : null,
          pts.length ? { tag: "\u092a\u0949\u0907\u0902\u091f\u094d\u0938", text: pts.join(" | ") } : null,
          topCase ? { tag: "\u0915\u0947\u0938 \u0932\u0949", text: topCase } : null
        ].filter(Boolean)
      };
    }
    return {
      heading: "Indian Professor Classroom (AI Teaching Mode)",
      sub: "Relatable Indian LL.B. classroom explanation + exam answer strategy",
      steps: [
        { tag: "Class Start", text: "Hello students! Let us understand " + t + " in simple Indian classroom style." },
        m1 ? { tag: "1-Min Core", text: m1 } : null,
        pr ? { tag: "Section Hook", text: pr } : null,
        mn ? { tag: "Plain Meaning", text: mn } : null,
        pts.length ? { tag: "Scoring Points", text: pts.join(" | ") } : null,
        topCase ? { tag: "Landmark Case", text: topCase } : null
      ].filter(Boolean)
    };
  }

  function injectCss() {
    if (document.getElementById("lsProfCssV321")) return;
    var st = document.createElement("style");
    st.id = "lsProfCssV321";
    st.textContent =
      ".ls-prof-card{margin:14px 0 16px;border-radius:16px;background:linear-gradient(135deg,#FFFBF2 0%,#FDF4F5 100%);border:1.5px solid #E5C9A8;padding:12px 14px}" +
      ".ls-prof-title{font-size:13.5px;font-weight:800;color:#7B1E2B}.ls-prof-sub{font-size:11px;color:#6B5B4D;font-weight:600}" +
      ".ls-prof-controls{display:flex;flex-wrap:wrap;align-items:center;gap:6px;margin-top:10px}" +
      ".ls-prof-btn,.ls-prof-sel{padding:6px 10px;border-radius:999px;border:1px solid #DFC5A4;background:#FFF;color:#7B1E2B;font-size:11.5px;font-weight:800;cursor:pointer}" +
      ".ls-prof-btn.primary{background:#7B1E2B;color:#FFF;border-color:#7B1E2B}.ls-prof-btn.active{background:#8C6D46;color:#FFF;border-color:#8C6D46}" +
      ".ls-prof-status{font-size:11px;color:#7B1E2B;font-weight:700;margin-top:8px}.ls-prof-body{margin-top:10px;display:flex;flex-direction:column;gap:7px}" +
      ".ls-prof-step{background:#FFF;border:1px solid #EFE4D6;border-left:3.5px solid #7B1E2B;border-radius:10px;padding:8px 10px;font-size:12.5px;line-height:1.55}" +
      ".ls-prof-step.speaking{background:#FFF7E6;border-left-color:#B45309}.ls-prof-tag{display:inline-block;font-size:10px;font-weight:800;color:#7B1E2B;background:#FBF1F2;padding:2px 7px;border-radius:999px;margin-bottom:4px}";
    document.head.appendChild(st);
  }

  async function getManifest() {
    if (manifest !== null) return manifest;
    manifest = {};
    try { var r = await fetch("./audio/manifest.json", { cache: "no-store" }); if (r.ok) manifest = await r.json(); } catch (e) {}
    return manifest;
  }

  function setStatus(msg) { var el = document.getElementById("lsProfStatus"); if (el) el.textContent = msg || ""; }
  function highlight(idx) { document.querySelectorAll("#lsProfLessonBody .ls-prof-step").forEach(function (el, i) { el.classList.toggle("speaking", i === idx); }); }

  function syncBtns() {
    var p = document.getElementById("lsProfPlayBtn"), s = document.getElementById("lsProfStopBtn"),
        f = document.getElementById("lsProfVoiceFemBtn"), m = document.getElementById("lsProfVoiceMaleBtn"),
        e = document.getElementById("lsProfEngineSel");
    if (p) p.textContent = playing ? (paused ? "Resume Class" : "Pause Class") : "Listen to Professor";
    if (s) s.style.display = (playing || paused) ? "inline-block" : "none";
    if (f) f.classList.toggle("active", getGen() === "female");
    if (m) m.classList.toggle("active", getGen() === "male");
    if (e) e.value = getEng();
  }

  function stopAudio() {
    token++; playing = false; paused = false;
    if (htmlAudio) { try { htmlAudio.pause(); htmlAudio.currentTime = 0; } catch (e) {} htmlAudio = null; }
    var tts = window.Capacitor && window.Capacitor.Plugins && window.Capacitor.Plugins.TextToSpeech;
    if (tts && tts.stop) { try { tts.stop().catch(function () {}); } catch (e) {} }
    if ("speechSynthesis" in window) { try { window.speechSynthesis.cancel(); } catch (e) {} }
    syncBtns(); highlight(-1);
  }

  async function tryMp3(tid, lang, tk) {
    if (getEng() !== "studio" || getGen() !== "female") return false;
    var mf = await getManifest();
    var rel = (mf && mf[lang] && mf[lang][tid]) ? mf[lang][tid] : null;
    if (!rel) return false;
    var urls = [rel, CDN_BASE + "/" + rel.replace(/^\.\//, "")];
    for (var i = 0; i < urls.length; i++) {
      try {
        var u = urls[i], playUrl = u;
        if ("caches" in window) {
          var c = await caches.open(AUDIO_CACHE), hit = await c.match(u);
          if (hit) playUrl = URL.createObjectURL(await hit.blob());
          else {
            var resp = await fetch(u);
            if (!resp.ok) continue;
            try { c.put(u, resp.clone()); } catch (e) {}
            playUrl = URL.createObjectURL(await resp.blob());
          }
        }
        if (tk !== token) return true;
        htmlAudio = new Audio(playUrl);
        htmlAudio.playbackRate = getRate();
        htmlAudio.onended = function () { playing = false; paused = false; setStatus("Class completed (Studio MP3)."); syncBtns(); };
        await htmlAudio.play();
        playing = true; paused = false;
        setStatus("Playing Studio Human MP3 (" + getRate() + "x)");
        syncBtns();
        return true;
      } catch (e) {}
    }
    return false;
  }

  async function speakOne(text, lang) {
    var tts = window.Capacitor && window.Capacitor.Plugins && window.Capacitor.Plugins.TextToSpeech;
    if (tts && typeof tts.speak === "function") {
      await tts.speak({ text: text, lang: bcp47(lang), rate: getRate(), pitch: getPitch(), volume: 1.0, category: "ambient" });
      return;
    }
    if ("speechSynthesis" in window) {
      await new Promise(function (resolve) {
        try { var u = new SpeechSynthesisUtterance(text); u.lang = bcp47(lang); u.onend = resolve; u.onerror = resolve; window.speechSynthesis.speak(u); }
        catch (e) { resolve(); }
      });
    }
  }

  async function loopSpeak(startAt) {
    var tk = ++token, lang = (typeof state !== "undefined" && state.lang) ? state.lang : "en";
    playing = true; paused = false; syncBtns();
    setStatus("Active: " + getEng().toUpperCase() + " | " + (getGen() === "male" ? "Sir" : "Ma'am") + " | " + bcp47(lang) + " | " + getRate() + "x");
    for (var i = startAt; i < sentences.length; i++) {
      if (tk !== token) return;
      curIdx = i; highlight(i);
      await speakOne(sentences[i], lang);
      if (tk !== token) return;
      await new Promise(function (r) { setTimeout(r, 200); });
    }
    if (tk === token) { playing = false; paused = false; highlight(-1); setStatus("Classroom explanation complete!"); syncBtns(); }
  }

  async function play(resumeIdx) {
    if (typeof state === "undefined" || !state.activeTopicId) return;
    if (typeof resumeIdx !== "number" && playing && !paused) {
      paused = true;
      if (htmlAudio) { try { htmlAudio.pause(); } catch (e) {} }
      else {
        token++;
        var tts = window.Capacitor && window.Capacitor.Plugins && window.Capacitor.Plugins.TextToSpeech;
        if (tts && tts.stop) { try { tts.stop().catch(function () {}); } catch (e) {} }
        if ("speechSynthesis" in window) { try { window.speechSynthesis.cancel(); } catch (e) {} }
      }
      setStatus("Class paused."); syncBtns(); return;
    }
    if (typeof resumeIdx !== "number" && playing && paused) {
      paused = false;
      if (htmlAudio) { htmlAudio.playbackRate = getRate(); try { await htmlAudio.play(); } catch (e) {} syncBtns(); return; }
      loopSpeak(curIdx); return;
    }
    if (window.LSAudioEngine && window.LSAudioEngine.stop) window.LSAudioEngine.stop();
    stopAudio();
    var tk = ++token, tid = state.activeTopicId, lang = state.lang || "en";
    var body = document.getElementById("lsProfLessonBody");
    if (body) body.style.display = "flex";
    var lesson = buildLesson(tid, lang);
    if (!lesson || !lesson.steps.length) return;
    sentences = lesson.steps.map(function (s) { return s.text; });
    curIdx = (typeof resumeIdx === "number" && resumeIdx >= 0 && resumeIdx < sentences.length) ? resumeIdx : 0;
    if (curIdx === 0 && await tryMp3(tid, lang, tk)) return;
    loopSpeak(curIdx);
  }

  window.addEventListener("ls:voice-settings-changed", function () {
    syncBtns();
    if (!playing || paused) return;
    if (htmlAudio && getEng() === "studio" && getGen() === "female") {
      htmlAudio.playbackRate = getRate();
      setStatus("Updated Studio MP3 speed (" + getRate() + "x)");
      return;
    }
    var idx = curIdx;
    stopAudio();
    setTimeout(function () { play(idx); }, 130);
  });

  function renderCard() {
    try {
      injectCss();
      if (typeof state === "undefined" || !state.activeTopicId) return;
      var pane = document.getElementById("readingPane");
      if (!pane) return;
      var old = document.getElementById("lsIndianProfessorCard"); if (old) old.remove();
      var lesson = buildLesson(state.activeTopicId, state.lang || "en");
      if (!lesson) return;

      var card = document.createElement("section");
      card.id = "lsIndianProfessorCard"; card.className = "ls-prof-card";
      card.innerHTML =
        '<div class="ls-prof-title">' + lesson.heading + '</div><div class="ls-prof-sub">' + lesson.sub + '</div>' +
        '<div class="ls-prof-controls">' +
          '<button type="button" id="lsProfPlayBtn" class="ls-prof-btn primary">Listen to Professor</button>' +
          '<button type="button" id="lsProfStopBtn" class="ls-prof-btn" style="display:none;">Stop</button>' +
          '<select id="lsProfEngineSel" class="ls-prof-sel">' +
            '<option value="studio">Engine: Studio MP3</option><option value="neural">Engine: Indian Neural</option><option value="device">Engine: Offline Device</option>' +
          '</select>' +
          '<button type="button" id="lsProfVoiceFemBtn" class="ls-prof-btn">Ma\'am</button>' +
          '<button type="button" id="lsProfVoiceMaleBtn" class="ls-prof-btn">Sir</button>' +
          '<button type="button" id="lsProfTestBtn" class="ls-prof-btn">Test Voice</button>' +
          '<button type="button" id="lsProfToggleBodyBtn" class="ls-prof-btn">Show Notes</button>' +
        '</div>' +
        '<div id="lsProfStatus" class="ls-prof-status"></div><div id="lsProfLessonBody" class="ls-prof-body" style="display:none;"></div>';

      var body = card.querySelector("#lsProfLessonBody");
      lesson.steps.forEach(function (st) {
        var r = document.createElement("div"); r.className = "ls-prof-step";
        r.innerHTML = '<span class="ls-prof-tag">' + st.tag.replace(/</g, "&lt;") + '</span><div>' + st.text.replace(/</g, "&lt;") + '</div>';
        body.appendChild(r);
      });

      card.querySelector("#lsProfPlayBtn").addEventListener("click", function () { play(); });
      card.querySelector("#lsProfStopBtn").addEventListener("click", stopAudio);
      card.querySelector("#lsProfEngineSel").addEventListener("change", function (ev) { if (vc()) vc().applySettings({ engine: ev.target.value, voiceId: "auto" }, true); });
      card.querySelector("#lsProfVoiceFemBtn").addEventListener("click", function () { if (vc()) vc().applySettings({ gender: "female", voiceId: "auto" }, true); });
      card.querySelector("#lsProfVoiceMaleBtn").addEventListener("click", function () { if (vc()) vc().applySettings({ gender: "male", voiceId: "auto" }, true); });
      card.querySelector("#lsProfTestBtn").addEventListener("click", function () { if (vc()) vc().testVoice(); });
      card.querySelector("#lsProfToggleBodyBtn").addEventListener("click", function (ev) {
        var open = body.style.display !== "none";
        body.style.display = open ? "none" : "flex";
        ev.currentTarget.textContent = open ? "Show Notes" : "Hide Notes";
      });

      var copyBar = document.getElementById("lsNoteCopyBar");
      if (copyBar && copyBar.parentNode === pane) copyBar.insertAdjacentElement("afterend", card);
      else pane.insertBefore(card, pane.firstChild);
      syncBtns();
    } catch (e) {}
  }

  function hook() {
    try {
      if (typeof window.renderReadingPane === "function" && !window.__lsProfHookV321) {
        window.__lsProfHookV321 = true;
        var orig = window.renderReadingPane;
        window.renderReadingPane = function () { stopAudio(); var r = orig.apply(this, arguments); renderCard(); return r; };
        renderCard();
      }
    } catch (e) {}
  }

  window.addEventListener("ls:lang-changed", stopAudio);
  window.LSIndianProfessor = { play: play, stop: stopAudio };
  window.addEventListener("DOMContentLoaded", function () { setTimeout(hook, 400); setTimeout(hook, 1250); });
})();