# Edge Topology & Ingestion Boundaries

*Note: This document has been sanitized for public release. Specific hardware vendor IDs, proprietary chemical tolerance bands, API identifiers, and exact physical facility locations have been redacted.*

## 1. Architectural Scope Constraint: Unit Operation Focus
This blueprint focuses strictly on the Phase 1 deployment: **The Bioreactor Unit Operation**. 

Upstream feed systems (peristaltic pumps) and downstream purification (centrifuges) are considered out-of-scope for this specific ledger implementation. Constraining the physical scope to the highest-value asset and its immediate thermal dependencies allows us to enforce strict operational ledger schemas in Spanner before attempting wide-factory integration.

## 2. Edge Context
The `[REDACTED]` production line utilizes a Continuous Stirred-Tank Bioreactor (CSTR) paired with an external Cooling Jacket system. Data is generated at the edge, buffered by local IoT gateways, and published to GCP Pub/Sub via MQTT. 

The architecture must handle high-frequency, semi-structured telemetry under strict ordering constraints to identify thermal drift and mechanical degradation before batch spoilage occurs.

## 3. Sanitized Sensor Registry
The following device models dictate the ingestion velocity and schema requirements for the Cloud Spanner operational ledger.

| Machine / Subsystem | Sensor / Device Class | Operational Role | Telemetry Frequency | Payload Blueprint | Architectural Constraint |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **CSTR** | **Thermal Probe** | Core API temperature monitoring. | 10 Hz | `{"thermal": float}` | **Critical Latency:** Triggers physical safety valves if tolerance is breached. |
| **CSTR** | **Pressure Transducer** | Internal tank pressure. | 10 Hz | `{"pressure": float}` | **Critical Latency:** Monitored for cavitation risks. |
| **CSTR** | **Agitator Tachometer** | Shaft vibration and RPM monitoring. | 50 Hz (Burst) | `{"rpm": int, "vib_hz": float}` | **Burst Handling:** Architecture relies on edge aggregation to smooth burst packets. |
| **Cooling Jacket** | **Inlet Temp Sensor** | Monitors coolant temperature before it hits the CSTR. | 5 Hz | `{"inlet_temp": float}` | **Relational Delta:** Must be time-joined in Dataform against CSTR temp to calculate cooling efficiency lag. |
| **Cooling Jacket** | **Flow Meter** | Coolant flow rate into the jacket. | 5 Hz | `{"flow_lpm": float}` | **Lineage Anchor:** Correlated via `BatchID` to track thermal mitigation efforts. |

## 4. Data Generation Rules (The Edge Contract)
To protect the integrity of the Spanner database and the downstream BigQuery analytical models, the Edge Gateway must enforce the following rules before data is permitted into the cloud environment:

1. **Clock Synchronization:** All edge devices must sync to a local NTP server. The cloud pipeline will reject any payload with a timestamp older than `[REDACTED_SLA_LIMIT]` seconds to prevent out-of-order state corruption in the ledger.
2. **Immutable Correlation:** The Edge Gateway assigns a unique UUID (`event_id`) to every packet. The Cloud architecture uses this exclusively for idempotent deduplication.
3. **Payload Flattening:** Deeply nested JSON from proprietary vendor hardware must be flattened at the edge gateway to map cleanly into Spanner's strict relational DDL.

## 5. Ingestion Governance & Frequency Management
To maintain the relational integrity of the operational ledger, ingestion is not "continuous streaming" in the traditional sense; it is **Managed Batch Ingestion**.

| Ingestion Source | Frequency | Handling Strategy | Downstream Impact |
| :--- | :--- | :--- | :--- |
| **Thermal/Pressure** | 1Hz - 10Hz | Buffered Write (1s batch) | Low latency; critical for immediate alerting. |
| **Agitator Tachometer** | 50Hz (Burst) | Aggregated Write (5s batch) | High latency; intended for trend analysis, not per-packet alerting. |

* **Velocity Control:** The edge gateway is configured to throttle bursts if throughput exceeds `[REDACTED_TPS]`, ensuring the cloud ingestion pipeline remains deterministic regardless of physical hardware anomalies.
* **Idempotency:** Because batches are retried on network failure, all `event_id`s are verified as unique by the Cloud Spanner index before the `INSERT` operation is committed.

## 6. Exception Handling & Dead Letter Queue (DLQ) Boundary
To enforce data integrity at the ingestion layer, payloads that violate the JSON Schema Contracts (located in `/data-contracts/ingestion/`) are strictly prevented from entering the Spanner operational ledger.

* **Validation Point:** Pub/Sub Schema Validation is enabled at the topic level.
* **Rejection Routing:** Messages failing validation (e.g., undocumented `sensor_type`, missing `BatchID`) are automatically routed to a dedicated Dead Letter Topic.
* **Storage & Alerting:** A secondary Cloud Function writes these failed payloads into a BigQuery `bronze_dlq` table, appending a `validation_error_string`. This triggers a high-priority alert to the operations team to investigate potential edge gateway misconfiguration without halting the valid telemetry stream.