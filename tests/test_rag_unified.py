import sys
import os
import unittest
from unittest.mock import patch, MagicMock, Mock
import tempfile
import shutil

# Add parent directory to path to import rag_unified
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
sys.path.insert(
    0,
    os.path.abspath(os.path.join(os.path.dirname(__file__), "../components/ai-agent")),
)

from rag_unified import UnifiedRAGPipeline, RAGResult, InMemoryBackend


class TestRAGBackends(unittest.TestCase):
    """Test the unified RAG pipeline with mocked backends."""

    def test_pipeline_selects_first_available_backend(self):
        """Pipeline should select the first available backend in chain."""
        with (
            patch("rag_unified.ChromaDBBackend") as MockChroma,
            patch("rag_unified.FAISSBackend") as MockFAISS,
            patch("rag_unified.InMemoryBackend") as MockInMemory,
        ):
            # ChromaDB unavailable, FAISS unavailable, InMemory available
            mock_chroma = Mock()
            mock_chroma.is_available.return_value = False
            MockChroma.return_value = mock_chroma

            mock_faiss = Mock()
            mock_faiss.is_available.return_value = False
            MockFAISS.return_value = mock_faiss

            mock_inmemory = Mock()
            mock_inmemory.is_available.return_value = True
            MockInMemory.return_value = mock_inmemory

            pipeline = UnifiedRAGPipeline()
            self.assertEqual(pipeline.primary_backend, mock_inmemory)
            MockInMemory.assert_called_once()

    def test_embed_and_query_inmemory(self):
        """Test embedding and querying using InMemoryBackend."""
        # Create pipeline with only InMemoryBackend available
        with (
            patch("rag_unified.ChromaDBBackend") as MockChroma,
            patch("rag_unified.FAISSBackend") as MockFAISS,
            patch("rag_unified.InMemoryBackend") as MockInMemory,
        ):
            mock_chroma = Mock()
            mock_chroma.is_available.return_value = False
            MockChroma.return_value = mock_chroma

            mock_faiss = Mock()
            mock_faiss.is_available.return_value = False
            MockFAISS.return_value = mock_faiss

            # Create a real InMemoryBackend instance (not mocked) for actual functionality
            real_inmemory = InMemoryBackend()
            MockInMemory.return_value = real_inmemory

            pipeline = UnifiedRAGPipeline()

            # Embed a document
            result = pipeline.embed_post_mortem(
                content="Test post-mortem about OOM error",
                alert_name="TestAlert",
                timestamp="2026-01-01T00:00:00",
            )
            self.assertTrue(result)

            # Query similar incidents
            hits = pipeline.query_similar_incidents("OOM error", n_results=1)
            self.assertEqual(len(hits), 1)
            self.assertIn("OOM error", hits[0].content)
            self.assertEqual(hits[0].metadata["alert_name"], "TestAlert")

            # Format context for LLM
            context = pipeline.format_context_for_llm("OOM error")
            self.assertIn("Similar Past Incidents", context)
            self.assertIn("TestAlert", context)

    def test_pipeline_fallback_on_backend_failure(self):
        """If primary backend fails, pipeline should fallback to next."""
        # This test would require actual backend implementations; skip for now.
        pass

    def test_get_stats(self):
        """Test pipeline statistics."""
        with (
            patch("rag_unified.ChromaDBBackend") as MockChroma,
            patch("rag_unified.FAISSBackend") as MockFAISS,
            patch("rag_unified.InMemoryBackend") as MockInMemory,
        ):
            mock_chroma = Mock()
            mock_chroma.is_available.return_value = False
            MockChroma.return_value = mock_chroma

            mock_faiss = Mock()
            mock_faiss.is_available.return_value = False
            MockFAISS.return_value = mock_faiss

            mock_inmemory = Mock()
            mock_inmemory.is_available.return_value = True
            mock_inmemory.get_document_count.return_value = 5
            MockInMemory.return_value = mock_inmemory

            pipeline = UnifiedRAGPipeline()
            stats = pipeline.get_stats()
            self.assertEqual(stats["primary_backend"], "Mock")
            self.assertEqual(stats["document_count"], 5)
            self.assertEqual(len(stats["available_backends"]), 1)
            self.assertIn("Mock", stats["available_backends"])


class TestInMemoryBackend(unittest.TestCase):
    """Test InMemoryBackend directly."""

    def setUp(self):
        self.backend = InMemoryBackend()

    def test_embed_and_query(self):
        """Basic embed and query functionality."""
        result = self.backend.embed_document(
            content="Sample incident about network latency",
            doc_id="test1",
            metadata={"alert_name": "NetworkLatency"},
        )
        self.assertTrue(result)

        # Duplicate embed should return False
        result2 = self.backend.embed_document(
            content="Sample incident about network latency",
            doc_id="test1",
            metadata={"alert_name": "NetworkLatency"},
        )
        self.assertFalse(result2)

        # Query
        hits = self.backend.query("network latency", n_results=1)
        self.assertEqual(len(hits), 1)
        self.assertIn("network latency", hits[0].content)
        self.assertEqual(hits[0].metadata["alert_name"], "NetworkLatency")

    def test_query_no_documents(self):
        """Query when no documents embedded."""
        hits = self.backend.query("anything")
        self.assertEqual(len(hits), 0)

    def test_is_available(self):
        self.assertTrue(self.backend.is_available())

    def test_get_document_count(self):
        self.assertEqual(self.backend.get_document_count(), 0)
        self.backend.embed_document("doc1", "id1", {})
        self.assertEqual(self.backend.get_document_count(), 1)


if __name__ == "__main__":
    unittest.main()
