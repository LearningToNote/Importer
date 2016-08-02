SET SCHEMA "LTN_DEVELOP";

DROP TABLE "PAIRS";
DROP TABLE "OFFSETS";
DROP TABLE "ENTITIES";
DROP TABLE "USER_DOCUMENTS";
DROP TABLE "USERS";
DROP TABLE "DOCUMENTS";
DROP TABLE "TYPES";
DROP TABLE "POS_TAGS";


CREATE COLUMN TABLE "DOCUMENTS" (
    "ID" VARCHAR(255) PRIMARY KEY,
    "TASK" INT
);

CREATE COLUMN TABLE "USERS" (
    "ID" VARCHAR(255) PRIMARY KEY,
    "NAME" VARCHAR(255),
    "TOKEN" VARCHAR(1024),
    "DESCRIPTION" NVARCHAR(255),
    "IMAGE" CLOB
);

CREATE COLUMN TABLE "USER_DOCUMENTS" (
    "ID" VARCHAR(255) PRIMARY KEY,
    "USER_ID" VARCHAR(255),
    "DOCUMENT_ID" VARCHAR(255),
    "VISIBILITY" TINYINT,
    "CREATED_AT" TIMESTAMP,
    "UPDATED_AT" TIMESTAMP

    -- FOREIGN KEY("USER_ID") REFERENCES "USERS",
    -- FOREIGN KEY("DOCUMENT_ID") REFERENCES "DOCUMENTS"
);

CREATE COLUMN TABLE "TYPES" (
    "ID" INT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    "CODE" VARCHAR(255),
    "GROUP_ID" VARCHAR(255),
    "GROUP" VARCHAR(255),
    "NAME" VARCHAR(255)
);

CREATE COLUMN TABLE "ENTITIES" (
    "ID" VARCHAR(255),
    "USER_DOC_ID" VARCHAR(255),
    "TYPE_ID" INT,
    "LABEL" VARCHAR(255),
    "TEXT" VARCHAR(255),

    PRIMARY KEY("ID", "USER_DOC_ID")
    -- FOREIGN KEY("USER_DOC_ID") REFERENCES "USER_DOCUMENTS",
    -- FOREIGN KEY("TYPE_ID") REFERENCES "TYPES"
);

CREATE COLUMN TABLE "OFFSETS" (
    "START" INT,
    "END" INT,
    "ENTITY_ID" VARCHAR(255),
    "USER_DOC_ID" VARCHAR(255)

    -- FOREIGN KEY("ENTITY_ID", "USER_DOC_ID") REFERENCES "ENTITIES"("ID", "USER_DOC_ID")
);

CREATE COLUMN TABLE "PAIRS" (
    "ID" INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "E1_ID" VARCHAR(255),
    "E2_ID" VARCHAR(255),
    "USER_DOC_ID" VARCHAR(255),
    "DDI" TINYINT,
    "TYPE_ID" INT,
    "LABEL" VARCHAR(255)

    -- FOREIGN KEY("E1_ID", "USER_DOC_ID") REFERENCES "ENTITIES"("ID", "USER_DOC_ID"),
    -- FOREIGN KEY("E2_ID", "USER_DOC_ID") REFERENCES "ENTITIES"("ID", "USER_DOC_ID"),
    -- FOREIGN KEY("TYPE_ID") REFERENCES "TYPES"
);

CREATE COLUMN TABLE "POS_TAGS" (
    "ID" INTEGER GENERATED BY DEFAULT AS IDENTITY,
    "POS" VARCHAR(255)
);

DROP TABLE "STOPWORDS";
CREATE COLUMN TABLE "STOPWORDS" (
    "STOPWORD" VARCHAR(255)
);

DROP TABLE "TASKS";
CREATE COLUMN TABLE "TASKS" (
    "ID" INT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    "NAME" VARCHAR(255),
    "DOMAIN" VARCHAR(255),
    "CONFIG" VARCHAR(255),
    "AUTHOR" VARCHAR(255)
);

