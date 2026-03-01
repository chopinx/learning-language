#!/bin/zsh
set -eo pipefail

set +u
source ~/.zshrc
set -u

if [[ -z "${DEEPGRAM_API_KEY:-}" ]]; then
  echo "DEEPGRAM_API_KEY is missing. Set it in ~/.zshrc first."
  exit 1
fi

AUDIO_OUT="${1:-docs/test-audio/deepgram_english_test.wav}"
RESP_OUT="${2:-docs/test-audio/deepgram_english_test_response.json}"

mkdir -p "$(dirname "$AUDIO_OUT")" "$(dirname "$RESP_OUT")"

curl -sS -X POST 'https://api.deepgram.com/v1/speak?model=aura-2-thalia-en' \
  -H "Authorization: Token $DEEPGRAM_API_KEY" \
  -H 'Content-Type: application/json' \
  --data '{"text":"Hello, this is an English test audio for the LearningLanguage app. I will speak clearly so transcription can be validated."}' \
  -o "$AUDIO_OUT"

curl -sS -X POST 'https://api.deepgram.com/v1/listen?punctuate=true&smart_format=true&utterances=true&language=en' \
  -H "Authorization: Token $DEEPGRAM_API_KEY" \
  -H 'Content-Type: audio/wav' \
  --data-binary "@$AUDIO_OUT" \
  -o "$RESP_OUT"

if command -v jq >/dev/null 2>&1; then
  echo "Transcript:"
  jq -r '.results.channels[0].alternatives[0].transcript' "$RESP_OUT"
  echo "Utterances: $(jq -r '.results.utterances | length' "$RESP_OUT")"
else
  echo "Saved response to $RESP_OUT"
fi
