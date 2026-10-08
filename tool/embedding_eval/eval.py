#!/usr/bin/env python3
"""Compares embedding models and prompt contracts on the user's own notes.

Phase 4.9 of docs/TECH_MIGRATION_PLAN.md. Reads the corpus the app exports
(Settings -> AI -> Export RAG corpus, debug builds) and an eval set the user
writes, embeds both with each model under each prompt contract, and prints
recall@1/5/10 and MRR per language.

Answers are PAGE ids. A chunk is a hit when its page is one of the answers, so
one set of questions scores every chunk size: a chunk id changes with its size,
a page id does not.

  python eval.py --corpus corpus.jsonl --eval eval_set.jsonl --csv results.csv
  python eval.py --self-test

The model code is imported only for a real run, so --self-test needs nothing but
Python. Measures the full-precision weights on this computer; phase 5 repeats the
winning configuration on the device build.
"""

from __future__ import annotations

import argparse
import csv
import json
import math
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Dict, List, Optional, Sequence, Set

MODELS = {
    "300m": "google/embeddinggemma-300m",
    "2": "google/embeddinggemma-2",
}

FULL_DIMS = 768
DIMS = (768, 512)
CHUNK_SIZES = (250, 500, 1000)
KS = (1, 5, 10)
COLUMNS = (
    "model",
    "contract",
    "chunk_words",
    "dims",
    "lang",
    "recall@1",
    "recall@5",
    "recall@10",
    "MRR",
)


@dataclass(frozen=True)
class Contract:
    """How a text is written before it is embedded.

    `document(title, passage)` and `query(question)` return exactly the string the
    model is given. They must match what the app sends for the same contract.
    """

    name: str
    document: Callable[[Optional[str], str], str]
    query: Callable[[str], str]


CONTRACTS = (
    # The app today. flutter_edge_ai writes the document prefix, and the app puts
    # the notebook title at the front of the passage (phase 4.3).
    Contract(
        "titled",
        lambda title, passage: "title: none | text: "
        + (f"{title}\n\n{passage}" if title else passage),
        lambda q: "task: search result | query: " + q,
    ),
    # EmbeddingGemma 2 candidates, from its two published sources (phase 5.2).
    Contract(
        "hf-card",
        lambda title, passage: f"title: {title or 'none'} | text: {passage}",
        lambda q: "task: search result | query: " + q,
    ),
    Contract(
        "litert-lm",
        lambda title, passage: "task: search result | text: " + passage,
        lambda q: "task: search query | text: " + q,
    ),
)


def read_jsonl(path: Path) -> List[dict]:
    with path.open(encoding="utf-8") as f:
        return [json.loads(line) for line in f if line.strip()]


def validate_corpus(chunks: Sequence[dict]) -> None:
    for chunk in chunks:
        for key in ("id", "chunk_words", "page_id", "title", "text"):
            if key not in chunk:
                raise ValueError(f"corpus line {chunk.get('id')!r} has no {key!r}")


def validate_queries(queries: Sequence[dict]) -> None:
    for query in queries:
        for key in ("query", "lang", "relevant_pages"):
            if key not in query:
                raise ValueError(f"eval line {query.get('query')!r} has no {key!r}")
        if not query["relevant_pages"]:
            raise ValueError(f"eval line {query['query']!r} lists no relevant pages")


def cosine(a: Sequence[float], b: Sequence[float]) -> float:
    dot = sum(x * y for x, y in zip(a, b))
    norm = math.sqrt(sum(x * x for x in a)) * math.sqrt(sum(y * y for y in b))
    return dot / norm if norm else 0.0


def truncate(vec: Sequence[float], dims: int) -> List[float]:
    """Matryoshka truncation: keep the leading dimensions, then renormalise."""
    head = list(vec[:dims])
    norm = math.sqrt(sum(x * x for x in head))
    return [x / norm for x in head] if norm else head


def ranked_pages(
    query: Sequence[float],
    chunks: Sequence[dict],
    vectors: Sequence[Sequence[float]],
) -> List[int]:
    """Pages in the order of their best-ranked chunk."""
    order = sorted(
        range(len(chunks)),
        key=lambda i: cosine(query, vectors[i]),
        reverse=True,
    )
    seen: Set[int] = set()
    pages: List[int] = []
    for i in order:
        page = chunks[i]["page_id"]
        if page not in seen:
            seen.add(page)
            pages.append(page)
    return pages


def recall_at(k: int, ranked: Sequence[int], relevant: Set[int]) -> float:
    """The share of the relevant pages that are in the top k."""
    return sum(1 for page in ranked[:k] if page in relevant) / len(relevant)


def reciprocal_rank(ranked: Sequence[int], relevant: Set[int]) -> float:
    for rank, page in enumerate(ranked, start=1):
        if page in relevant:
            return 1.0 / rank
    return 0.0


def evaluate(
    chunks: Sequence[dict],
    vectors: Sequence[Sequence[float]],
    queries: Sequence[dict],
    query_vectors: Sequence[Sequence[float]],
) -> Dict[str, Dict[str, float]]:
    """Mean recall@k and MRR for each language in the eval set."""
    sums: Dict[str, Dict[str, List[float]]] = {}
    for query, qv in zip(queries, query_vectors):
        ranked = ranked_pages(qv, chunks, vectors)
        relevant = set(query["relevant_pages"])
        row = sums.setdefault(
            query["lang"],
            {**{f"recall@{k}": [] for k in KS}, "MRR": []},
        )
        for k in KS:
            row[f"recall@{k}"].append(recall_at(k, ranked, relevant))
        row["MRR"].append(reciprocal_rank(ranked, relevant))
    return {
        lang: {metric: sum(values) / len(values) for metric, values in row.items()}
        for lang, row in sums.items()
    }


