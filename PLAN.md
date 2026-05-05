# Remove the standalone Vial Inventory page and surface vials inside each protocol

## What changes

The standalone "Vial Inventory" page is going away. Every vial will live where it actually matters — inside the protocol it belongs to. One source of truth, less navigation.

## What you'll see

- **Profile menu**: the "Vial Inventory" row is removed. Scan history stays accessible from a smaller link in Settings (so old scans aren't lost).
- **Protocol detail page**: gets a new **"Vials"** section in the same premium editorial styling as the rest of the page. It shows:
  - Active vial up top (with batch, source, expiration/BUD, doses remaining, low-stock chip)
  - Stockpiled / reserve vials below (collapsed by default, tap to expand)
  - Archived/depleted vials tucked into a "History" disclosure
  - Add Vial, Scan Vial, and Integrity Check actions live right here
- **Home protocol tracker**: unchanged on the surface, but the "Manage Vials" button now jumps directly to the Vials section of that protocol's detail page instead of opening the old inventory sheet.
- **Reconstitution Calculator**: still pulls from the same vial data, no visible change.

## Rules

- Every vial must be tied to a protocol's compound. You can't add a "floating" vial anymore.
- If a user tries to add a vial for a compound with no active protocol, we prompt them to start a protocol first (one tap — pre-fills the compound).
- Existing vials are preserved and automatically shown under their matching protocol.

## What stays the same

- All vial data, batch info, scan history, BUD/expiry tracking, low-stock alerts, supply forecasts, and AI context — fully intact.
- Onboarding's vial-setup step still works.
- The morning brief and AI assistant still see the full vial picture.

