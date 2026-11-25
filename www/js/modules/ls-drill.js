(function () {
  "use strict";
  function esc(s) {
    return String(s || "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
  }

  async function renderExamDrill(container) {
    if (!container || !window.LSStore) return;
    var extras = await window.LSStore.loadExtras();
    var mcqs = (extras && Array.isArray(extras.mcqs) && extras.mcqs.length) ? extras.mcqs : [];

    // Fallback: if extras_db.json has no MCQs yet, build interactive flashcard drills from selfTest Q&A
    var qaItems = window.LSStore.extractQaFromNotes();
    if (!mcqs.length && !qaItems.length) {
      container.innerHTML = '<div class="p-6 text-center text-xs text-[#5F554E]">No practice questions loaded yet.</div>';
      return;
    }

    var idx = 0;
    var score = 0;
    var answered = 0;

    function renderCard() {
      if (mcqs.length) {
        var q = mcqs[idx % mcqs.length];
        var optsHtml = (q.options || []).map(function (opt, oi) {
          return '<button type="button" data-opt-idx="' + oi + '" class="ls-drill-opt w-full text-left px-3.5 py-2.5 rounded-xl border border-[#E8E0D5] bg-[#FAF7F2] text-xs font-semibold text-[#1F1B18] active:scale-[0.99]">' + esc(opt) + '</button>';
        }).join("");

        container.innerHTML =
          '<div class="space-y-3 pb-6">' +
            '<div class="flex items-center justify-between bg-white border border-[#E8E0D5] rounded-2xl px-4 py-3">' +
              '<div><div class="text-sm font-bold text-[#7B1E2B]">Exam Drill Arena</div><div class="text-[11px] text-[#5F554E]">Question ' + (idx + 1) + ' of ' + mcqs.length + '</div></div>' +
              '<div class="text-xs font-extrabold px-2.5 py-1 rounded-full bg-[#FBF1F2] text-[#7B1E2B]">Score: ' + score + '/' + answered + '</div>' +
            '</div>' +
            '<div class="bg-white border border-[#E8E0D5] rounded-2xl p-4 shadow-sm space-y-3">' +
              '<div class="text-[11px] font-bold text-[#8C6D46]">' + esc(q.subject || "LL.B. Practice") + '</div>' +
              '<div class="text-sm font-bold text-[#1F1B18] leading-snug">' + esc(q.q) + '</div>' +
              '<div class="space-y-2">' + optsHtml + '</div>' +
              '<div id="lsDrillExplain" class="hidden p-3 rounded-xl bg-[#FAF7F2] border border-[#E8E0D5] text-xs text-[#3D352E]"></div>' +
              '<div class="flex justify-between pt-2">' +
                '<button type="button" id="lsDrillPrev" class="px-3 py-1.5 rounded-xl border border-[#D6C7BC] text-xs font-bold text-[#5F554E]">&larr; Prev</button>' +
                '<button type="button" id="lsDrillNext" class="px-4 py-1.5 rounded-xl bg-[#7B1E2B] text-white text-xs font-bold">Next Question &rarr;</button>' +
              '</div>' +
            '</div>' +
          '</div>';

        var locked = false;
        container.querySelectorAll(".ls-drill-opt").forEach(function (b) {
          b.addEventListener("click", function () {
            if (locked) return;
            locked = true;
            answered++;
            var picked = parseInt(b.getAttribute("data-opt-idx"), 10);
            var correct = typeof q.answerIndex === "number" ? q.answerIndex : 0;
            if (picked === correct) {
              score++;
              b.style.background = "#ECFDF5";
              b.style.borderColor = "#10B981";
            } else {
              b.style.background = "#FEF2F2";
              b.style.borderColor = "#EF4444";
              var rightBtn = container.querySelector('.ls-drill-opt[data-opt-idx="' + correct + '"]');
              if (rightBtn) { rightBtn.style.background = "#ECFDF5"; rightBtn.style.borderColor = "#10B981"; }
            }
            var ex = container.querySelector("#lsDrillExplain");
            if (ex) {
              ex.textContent = q.explanation || ("Correct answer: " + ((q.options && q.options[correct]) || ""));
              ex.classList.remove("hidden");
            }
          });
        });
      } else {
        var item = qaItems[idx % qaItems.length];
        container.innerHTML =
          '<div class="space-y-3 pb-6">' +
            '<div class="bg-white border border-[#E8E0D5] rounded-2xl px-4 py-3 flex items-center justify-between">' +
              '<div><div class="text-sm font-bold text-[#7B1E2B]">Exam Drill Flashcards</div><div class="text-[11px] text-[#5F554E]">Card ' + (idx + 1) + ' of ' + qaItems.length + '</div></div>' +
              '<span class="text-[11px] font-bold px-2.5 py-1 rounded-full bg-[#FBF1F2] text-[#7B1E2B]">Active Recall</span>' +
            '</div>' +
            '<div class="bg-white border border-[#E8E0D5] rounded-2xl p-4 shadow-sm space-y-3">' +
              '<div class="text-[11px] font-bold text-[#8C6D46] uppercase">' + esc(item.subject) + '</div>' +
              '<div class="text-sm font-bold text-[#1F1B18]">' + esc(item.q) + '</div>' +
              '<button type="button" id="lsRevealAnsBtn" class="px-3.5 py-2 rounded-xl bg-[#FAF7F2] border border-[#7B1E2B] text-xs font-bold text-[#7B1E2B]">Reveal Answer</button>' +
              '<div id="lsFlashAns" class="hidden p-3 rounded-xl bg-[#ECFDF5] border border-[#A7F3D0] text-xs text-[#065F46] leading-relaxed">' + esc(item.a) + '</div>' +
              '<div class="flex justify-between pt-2">' +
                '<button type="button" id="lsDrillPrev" class="px-3 py-1.5 rounded-xl border border-[#D6C7BC] text-xs font-bold text-[#5F554E]">&larr; Prev</button>' +
                '<button type="button" id="lsDrillNext" class="px-4 py-1.5 rounded-xl bg-[#7B1E2B] text-white text-xs font-bold">Next Card &rarr;</button>' +
              '</div>' +
            '</div>' +
          '</div>';
        var rb = container.querySelector("#lsRevealAnsBtn");
        if (rb) rb.addEventListener("click", function () {
          var fa = container.querySelector("#lsFlashAns");
          if (fa) fa.classList.remove("hidden");
        });
      }

      var prev = container.querySelector("#lsDrillPrev");
      var next = container.querySelector("#lsDrillNext");
      var totalLen = mcqs.length || qaItems.length;
      if (prev) prev.addEventListener("click", function () { idx = (idx - 1 + totalLen) % totalLen; renderCard(); });
      if (next) next.addEventListener("click", function () { idx = (idx + 1) % totalLen; renderCard(); });
    }

    renderCard();
  }

  window.LSDrill = { render: renderExamDrill };
})();