def embed(model, texts: Sequence[str]) -> List[List[float]]:
    vectors = model.encode(
        list(texts),
        batch_size=16,
        normalize_embeddings=True,
        show_progress_bar=False,
    )
    return [[float(x) for x in vector] for vector in vectors]


def run(args: argparse.Namespace) -> List[dict]:
    # Imported here so that --self-test needs none of the model stack.
    import torch
    from sentence_transformers import SentenceTransformer

    corpus = read_jsonl(args.corpus)
    queries = read_jsonl(args.eval)
    validate_corpus(corpus)
    validate_queries(queries)
    contracts = [c for c in CONTRACTS if c.name in args.contracts]

    rows: List[dict] = []
    for key in args.models:
        # float32 on purpose: fp16 changes the vectors and is not what the app runs.
        model = SentenceTransformer(
            MODELS[key], model_kwargs={"torch_dtype": torch.float32}
        )
        for contract in contracts:
            for size in args.chunk_words:
                chunks = [c for c in corpus if c["chunk_words"] == size]
                if not chunks:
                    print(f"no chunks at {size} words; export them again", file=sys.stderr)
                    continue
                doc_vectors = embed(
                    model,
                    [contract.document(c["title"], c["text"]) for c in chunks],
                )
                query_vectors = embed(
                    model, [contract.query(q["query"]) for q in queries]
                )
                for dims in args.dims:
                    if len(doc_vectors[0]) < dims:
                        raise ValueError(f"{MODELS[key]} has no {dims}-dim output")
                    vectors = [truncate(v, dims) for v in doc_vectors]
                    qvs = [truncate(v, dims) for v in query_vectors]
                    for lang, metrics in evaluate(chunks, vectors, queries, qvs).items():
                        rows.append({
                            "model": key,
                            "contract": contract.name,
                            "chunk_words": size,
                            "dims": dims,
                            "lang": lang,
                            **metrics,
                        })
                print(f"done: {key} {contract.name} {size} words", file=sys.stderr)
    return rows


def write_outputs(rows: Sequence[dict], csv_path: Path) -> None:
    with csv_path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=COLUMNS)
        writer.writeheader()
        writer.writerows(rows)

    header = (
        f"{'model':<6} {'contract':<10} {'words':>5} {'dims':>4} {'lang':<4} "
        f"{'R@1':>6} {'R@5':>6} {'R@10':>6} {'MRR':>6}"
    )
    print(header)
    print("-" * len(header))
    for row in rows:
        print(
            f"{row['model']:<6} {row['contract']:<10} {row['chunk_words']:>5} "
            f"{row['dims']:>4} {row['lang']:<4} "
            f"{row['recall@1']:>6.3f} {row['recall@5']:>6.3f} "
            f"{row['recall@10']:>6.3f} {row['MRR']:>6.3f}"
        )
    print(f"\nwrote {csv_path}")


def self_test() -> None:
    # The scoring. A page that answers first scores MRR 1; second, 0.5.
    assert reciprocal_rank([1, 2, 3], {1}) == 1.0
    assert reciprocal_rank([2, 1, 3], {1}) == 0.5
    assert reciprocal_rank([2, 3], {9}) == 0.0
    assert recall_at(1, [1, 2], {1, 2}) == 0.5
    assert recall_at(5, [1, 2], {1, 2}) == 1.0

    # Ranking. Chunks of one page count once, at their best position.
    chunks = [{"page_id": 1}, {"page_id": 1}, {"page_id": 2}]
    vectors = [[1.0, 0.0], [0.9, 0.1], [0.0, 1.0]]
    assert ranked_pages([0.0, 1.0], chunks, vectors) == [2, 1]

    # Truncation keeps the direction and gives a unit vector.
    t = truncate([3.0, 4.0, 100.0], 2)
    assert abs(math.hypot(*t) - 1.0) < 1e-9 and abs(t[0] - 0.6) < 1e-9

    # The strings the contracts send, as the app sends them.
    titled = CONTRACTS[0]
    assert titled.document(None, "p") == "title: none | text: p"
    assert titled.document("T", "p") == "title: none | text: T\n\np"
    assert titled.query("q") == "task: search result | query: q"
    print("self-test passed")


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--corpus", type=Path, help="corpus.jsonl, exported by the app")
    parser.add_argument("--eval", type=Path, help="eval_set.jsonl, one question per line")
    parser.add_argument("--csv", type=Path, default=Path("results.csv"))
    parser.add_argument("--models", nargs="+", choices=sorted(MODELS), default=sorted(MODELS))
    parser.add_argument(
        "--contracts",
        nargs="+",
        choices=[c.name for c in CONTRACTS],
        default=[c.name for c in CONTRACTS],
    )
    parser.add_argument("--chunk-words", nargs="+", type=int, default=list(CHUNK_SIZES))
    parser.add_argument("--dims", nargs="+", type=int, default=list(DIMS))
    parser.add_argument("--self-test", action="store_true", help="check the scoring and exit")
    args = parser.parse_args(argv)

    if args.self_test:
        self_test()
        return 0
    if args.corpus is None or args.eval is None:
        parser.error("--corpus and --eval are required")

    write_outputs(run(args), args.csv)
    return 0


if __name__ == "__main__":
    sys.exit(main())
