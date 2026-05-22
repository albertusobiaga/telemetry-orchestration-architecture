# Pharmaceutical Factory IoT Telemetry Orchestration (Sanitized Blueprint)

> **Security & Compliance Disclaimer:** > This repository is a sanitized architectural blueprint authorized for public portfolio release. Specific facility codes, hardware vendor IDs, proprietary chemical tolerance bands, API identifiers, and exact physical facility locations have been redacted or replaced with generic identifiers to comply with NDA and FDA 21 CFR Part 11 security guidelines.

## Executive Summary
This repository contains the architectural blueprints, data contracts, and decision logs for a high-frequency IoT ingestion and analytical pipeline designed for a critical pharmaceutical production line. The system ingests continuous telemetry from manufacturing equipment, enforcing strict relational integrity for real-time alerting before bridging the data into an analytical feature store for downstream predictive maintenance models.

## System Scope & Phase 1 Constraints
A standard pharmaceutical production line contains dozens of Programmable Logic Controllers (PLCs) and hundreds of sensor arrays. However, attempting a "big-bang" cloud integration across an entire factory floor introduces unacceptable operational risk and data governance complexities.

This repository documents the **Phase 1 Unit Operation Rollout**. 
* **In Scope (Phase 1):** The highest-value asset (The CSTR Bioreactor) and its primary thermal dependency (The Cooling Jacket). 
* **Out of Scope (Phase 2+):** Upstream peristaltic feed pumps, downstream centrifuges, and secondary holding tanks.

By constraining the Phase 1 scope to these two critical machines, we establish a hardened, auditable data contract capable of complex time-series correlation (e.g., calculating thermal lag between systems operating at different frequencies). Once this relational ledger achieves a 99.9% validation pass rate, it can scale horizontally to the remaining factory assets without altering the core infrastructure.

## System Topology (The GCP Stack)
This architecture utilizes a **Log-Structured Relational to Analytics** pattern, explicitly minimizing procedural Python pipelines in favor of declarative SQL state management to ensure regulatory auditability.

1. **Ingestion Gate (Cloud Pub/Sub):** Absorbs high-frequency bursts (10Hz - 50Hz) from the edge gateways via MQTT, providing asynchronous decoupling.
2. **Operational Ledger (Cloud Spanner):** Enforces external ACID consistency for real-time sensor state. `MachineID` is used as the primary key prefix to distribute write-load, enabling sub-second alerting for temperature and pressure anomalies.
3. **Analytical Federation (BigQuery):** Reads directly from Spanner via Federated Queries, eliminating the need to duplicate raw event logs into a separate Data Lake.
4. **Transformation Boundary (Dataform / SQLX):** Acts as the exclusive logic engine, aggregating raw operational events into time-windowed feature tables for downstream Machine Learning models.

## Data Science Integration & Consumption

This architecture strictly separates **Data Engineering** (Feature Creation) from **Data Science** (Model Training/Inference). We use an "Interface Contract" to govern how the ML models consume the data we produce.

| Component | Responsibility | Technical Implementation |
| :--- | :--- | :--- |
| **Feature Engineering (Engineering)** | Logic, sanitization, time-series alignment, and windowing. | Dataform (SQLX) |
| **The Interface (The Contract)** | A finalized BigQuery "Gold" table (The Feature Store). | BigQuery View / Materialized Table |
| **Model Consumption (Data Science)** | Experimentation, feature selection, training, and inference. | Vertex AI / TensorFlow / Python |

### The Interface Protocol
The ML models do not access raw sensor telemetry. They consume the **Feature Store** (the Gold Layer tables produced by Dataform) using a strict access protocol:

1. **Immutability**: The feature tables (e.g., `thermal_drift_5min`) are versioned by batch and timestamp. Models never overwrite the underlying data; they read from specific, time-bound snapshots.
2. **Schema Enforcement**: If the Data Science team requires a new feature (e.g., "Rolling 10-minute Pressure Variance"), they cannot modify the SQLX code directly. They submit a request to the Data Engineering team, who implements the logic, validates the DDL, and promotes the feature to the Gold Layer. This ensures the ML pipeline remains decoupled from the infrastructure pipeline.
3. **Latency**: The ML inference service polls the Gold Layer tables via the BigQuery Storage API, ensuring high-throughput access that does not contend with raw ingestion processes.

## Repository Structure

* `/architecture-artifacts/`
  * `architectural-decisions.md`: The log of major technical trade-offs (e.g., Spanner vs. Azure Lakehouse, Dataform vs. Python).
  * `edge-topology.md`: The physical hardware constraints and generation rules driving the cloud infrastructure.
  * `spanner-ddl.sql`: The strictly typed relational schema for the operational ledger.
* `/data-contracts/` (Hardened interfaces for data producers and consumers)
  * `/ingestion/`: JSON Schemas governing raw IoT event payloads.
    * `cstr-telemetry-spec.json`: JSON Schema (Draft-07) for the Bioreactor edge payloads.
    * `chiller-telemetry-spec.json`: JSON Schema (Draft-07) for the Cooling Jacket edge payloads.
  * `/consumption/`: API contracts governing Gold-layer feature tables for ML consumption.

## Intellectual Property Notice
This repository contains generalized architectural patterns and abstract design logic intended for portfolio demonstration purposes. It does not contain proprietary data, business logic, sensitive implementation code, or confidential intellectual property belonging to any past or present client. All identifiers and data structures have been sanitized or synthesized to ensure compliance with Non-Disclosure Agreements (NDAs).

---
* Licensed under the [MIT License](LICENSE).*