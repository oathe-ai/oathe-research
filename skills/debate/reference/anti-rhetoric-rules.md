# Anti-Rhetoric Detection Rules

These rules protect debate integrity by identifying and penalizing rhetorical tactics that substitute for evidence.

## Automatic Penalties

### 1. Appeal to Authority (-3 points)
**Detection**: Argument relies on who said something rather than what the evidence shows.
**Examples**:
- "This must be true because it's from a Nature paper"
- "The lead author is a renowned expert in this field"
- "This approach is endorsed by Google/OpenAI/DeepMind"
**Exception**: Citing an author's specific experimental results is NOT an authority appeal.

### 2. Unfalsifiable Claims (-3 points)
**Detection**: Claim is structured so no possible evidence could disprove it.
**Examples**:
- "This approach is likely to work in many scenarios"
- "The model captures something important about intelligence"
- "Further research may show this is correct"
**Test**: Ask "What evidence would prove this wrong?" If no answer exists, it's unfalsifiable.

### 3. Strawmanning (-5 points — HIGHEST PENALTY)
**Detection**: Misrepresenting an opponent's argument to make it easier to attack.
**Examples**:
- Oversimplifying a nuanced position
- Attributing claims the opponent didn't make
- Ignoring qualifications and caveats in opponent's argument
**Verification**: Compare the attack target with the original argument verbatim.

### 4. Ignoring Cited Counterevidence (-3 points)
**Detection**: Opponent presented specific evidence that contradicts the claim, and the agent proceeds without addressing it.
**Examples**:
- Moving to a new argument without addressing the challenge
- Repeating the original claim louder
- Acknowledging the evidence exists but not engaging with it

### 5. Emotional/Urgency Framing (-2 points)
**Detection**: Using emotional language or urgency to bypass critical evaluation.
**Examples**:
- "This is critical for the future of AI safety"
- "Failure to adopt this approach could be catastrophic"
- "This breakthrough represents a paradigm shift"
**Exception**: If urgency claim is backed by specific quantitative evidence, no penalty.

### 6. Cherry-Picking (-2 points)
**Detection**: Selecting favorable evidence while ignoring contradictory data from the SAME source.
**Examples**:
- Citing one benchmark where method excels, ignoring others where it fails
- Quoting results paragraph but ignoring limitations section
- Using specific numbers out of context

## Judge Instructions
- Apply penalties CUMULATIVELY — an argument can receive multiple penalties
- Always justify each penalty with a specific quote or reference
- Penalties cannot reduce adjusted score below 0
- Track total penalties per agent across the round for pattern detection
