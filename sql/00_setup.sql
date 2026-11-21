/* 00_setup.sql
   Creates the database and one schema per layer.
     raw   = file as-is, every column text
     stg   = same rows, typed (numbers, dates), nothing removed
     clean = filtered, tidy scorecard tables (02_clean.sql)
     mart  = views Power BI reads (04_powerbi_views.sql)
   Safe to re-run.
*/
IF DB_ID(N'OntarioScorecard') IS NULL
    CREATE DATABASE OntarioScorecard;
GO
USE OntarioScorecard;
GO
IF SCHEMA_ID(N'raw')   IS NULL EXEC(N'CREATE SCHEMA raw');
IF SCHEMA_ID(N'stg')   IS NULL EXEC(N'CREATE SCHEMA stg');
IF SCHEMA_ID(N'clean') IS NULL EXEC(N'CREATE SCHEMA clean');
IF SCHEMA_ID(N'mart')  IS NULL EXEC(N'CREATE SCHEMA mart');
GO
