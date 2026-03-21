"""Semantic Scholar MCP Server — Direct OpenAPI integration via httpx.

Exposes 4 tools for paper search, paper details, author details, and citations.
Uses async httpx with explicit rate limiting (1 req/sec) and 10s timeouts.
"""

import os
import re
import asyncio
import logging
import time
from typing import Any, List, Dict, Optional

import httpx
from mcp.server.fastmcp import FastMCP

logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")

S2_BASE_URL = "https://api.semanticscholar.org/graph/v1"
REQUEST_TIMEOUT = 10.0
MIN_REQUEST_INTERVAL = 1.0

PAPER_FIELDS = "paperId,title,abstract,year,authors,url,venue,publicationTypes,citationCount"
AUTHOR_FIELDS = "authorId,name,url,affiliations,paperCount,citationCount,hIndex"
CITATION_FIELDS = (
    "citations.paperId,citations.title,citations.year,citations.authors,"
    "references.paperId,references.title,references.year,references.authors"
)


def normalize_paper_id(paper_id: str) -> str:
    """Normalize paper IDs to formats the S2 API accepts."""
    stripped = paper_id.strip()
    if re.match(r"^\d{4}\.\d{4,5}(v\d+)?$", stripped):
        return f"ARXIV:{stripped}"
    if stripped.lower().startswith("arxiv:"):
        return f"ARXIV:{stripped.split(':', 1)[1]}"
    return stripped


class RateLimiter:
    def __init__(self, min_interval: float):
        self._min_interval = min_interval
        self._lock = asyncio.Lock()
        self._last_request: float = 0.0

    async def acquire(self):
        async with self._lock:
            now = time.monotonic()
            elapsed = now - self._last_request
            if elapsed < self._min_interval:
                await asyncio.sleep(self._min_interval - elapsed)
            self._last_request = time.monotonic()


class SemanticScholarClient:
    def __init__(self):
        api_key = os.environ.get("SEMANTIC_SCHOLAR_API_KEY", "")
        headers = {}
        if api_key:
            headers["x-api-key"] = api_key
        self._client = httpx.AsyncClient(
            base_url=S2_BASE_URL,
            headers=headers,
            timeout=httpx.Timeout(REQUEST_TIMEOUT),
        )
        self._rate_limiter = RateLimiter(MIN_REQUEST_INTERVAL)

    async def _get(self, path: str, params: Optional[Dict] = None) -> Any:
        await self._rate_limiter.acquire()
        response = await self._client.get(path, params=params)
        response.raise_for_status()
        return response.json()

    async def search_papers(self, query: str, limit: int = 10) -> List[Dict[str, Any]]:
        data = await self._get("/paper/search", params={
            "query": query,
            "limit": limit,
            "fields": PAPER_FIELDS,
        })
        results = data.get("data", [])
        return [_format_paper(p) for p in results]

    async def get_paper(self, paper_id: str) -> Dict[str, Any]:
        pid = normalize_paper_id(paper_id)
        data = await self._get(f"/paper/{pid}", params={"fields": PAPER_FIELDS})
        return _format_paper(data)

    async def get_author(self, author_id: str) -> Dict[str, Any]:
        data = await self._get(f"/author/{author_id}", params={"fields": AUTHOR_FIELDS})
        return {
            "authorId": data.get("authorId"),
            "name": data.get("name"),
            "url": data.get("url"),
            "affiliations": data.get("affiliations") or [],
            "paperCount": data.get("paperCount"),
            "citationCount": data.get("citationCount"),
            "hIndex": data.get("hIndex"),
        }

    async def get_citations(self, paper_id: str) -> Dict[str, List[Dict[str, Any]]]:
        pid = normalize_paper_id(paper_id)
        data = await self._get(f"/paper/{pid}", params={"fields": CITATION_FIELDS})
        return {
            "citations": [_format_citation(c) for c in (data.get("citations") or [])],
            "references": [_format_citation(r) for r in (data.get("references") or [])],
        }

    async def close(self):
        await self._client.aclose()


