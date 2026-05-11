// PrintService — ESC/POS thermal printing is no longer used.
// All printing (kitchen slips & customer bills) is handled via PDF
// through BillService using the `printing` + `pdf` packages, which
// are fully compatible with Windows, Linux, macOS, and web.
//
// This file is kept as a stub for backward compatibility.

class PrintService {
  // Intentionally empty — see BillService for PDF-based printing.
}
