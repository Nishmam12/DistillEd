# Antigravity Agent Rules — Notepad- Workspace

## OpenRouter API Integration

The OpenRouter API key is available as the environment variable `OPENROUTER_API_KEY`.
**Never hardcode the key in source files.** Always read it from the environment.

### Base URL & Auth
- **Base URL**: `https://openrouter.ai/api/v1`
- **Auth Header**: `Authorization: Bearer $OPENROUTER_API_KEY`
- **Default Model**: `openai/gpt-4o` (override per task as needed)

### JavaScript / Fetch example
```js
const res = await fetch('https://openrouter.ai/api/v1/chat/completions', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${process.env.OPENROUTER_API_KEY}`,
    'HTTP-Referer': 'https://notepad.app',
    'X-Title': 'Notepad-',
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({
    model: 'openai/gpt-4o',
    messages: [{ role: 'user', content: prompt }],
  }),
});
const data = await res.json();
```

### Python / httpx example
```python
import os, httpx

OPENROUTER_API_KEY = os.environ["OPENROUTER_API_KEY"]

response = httpx.post(
    "https://openrouter.ai/api/v1/chat/completions",
    headers={
        "Authorization": f"Bearer {OPENROUTER_API_KEY}",
        "HTTP-Referer": "https://notepad.app",
        "X-Title": "Notepad-",
        "Content-Type": "application/json",
    },
    json={
        "model": "openai/gpt-4o",
        "messages": [{"role": "user", "content": prompt}],
    },
)
data = response.json()
```

### Dart / Flutter example
```dart
import 'dart:io';
// Read key at runtime from env or secure storage — never hardcode.
final apiKey = Platform.environment['OPENROUTER_API_KEY']!;
```

### Available Models (common)
| Model ID | Notes |
|---|---|
| `openai/gpt-4o` | Default — fast & capable |
| `openai/gpt-4o-mini` | Cheaper, good for simple tasks |
| `anthropic/claude-3.5-sonnet` | Strong reasoning |
| `google/gemini-pro-1.5` | Long context |
| `meta-llama/llama-3.1-405b-instruct` | Open-source |

### Agent Instructions
- When implementing AI features for this project, use OpenRouter as the LLM gateway.
- Read the key from `process.env.OPENROUTER_API_KEY` (JS), `os.environ["OPENROUTER_API_KEY"]` (Python), or equivalent.
- Always set `HTTP-Referer: https://notepad.app` and `X-Title: Notepad-` in requests.
- Prefer `openai/gpt-4o` unless the task specifically benefits from another model.
