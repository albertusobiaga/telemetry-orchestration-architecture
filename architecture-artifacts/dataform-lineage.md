# Dataform Lineage & Transformation Strategy

This blueprint utilizes a "Medallion Architecture" implemented via Dataform (SQLX). All transformations are declarative and pushed down to BigQuery compute.

## 1. Bronze: The Raw Ingestion Layer
* **Source:** Cloud Spanner (Federated Query).
* **Logic:** 1:1 mapping of raw telemetry events.
* **Goal:** Create an immutable, append-only staging area. No filtering or transformation applied here.

## 2. Silver: The Normalized/Validated Layer
* **Logic:** * Deduplication based on `event_id`.
    * Time-series alignment (joining CSTR and Chiller streams).
    * Handling of "Burst" Agitator data (Aggregation of 50Hz samples into 1-second averages).
* **Goal:** Create a "Clean" event stream ready for analytical querying.

## 3. Gold: The Feature Store Layer
* **Logic:** Rolling-window calculations.
    * Example: `AVG(ReadingValue) OVER (PARTITION BY MachineID ORDER BY EventTimestamp ROWS BETWEEN 5 PRECEDING AND CURRENT ROW)`
* **Goal:** Deliver ready-to-consume features (e.g., "5-Minute Thermal Drift") to the ML Models (`[REDACTED_MODEL_V3]`).

## Lineage Governance
* **Auditability:** Every transformation is defined in SQLX. BigQuery generates the lineage graph automatically, providing a visual audit trail for compliance teams to trace any feature value back to the raw sensor reading.