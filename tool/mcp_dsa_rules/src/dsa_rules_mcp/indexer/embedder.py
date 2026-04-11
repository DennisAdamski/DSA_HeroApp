"""Lokaler Embedder auf Basis von sentence-transformers."""

from __future__ import annotations

import os
from pathlib import Path
from typing import Iterable, Sequence

import numpy as np


class Embedder:
    """Lazy Wrapper um ein lokales Embedding-Modell."""

    def __init__(self, *, model_name: str, cache_dir: Path) -> None:
        self._model_name = model_name
        self._cache_dir = cache_dir
        self._model = None
        self._dim: int | None = None

    def _ensure_loaded(self) -> None:
        if self._model is not None:
            return
        os.environ.setdefault("HF_HOME", str(self._cache_dir))
        os.environ.setdefault("SENTENCE_TRANSFORMERS_HOME", str(self._cache_dir))

        from sentence_transformers import SentenceTransformer  # type: ignore[import-not-found]

        self._cache_dir.mkdir(parents=True, exist_ok=True)
        self._model = SentenceTransformer(
            self._model_name,
            cache_folder=str(self._cache_dir),
        )
        probe = self._model.encode(["probe"], convert_to_numpy=True)
        self._dim = int(probe.shape[1])

    @property
    def dim(self) -> int:
        self._ensure_loaded()
        assert self._dim is not None
        return self._dim

    def encode_many(self, texts: Sequence[str], *, batch_size: int = 32) -> np.ndarray:
        self._ensure_loaded()
        assert self._model is not None
        if not texts:
            return np.zeros((0, self.dim), dtype=np.float32)
        vectors = self._model.encode(
            list(texts),
            batch_size=batch_size,
            convert_to_numpy=True,
            normalize_embeddings=False,
            show_progress_bar=False,
        )
        return vectors.astype(np.float32, copy=False)

    def encode_one(self, text: str) -> np.ndarray:
        return self.encode_many([text])[0]


def embedding_to_bytes(vector: np.ndarray) -> bytes:
    return np.asarray(vector, dtype=np.float32).tobytes()
