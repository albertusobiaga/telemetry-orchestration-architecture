-- Spanner DDL: High-Throughput IoT Telemetry Ledger

-- Parent table for machines (Bioreactors and Chillers)
CREATE TABLE Assets (
    FacilityID STRING(10) NOT NULL,
    MachineID STRING(50) NOT NULL,
    AssetType STRING(20) NOT NULL, -- 'CSTR' or 'CHILLER'
    InstallationDate DATE,
    Status STRING(20)
) PRIMARY KEY (FacilityID, MachineID);

-- Interleaved child table for telemetry events
-- This ensures sensor readings are co-located with their parent asset
CREATE TABLE TelemetryEvents (
    FacilityID STRING(10) NOT NULL,
    MachineID STRING(50) NOT NULL,
    EventTimestamp TIMESTAMP NOT NULL,
    EventID STRING(36) NOT NULL,
    SensorType STRING(20) NOT NULL,
    ReadingValue FLOAT64 NOT NULL,
    UnitOfMeasure STRING(10),
    BatchID STRING(50),
    MaintenanceMode BOOL
) PRIMARY KEY (FacilityID, MachineID, EventTimestamp DESC),
  INTERLEAVE IN PARENT Assets ON DELETE CASCADE;

-- Index for real-time alerting on critical temperature/pressure anomalies
CREATE INDEX idx_critical_readings 
ON TelemetryEvents (SensorType, ReadingValue DESC) 
WHERE SensorType IN ('thermal', 'pressure');