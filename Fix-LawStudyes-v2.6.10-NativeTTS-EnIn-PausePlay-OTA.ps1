<#
.SYNOPSIS
  Law Studyes v2.6.10 - Fixes Native Android Text-to-Speech ("TTS Unavailable"),
  Fixes Arabic Default Voice (Forces en-IN / te-IN), Fixes Pause & Play (Resume from Exact Sentence),
  Builds Clean Signed Release APK v2.6.10 (versionCode 270), and Pushes Verified OTA to GitHub & Vercel!
.USAGE
  Run inside C:\Users\khoda\OneDrive\Desktop\law-studyes-offline-apk-kit:
    powershell -ExecutionPolicy Bypass -File .\Fix-LawStudyes-v2.6.10-NativeTTS-EnIn-PausePlay-OTA.ps1
#>

$ErrorActionPreference = "Stop"
$u = New-Object System.Text.UTF8Encoding $false
$root = (Get-Location).Path
$ver = "2.6.10"
$verCode = 270

Write-Host "`n=== 1. Patching www/index.html with Native Capacitor TTS (en-IN / te-IN + Sentence-Level Pause/Play) ===" -ForegroundColor Cyan
$idx = Join-Path $root "www\index.html"
$h = [System.IO.File]::ReadAllText($idx, $u)

# Remove any older managed TTS block
$h = [regex]::Replace($h, '(?s)<!-- LS_NATIVE_TTS_V2610_START -->.*?<!-- LS_NATIVE_TTS_V2610_END -->', '')

# Bump version labels cleanly to 2.6.10
$h = $h -replace '3-Year LL\.B\. [^<"]*Audio &amp; Sync( [^<"]*v[\d\.]+)?', "3-Year LL.B. &middot; All Years Audio &amp; Sync &middot; v$ver"
$h = $h -replace 'var BUILT_IN = "[^"]+";', "var BUILT_IN = `"$ver`";"
$h = $h -replace 'var BUILT_IN_VER = "[^"]+";', "var BUILT_IN_VER = `"$ver`";"
$h = $h -replace 'var CURRENT_APP_VER = "[^"]+";', "var CURRENT_APP_VER = `"$ver`";"
$h = $h -replace 'var APP_VER = "[^"]+";', "var APP_VER = `"$ver`";"

