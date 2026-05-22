## 1. Platform Selection: Google Cloud Stack (Spanner) vs. Azure + Databricks (Lakehouse)
Status: Proposed
Context: The chemical production line generates continuous high-frequency telemetry streams from critical manufacturing equipment. A single unexpected equipment failure can ruin active pharmaceutical ingredient (API) batches, causing severe financial loss and regulatory compliance violations. The data platform must ingest thousands of events per second while guaranteeing absolute data integrity, sub-second transactional alerting, and a bulletproof audit trail for regulatory bodies.
Decision: We select native Google Cloud infrastructure centered on Cloud Spanner for operational event storage and BigQuery for analytical data modeling, rejecting an Azure + Databricks Lakehouse architecture.

+--------------------------------------------------------------------------+
|                          COMPLIANCE & RISK PROFILES                      |
+--------------------------------------------------------------------------+
| AZURE / DATABRICKS (Delta Lake)    | GCP STACK (Cloud Spanner)           |
|------------------------------------|-------------------------------------|
| - Storage: Object Store (ABFS)     | - Storage: Relational Compute Engine|
| - Consistency: Micro-batch ACID    | - Consistency: True External ACID   |
| - Latency: Near Real-Time (Seconds)| - Latency: Sub-second Operational   |
| - Audit: Eventual Log Commits      | - Audit: Real-time Strict Ledger    |
+--------------------------------------------------------------------------+

Consequences:
  * Pros: 
    * True ACID Compliance at Scale: Spanner provides external consistency and relational integrity at horizontal scale. This guarantees that sensor threshold alerts and system state changes are recorded with zero risk of replication lag or dirty reads, satisfying strict regulatory compliance audits.
    * Hybrid Operational/Analytical Capability: We can run operational alerting systems directly on the live database without degrading ingestion performance, using BigQuery federated queries for immediate downstream analysis.
    * Reduced Operational Overhead: A fully managed serverless infrastructure (Pub/Sub + Spanner + BigQuery) eliminates the cluster management, tuning, and node provisioning overhead inherent in Databricks/Spark environments.
  * Cons: 
    * Financial Cost: Cloud Spanner carries a significantly higher baseline compute cost compared to storing raw files in Azure Blob Storage or AWS S3.
    * Rigid Schemas: Unlike an open-ended data lakehouse where schemas can be applied lazily at read time, Spanner requires strict upfront relational schemas for the event ledger.

Alternatives Rejected: Azure Event Hubs + Databricks (Delta Lake)
Why: While a Delta Lake structure on Azure provides cost-effective storage and powerful analytical processing, it operates on an object-storage abstraction layer. For a pharmaceutical production line, micro-batching latencies and eventual consistency models pose an architectural risk. If an alerting system misses an operational state transition due to storage commit delays, a batch of medicine could be compromised before the pipeline registers the anomaly. We prioritized real-time relational consistency and compliance isolation over cheap analytical storage.

## 2. Analytical Transformation Boundary: Dataform (SQLX) vs. Procedural Pipelines (Python/Beam)##
Status: Accepted (Sanitized)
Context: Raw continuous telemetry from the [REDACTED] Bioreactor arrays is successfully landing in Cloud Spanner. However, the downstream Data Science team requires aggregated, time-windowed feature tables (e.g., 5-minute rolling averages of thermal drift) to train the predictive maintenance models ([REDACTED_MODEL_V3]). We require an ELT layer to bridge the operational ledger (Spanner) and the analytical feature store (BigQuery).
Constraint: The architecture must minimize procedural code (Python/Java) to reduce infrastructure overhead, mitigate dependency vulnerabilities, and ensure that all transformations are strictly declarative and auditable for FDA compliance.
Decision: We utilize BigQuery Federated Queries to bridge Spanner data into BigQuery, and Dataform (SQLX) as the exclusive orchestration and transformation engine. We strictly prohibit the use of procedural Python pipelines for standard feature engineering.
Consequences:
  * Pros: 
    * Zero-Infrastructure ELT: By relying entirely on Dataform, all transformations are pushed down into BigQuery's native compute engine. We maintain zero custom Python environments or Spark clusters.
    * Declarative Auditability: SQLX acts as self-documenting code. Every feature transformation is version-controlled in Git, and Dataform automatically generates the dependency DAG. This provides a transparent lineage graph required by pharmaceutical regulators.
    * Skill-Set Alignment: The platform team can manage complex data engineering using advanced SQL, removing the bottleneck of requiring specialized Python Data Engineers for every feature request.
  * Cons: 
    * Compute Cost: Executing heavy, rolling-window SQL transformations directly in BigQuery incurs higher query costs compared to processing them in-memory on a dedicated Spark cluster.
    * Mathematical Limitations: SQL is sub-optimal for complex mathematical transformations (e.g., Fourier transforms on vibration data). If the Data Science team requires these, they must handle them downstream in Vertex AI.
Alternatives Rejected: Cloud Dataflow (Apache Beam / Python). While Apache Beam is the GCP standard for streaming data transformations, deploying custom Python pipelines introduces significant CI/CD overhead, library dependency management, and complex error handling. In a highly regulated environment, a declarative SQL state (Dataform) is significantly easier to audit and defend during a compliance review than thousands of lines of procedural Python code. We traded computational flexibility for auditability and simplicity.

## 3. Deployment Strategy: Unit Operation Focus vs. Full-Line Integration

**Status:** Accepted

**Context:** The `[REDACTED]` production line consists of 45+ distinct machine assets. The business requires predictive maintenance models across the entire line. We must decide between engineering the data contracts for all machines simultaneously or constraining the initial architecture to a single unit operation.

**Decision:** We will strictly constrain the Phase 1 data architecture to the Bioreactor and its integrated Cooling Jacket. We will not ingest data from upstream or downstream assets until the relational ledger for these two systems achieves a 99.9% validation pass rate.

**Consequences:**
  * **Pros:** 
    * Allows the engineering team to focus on solving the hardest logic problem first: time-series correlation between two systems running at different frequencies (10 Hz vs. 5 Hz).
    * Limits the "blast radius" if a schema migration is required during early testing.
  * **Cons:** 
    * Delays the delivery of end-to-end line analytics for the Data Science team.

## 4. High-Frequency Ingestion Strategy (Edge-to-Ledger)
Status: Accepted
Context: The Agitator Tachometer generates 50Hz (burst) telemetry. Directly writing these events into Cloud Spanner creates significant write-amplification, risks exceeding row-mutation limits per second, and dramatically inflates costs.
Decision: We implement an Asynchronous Edge-Buffering Pattern. Edge gateways batch 5 seconds of telemetry into a single Pub/Sub message. The ingestion pipeline (Dataflow/Cloud Function) then performs a bulk write into Spanner.
Consequences:
Pros: * Cost Optimization: Reduces the volume of individual transaction commits, lowering Cloud Spanner processing costs.
System Stability: Eliminates write-hotspots on the TelemetryEvents table by smoothing out the spikey 50Hz bursts into predictable batch writes.
Cons: * Increased Latency: Real-time data availability in Spanner is delayed by the 5-second buffer window.
Complexity: Requires handling "late-arrival" data if the gateway buffer flushes intermittently.
Alternatives Rejected: Direct Synchronous API Writes
Why: Synchronous writing at 50Hz would lock our Spanner nodes during high-burst events, causing backpressure in the production line. We prioritize system resilience over sub-second event visibility.