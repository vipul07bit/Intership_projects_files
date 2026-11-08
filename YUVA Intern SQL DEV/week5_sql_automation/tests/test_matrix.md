# Test matrix and evidence

| ID | Scenario | Expected outcome | Evidence source |
|---|---|---|---|
| T01 | Valid sale of 1 unit | One order + one line; stock decreases by 1 | `sql/07_tests.sql` |
| T02 | Quantity 0 / negative | Procedure raises validation error; no sale | Procedure guard |
| T03 | Quantity exceeds stock | Error; no partial order remains | `sql/07_tests.sql` |
| T04 | Stock falls to reorder level or below | One OPEN alert exists | Trigger assertion |
| T05 | Stock replenished above reorder level | OPEN alert becomes RESOLVED | Trigger assertion |
| T06 | Re-run daily snapshot same date | Upsert, no duplicate daily row | `sp_capture_daily_inventory` |
| T07 | Re-run archive procedure | No duplicate archive IDs | Unique indexes + ON CONFLICT |
| T08 | Archive failure | Transaction aborts; source records retained | Procedure exception path |

## Execution record
The package has not been run against the user's PostgreSQL instance in this workspace. After execution, paste the terminal output below or save it as `execution_log.txt`.

- PostgreSQL version:
- Execution date/time:
- Database/schema:
- Script exit status:
- Test assertions:
- Actual row counts:
- Any failures and corrective actions:

Never convert an expected result into an observed result without executing the script.
