# Credibility Profile Scoring Template

Compute the credibility profile for paper `{ARXIV_ID}` using the data retrieved from Semantic Scholar. All scores feed into a composite credibility score stored in `summary.json` under the `credibility` key.

## Recency Score

Formula:
```
recency_score = e^(-0.15 * (CURRENT_YEAR - paper_year))
```

Reference values:
- 2026 paper: ~1.0
- 2025 paper: ~0.86
- 2024 paper: ~0.74
- 2022 paper: ~0.55
- 2020 paper: ~0.41
- 2018 paper: ~0.30

Use the paper's publication year. If the paper is a preprint without a formal publication date, use the preprint submission year.

## Citation Count

Raw citation count from Semantic Scholar (`get_paper_details`).

Context normalization -- set `citation_context` based on paper age:
- **Papers < 1 year old**: Citation count is unreliable. Set `citation_context` to `"too_recent_for_citations"`.
- **Papers 1-3 years old**: Compare to field average if available. Set `citation_context` to `"early_citations"`.
- **Papers 3+ years old**: Raw count is meaningful. Set `citation_context` to `"mature"`.

## Author H-Index

Collect h-index values for each author (or top 3 authors if more than 3).
Source: `mcp__semantic-scholar__get_author_details(author_id)` for each author.

Store as `author_h_indices` array and compute `avg_h_index` as the arithmetic mean.

## Venue Tier

Classify the publication venue into one of these tiers:

- **`"top_tier"`**: NeurIPS, ICML, ICLR, ACL, EMNLP, CVPR, ICCV, ECCV, Nature, Science, JMLR, TACL, Transactions on Pattern Analysis and Machine Intelligence (TPAMI), KDD, SIGIR, WWW, AAAI (main conference)
- **`"respected"`**: AAAI workshop tracks, IJCAI, NAACL, COLING, WACV, BMVC, workshops at top-tier venues, COLM, EACL, Findings of ACL/EMNLP
- **`"preprint"`**: arxiv only, no peer review venue listed
- **`"other"`**: Any other venue not listed above

If the venue is ambiguous or unknown, default to `"other"`.

## Reproducibility Signals

Check the paper content for reproducibility indicators:

- **`has_code`**: Search for "github.com", "gitlab.com", "code available", "our implementation", "source code", or "code release" in the paper text. Set `true` if any match is found.
- **`has_data`**: Search for "dataset available", "publicly available", "benchmark", "we release", or "data release" in the paper text. Set `true` if any match is found.
- **`peer_reviewed`**: Set `true` if `venue_tier` is NOT `"preprint"`.

## Composite Score

Compute the composite credibility score:

```
composite = (recency * 0.2)
          + (normalized_citations * 0.25)
          + (avg_h_index_normalized * 0.2)
          + (venue_score * 0.2)
          + (reproducibility_score * 0.15)
```

Component normalization:
- `normalized_citations`: `min(citation_count / 100, 1.0)` -- caps contribution at 100 citations
- `avg_h_index_normalized`: `min(avg_h_index / 50, 1.0)` -- caps contribution at h-index of 50
- `venue_score`: `top_tier=1.0`, `respected=0.7`, `preprint=0.3`, `other=0.5`
- `reproducibility_score`: `(has_code * 0.4) + (has_data * 0.3) + (peer_reviewed * 0.3)` where `true=1`, `false=0`

If any component data is unavailable (`null`), exclude it from the calculation and redistribute its weight proportionally across the remaining components.

Round the final composite score to 3 decimal places.

## Flags

Assign applicable flags as a string array:

- `"retracted"` -- Paper has been retracted (check Semantic Scholar metadata).
- `"superseded"` -- A newer version of the paper exists (check arxiv version info).
- `"preprint"` -- Not peer reviewed (venue_tier is `"preprint"`).
- `"highly_cited"` -- Citation count exceeds 500 (rough proxy for top 1% in ML/AI).
- `"too_recent_for_citations"` -- Published within the last year; citation count is not yet meaningful.
- `"insufficient_data"` -- Could not retrieve enough data from Semantic Scholar to compute a reliable score.

## Output

Store all computed values in the `credibility` object within `summary.json`. Set `credibility.status` to:
- `"scored"` if the composite score was successfully computed.
- `"insufficient_data"` if Semantic Scholar returned no results or too little data to compute scores.
