# Embedding evaluation

Which embedding model, prompt contract and chunk size should DistillEd use? The
public benchmarks do not cover Bangla or OCR'd handwriting, which is most of what
the app embeds, so this measures the models on the student's own notes. It is the
evidence for phase 5 of `docs/TECH_MIGRATION_PLAN.md`.

## What you need

- A debug build of the app on a phone, with notes in it.
- A computer with Python 3.10 or newer.
- A Hugging Face account that has accepted the licences for
  `google/embeddinggemma-300m` and `google/embeddinggemma-2` (accept on each model
  page), and a read token.

## 1. Export the notes

On the phone, open **Settings → AI → Export RAG corpus** (debug builds only) and
share the file to the computer as `corpus.jsonl`.

Each line is one chunk of one page, at each of three sizes (250, 500 and 1000
words):

```json
{"id": "w250-p12-c0", "chunk_words": 250, "page_id": 12, "title": "Biology · Cells", "text": "..."}
```

`page_id` is what you answer with. Find it by searching `corpus.jsonl` for a
passage that answers your question.

## 2. Write the questions

`eval_set.jsonl` has one question per line:

```json
{"query": "What drives mitosis?", "lang": "en", "relevant_pages": [12]}
{"query": "কোষ কীভাবে বিভক্ত হয়?", "lang": "bn", "relevant_pages": [12, 40]}
```

- `lang` is `en` or `bn`. The table reports each language separately.
- `relevant_pages` lists every page that answers the question. Recall is the
  share of those pages found in the top results.
- Write the questions as a student would ask them, in both languages. Include
  some handwriting-OCR text, since that is what the notes often contain.

## 3. Run it

```sh
cd tool/embedding_eval
python3 -m venv .venv
. .venv/bin/activate
pip install -r requirements.txt
hf auth login        # or: huggingface-cli login, depending on your huggingface_hub
python eval.py --corpus corpus.jsonl --eval eval_set.jsonl --csv results.csv
```

Each run covers every model, every prompt contract and every chunk size, and at
768 and 512 dimensions. To run a subset, pass `--models 300m`,
`--contracts titled`, `--chunk-words 250 500` or `--dims 768`.

The table prints as it finishes, and `results.csv` holds the same rows with
columns `model, contract, chunk_words, dims, lang, recall@1, recall@5, recall@10,
MRR`.

## What it measures, and what it does not

- The models run in **float32**. fp16 changes the vectors, and the app does not
  run that. The numbers are for the full-precision weights on this computer. The
  device runs a different build, so phase 5 repeats the best two configurations on
  the phone before anything is switched.
- The 512-dimension rows are the first 512 dimensions, renormalised. This is how
  the model is meant to be shortened.
- Chunks are scored by page, not by chunk id, so one set of questions compares
  every chunk size fairly. A chunk id changes with its size.
- The prompt contracts are the app's own text, written exactly as the app sends
  it. `titled` is what the app sends now. `hf-card` and `litert-lm` are the two
  candidates for EmbeddingGemma 2, from its two published sources.

## Checking the scoring without a model

```sh
python3 eval.py --self-test
```

This runs with no model and no packages beyond the Python standard library.
