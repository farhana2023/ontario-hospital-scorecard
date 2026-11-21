/* run_all.sql - rebuilds everything from the CSV.
   Run in SSMS with SQLCMD Mode on (Query menu > SQLCMD Mode), or from a prompt:
     sqlcmd -S localhost -E -i run_all.sql
   Set the CSV path at the top of 01_load.sql first. */
-- Change to the full path of this sql folder:
:setvar SqlDir "C:\projects\ontario-hospital-scorecard\sql"
:r $(SqlDir)\00_setup.sql
:r $(SqlDir)\01_load.sql
:r $(SqlDir)\02_clean.sql
:r $(SqlDir)\03_analysis.sql
:r $(SqlDir)\04_powerbi_views.sql