$ttsPatch = @'
<!-- LS_NATIVE_TTS_V2610_START -->
<script>
(function () {
  if (window.__lsNativeTtsV2610) return;
  window.__lsNativeTtsV2610 = true;

  var ttsState = {
    playing: false,
    paused: false,
    chunks: [],
    index: 0,
    runId: 0,
    rate: 1.0,
    lang: "en-IN"
  };

  function getNativeTts() {
    return window.Capacitor && window.Capacitor.Plugins && window.Capacitor.Plugins.TextToSpeech;
  }

  function getTargetLang() {
    var cur = (typeof state !== "undefined" && state && state.lang) ? String(state.lang).toLowerCase() : "";
    if (!cur) {
      try { cur = (localStorage.getItem("law_studyes_lang") || "en").toLowerCase(); } catch (e) { cur = "en"; }
    }
    return cur === "te" ? "te-IN" : "en-IN";
  }

  function getReadingText() {
    var pane = document.getElementById("readingPane");
    if (!pane) return "";
    // Clone so we can strip visual diagram SVG/code/buttons before reading legal prose
    var clone = pane.cloneNode(true);
    clone.querySelectorAll("script, style, svg, button, #lsVisualDiagramsSection, .ls-visual-card, .mermaid").forEach(function (el) {
      el.remove();
    });
    var raw = (clone.innerText || clone.textContent || "").replace(/\s+/g, " ").trim();
    return raw;
  }

  function splitIntoChunks(text) {
    if (!text) return [];
    // Split on sentence boundaries (English & Telugu) while keeping chunks under ~220 chars for responsive Pause/Resume
    var parts = text.match(/[^.!?\u0964\n]+[.!?\u0964\n]*/g) || [text];
    var chunks = [];
    var buf = "";
    for (var i = 0; i < parts.length; i++) {
      var s = parts[i].trim();
      if (!s) continue;
      if ((buf + " " + s).length > 220 && buf) {
        chunks.push(buf.trim());
        buf = s;
      } else {
        buf = buf ? (buf + " " + s) : s;
      }
    }
    if (buf.trim()) chunks.push(buf.trim());
    return chunks;
  }

  function updateTtsButtonsUI() {
    var playBtns = document.querySelectorAll("#playAudioBtn, #listenBtn, #ttsPlayBtn, [data-tts-action='play'], [data-tts-action='toggle']");
    playBtns.forEach(function (btn) {
      if (ttsState.playing && !ttsState.paused) {
        btn.setAttribute("data-tts-state", "playing");
        if (/play|listen|resume/i.test(btn.textContent || "")) {
          btn.textContent = "Pause";
        }
      } else if (ttsState.paused) {
        btn.setAttribute("data-tts-state", "paused");
        if (/pause|play|listen/i.test(btn.textContent || "")) {
          btn.textContent = "Resume";
        }
      } else {
        btn.setAttribute("data-tts-state", "stopped");
        if (/pause|resume/i.test(btn.textContent || "")) {
          btn.textContent = "Listen";
        }
      }
    });
  }

  // Pick an explicit en-IN (or te-IN) voice index for Capacitor TTS; NEVER pick Arabic (ar-*)
  var cachedVoiceIdx = {};
  async function resolveNativeVoice(nativeTts, targetLang) {
    if (cachedVoiceIdx[targetLang] !== undefined) return cachedVoiceIdx[targetLang];
    var result = { lang: targetLang, voice: undefined };
    try {
      if (typeof nativeTts.getSupportedVoices === "function") {
        var res = await nativeTts.getSupportedVoices();
        var voices = (res && Array.isArray(res.voices)) ? res.voices : [];
        var exact = -1, prefixMatch = -1, enFallback = -1;
        var prefix = targetLang.split("-")[0].toLowerCase(); // "en" or "te"
        for (var i = 0; i < voices.length; i++) {
          var vLang = String((voices[i] && voices[i].lang) || "").toLowerCase().replace("_", "-");
          // Strictly skip Arabic or unrelated locales
          if (vLang.indexOf("ar") === 0) continue;
          if (vLang === targetLang.toLowerCase()) { exact = i; break; }
          if (prefixMatch === -1 && vLang.indexOf(prefix + "-") === 0) prefixMatch = i;
          if (prefix === "en" && enFallback === -1 && (vLang === "en-gb" || vLang === "en-us")) enFallback = i;
        }
        var chosen = exact !== -1 ? exact : (prefixMatch !== -1 ? prefixMatch : enFallback);
        if (chosen !== -1) {
          result.voice = chosen;
          result.lang = voices[chosen].lang || targetLang;
        }
      }
    } catch (e) {}
    cachedVoiceIdx[targetLang] = result;
    return result;
  }

  function pickWebVoice(targetLang) {
    if (!window.speechSynthesis || typeof window.speechSynthesis.getVoices !== "function") return null;
    var voices = window.speechSynthesis.getVoices() || [];
    var prefix = targetLang.split("-")[0].toLowerCase();
    var exact = null, pref = null;
    for (var i = 0; i < voices.length; i++) {
      var vl = String(voices[i].lang || "").toLowerCase().replace("_", "-");
      if (vl.indexOf("ar") === 0) continue;
      if (vl === targetLang.toLowerCase()) { exact = voices[i]; break; }
      if (!pref && vl.indexOf(prefix + "-") === 0) pref = voices[i];
    }
    return exact || pref;
  }

  async function speakNextChunk(myRunId) {
    if (myRunId !== ttsState.runId || !ttsState.playing || ttsState.paused) return;
    if (ttsState.index >= ttsState.chunks.length) {
      ttsState.playing = false;
      ttsState.paused = false;
      ttsState.index = 0;
      updateTtsButtonsUI();
      if (typeof showToast === "function") showToast("Finished reading note.");
      return;
    }

    var chunk = ttsState.chunks[ttsState.index];
    var nativeTts = getNativeTts();
    var targetLang = ttsState.lang;

    if (nativeTts && typeof nativeTts.speak === "function") {
      try {
        var resolved = await resolveNativeVoice(nativeTts, targetLang);
        var opts = {
          text: chunk,
          lang: resolved.lang || targetLang,
          rate: ttsState.rate || 1.0,
          pitch: 1.0,
          volume: 1.0,
          category: "ambient"
        };
        if (typeof resolved.voice === "number") opts.voice = resolved.voice;
        await nativeTts.speak(opts);
        if (myRunId !== ttsState.runId || !ttsState.playing || ttsState.paused) return;
        ttsState.index++;
        speakNextChunk(myRunId);
        return;
      } catch (err) {
        // Fallback to standard en-US if te-IN/en-IN pack is missing on device
        if (targetLang !== "en-US") {
          try {
            await nativeTts.speak({ text: chunk, lang: "en-US", rate: ttsState.rate || 1.0, pitch: 1.0, volume: 1.0 });
            if (myRunId !== ttsState.runId || !ttsState.playing || ttsState.paused) return;
            ttsState.index++;
            speakNextChunk(myRunId);
            return;
          } catch (e2) {}
        }
      }
    }

    // Web Speech API fallback (for desktop browser preview)
    if (typeof window.speechSynthesis !== "undefined" && typeof SpeechSynthesisUtterance !== "undefined") {
      try {
        window.speechSynthesis.cancel();
        var utt = new SpeechSynthesisUtterance(chunk);
        utt.lang = targetLang;
        utt.rate = ttsState.rate || 1.0;
        var wv = pickWebVoice(targetLang);
        if (wv) utt.voice = wv;
        utt.onend = function () {
          if (myRunId !== ttsState.runId || !ttsState.playing || ttsState.paused) return;
          ttsState.index++;
          speakNextChunk(myRunId);
        };
        utt.onerror = function () {
          if (myRunId !== ttsState.runId) return;
          ttsState.playing = false;
          ttsState.paused = false;
          updateTtsButtonsUI();
        };
        window.speechSynthesis.speak(utt);
        return;
      } catch (we) {}
    }

    ttsState.playing = false;
    ttsState.paused = false;
    updateTtsButtonsUI();
    if (typeof showToast === "function") showToast("Install Google Speech Services on Android to enable audio.");
  }

  async function stopEngineOnly() {
    var nativeTts = getNativeTts();
    if (nativeTts && typeof nativeTts.stop === "function") {
      try { await nativeTts.stop(); } catch (e) {}
    }
    if (typeof window.speechSynthesis !== "undefined") {
      try { window.speechSynthesis.cancel(); } catch (e) {}
    }
  }

  window.stopAudio = async function () {
    ttsState.runId++;
    ttsState.playing = false;
    ttsState.paused = false;
    ttsState.index = 0;
    await stopEngineOnly();
    updateTtsButtonsUI();
  };

  window.pauseAudio = async function () {
    if (!ttsState.playing || ttsState.paused) return;
    ttsState.runId++;
    ttsState.paused = true;
    await stopEngineOnly();
    updateTtsButtonsUI();
    if (typeof showToast === "function") showToast("Audio paused");
  };

  window.playAudio = async function (customText) {
    // If paused, resume from the exact sentence chunk!
    if (ttsState.paused && ttsState.chunks.length > 0 && !customText) {
      ttsState.paused = false;
      ttsState.playing = true;
      ttsState.runId++;
      updateTtsButtonsUI();
      speakNextChunk(ttsState.runId);
      return;
    }

    var text = (typeof customText === "string" && customText.trim()) ? customText.trim() : getReadingText();
    if (!text) {
      if (typeof showToast === "function") showToast("Open a topic note first to listen.");
      return;
    }

    ttsState.runId++;
    await stopEngineOnly();
    ttsState.lang = getTargetLang();
    ttsState.chunks = splitIntoChunks(text);
    ttsState.index = 0;
    ttsState.playing = true;
    ttsState.paused = false;
    updateTtsButtonsUI();
    speakNextChunk(ttsState.runId);
  };

  window.toggleAudio = function () {
    if (ttsState.playing && !ttsState.paused) {
      return window.pauseAudio();
    }
    return window.playAudio();
  };

  window.setAudioRate = function (r) {
    var num = parseFloat(r);
    if (!isNaN(num) && num >= 0.5 && num <= 2.0) {
      ttsState.rate = num;
    }
  };

  // Intercept any Play / Pause / Stop / Listen button clicks in capture phase so broken web-only TTS never fires
  document.addEventListener("click", function (ev) {
    var btn = ev.target && ev.target.closest ? ev.target.closest("button") : null;
    if (!btn) return;
    var id = (btn.id || "").toLowerCase();
    var txt = (btn.textContent || "").trim().toLowerCase();
    if (id === "playaudiobtn" || id === "listenbtn" || id === "ttsplaybtn" || id === "toggleaudiobtn") {
      ev.preventDefault();
      ev.stopImmediatePropagation();
      window.toggleAudio();
      return;
    }
    if (id === "pauseaudiobtn" || id === "ttspausebtn") {
      ev.preventDefault();
      ev.stopImmediatePropagation();
      if (ttsState.paused) window.playAudio();
      else window.pauseAudio();
      return;
    }
    if (id === "stopaudiobtn" || id === "ttsstopbtn") {
      ev.preventDefault();
      ev.stopImmediatePropagation();
      window.stopAudio();
      return;
    }
    // Catch unlabeled audio control buttons by aria-label/title
    var lbl = ((btn.getAttribute("aria-label") || "") + " " + (btn.getAttribute("title") || "")).toLowerCase();
    if (lbl.indexOf("read aloud") !== -1 || lbl.indexOf("text to speech") !== -1 || txt === "listen" || txt === "pause audio" || txt === "resume audio") {
      ev.preventDefault();
      ev.stopImmediatePropagation();
      window.toggleAudio();
    }
  }, true);
})();
</script>
<!-- LS_NATIVE_TTS_V2610_END -->
'@
$h = $h.Replace('</body>', ($ttsPatch + "`r`n</body>"))
[System.IO.File]::WriteAllText($idx, $h, $u)

