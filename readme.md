# COLLATERALIZATION / BESICHERUNGSSTRUKTUR

## NordLB Sicht

In der Nord/LB reden wir von Konten, Verträgen und Vermögensobjekten.

```mermaid
graph TB

  subgraph "Nord/LB Sicht"
  SubGraph1F(Konto/Facility)
  SubGraph1K(Kunde/Client)
  SubGraph2SV(Sicherheitenvertrag/Sicherheitenrecht/Collateral)
  SubGraph3VO(Vermögensobjekt/Asset)
  SubGraph1K -- 1:n --> SubGraph1F
  SubGraph1F -- n:m --> SubGraph2SV
  SubGraph1K -- n:m --> SubGraph2SV
  SubGraph2SV -- n:m --> SubGraph3VO
  end

```

## EZB Sicht

In der EZB redet man von Instruments und Protections.

```mermaid
graph TB

  subgraph "EZB Sicht"
  SubGraph1F(Konto/Instrument)
  SubGraph1K(Kunde/Entity)
  SubGraph3VO(Sicherheit/Protection)
  SubGraph1K -- 1:n --> SubGraph1F
  SubGraph1F -- n:m --> SubGraph3VO
  end

```
