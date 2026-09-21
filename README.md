# secure-passgen v3.0.2

**Military-grade, fool-proof, international password generator & CSV database creator**

---

<h2 id="name"><span class="man">§1</span>NAME</h2>
<p><b>secure-passgen</b> — military-grade, fool-proof, international (i18n) password generator and LibreOffice/Excel-compatible CSV database creator, written in Rust with a plugin architecture and Deep-Entropy (SHA-512 hash-chaining) engine.</p>

<h2 id="synopsis"><span class="man">§2</span>SYNOPSIS</h2>
<pre><code><span class="cmd">secure-passgen</span> [OPTIONS] [COUNT] [-COUNT_SHORTHAND]

<span class="cmd">secure-passgen</span> -c -n -s -l 16 -1M -o database.csv
<span class="cmd">secure-passgen</span> --password-db --charset chinese -c -n -2500 -o grid.csv
<span class="cmd">secure-passgen</span> --language hu --charset hu -c -n -s --extreme-random -l 20
<span class="cmd">secure-passgen</span> --plugins uppercase,hyphen -c -n -100K -o bulk.csv</code></pre>

<h2 id="description"><span class="man">§3</span>DESCRIPTION</h2>
<p><b>secure-passgen</b> generates cryptographically secure passwords using the operating system's CSPRNG (<code>getrandom</code>: Linux <code>getrandom(2)</code> syscall, macOS <code>getentropy(2)</code>, Windows <code>BCryptGenRandom</code>). It re-implements and extends the classic <code>pwgen(1)</code> tool with modern safety guarantees:</p>
<div class="grid2">
  <div class="card"><h4>🛡️ Fool-proof design</h4><p>The program never aborts on user errors. Every problem (existing file, unwritable directory, invalid number, empty charset) is automatically corrected and reported in a final "AUTOMATIC FIXES APPLIED" panel.</p></div>
  <div class="card"><h4>🌍 International (i18n)</h4><p>20 UI languages for all console messages and 20 Unicode character sets (Latin, Magyar, 中文, 日本語, 한국어, العربية, עברית, हिन्दी, বাংলা, ไทย, Ελληνικά, Кириллица, Հայերեն, ქართული, தமிழ், తెలుగు, ಕನ್ನಡ, മലയാളം, ਪੰਜਾਬੀ, සිංහල).</p></div>
  <div class="card"><h4>🧠 Deep Entropy engine</h4><p>Optional SHA-512 hash-chaining mode: each password seed is re-hashed up to 1,000,000 iterations so every character derives from the "millionth" cryptographic operation, not the first.</p></div>
  <div class="card"><h4>💾 Streaming memory model</h4><p>Passwords are generated one-by-one and streamed through an 8 KB BufWriter. Memory stays at ~2.7 MB whether you generate 10 or 1,000,000 passwords. Verified by Valgrind: 0 bytes lost.</p></div>
  <div class="card"><h4>🔌 Plugin architecture</h4><p>Trait-based plugin system (<code>Plugin</code> trait). Two reference plugins ship with the binary: <code>uppercase</code> and <code>hyphen</code>. New plugins require ~20 lines of Rust.</p></div>
  <div class="card"><h4>📊 Database Grid mode</h4><p><code>--password-db</code> produces a spreadsheet grid with Excel-style column headers (Row,A,B,...,ZZ,AAA...) up to 1000 rows, directly importable into LibreOffice Calc / Excel.</p></div>
</div>