# Verify 0 JS syntax errors across every inline <script> tag
$i = 0; $fails = 0
[regex]::Matches($h, '(?s)<script>(.*?)</script>') | ForEach-Object {
  $i++; $tmp = "$env:TEMP\ls_chk_2610_$i.js"
  [System.IO.File]::WriteAllText($tmp, $_.Groups[1].Value, $u)
  $err = node --check $tmp 2>&1
  if ($LASTEXITCODE -ne 0) { $fails++; Write-Host "Script #$i FAIL: $err" -ForegroundColor Red }
}
if ($fails -gt 0) { throw "$fails JS error(s) found in www/index.html!" }
Write-Host "[PASS] All $i inline JS blocks verified (0 errors)! Native TTS (en-IN/te-IN + Pause/Resume) wired." -ForegroundColor Green

Write-Host "`n=== 2. Building Clean Signed Release APK v$ver (versionCode $verCode) ===" -ForegroundColor Cyan
$bg = Join-Path $root "android\app\build.gradle"
$bgTxt = [System.IO.File]::ReadAllText($bg, $u)
$bgTxt = $bgTxt -replace 'versionCode\s+\d+', "versionCode $verCode"
$bgTxt = $bgTxt -replace 'versionName\s+"[^"]+"', "versionName `"$ver`""
[System.IO.File]::WriteAllText($bg, $bgTxt, $u)

Remove-Item (Join-Path $root "www\LawStudyes-Offline.apk"), (Join-Path $root "www\ota-bundle.zip") -ErrorAction SilentlyContinue
npx cap sync android
if ($LASTEXITCODE -ne 0) { throw "npx cap sync android failed!" }

Push-Location ".\android"
try {
  .\gradlew.bat assembleRelease
  if ($LASTEXITCODE -ne 0) { throw "Gradle assembleRelease failed!" }
} finally {
  Pop-Location
}

$apk = ".\android\app\build\outputs\apk\release\app-release.apk"
$dest = Join-Path ([Environment]::GetFolderPath("Desktop")) "LawStudyes-v$ver-NativeTTS-EnIn-OTA.apk"
Copy-Item $apk $dest -Force
Copy-Item $apk (Join-Path $root "www\LawStudyes-Offline.apk") -Force
$apkMB = [Math]::Round((Get-Item $dest).Length / 1MB, 2)
Write-Host "[SUCCESS] Clean Desktop APK ready: $dest ($apkMB MB)" -ForegroundColor Green

Write-Host "`n=== 3. Pushing Verified OTA Bundle + APK to GitHub & Vercel ===" -ForegroundColor Cyan
& (Join-Path $root "Push-LawStudyes-OTA.ps1")
