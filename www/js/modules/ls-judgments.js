(function () {
  "use strict";
  function esc(s) {
    return String(s || "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
  }

  function renderJudgments(container) {
    if (!container || !window.LSStore) return;
    var allCases = window.LSStore.extractCasesFromNotes();
    container.innerHTML =
      '<div class="space-y-3 pb-6">' +
        '<div class="bg-white border border-[#E8E0D5] rounded-2xl p-4 shadow-sm">' +
          '<div class="text-base font-bold text-[#7B1E2B]">Landmark Judgments (' + allCases.length + ')</div>' +
          '<p class="text-xs text-[#5F554E] mt-0.5">Search Supreme Court, High Court &amp; English precedents across all subjects.</p>' +
          '<input id="lsCaseSearchInput" type="search" placeholder="Search case name, fact, or subject..." class="mt-2.5 w-full px-3 py-2 rounded-xl border border-[#D6C7BC] text-xs bg-[#FAF7F2]" />' +
        '</div>' +
        '<div id="lsCaseListBox" class="space-y-2.5"></div>' +
      '</div>';

    var listBox = container.querySelector("#lsCaseListBox");
    var searchIn = container.querySelector("#lsCaseSearchInput");

    function paint(q) {
      var query = String(q || "").trim().toLowerCase();
      var filtered = query
        ? allCases.filter(function (c) {
            return (c.name + " " + c.facts + " " + c.subject).toLowerCase().indexOf(query) !== -1;
          })
        : allCases;
      var slice = filtered.slice(0, 60);
      if (!slice.length) {
        listBox.innerHTML = '<div class="text-xs text-center text-[#5F554E] py-8">No matching judgments found.</div>';
        return;
      }
      var rows = [];
      slice.forEach(function (c) {
        var saved = window.LSStore.isInShelf(c.id);
        rows.push(
          '<div class="bg-white border border-[#E8E0D5] rounded-2xl p-3.5 shadow-sm">' +
            '<div class="flex items-start justify-between gap-2">' +
              '<div class="text-xs font-bold text-[#7B1E2B]">' + esc(c.name) + '</div>' +
              '<button type="button" data-ls-shelf-id="' + esc(c.id) + '" data-ls-shelf-title="' + esc(c.name) + '" data-ls-shelf-sub="' + esc(c.subject) + '" class="text-[11px] px-2 py-0.5 rounded-full border border-[#7B1E2B] ' + (saved ? 'bg-[#7B1E2B] text-white' : 'text-[#7B1E2B]') + '">' + (saved ? 'Saved' : 'Save') + '</button>' +
            '</div>' +
            '<div class="text-[10.5px] font-semibold text-[#8C6D46] mt-0.5">' + esc(c.subject) + '</div>' +
            '<p class="text-xs text-[#3D352E] mt-1.5 leading-relaxed">' + esc(c.facts) + '</p>' +
            '<button type="button" data-ls-open-topic="' + esc(c.topicId) + '" class="mt-2 text-[11px] font-bold text-[#7B1E2B] underline">Open Full Topic Note &rarr;</button>' +
          '</div>'
        );
      });
      if (filtered.length > 60) {
        rows.push('<div class="text-[11px] text-center text-[#5F554E]">Showing top 60 of ' + filtered.length + ' results. Type to narrow down.</div>');
      }
      listBox.innerHTML = rows.join("");
    }

    paint("");
    searchIn.addEventListener("input", function () { paint(searchIn.value); });
  }

  window.LSJudgments = { render: renderJudgments };
})();