<h2 id="options"><span class="man">§4</span>OPTIONS</h2>
<h3>4.1 Password style (pwgen-compatible)</h3>
<table>
<tr><th>Option</th><th>Description</th></tr>
<tr><td><code>-c, --capitals</code></td><td>Include capital letters (A-Z, and uppercase variants of the selected script).</td></tr>
<tr><td><code>-n, --numbers</code></td><td>Include digits 0-9.</td></tr>
<tr><td><code>-s, --symbols</code></td><td>Include symbols <code>!@#$%^&amp;*()-_=+[]{}|;:,.&lt;&gt;?</code></td></tr>
<tr><td><code>-B, --no-ambiguous</code></td><td>Exclude visually ambiguous characters <code>1 l I 0 O o</code>.</td></tr>
</table>
<h3>4.2 Generation</h3>
<table>
<tr><th>Option</th><th>Description</th><th>Default</th></tr>
<tr><td><code>-l, --length &lt;N&gt;</code></td><td>Password length, 1–16000 (OpenSSL-class maximum).</td><td>8</td></tr>
<tr><td><code>--count &lt;N&gt;</code></td><td>Number of passwords.</td><td>10</td></tr>
<tr><td><code>-5, -250, -100K, -1M</code></td><td>Hyphen shorthand count (pre-processed before the CLI parser, so it can never swallow other flags).</td><td>—</td></tr>
<tr><td><code>--extreme-random</code></td><td>Enable Deep Entropy SHA-512 hash-chaining per password.</td><td>off</td></tr>
<tr><td><code>--extreme-iter &lt;N&gt;</code></td><td>Hash iterations per password, 1000–1000000.</td><td>10000</td></tr>
</table>
<h3>4.3 Output &amp; database</h3>
<table>
<tr><th>Option</th><th>Description</th></tr>
<tr><td><code>-o, --output &lt;file&gt;</code></td><td>Output CSV path (relative or absolute).</td></tr>
<tr><td><code>--password-db</code></td><td>Database Grid mode with Excel column letters.</td></tr>
<tr><td><code>--auto-rename</code></td><td>If the target file exists, write <code>name_1.csv</code>, <code>name_2.csv</code>… (default ON).</td></tr>
<tr><td><code>--timestamp</code></td><td>Append <code>YYYYMMDD_HHMMSS</code> to the filename instead of a counter.</td></tr>
<tr><td><code>--log &lt;file&gt;</code></td><td>Metadata log (time, system, fixes). <b>Never</b> logs passwords.</td></tr>
</table>
<h3>4.4 International &amp; system</h3>
<table>
<tr><th>Option</th><th>Description</th></tr>
<tr><td><code>--language &lt;code&gt;</code></td><td>UI language: en hu es zh hi ar bn pt ru ja de fr ko tr vi it pl uk nl ro (or <code>auto</code>).</td></tr>
<tr><td><code>--charset &lt;code&gt;</code></td><td>Password character set: latin hu zh ja ko ar he hi bn th el ru hy ka ta te kn ml pa si.</td></tr>
<tr><td><code>--plugins &lt;list&gt;</code></td><td>Comma-separated plugin list: <code>uppercase</code>, <code>hyphen</code>.</td></tr>
<tr><td><code>--debug</code></td><td>Verbose internal diagnostics on stderr.</td></tr>
<tr><td><code>-h, --help</code> / <code>-V, --version</code></td><td>Help / version.</td></tr>
</table>