DROP TABLE "TASK_TYPES";
CREATE COLUMN TABLE "TASK_TYPES" (
    "ID" INT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    "LABEL" VARCHAR(255),
    "TASK_ID" INT NOT NULL,
    "TYPE_ID" INT NOT NULL,
    "RELATION" TINYINT
);

DROP TYPE T_INDEX;
CREATE TYPE T_INDEX AS TABLE ("DOCUMENT_ID" VARCHAR(255),
     "TA_RULE" NVARCHAR(200),
     "TA_COUNTER" BIGINT CS_FIXED,
     "TA_TOKEN" NVARCHAR(5000),
     "TA_LANGUAGE" NVARCHAR(2),
     "TA_TYPE" NVARCHAR(100),
     "TA_NORMALIZED" NVARCHAR(5000),
     "TA_STEM" NVARCHAR(5000),
     "TA_PARAGRAPH" INTEGER CS_INT,
     "TA_SENTENCE" INTEGER CS_INT,
     "TA_CREATED_AT" LONGDATE CS_LONGDATE,
     "TA_OFFSET" BIGINT CS_FIXED,
     "TA_PARENT" BIGINT CS_FIXED);

-- Example Task:
--   CALL add_task('Biomedical Domain', 'BIO_TEXTS', 'LTN::ltn_analysis', 'dr.schneider', ?);
--
-- Parameters:
--   NAME       Some user-friendly name for the task
--   DOMAIN     Name of the table and part of the name of the accompanying full text index
--              -> Table: "BIO_TEXTS", Full Text Index: "INDEX_BIO_TEXTS", Index Output: "$TA_INDEX_BIO_TEXTS"
--   CONFIG     Text analysis configuration to use for the entity recognition full text index
--   AUTHOR     optionally specify who's in charge

