# Apple Intelligence Ask Runtime

Hive treats Ask as a complementary, reactive, visible machine-learning feature over private local data. It must work without Apple Intelligence, but when Apple Intelligence is available it should synthesize from The Colony instead of repeating raw wiki snippets.

## Runtime Order

1. Build deterministic local context from The Colony, maintained claims, review state, and source visibility.
2. If Foundation Models are available, use Apple Intelligence on device to synthesize a typed answer envelope.
3. If Foundation Models are unavailable, disabled, still downloading, over context, or unsupported for the current language, keep the deterministic Colony answer.
4. Use online Ask only when the user has configured a key and the existing pre-send review policy allows it.

## Foundation Models Contract

- Check `SystemLanguageModel.default.availability` before every Apple Intelligence route.
- Use `LanguageModelSession` only for bounded local synthesis.
- Use guided generation for a structured answer envelope instead of parsing raw strings.
- Give the model a single local `findColonyPages` tool so it can retrieve concise Colony context without direct file access or side effects.
- Keep prompts short enough for the on-device context window and fall back when context is exceeded.
- Catch unsupported language and availability errors with plain user-facing limitations.

## HIG Mapping

- Complementary: Ask still works from the indexed Wiki when Apple Intelligence is unavailable.
- Private: personal context remains on device unless the user explicitly enables online Ask.
- Reactive: Ask runs only after the user asks a question.
- Visible: every answer carries an attribution/limitation note rather than a hidden model decision.
- Corrections: fallback suggestions favor adding evidence, editing The Colony, or asking a narrower question.
- Confidence: Hive uses semantic language such as local context and limitations, not percentages.