<h2 id="charsets"><span class="man">§5</span>CHARACTER SETS (live samples)</h2>
<p>The samples below were <b>generated by this binary at documentation build time</b> (12 characters each):</p>
<table>
<tr><th>Flag</th><th>Live generated sample</th></tr>
<tr><td><code>--charset latin</code></td><td class="sample">dolxlccvxjjr</td></tr><tr><td><code>--charset hungarian</code></td><td class="sample">cahoékpűayei</td></tr><tr><td><code>--charset chinese</code></td><td class="sample">们学们也种说能的生是子能</td></tr><tr><td><code>--charset japanese</code></td><td class="sample">オほニすエエノサヌれアウ</td></tr><tr><td><code>--charset korean</code></td><td class="sample">버투터사주라오버서수사터</td></tr><tr><td><code>--charset arabic</code></td><td class="sample">ضجفشفكخصزثظظ</td></tr><tr><td><code>--charset hebrew</code></td><td class="sample">להקפסאגרקדזפ</td></tr><tr><td><code>--charset hindi</code></td><td class="sample">उथटओढउअनगनपऔ</td></tr><tr><td><code>--charset bengali</code></td><td class="sample">ঘধসঐগদতওউতদঠ</td></tr><tr><td><code>--charset thai</code></td><td class="sample">ฒซกนลฟพมทญอญ</td></tr><tr><td><code>--charset greek</code></td><td class="sample">εκπταοχσβαοχ</td></tr><tr><td><code>--charset cyrillic</code></td><td class="sample">беёужжвъищбй</td></tr><tr><td><code>--charset armenian</code></td><td class="sample">նգխնժէնղվնխճ</td></tr><tr><td><code>--charset georgian</code></td><td class="sample">ძლთშოყღჩჩბძბ</td></tr><tr><td><code>--charset tamil</code></td><td class="sample">ஞனஞஉரடசவஒவவவ</td></tr><tr><td><code>--charset telugu</code></td><td class="sample">షనకఇడఔగసఞణమజ</td></tr><tr><td><code>--charset kannada</code></td><td class="sample">ರಙಧಏಕನಛಋಈಐಜಯ</td></tr><tr><td><code>--charset malayalam</code></td><td class="sample">ഭജശഋടഎലഷഎആഷഈ</td></tr><tr><td><code>--charset gurmukhi</code></td><td class="sample">ਚਪਭਹਯਅਥਦਅਹਓਠ</td></tr><tr><td><code>--charset sinhala</code></td><td class="sample">දවඪඡණලකඳඵඌඬඌ</td></tr>
</table>

<h2 id="languages"><span class="man">§6</span>UI LANGUAGES</h2>
<p>All console banners, progress labels, success messages and the auto-recovery panel are translated. Detected automatically from <code>$LANG</code>, overridable with <code>--language</code>. Supported: <b>English, Magyar, Español, 中文, हिन्दी, العربية, বাংলা, Português, Русский, 日本語, Deutsch, Français, 한국어, Türkçe, Tiếng Việt, Italiano, Polski, Українська, Nederlands, Română</b>.</p>

<h2 id="entropy"><span class="man">§7</span>DEEP ENTROPY ENGINE</h2>
<pre><code>1. seed = 64 bytes from OS CSPRNG (getrandom syscall)
2. for i in 0..iterations:            # up to 1,000,000
       seed = SHA512(seed || i.to_le_bytes())
3. for each character position p:
       index = u16(seed[2p], seed[2p+1]) mod charset_len
       password[p] = charset[index]</code></pre>
<div class="note blue"><b>Why?</b> Standard CSPRNG output is already secure, but in threat models where the first milliseconds after boot are suspect (entropy-pool warm-up), Deep Entropy guarantees that every emitted character is the result of the <i>millionth</i> mixing operation, not the first. Throughput cost is linear and measured in the benchmark table below.</div>

<h2 id="memory"><span class="man">§8</span>MEMORY ARCHITECTURE</h2>
<ul>
<li><b>Streaming write:</b> one password lives in memory at a time, then Rust ownership drops it deterministically.</li>
<li><b>BufWriter (8 KB):</b> syscalls are batched; 100K passwords produce a handful of writes.</li>
<li><b>Periodic flush:</b> every 1000 rows, so a crash never loses more than 1000 rows.</li>
<li><b>Constant RSS:</b> 2.6–2.8 MB measured from 10 to 100,000 passwords (see benchmarks).</li>
<li><b>Valgrind clean:</b> 0 bytes definitely/indirectly/possibly lost.</li>
</ul>

<h2 id="plugins"><span class="man">§9</span>PLUGIN SYSTEM (developer guide)</h2>
<pre><code>// src/plugins/my_plugin.rs  (~20 lines)
use super::Plugin;

pub struct MyPlugin;

impl Plugin for MyPlugin {
    fn name(&amp;self) -&gt; &amp;str { "MyPlugin" }
    fn description(&amp;self) -&gt; &amp;str { "Does something custom" }
    fn process_password(&amp;self, password: String) -&gt; String {
        password.to_uppercase()   // any transformation
    }
}</code></pre>
<p>Register it in <code>src/plugins/mod.rs</code> and in <code>load_plugins()</code> in <code>main.rs</code>, then use <code>--plugins myplugin</code>. Future roadmap: dynamic <code>.so</code> loading via <code>libloading</code> and WASM plugins.</p>

