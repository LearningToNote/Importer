SET SCHEMA "MP12015"

DROP FULLTEXT INDEX "FTI";
CREATE FULLTEXT INDEX "FTI" ON "SENTENCE" ("TEXT")
  TEXT ANALYSIS ON
  CONFIGURATION 'EXTRACTION_CORE_VOICEOFCUSTOMER';