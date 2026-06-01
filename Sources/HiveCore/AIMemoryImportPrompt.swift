import Foundation

public enum AIMemoryImportPrompt {
    public static let markdown = """
    I am importing this into Hive, a premium second-brain app that builds an initial memory web from prior AI conversations.

    Your job is NOT to write a conversational summary.
    Your job is to convert this chat history into a structured memory seed that Hive can use with high confidence.

    Read the entire conversation I provide after this prompt and output the result in the exact format below.

    GOALS
    - Extract the highest-signal durable memory from the conversation.
    - Prioritize things that would matter to a second brain:
      projects, recurring goals, preferences, constraints, people, organizations, places, tools, plans, repeated topics, decisions, habits, unresolved questions.
    - Distinguish certainty levels very carefully.
    - Do not invent facts.
    - Do not use vague motivational language.
    - Do not output generic AI-summary filler.
    - If something is ambiguous, mark it unresolved instead of claiming it as true.

    OUTPUT FORMAT

    # HIVE MEMORY SEED

    ## 1. Canonical Profile
    A compact factual profile of the user with only high-confidence details.

    Return as JSON:

    ```json
    {
      "identity": {
        "name": "",
        "role_or_roles": [],
        "locations": [],
        "organizations": [],
        "high_confidence_descriptors": []
      },
      "preferences": [
        {
          "claim": "",
          "confidence": 0.0,
          "evidence_quote": ""
        }
      ],
      "constraints": [
        {
          "claim": "",
          "confidence": 0.0,
          "evidence_quote": ""
        }
      ]
    }
    ```

    ## 2. Entities
    Return a JSON array of entities mentioned in the conversation.

    Entity types allowed:
    - person
    - project
    - company
    - organization
    - place
    - product
    - technology
    - concept
    - event

    Format:

    ```json
    [
      {
        "id": "entity_slug",
        "name": "",
        "type": "",
        "description": "",
        "confidence": 0.0,
        "aliases": [],
        "evidence_quote": ""
      }
    ]
    ```

    Only include entities that matter enough to appear in an initial memory graph.

    ## 3. Confirmed Claims
    Return a JSON array of claims that are strongly supported by the conversation.

    Format:

    ```json
    [
      {
        "id": "claim_slug",
        "subject": "entity_slug_or_user",
        "predicate": "",
        "object": "",
        "confidence": 0.0,
        "why_it_matters": "",
        "evidence_quote": ""
      }
    ]
    ```

    Do NOT include trivial one-off remarks.

    ## 4. Unresolved Claims
    Return a JSON array of plausible but not fully confirmed claims.

    ```json
    [
      {
        "id": "unresolved_slug",
        "claim": "",
        "confidence": 0.0,
        "why_uncertain": "",
        "best_followup_question": "",
        "evidence_quote": ""
      }
    ]
    ```

    ## 5. Refused Inferences
    ```json
    [
      {
        "id": "refusal_slug",
        "possible_inference": "",
        "reason_to_refuse": "",
        "evidence_quote": ""
      }
    ]
    ```

    ## 6. Projects
    ```json
    [
      {
        "id": "project_slug",
        "name": "",
        "status": "active|paused|idea|unclear",
        "summary": "",
        "goals": [],
        "stack_or_tools": [],
        "related_entities": [],
        "confidence": 0.0,
        "evidence_quote": ""
      }
    ]
    ```

    ## 7. Source Clusters
    ```json
    [
      {
        "id": "cluster_slug",
        "label": "",
        "summary": "",
        "primary_entities": [],
        "primary_projects": [],
        "signal_level": "high|medium|low",
        "why_this_cluster_matters": ""
      }
    ]
    ```

    ## 8. Relationship Edges
    ```json
    [
      {
        "source": "entity_or_project_slug",
        "target": "entity_or_project_slug",
        "relationship": "",
        "confidence": 0.0,
        "evidence_quote": ""
      }
    ]
    ```

    ## 9. Wiki Starters
    ```json
    [
      {
        "title": "",
        "type": "project|person|topic|workflow|preference",
        "starter_summary": "",
        "linked_entities": [],
        "open_questions": []
      }
    ]
    ```

    ## 10. One-Question Priorities
    ```json
    [
      {
        "question": "",
        "unlocks": ""
      }
    ]
    ```

    QUALITY RULES
    - Be precise.
    - Be conservative.
    - Prefer omission over invention.
    - Confidence scoring guide:
      - 0.95 to 1.00 = directly and repeatedly stated
      - 0.80 to 0.94 = directly stated once, still clear
      - 0.60 to 0.79 = plausible but not fully established
      - below 0.60 = usually should not appear unless in Refused Inferences
    - Use short evidence quotes pulled from the conversation.
    - No prose before or after the output.
    - Output valid JSON blocks exactly where requested.

    After this prompt, I will paste the conversation transcript.

    IMPORTANT FOR HIVE INGESTION:
    \(ExtractionQualityRules.systemPrompt)

    - Normalize duplicate names and projects into single canonical entities.
    - Prefer project-centric extraction over generic life-summary extraction.
    - Preserve technical nouns exactly when possible.
    - If the user appears to be building software, extract repositories, app names, stack choices, architectural constraints, and active implementation goals as first-class memory.
    - If the conversation contains repeated stylistic or UX preferences, treat them as likely durable preferences.
    - Never output empty arrays unless the conversation truly contains no signal for that section.
    """
}
