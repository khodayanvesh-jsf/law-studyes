(function () {
  "use strict";
  if (window.__lsIndianProfessorV323) return;
  window.__lsIndianProfessorV323 = true;

  function clean(s) { return String(s || "").replace(/<[^>]+>/g, " ").replace(/\s*\|\s*/g, ". ").replace(/\s+/g, " ").trim(); }
  function topicTitle(tid) {
    try { var m = typeof findTopicMeta === "function" ? findTopicMeta(tid) : null; if (m && m.topic && m.topic.title) return m.topic.title; } catch (e) {}
    return String(tid || "Topic").replace(/-/g, " ");
  }

  function buildLesson(tid, lang) {
    var rec = (typeof state !== "undefined" && state.notes) ? state.notes[tid] : null;
    if (!rec) return null;
    var ld = rec[lang] || rec.en; if (!ld) return null;
    var t = topicTitle(tid), m1 = clean(ld.inOneMinute), pr = clean(ld.legalProvision), mn = clean(ld.meaning);
    var pts = Array.isArray(ld.keyPoints) ? ld.keyPoints.slice(0, 5).map(function (x, i) { var tx = clean(typeof x === "string" ? x : (x && (x.point || x.text || x.summary))); return tx ? ((i + 1) + ". " + tx) : ""; }).filter(Boolean) : [];
    var c0 = Array.isArray(ld.caseLaws) && ld.caseLaws[0];
    var topCase = !c0 ? "" : (typeof c0 === "string" ? clean(c0) : (clean(c0.name || c0.title) + (c0.principle || c0.summary ? " - " + clean(c0.principle || c0.summary) : "")));

    if (lang === "te") {
      return {
        heading: "\u0c07\u0c02\u0c21\u0c3f\u0c2f\u0c28\u0c4d \u0c2a\u0c4d\u0c30\u0c4a\u0c2b\u0c46\u0c38\u0c30\u0c4d \u0c15\u0c4d\u0c32\u0c3e\u0c38\u0c4d\u200c\u0c30\u0c42\u0c2e\u0c4d",
        sub: "\u0c38\u0c41\u0c32\u0c2d\u0c2e\u0c48\u0c28 \u0c24\u0c46\u0c32\u0c41\u0c17\u0c41 \u0c35\u0c3f\u0c35\u0c30\u0c23 & \u0c0e\u0c17\u0c4d\u0c1c\u0c3e\u0c2e\u0c4d \u0c1f\u0c3f\u0c2a\u0c4d\u0c38\u0c4d",
        steps: [
          { step: 0, tag: "\u0c2a\u0c30\u0c3f\u0c1a\u0c2f\u0c02", text: "\u0c08\u0c30\u0c4b\u0c1c\u0c41 \u0c2e\u0c28\u0c02 " + t + " \u0c17\u0c41\u0c30\u0c3f\u0c02\u0c1a\u0c3f \u0c38\u0c41\u0c32\u0c2d\u0c02\u0c17\u0c3e \u0c05\u0c30\u0c4d\u0c25\u0c02 \u0c1a\u0c47\u0c38\u0c41\u0c15\u0c41\u0c02\u0c26\u0c3e\u0c02." },
          m1 ? { step: 1, tag: "\u0c12\u0c15 \u0c28\u0c3f\u0c2e\u0c3f\u0c37\u0c02\u0c32\u0c4b", text: m1 } : null,
          pr ? { step: 2, tag: "\u0c1a\u0c1f\u0c4d\u0c1f\u0c2a\u0c30\u0c2e\u0c48\u0c28 \u0c28\u0c3f\u0c2c\u0c02\u0c27\u0c28", text: pr } : null,
          mn ? { step: 3, tag: "\u0c38\u0c4d\u0c2a\u0c37\u0c4d\u0c1f\u0c2e\u0c48\u0c28 \u0c05\u0c30\u0c4d\u0c25\u0c02", text: mn } : null,
          pts.length ? { step: 4, tag: "\u0c2e\u0c41\u0c16\u0c4d\u0c2f \u0c2a\u0c3e\u0c2f\u0c3f\u0c02\u0c1f\u0c4d\u0c32\u0c41", text: pts.join(" ") } : null,
          topCase ? { step: 5, tag: "\u0c2e\u0c41\u0c16\u0c4d\u0c2f\u0c2e\u0c48\u0c28 \u0c15\u0c47\u0c38\u0c41 \u0c32\u0c3e", text: topCase } : null
        ].filter(Boolean)
      };
    }
    if (lang === "hi") {
      return {
        heading: "\u0907\u0902\u0921\u093f\u092f\u0928 \u092a\u094d\u0930\u094b\u092b\u0947\u0938\u0930 \u0915\u094d\u0932\u093e\u0938\u0930\u0942\u092e",
        sub: "\u0906\u0938\u093e\u0928 \u0939\u093f\u0902\u0926\u0940 \u0935\u094d\u092f\u093e\u0916\u094d\u092f\u093e & \u090f\u0917\u094d\u091c\u093e\u092e \u091f\u093f\u092a\u094d\u0938",
        steps: [
          { step: 0, tag: "\u092a\u0930\u093f\u091a\u092f", text: "\u0906\u091c \u0939\u092e " + t + " \u0915\u094b \u0906\u0938\u093e\u0928 \u0914\u0930 \u0938\u094d\u092a\u0937\u094d\u091f \u092d\u093e\u0937\u093e \u092e\u0947\u0902 \u0938\u092e\u091d\u0947\u0902\u0917\u0947\u0964" },
          m1 ? { step: 1, tag: "\u090f\u0915 \u092e\u093f\u0928\u091f \u092e\u0947\u0902", text: m1 } : null,
          pr ? { step: 2, tag: "\u0935\u093f\u0927\u093f\u0915 \u092a\u094d\u0930\u093e\u0935\u0927\u093e\u0928", text: pr } : null,
          mn ? { step: 3, tag: "\u0938\u0930\u0932 \u0905\u0930\u094d\u0925", text: mn } : null,
          pts.length ? { step: 4, tag: "\u092e\u0941\u0916\u094d\u092f \u092a\u0949\u0907\u0902\u091f\u094d\u0938", text: pts.join(" ") } : null,
          topCase ? { step: 5, tag: "\u092a\u094d\u0930\u092e\u0941\u0916 \u0915\u0947\u0938 \u0932\u0949", text: topCase } : null
        ].filter(Boolean)
      };
    }
    return {
      heading: "Indian Professor Classroom",
      sub: "Clear Indian LL.B. classroom explanation & exam structure",
      steps: [
        { step: 0, tag: "Overview", text: "Today let us clearly understand " + t + "." },
        m1 ? { step: 1, tag: "1-Minute Core", text: m1 } : null,
        pr ? { step: 2, tag: "Legal Provision", text: pr } : null,
        mn ? { step: 3, tag: "Plain Meaning", text: mn } : null,
        pts.length ? { step: 4, tag: "Key Scoring Points", text: pts.join(" ") } : null,
        topCase ? { step: 5, tag: "Landmark Case", text: topCase } : null
      ].filter(Boolean)
    };
  }

  function injectCss() {
    if (document.getElementById("lsProfCssV323")) return;
    var st = document.createElement("style"); st.id = "lsProfCssV323";
    st.textContent =
      ".ls-prof-card{margin:14px 0 16px;border-radius:16px;background:linear-gradient(135deg,#FFFBF2 0%,#FDF4F5 100%);border:1.5px solid #E5C9A8;padding:12px 14px}" +
      ".ls-prof-title{font-size:13.5px;font-weight:800;color:#7B1E2B}.ls-prof-sub{font-size:11px;color:#6B5B4D;font-weight:600}" +
      ".ls-prof-controls{display:flex;flex-wrap:wrap;align-items:center;gap:6px;margin-top:10px}" +
      ".ls-prof-btn{padding:6px 11px;border-radius:999px;border:1px solid #DFC5A4;background:#FFF;color:#7B1E2B;font-size:11.5px;font-weight:800;cursor:pointer}" +
      ".ls-prof-btn.primary{background:#7B1E2B;color:#FFF;border-color:#7B1E2B}.ls-prof-status{font-size:11px;color:#7B1E2B;font-weight:700;margin-top:8px}" +
      ".ls-prof-body{margin-top:10px;display:flex;flex-direction:column;gap:7px}" +
      ".ls-prof-step{background:#FFF;border:1px solid #EFE4D6;border-left:3.5px solid #7B1E2B;border-radius:10px;padding:8px 10px;font-size:12.5px;line-height:1.55}" +
      ".ls-prof-step.speaking{background:#FFF7E6;border-left-color:#B45309}.ls-prof-tag{display:inline-block;font-size:10px;font-weight:800;color:#7B1E2B;background:#FBF1F2;padding:2px 7px;border-radius:999px;margin-bottom:4px}";
    document.head.appendChild(st);
  }

  function sync(st) {
    if (!st) return;
    var p = document.getElementById("lsProfPlayBtn"), s = document.getElementById("lsProfStopBtn"), el = document.getElementById("lsProfStatus");
    if (p) p.textContent = (st.playing && !st.paused) ? "Pause Class" : (st.paused ? "Resume Class" : "Listen to Professor");
    if (s) s.style.display = (st.playing || st.paused) ? "inline-block" : "none";
    if (el) el.textContent = (st.playing && !st.paused) ? ("Playing: " + st.voiceName + " (" + st.percent + "%)") : (st.paused ? "Paused" : "");
    document.querySelectorAll("#lsProfLessonBody .ls-prof-step").forEach(function (n) {
      n.classList.toggle("speaking", st.playing && !st.paused && !st.studioMp3 && parseInt(n.getAttribute("data-step") || "-9", 10) === st.stepIdx);
    });
  }

  function renderCard() {
    try {
      injectCss();
      if (typeof state === "undefined" || !state.activeTopicId) return;
      var pane = document.getElementById("readingPane"); if (!pane) return;
      var old = document.getElementById("lsIndianProfessorCard"); if (old) old.remove();
      var lesson = buildLesson(state.activeTopicId, state.lang || "en"); if (!lesson) return;

      var card = document.createElement("section"); card.id = "lsIndianProfessorCard"; card.className = "ls-prof-card";
      card.innerHTML =
        '<div class="ls-prof-title">' + lesson.heading + '</div><div class="ls-prof-sub">' + lesson.sub + '</div>' +
        '<div class="ls-prof-controls">' +
          '<button type="button" id="lsProfPlayBtn" class="ls-prof-btn primary">Listen to Professor</button>' +
          '<button type="button" id="lsProfStopBtn" class="ls-prof-btn" style="display:none;">Stop</button>' +
          '<button type="button" id="lsProfOpenPlayerBtn" class="ls-prof-btn">Voice &amp; Speed Settings</button>' +
          '<button type="button" id="lsProfToggleBodyBtn" class="ls-prof-btn">Show Classroom Notes</button>' +
        '</div><div id="lsProfStatus" class="ls-prof-status"></div><div id="lsProfLessonBody" class="ls-prof-body" style="display:none;"></div>';

      var body = card.querySelector("#lsProfLessonBody");
      lesson.steps.forEach(function (st) {
        var r = document.createElement("div"); r.className = "ls-prof-step"; r.setAttribute("data-step", String(st.step));
        r.innerHTML = '<span class="ls-prof-tag">' + st.tag.replace(/</g, "&lt;") + '</span><div>' + st.text.replace(/</g, "&lt;") + '</div>';
        body.appendChild(r);
      });

      card.querySelector("#lsProfPlayBtn").addEventListener("click", function () {
        var eng = window.LSAudioEngine; if (!eng) return;
        var st = eng.getState();
        if (st.playing && st.topicId === state.activeTopicId) eng.togglePlay();
        else { body.style.display = "flex"; card.querySelector("#lsProfToggleBodyBtn").textContent = "Hide Classroom Notes"; eng.playTopic(state.activeTopicId, true); }
      });
      card.querySelector("#lsProfStopBtn").addEventListener("click", function () { if (window.LSAudioEngine) window.LSAudioEngine.stop(); });
      card.querySelector("#lsProfOpenPlayerBtn").addEventListener("click", function () {
        if (window.LSAudioWindow && typeof window.LSAudioWindow.open === "function") window.LSAudioWindow.open();
        else { var m = document.getElementById("lsPlayerWindowModal"); if (m) m.classList.add("show"); }
      });
      card.querySelector("#lsProfToggleBodyBtn").addEventListener("click", function (ev) {
        var open = body.style.display !== "none"; body.style.display = open ? "none" : "flex";
        ev.currentTarget.textContent = open ? "Show Classroom Notes" : "Hide Classroom Notes";
      });

      var copyBar = document.getElementById("lsNoteCopyBar");
      if (copyBar && copyBar.parentNode === pane) copyBar.insertAdjacentElement("afterend", card);
      else pane.insertBefore(card, pane.firstChild);
      if (window.LSAudioEngine) sync(window.LSAudioEngine.getState());
    } catch (e) {}
  }

  window.addEventListener("ls:audio-state", function (ev) { sync(ev.detail); });
  function hook() {
    try {
      if (typeof window.renderReadingPane === "function" && !window.__lsProfHookV323) {
        window.__lsProfHookV323 = true;
        var orig = window.renderReadingPane;
        window.renderReadingPane = function () { var r = orig.apply(this, arguments); renderCard(); return r; };
        renderCard();
      }
    } catch (e) {}
  }

  window.LSIndianProfessor = {
    play: function () { if (window.LSAudioEngine) window.LSAudioEngine.playTopic(state.activeTopicId, true); },
    stop: function () { if (window.LSAudioEngine) window.LSAudioEngine.stop(); }
  };
  window.addEventListener("DOMContentLoaded", function () { setTimeout(hook, 350); setTimeout(hook, 1200); });
})();