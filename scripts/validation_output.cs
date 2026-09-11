using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading.Tasks;

// Drain pipes independently of PowerShell/telemetry so noisy children cannot
// deadlock. Full lines go to disk immediately; the caller chooses display detail.
public sealed class AlpineValidationOutput {
    static readonly Regex EngineError = new Regex(@"^(ERROR:|SCRIPT ERROR:|Parse Error)");
    static readonly Regex TestFailure = new Regex(@"^FAIL(?::|\s)");
    readonly ConcurrentQueue<string> pending = new ConcurrentQueue<string>();
    public volatile bool HasEngineError;
    public volatile bool HasTestFailure;
    public Task Completion { get; private set; }

    public AlpineValidationOutput(StreamReader reader, string path) {
        Completion = Task.Run(async () => {
            using (var file = new FileStream(path, FileMode.Create, FileAccess.Write, FileShare.ReadWrite))
            using (var writer = new StreamWriter(file, new UTF8Encoding(false)) { AutoFlush = true }) {
                string line;
                while ((line = await reader.ReadLineAsync().ConfigureAwait(false)) != null) {
                    await writer.WriteLineAsync(line).ConfigureAwait(false);
                    if (EngineError.IsMatch(line)) HasEngineError = true;
                    if (TestFailure.IsMatch(line)) HasTestFailure = true;
                    pending.Enqueue(line);
                }
            }
        });
    }

    public string[] Drain() {
        var lines = new List<string>();
        string line;
        while (pending.TryDequeue(out line)) lines.Add(line);
        return lines.ToArray();
    }
}