def _format_paper(p: Dict) -> Dict[str, Any]:
    return {
        "paperId": p.get("paperId"),
        "title": p.get("title"),
        "abstract": p.get("abstract"),
        "year": p.get("year"),
        "authors": [
            {"name": a.get("name"), "authorId": a.get("authorId")}
            for a in (p.get("authors") or [])
        ],
        "url": p.get("url"),
        "venue": p.get("venue"),
        "publicationTypes": p.get("publicationTypes") or [],
        "citationCount": p.get("citationCount"),
    }


def _format_citation(c: Dict) -> Dict[str, Any]:
    return {
        "paperId": c.get("paperId"),
        "title": c.get("title"),
        "year": c.get("year"),
        "authors": [
            {"name": a.get("name"), "authorId": a.get("authorId")}
            for a in (c.get("authors") or [])
        ],
    }


# --- FastMCP Server ---

mcp = FastMCP("semanticscholar")
client = SemanticScholarClient()


@mcp.tool()
async def search_papers(query: str, num_results: int = 10) -> List[Dict[str, Any]]:
    """Search for papers on Semantic Scholar.

    Args:
        query: Search query string
        num_results: Number of results to return (default: 10)
    """
    logging.info(f"search_papers: query={query!r}, limit={num_results}")
    try:
        return await client.search_papers(query, limit=num_results)
    except httpx.TimeoutException:
        return [{"error": "Request timed out after 10s"}]
    except httpx.HTTPStatusError as e:
        return [{"error": f"S2 API error: {e.response.status_code}"}]
    except Exception as e:
        return [{"error": f"Search failed: {e}"}]


@mcp.tool()
async def get_paper_details(paper_id: str) -> Dict[str, Any]:
    """Get details of a specific paper. Accepts S2 paper ID, DOI, or arxiv ID (e.g. '2301.10226').

    Args:
        paper_id: Paper identifier (S2 ID, DOI, or arxiv ID)
    """
    logging.info(f"get_paper_details: paper_id={paper_id!r}")
    try:
        return await client.get_paper(paper_id)
    except httpx.TimeoutException:
        return {"error": "Request timed out after 10s"}
    except httpx.HTTPStatusError as e:
        return {"error": f"S2 API error: {e.response.status_code}"}
    except Exception as e:
        return {"error": f"Paper lookup failed: {e}"}


@mcp.tool()
async def get_author_details(author_id: str) -> Dict[str, Any]:
    """Get details of a specific author including h-index and citation count.

    Args:
        author_id: Semantic Scholar author ID
    """
    logging.info(f"get_author_details: author_id={author_id!r}")
    try:
        return await client.get_author(author_id)
    except httpx.TimeoutException:
        return {"error": "Request timed out after 10s"}
    except httpx.HTTPStatusError as e:
        return {"error": f"S2 API error: {e.response.status_code}"}
    except Exception as e:
        return {"error": f"Author lookup failed: {e}"}


@mcp.tool()
async def get_citations(paper_id: str) -> Dict[str, Any]:
    """Get citations and references for a paper. Accepts S2 paper ID, DOI, or arxiv ID.

    Args:
        paper_id: Paper identifier (S2 ID, DOI, or arxiv ID)
    """
    logging.info(f"get_citations: paper_id={paper_id!r}")
    try:
        return await client.get_citations(paper_id)
    except httpx.TimeoutException:
        return {"error": "Request timed out after 10s"}
    except httpx.HTTPStatusError as e:
        return {"error": f"S2 API error: {e.response.status_code}"}
    except Exception as e:
        return {"error": f"Citations lookup failed: {e}"}


if __name__ == "__main__":
    logging.info("Starting Semantic Scholar MCP server (httpx)")
    mcp.run(transport="stdio")