DROP PROCEDURE add_task;
CREATE PROCEDURE add_task(IN task_name nvarchar(255), IN table_name nvarchar(255), IN er_analysis_config nvarchar(255), IN new_author nvarchar(255), OUT task_id INT) LANGUAGE SQLSCRIPT AS
BEGIN
    INSERT INTO TASKS (name, domain, config, author) VALUES (task_name, table_name, er_analysis_config, new_author);
    SELECT MAX(id) INTO task_id FROM TASKS;
    EXECUTE IMMEDIATE 'CREATE COLUMN TABLE "' || table_name || '" (DOCUMENT_ID VARCHAR(255) PRIMARY KEY, TEXT NCLOB, ER_TEXT NCLOB)';
    EXECUTE IMMEDIATE 'CREATE FULLTEXT INDEX "INDEX_' || table_name || '" ON "' || table_name || '"("TEXT") LANGUAGE DETECTION (''EN'', ''DE'') ASYNC PHRASE INDEX RATIO 0.0 CONFIGURATION ''LINGANALYSIS_FULL'' SEARCH ONLY OFF FAST PREPROCESS OFF TEXT ANALYSIS ON TOKEN SEPARATORS ''\/;,.:-_()[]<>!?*@+{}="&#$~|''';
    EXECUTE IMMEDIATE 'CREATE FULLTEXT INDEX "ER_INDEX_' || table_name || '" ON "' || table_name || '"("ER_TEXT") LANGUAGE DETECTION (''EN'') CONFIGURATION ''' || er_analysis_config || ''' TEXT ANALYSIS ON';
END;

DROP PROCEDURE update_task;
CREATE PROCEDURE update_task(IN task_id Int, IN task_name nvarchar(255), IN table_name nvarchar(255), IN er_analysis_config nvarchar(255), IN new_author nvarchar(255)) LANGUAGE SQLSCRIPT AS
BEGIN
    DECLARE old_table varchar(255);
    DECLARE old_config varchar(255);

    SELECT concat(t.domain, '') INTO old_table FROM TASKS t WHERE t.id = task_id;
    SELECT concat(t.config, '') INTO old_config FROM TASKS t WHERE t.id = task_id;

    IF table_name != old_table THEN
        DELETE FROM DOCUMENTS WHERE task = task_id;
        EXECUTE IMMEDIATE 'DROP TABLE "' || old_table || '" CASCADE';
        EXECUTE IMMEDIATE 'CREATE COLUMN TABLE ' || table_name || ' (DOCUMENT_ID VARCHAR(255) PRIMARY KEY, TEXT NCLOB, ER_TEXT NCLOB)';
        EXECUTE IMMEDIATE 'CREATE FULLTEXT INDEX INDEX_' || table_name || ' ON "' || table_name || '"("TEXT") LANGUAGE DETECTION (''EN'', ''DE'') ASYNC PHRASE INDEX RATIO 0.0 CONFIGURATION ''LINGANALYSIS_FULL'' SEARCH ONLY OFF FAST PREPROCESS OFF TEXT ANALYSIS ON TOKEN SEPARATORS ''\/;,.:-_()[]<>!?*@+{}="&#$~|''';
        EXECUTE IMMEDIATE 'CREATE FULLTEXT INDEX ER_INDEX_' || table_name || ' ON "' || table_name || '"("ER_TEXT")LANGUAGE DETECTION (''EN'') CONFIGURATION ''' || er_analysis_config || ''' TEXT ANALYSIS ON';
    ELSEIF old_config != er_analysis_config THEN
        EXECUTE IMMEDIATE 'DROP FULLTEXT INDEX "ER_INDEX_' || old_table || '"';
        EXECUTE IMMEDIATE 'CREATE FULLTEXT INDEX ER_INDEX_' || table_name || ' ON "' || table_name || '"("ER_TEXT") LANGUAGE DETECTION (''EN'') CONFIGURATION ''' || er_analysis_config || ''' TEXT ANALYSIS ON';
    END IF;
    UPDATE TASKS SET "NAME" = task_name, "DOMAIN" = table_name, "CONFIG" = er_analysis_config, "AUTHOR" = new_author WHERE "ID" = task_id;
END;

DROP PROCEDURE delete_task;
CREATE PROCEDURE delete_task(IN task_id Int) LANGUAGE SQLSCRIPT AS
BEGIN
    DECLARE table_id nvarchar(255);
    SELECT concat(t.domain, '') INTO table_id FROM tasks t WHERE t.id = task_id;
    EXECUTE IMMEDIATE 'DROP TABLE "' || table_id || '" CASCADE';
    DELETE FROM TASKS WHERE "ID" = task_id;
    DELETE FROM DOCUMENTS WHERE "TASK" = task_id;
END;

DROP PROCEDURE add_document;
CREATE PROCEDURE add_document(IN document_id varchar(255), IN document_text NCLOB, IN task INT) LANGUAGE SQLSCRIPT AS
BEGIN
    DECLARE table_id nvarchar(255);
    SELECT concat(t.domain, '') INTO table_id FROM tasks t WHERE t.id = task;
    INSERT INTO DOCUMENTS VALUES (document_id, task);
    EXECUTE IMMEDIATE 'INSERT INTO "' || :table_id || '" VALUES (''' || document_id || ''', ''' || document_text || ''', ''' || lower(document_text) || ''')';
END;

DROP PROCEDURE delete_document;
CREATE PROCEDURE delete_document(IN document_id varchar(255)) LANGUAGE SQLSCRIPT AS
BEGIN
    DECLARE table_id nvarchar(255);
    SELECT concat(t.domain, '') INTO table_id FROM tasks t JOIN documents d ON d.task = t.id WHERE d.id = document_id;
    EXECUTE IMMEDIATE 'DELETE FROM "' || :table_id || '" WHERE document_id = ''' || document_id || '''';
    DELETE FROM DOCUMENTS WHERE id = :document_id;
    user_document_ids = SELECT ud.id FROM USER_DOCUMENTS ud WHERE ud.document_id = :document_id;
    DELETE FROM OFFSETS WHERE USER_DOC_ID IN (SELECT ID FROM :user_document_ids);
    DELETE FROM PAIRS WHERE USER_DOC_ID IN (SELECT ID FROM :user_document_ids);
    DELETE FROM ENTITIES WHERE USER_DOC_ID IN (SELECT ID FROM :user_document_ids);
    DELETE FROM USER_DOCUMENTS WHERE document_id = :document_id;
END;

DROP PROCEDURE get_document_content;
CREATE PROCEDURE get_document_content(IN document_id varchar(255), OUT text NCLOB) LANGUAGE SQLSCRIPT AS
BEGIN
    DECLARE table_id nvarchar(255);
    SELECT concat(t.domain, '') INTO table_id FROM TASKS t JOIN DOCUMENTS d ON d.task = t.id WHERE d.id = document_id;
    CREATE LOCAL TEMPORARY COLUMN TABLE "#temp" ("DOCUMENT_ID" varchar(255), "TEXT" nclob);
    EXECUTE IMMEDIATE 'INSERT INTO "#temp" SELECT document_id, text FROM "' || :table_id || '" WHERE document_id = ''' || document_id || '''';
    SELECT "TEXT" INTO text FROM "#temp";
    DROP TABLE "#temp";
END;

DROP PROCEDURE get_fulltext_index;
CREATE PROCEDURE get_fulltext_index(IN document_id varchar(255), OUT o_index T_INDEX) LANGUAGE SQLSCRIPT AS
BEGIN
    DECLARE table_id nvarchar(255);
    SELECT concat(t.domain, '') INTO table_id FROM tasks t JOIN documents d ON d.task = t.id WHERE d.id = document_id;
    table_id := '$TA_INDEX_' || table_id;
    CREATE LOCAL TEMPORARY COLUMN TABLE "#temp" LIKE T_INDEX;
    EXECUTE IMMEDIATE 'INSERT INTO "#temp" SELECT * FROM "' || :table_id || '";';
    o_index = SELECT * FROM "#temp";
    DROP TABLE "#temp";
END;

DROP PROCEDURE get_fulltext_index_for_task;
CREATE PROCEDURE get_fulltext_index_for_task(IN task_id Int, OUT o_index T_INDEX) LANGUAGE SQLSCRIPT AS
BEGIN
    DECLARE table_id nvarchar(255);
    SELECT concat(t.domain, '') INTO table_id FROM tasks t WHERE t.id = task_id;
    table_id := '$TA_INDEX_' || table_id;
    CREATE LOCAL TEMPORARY COLUMN TABLE "#temp" LIKE T_INDEX;
    EXECUTE IMMEDIATE 'INSERT INTO "#temp" SELECT * FROM "' || :table_id || '";';
    o_index = SELECT * FROM "#temp";
    DROP TABLE "#temp";
END;

DROP PROCEDURE get_er_index;
CREATE PROCEDURE get_er_index(IN document_id varchar(255), OUT o_index T_INDEX) LANGUAGE SQLSCRIPT AS
BEGIN
    DECLARE table_id nvarchar(255);
    SELECT concat(t.domain, '') INTO table_id FROM tasks t JOIN documents d ON d.task = t.id WHERE d.id = document_id;
    table_id := '$TA_ER_INDEX_' || table_id;
    CREATE LOCAL TEMPORARY COLUMN TABLE "#temp" LIKE T_INDEX;
    EXECUTE IMMEDIATE 'INSERT INTO "#temp" SELECT * FROM "' || :table_id || '"';
    o_index = SELECT * FROM "#temp";
    DROP TABLE "#temp";
END;

DROP PROCEDURE get_er_index_for_task;
CREATE PROCEDURE get_er_index_for_task(IN task_id Int, OUT o_index T_INDEX) LANGUAGE SQLSCRIPT AS
BEGIN
    DECLARE table_id nvarchar(255);
    SELECT concat(t.domain, '') INTO table_id FROM tasks t WHERE t.id = task_id;
    table_id := '$TA_ER_INDEX_' || table_id;
    CREATE LOCAL TEMPORARY COLUMN TABLE "#temp" LIKE T_INDEX;
    EXECUTE IMMEDIATE 'INSERT INTO "#temp" SELECT * FROM "' || :table_id || '";';
    o_index = SELECT * FROM "#temp";
    DROP TABLE "#temp";
END;
