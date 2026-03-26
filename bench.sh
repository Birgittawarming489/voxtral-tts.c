#!/bin/bash
# Voxtral TTS.c Benchmark Script
#
# Usage: ./bench.sh <model-dir> [voice]
#
# Example: ./bench.sh voxtral-tts-model neutral_female

set -e

MODEL="${1:?Usage: $0 <model-dir> [voice]}"
VOICE="${2:-neutral_female}"
BIN="$(dirname "$0")/voxtral_tts"
SEED=42

if [ ! -f "$BIN" ]; then
    echo "Binary not found at $BIN — run 'make blas' first"
    exit 1
fi

if [ ! -f "$MODEL/consolidated.safetensors" ]; then
    echo "Model not found at $MODEL — run './download_model.sh $MODEL' first"
    exit 1
fi

echo "=== Voxtral TTS.c Benchmarks ==="
echo "System: $(lscpu 2>/dev/null | grep 'Model name' | sed 's/.*: *//' || echo 'unknown')"
echo "RAM: $(free -h 2>/dev/null | awk '/Mem:/{print $2}' || echo 'unknown')"
echo "Voice: $VOICE"
echo "Seed: $SEED"
echo ""

texts=(
    "Hello world"
    "The quick brown fox jumps over the lazy dog"
    "I believe whatever doesn't kill you simply makes you stranger. That's a famous quote from a movie."
    "Artificial intelligence is transforming how we interact with technology. From voice assistants to autonomous vehicles, AI systems are becoming more capable every day. The future holds incredible possibilities."
)
labels=(
    "Hello world (2w)"
    "Quick brown fox (9w)"
    "Two sentences (17w)"
    "Paragraph (40w)"
)

printf "%-30s %7s %7s %8s %10s %6s\n" "Input" "Tokens" "Frames" "Audio" "Time" "RTF"
printf "%s\n" "------------------------------------------------------------------------"

for i in "${!texts[@]}"; do
    text="${texts[$i]}"
    label="${labels[$i]}"
    out=$(mktemp /tmp/bench_XXXXXX.wav)

    start_ns=$(date +%s%N)
    output=$("$BIN" -d "$MODEL" -v "$VOICE" -s "$SEED" --verbose -o "$out" "$text" 2>&1)
    end_ns=$(date +%s%N)

    total_ms=$(( (end_ns - start_ns) / 1000000 ))

    n_tokens=$(echo "$output" | grep "Text tokenized" | sed 's/[^0-9]//g')
    n_frames=$(echo "$output" | grep "Generated .* audio frames" | sed 's/.*Generated \([0-9]*\).*/\1/')
    audio_s=$(echo "$output" | grep "Generated .* audio frames" | sed 's/.*(\([0-9.]*\) seconds.*/\1/')

    total_s=$(echo "$total_ms" | awk '{printf "%.1f", $1/1000}')
    rtf=$(echo "$total_ms $audio_s" | awk '{if ($2+0 > 0) printf "%.1f", ($1/1000)/$2; else print "N/A"}')

    printf "%-30s %7s %7s %7ss %9ss %5sx\n" "$label" "$n_tokens" "$n_frames" "$audio_s" "$total_s" "$rtf"

    rm -f "$out"
done

echo ""
echo "Notes:"
echo "  RTF = real-time factor (wall time / audio duration, lower is better)"
echo "  Each frame = 80ms of audio at 12.5 Hz"
echo "  Pure CPU inference, no GPU"