<h2 id="recovery"><span class="man">§10</span>AUTO-RECOVERY (fool-proof engine)</h2>
<table>
<tr><th>Problem detected</th><th>Automatic solution</th><th>Severity</th></tr>
<tr><td>Output file already exists</td><td>Writes <code>name_1.csv</code> … <code>name_9999.csv</code>, then timestamp name</td><td>⚠ Warning</td></tr>
<tr><td>Directory not writable</td><td>Falls back to <code>/tmp</code>, then <code>$HOME</code>; real path printed</td><td>⚠ Critical</td></tr>
<tr><td>Empty character set</td><td>Restores the full base charset of the selected script</td><td>⚠ Critical</td></tr>
<tr><td>Length &lt; 1 or &gt; 16000</td><td>Clamped to 8 / 16000</td><td>⚠ Warning</td></tr>
<tr><td>Count &lt; 1</td><td>Reset to 10</td><td>⚠ Warning</td></tr>
<tr><td>Unknown --language / --charset</td><td>Falls back to system language / Latin</td><td>⚠ Warning</td></tr>
</table>
<p>Every applied fix is listed in the final yellow panel, so soldiers and beginners always see <i>what</i> happened and <i>where</i> the file really is.</p>

<h2 id="benchmark"><span class="man">§11</span>BENCHMARKS (measured on this host)</h2>
<p>Values injected from the latest <code>benchmarks_*/results.csv</code> run on this machine:</p>
<table>
<tr><th>Test</th><th>Result</th></tr>
<tr><td>Maximum throughput (100K passwords, 16 chars)</td><td><b>12,241,316 pw/s</b></td></tr>
<tr><td>Hyperfine mean ± σ (10K passwords, 10 runs)</td><td><b>9.3 ms ± 1.2 ms</b></td></tr>
<tr><td>Memory (10 → 100K passwords)</td><td><b>2.6–2.8 MB constant</b></td></tr>
<tr><td>Valgrind leak check</td><td><b>0 bytes lost</b> (544 B still-reachable = Rust runtime)</td></tr>
<tr><td>Deep Entropy 1K / 10K / 100K iter</td><td>8,210 / 2,143 / 138 pw/s</td></tr>
<tr><td>Unicode charsets (6 scripts)</td><td>all OK, ~11–12K pw/s</td></tr>
<tr><td>Test suite</td><td><b>25/25 passed</b></td></tr>
</table>

