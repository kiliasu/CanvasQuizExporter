# JSON / JSONL schema 2.0

All files use UTF-8 and schema 2.0. Consumers should check `schema_version`.

JSON has top-level `schema_version`, `title`, `course`, `questions`, `warnings` and optional `diagnostics`. JSONL contains one independent `{"meta": {...}, "question": {...}}` per line. Its meta contains schema version, title, course and optional diagnostics.

| Question field | Type | Meaning |
| --- | --- | --- |
| `number` | integer | Saved question number, or sequential fallback |
| `type` | string | Canvas question type identifier |
| `question` | string | Plain text, preserving useful line breaks and blanks |
| `options` | array | Saved option order, text, selected/correct flags and images |
| `question_images` | array | Question images |
| `user_answer` | string or null | Saved selection or entered response |
| `correct_answer` | string or null | Only published correctness markers |

An option contains `text`, `is_selected`, `is_correct`, `images`. Selected and correct are independent; absence of correctness does not by itself mean an answer is wrong. Matching options retain both sides as `left → right`; missing saved selections are explicitly labelled.

Image objects contain `alt`, `available` and `path`. Paths are relative to the output directory, or null when assets are unavailable/omitted. Original remote URLs, source paths and binary image data are not serialized. Automatic redaction and user filters run before serialization.

Diagnostics contain counts (`questions`, `iframe_depth`, `redactions`, `missing_images`), not raw identities. Empty/unknown answers are null. Future readers should tolerate additional optional fields.
