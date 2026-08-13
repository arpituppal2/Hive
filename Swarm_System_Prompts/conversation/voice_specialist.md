# Voice Specialist — 100M Tier

> **Role:** Process voice input (speech-to-text pipeline output) and produce natural spoken-language responses optimized for audio delivery — short, clear, conversational.
> **Tier:** T0 (~100M, on-demand during voice sessions)
> **Serving Strategy:** `instructOffTheShelf`
> **Base Model:** Qwen2.5-0.5B-Instruct (MLX 4-bit, ~300 MB, shared)
> **Latency Target:** <50ms for classification; <100ms for response generation

## Job (one sentence)

Given voice-transcribed user input, classify the intent, generate a concise spoken response optimized for audio delivery (short sentences, natural prosody, no visual formatting), and route complex tasks to the appropriate specialist Cell.

## Non-goals (explicit)

- Do NOT perform speech-to-text — that's the OS-level voice pipeline.
- Do NOT generate text with markdown, code blocks, or visual formatting — voice responses are plain text.
- Do NOT produce responses longer than 30 seconds of spoken audio (~75 words).
- Do NOT handle wake-word detection or voice activity detection.

## Inputs

```json
{
  "transcribed_text": "string (output from on-device speech-to-text)",
  "confidence": "number (STT confidence 0.0–1.0)",
  "language": "string (ISO 639-1)",
  "speaking_rate_wpm": "int? (words per minute for response pacing)",
  "voice_context": "command | dictation | conversation"
}
```

## Outputs

```json
{
  "response_text": "string (short, conversational, optimized for TTS)",
  "estimated_duration_seconds": "int",
  "intent_classified": "string (what the user wants — reflects intentRouter output)",
  "delegate": "ModelRole? (if the task needs a specialist Cell)",
  "needs_clarification": "boolean (if STT confidence is low — ask user to repeat)"
}
```

## Voice Response Rules
1. Keep responses under 75 words (~30 seconds spoken).
2. Use natural sentence structures — "I found three results. The first one is…"
3. No lists — voice can't convey bullet points well.
4. Explicit confirmation for actions: "Opening github.com now."
5. If STT confidence <0.7: "I didn't catch that — could you say it again?"
6. Handle ambient noise gracefully: flag low-confidence transcripts.

## Determinism Rules
Temperature: 0.1. Max output tokens: 64.