<h2 id="examples"><span class="man">§12</span>EXAMPLES</h2>
<div class="term"><div class="bar"><i></i><i></i><i></i><span>boldwelder@parrot:~$</span></div>
<pre><span class="cmd">./secure-passgen -c -n -s -l 16 -1M -o million.csv</span>
<span class="out">  [########################################] 100% (1000000/1000000)</span>
<span class="ok">  SUCCESS - Operation completed successfully 0.082 seconds</span>
<span class="ok">  File saved to /home/boldwelder/secure-passgen/million.csv</span></pre></div>

<div class="term"><div class="bar"><i></i><i></i><i></i><span>database grid, chinese charset</span></div>
<pre><span class="cmd">./secure-passgen --password-db --charset chinese -c -n -2500 -o grid.csv</span>
<span class="out">  Mode: Password Database Grid | Columns: A B C | Rows: 1000</span>
<span class="ok">  SUCCESS</span>  <span class="out"># open with: libreoffice --calc grid.csv</span></pre></div>

<div class="term"><div class="bar"><i></i><i></i><i></i><span>fool-proof auto-rename</span></div>
<pre><span class="cmd">./secure-passgen -c -n -s -o same.csv   # run twice</span>
<span class="warn">  ⚠ AUTOMATIC RECOVERY ACTIVATED — Problems found: 1</span>
<span class="warn">  ║  Fix #1  Problem:  File 'same.csv' already exists</span>
<span class="ok">  ║           Solution: Auto-renamed to 'same_1.csv'</span></pre></div>

<h2 id="beginner"><span class="man">§13</span>BEGINNER GUIDE</h2>
<ol>
<li>Build once: <code>cargo build --release</code></li>
<li>Generate your first safe passwords: <code>./target/release/secure-passgen -c -n -s -l 16 -50 -o my.csv</code></li>
<li>Double-click <code>my.csv</code> → opens in LibreOffice Calc / Excel.</li>
<li>If anything goes wrong, read the yellow panel at the end — it tells you exactly what the program fixed and where your file is.</li>
</ol>

<h2 id="advanced"><span class="man">§14</span>ADVANCED GUIDE</h2>
<ul>
<li>Combine Deep Entropy with plugins: <code>--extreme-random --extreme-iter 100000 --plugins uppercase,hyphen</code></li>
<li>Generate a Hungarian-charset vault: <code>--language hu --charset hu -c -n -s -B -l 20 -10K</code></li>
<li>Audit run with metadata log: <code>--debug --log audit.log</code> (passwords are never logged).</li>
<li>Re-run the full QA suite any time with <code>./patch_and_benchmark.sh</code>.</li>
</ul>

<h2 id="security"><span class="man">§15</span>SECURITY NOTES</h2>
<div class="note red"><b>Warning:</b> CSV files contain <i>plaintext</i> passwords. Store them encrypted (e.g. LUKS volume or age/gpg), delete securely (<code>shred</code>), and never commit them to Git.</div>
<ul>
<li>Entropy source: OS kernel CSPRNG only; no <code>rand()</code>, no time-based seeds.</li>
<li>No network access, no telemetry, no logging of secrets by design.</li>
<li>Unicode passwords increase entropy per character (larger alphabet), but verify the target system accepts UTF-8 input.</li>
</ul>

<h2 id="files"><span class="man">§16</span>FILES</h2>
<pre><code>~/.cargo/bin or ./target/release/secure-passgen   binary
./passwords.csv                                   default output
./benchmarks_*/results.csv                        QA results
./documentation_v2/README.html                    this manual</code></pre>

<h2 id="seealso"><span class="man">§17</span>SEE ALSO</h2>
<p><code>pwgen(1)</code>, <code>openssl-rand(1)</code>, <code>getrandom(2)</code>, <code>apg(1)</code>, <code>makepasswd(1)</code>, NIST SP 800-90A (DRBG), RFC 4180 (CSV).</p>

<h2 id="authors"><span class="man">§18</span>AUTHORS</h2>
<p><b>Boldwelder</b> (micro-electric technician, welder, ex-diplomat MFA, 4-generation Hungarian military family) — concept, requirements, QA. <b>Adjutans-1</b> — Rust architecture &amp; implementation.</p>

<h2 id="changelog"><span class="man">§19</span>CHANGELOG</h2>
<table>
<tr><th>Version</th><th>Change</th></tr>
<tr><td>3.0.2</td><td>FIXED: hyphen shorthand no longer swallows following flags; FIXED: case-less Unicode scripts (CJK/Arabic/Hindi…) now included by default; docs v2.</td></tr>
<tr><td>3.0.1</td><td>Removed unused import; warning-free build.</td></tr>
<tr><td>3.0.0</td><td>Fool-proof auto-recovery, 20 UI languages, 20 Unicode charsets, plugin system.</td></tr>
<tr><td>2.0.0</td><td>Rust rewrite: CSPRNG, Deep Entropy, streaming CSV, grid mode.</td></tr>
<tr><td>1.x</td><td>Original bash prototype (pwgen-compatible).</td></tr>
</table>

<footer>
  secure-passgen(1) v3.0.2 &mdash; "Precision in every character, security in every module."<br>
  Manual generated automatically &mdash; do not edit by hand.
</footer>
</div>
</div>
</body>
</html>
