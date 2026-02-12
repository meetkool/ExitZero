import numpy as np
from sentence_transformers import SentenceTransformer
import anthropic
from typing import List, Dict, Optional
import logging
from dataclasses import dataclass
import uuid

logger = logging.getLogger(__name__)


@dataclass
class Memory:
    id: str
    memory: str
    embedding: np.ndarray
    user_id: str


class BaselineMemory:
    def __init__(self, api_key: str):
        """Initialize baseline memory system.

        Args:
            api_key: Anthropic API key for LLM interactions
        """
        self.client = anthropic.Client(api_key=api_key)
        # Initialize sentence transformer model for embeddings
        self.model = SentenceTransformer("all-MiniLM-L6-v2")
        # Storage for memories, keyed by user_id
        self.memories: Dict[str, List[Memory]] = {}

    def _get_embeddings(self, texts: List[str]) -> np.ndarray:
        """Generate embeddings for a list of texts."""
        return self.model.encode(texts)

    def _extract_facts(self, messages) -> List[str]:
        """Use LLM to extract key facts from conversation messages."""
        # Convert messages to string format
        if isinstance(messages, str):
            conversation = messages
        else:
            conversation = "\n".join(
                [f"{msg['role']}: {msg['content']}" for msg in messages]
            )

        prompt = f"""Extract meaningful memories from this conversation. A good memory is:
1. A specific fact about a person, place, thing, or relationship
2. Information that could be important to recall later
3. May include relevant context (time, place, circumstances)
4. Clear about who/what it refers to

Focus on extracting:
- Personal details (names, locations, jobs)
- Preferences and interests
- Important life events
- Relationships and connections
- Specific experiences or activities
- Future plans or intentions

Avoid:
- Generic small talk
- Temporary states or feelings
- Obvious or common knowledge
- Information without clear attribution

Conversation:
{conversation}

Format each memory as a complete, specific sentence. Return ONLY a JSON array of strings.

Example good memories:
[
    "Sarah Johnson lives in Boston's Back Bay neighborhood",
    "Sarah has been a software engineer at Google since March 2023",
    "Sarah's cat Luna is allergic to fish",
    "Sarah met her best friend Kim during their freshman year at MIT",
    "Sarah plans to run the Chicago Marathon in October 2024",
    "Sarah prefers working early mornings, usually starting at 6 AM"
]

Example memories to avoid:
[
    "Sarah is having a good day",  // temporary state
    "Sarah likes food",  // too generic
    "The weather is nice",  // not a meaningful memory
    "Someone mentioned traveling"  // lacks specific attribution
]

Return ONLY the JSON array of extracted memories, nothing else."""

        response = self.client.messages.create(
            model="claude-3-5-sonnet-20241022",
            messages=[{"role": "user", "content": prompt}],
            max_tokens=8192,
        )

        try:
            import json

            # Extract JSON array from response
            response_text = response.content[0].text
            # Find array portion
            start = response_text.find("[")
            end = response_text.rfind("]") + 1
            if start == -1 or end == 0:
                logger.error(f"Could not find JSON array in response: {response_text}")
                return []
            facts = json.loads(response_text[start:end])
            return facts
        except Exception as e:
            logger.error(f"Error extracting facts: {str(e)}")
            return []

    def add(self, messages: List[Dict[str, str]], user_id: str) -> None:
        """Add new memories from conversation messages."""
        # Extract facts using LLM
        facts = self._extract_facts(messages)

        # Generate embeddings for facts
        if facts:
            embeddings = self._get_embeddings(facts)

            # Create Memory objects
            new_memories = [
                Memory(
                    id=str(uuid.uuid4()),
                    memory=fact,
                    embedding=embedding,
                    user_id=user_id,
                )
                for fact, embedding in zip(facts, embeddings)
            ]

            # Add to storage
            if user_id not in self.memories:
                self.memories[user_id] = []
            self.memories[user_id].extend(new_memories)

    def search(self, query: str, user_id: str, limit: int = 32) -> List[Dict[str, str]]:
        """Search memories using embedding similarity."""
        if user_id not in self.memories:
            return []

        # Get query embedding
        query_embedding = self._get_embeddings([query])[0]

        # Get user's memories
        user_memories = self.memories[user_id]
        if not user_memories:
            return []

        # Calculate similarities
        similarities = [
            np.dot(query_embedding, mem.embedding)
            / (np.linalg.norm(query_embedding) * np.linalg.norm(mem.embedding))
            for mem in user_memories
        ]

        # Sort by similarity
        memory_similarities = list(zip(user_memories, similarities))
        memory_similarities.sort(key=lambda x: x[1], reverse=True)

        # Return top matches
        results = []
        for memory, similarity in memory_similarities[:limit]:
            if similarity > 0.1:  # Similarity threshold
                results.append({"id": memory.id, "memory": memory.memory})

        return results

    def update(self, memory_id: str, new_content: str) -> None:
        """Update a specific memory with new content."""
        # Find memory
        for memories in self.memories.values():
            for i, memory in enumerate(memories):
                if memory.id == memory_id:
                    # Create new embedding for updated content
                    new_embedding = self._get_embeddings([new_content])[0]
                    # Update memory
                    memories[i] = Memory(
                        id=memory.id,
                        memory=new_content,
                        embedding=new_embedding,
                        user_id=memory.user_id,
                    )
                    return

        logger.warning(f"Memory {memory_id} not found")

    def delete_all(self, user_id: str) -> None:
        """Delete all memories for a specific user.

        Args:
            user_id: ID of user whose memories should be deleted
        """
        if user_id in self.memories:
            del self.memories[user_id]
