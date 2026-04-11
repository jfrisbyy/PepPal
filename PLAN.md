# Smarter Protocol Setup: Compound-Aware Dosing, Skip Goal for Existing Protocols, Log Past Doses

## What's Changing

The protocol setup flow is getting a major intelligence upgrade. The system will know what unit each compound uses (mg vs mcg), skip unnecessary steps when logging an existing protocol, remove the experience level picker, and let users log past doses with specific dates.

---

### **Features**

- **"Log Current Protocol" skips the goal step entirely** — goes straight from path selection to compound selection (3 steps instead of 5: Compounds → Dosing → Schedule/Review)
- **"Start New Protocol" keeps the goal step** but it becomes optional (can skip it)
- **Experience level picker is removed** from the dosing screen — doses default to sensible mid-range values based on compound data
- **Compound-aware dose units** — each compound automatically shows the correct unit:
  - Semaglutide → mg (0.25–2.4)
  - Tirzepatide → mg (2.5–15)
  - Retatrutide → mg (1–12)
  - Tesamorelin → mg (1–2)
  - MK-677 → mg (10–25)
  - BPC-157 → mcg (250–500)
  - Ipamorelin → mcg (100–300)
  - Sermorelin → mcg (200–500)
  - …and so on for all compounds in the database
- **Dose input shows the compound's natural unit** — no more seeing "mcg" for compounds that are always dosed in mg
- **Simplified dosing card for "Log Current Protocol"** — just shows a clean dose input, frequency, and route without the tiered dosing recommendation panel (you already know what you're taking)
- **Log past doses when saving an existing protocol** — after saving, a sheet asks "Want to log any past doses?" with the ability to add multiple entries with custom dates and dosages
- **Dose logging sheet updated** to show the correct unit per compound (mg or mcg) instead of always showing "mcg"
- **All display surfaces updated** — home screen protocol cards, protocol detail view, and dose history will show the proper unit (e.g. "2.5 mg Semaglutide" not "2500 mcg")

---

### **Design**

- The dosing card for existing protocols is cleaner and more streamlined — just the compound name, a dose field with the correct unit, frequency picker, and route
- The recommended dose range still appears as a subtle hint below the dose field (e.g. "Typical: 0.25–2.4 mg weekly") but without the beginner/intermediate/advanced breakdown
- Past dose logging uses a simple list-style sheet where each row has: date picker, dose amount, and an add button
- The flow for logging an existing protocol feels noticeably faster — 3 taps to get through if you know what you're on

---

### **Flow Changes**

**New Protocol path:** Choose Path → Goal (optional) → Compounds → Dosing → Schedule → Review
**Log Current Protocol path:** Choose Path → Compounds → Dosing → Schedule → Review (no goal step)

---

### **Data & Storage**

- A new compound-to-unit mapping system determines the correct unit for each compound
- The database field `dose_mcg` continues to store values in mcg internally for consistency — compounds dosed in mg are converted (e.g. 2.5 mg stored as 2500 mcg) and displayed back in mg
- Past dose entries are saved to the existing `dose_logs` table with the user-specified dates
