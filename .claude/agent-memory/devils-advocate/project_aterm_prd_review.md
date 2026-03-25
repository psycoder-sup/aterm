---
name: aterm PRD review status
description: Status and key findings from devil's advocate reviews of aterm PRD (v1.0 scored 0.68, v1.1 scored 0.82, v1.3 scored 0.87)
type: project
---

Reviewed aterm PRD v1.3 on 2026-03-24. Score: 0.87/1.0 (up from 0.82 on v1.1, 0.68 on v1.0).

**Why:** v1.1 majors were resolved (persistence location, quit race condition, OQ#6 fresh shell). Two new Major concerns: (1) OQ#10 persistence format still unresolved but FR-23 already uses JSON-like notation (internal inconsistency); (2) OQ#3 pane limit still TBD with no due date -- unlimited recursive splits with no resource exhaustion handling. Minor issues: serialization failure path unspecified in FR-23, FR-43 keyboard resize interaction model vague, FR-01/FR-02 missing "reorder" despite User Story 10 requiring it, profile inheritance visibility unspecified, macOS 26 rationale doesn't name specific APIs.

**How to apply:** PRD is implementation-ready through M4. Major items must resolve before M2 (pane limits) and M5 (persistence format). If v1.4 review requested, verify OQ#10 is closed, OQ#3 has a due date, and FR-23 has a serialization failure clause.
