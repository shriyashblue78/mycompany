import json
import logging
from abc import ABC, abstractmethod
from typing import Any, Dict, List, Optional
import httpx

from app.core.config import settings

logger = logging.getLogger(__name__)


class LLMClientException(Exception):
    """Base exception for LLM provider errors."""
    pass


class LLMProvider(ABC):
    """Abstract interface for local language model providers."""

    @abstractmethod
    async def chat_completion(
        self,
        messages: List[Dict[str, Any]],
        tools: Optional[List[Dict[str, Any]]] = None,
        temperature: Optional[float] = None,
        max_tokens: Optional[int] = None,
    ) -> Dict[str, Any]:
        """
        Sends messages to the local model and returns the choice dictionary containing
        content and optional tool_calls.
        """
        pass


class LlamaCppServerProvider(LLMProvider):
    """
    Client for llama.cpp HTTP server (exposes /v1/chat/completions compatible with OpenAI API).
    """

    def __init__(
        self,
        base_url: Optional[str] = None,
        timeout: Optional[float] = None,
        client: Optional[httpx.AsyncClient] = None,
    ):
        self.base_url = (base_url or settings.LLM_SERVER_URL).rstrip("/")
        self.timeout = timeout or settings.LLM_TIMEOUT_SECONDS
        self._client = client

    async def _get_client(self) -> httpx.AsyncClient:
        if self._client is not None:
            return self._client
        # Fast 10s connect timeout detects downed server immediately;
        # Generous read timeout accommodates local model startup, prompt prefill & generation.
        timeout_config = httpx.Timeout(
            timeout=self.timeout,
            connect=10.0,
        )
        return httpx.AsyncClient(timeout=timeout_config)

    async def chat_completion(
        self,
        messages: List[Dict[str, Any]],
        tools: Optional[List[Dict[str, Any]]] = None,
        temperature: Optional[float] = None,
        max_tokens: Optional[int] = None,
    ) -> Dict[str, Any]:
        endpoint = f"{self.base_url}/v1/chat/completions"
        payload: Dict[str, Any] = {
            "model": settings.LLM_MODEL_NAME,
            "messages": messages,
            "temperature": temperature if temperature is not None else settings.LLM_TEMPERATURE,
            "max_tokens": max_tokens if max_tokens is not None else settings.LLM_MAX_TOKENS,
        }
        if tools:
            payload["tools"] = tools
            payload["tool_choice"] = "auto"

        client = await self._get_client()
        try:
            response = await client.post(endpoint, json=payload)
            if response.status_code != 200:
                logger.error(
                    "Local llama.cpp server error %d: %s",
                    response.status_code,
                    response.text,
                )
                raise LLMClientException(
                    f"Local model server returned status {response.status_code}: {response.text[:200]}"
                )

            data = response.json()
            choices = data.get("choices")
            if not choices or not isinstance(choices, list):
                raise LLMClientException("Local model returned invalid response format: missing choices.")

            message = choices[0].get("message") or {}
            return message
        except httpx.ConnectError as e:
            logger.error("Could not connect to local llama.cpp server at %s: %s", self.base_url, e)
            raise LLMClientException(
                f"Local LLM server is unavailable at {self.base_url}. Please ensure llama.cpp server is started."
            )
        except httpx.TimeoutException as e:
            logger.error("Timeout communicating with local llama.cpp server: %s", e)
            raise LLMClientException("Request to local LLM server timed out.")
        except LLMClientException:
            raise
        except Exception as e:
            logger.error("Unexpected error in local LLM chat completion: %s", e, exc_info=True)
            raise LLMClientException(f"Failed to communicate with local model: {str(e)}")
        finally:
            if self._client is None:
                await client.aclose()


# Default singleton provider instance
local_llm_provider: LLMProvider = LlamaCppServerProvider()

